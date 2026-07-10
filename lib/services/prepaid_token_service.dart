import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// What went wrong when redeeming a prepaid code, so the UI can pick the
/// right message (see the "Error handling checklist" in the API docs).
enum PrepaidErrorKind {
  /// Wrong, expired, already-used, or malformed code (HTTP 400 / bad format).
  invalidCode,

  /// HTTP 429 — the user should wait ~60s and try again.
  rateLimited,

  /// No connection, timeout, or unreadable response.
  network,

  /// Server misconfiguration (base URL not set, or bad/missing API key).
  /// Not the user's fault; the app shows a neutral "unavailable" message.
  config,
}

class PrepaidTokenException implements Exception {
  final PrepaidErrorKind kind;
  final String message;
  PrepaidTokenException(this.kind, this.message);

  @override
  String toString() => 'PrepaidTokenException($kind): $message';
}

/// Redeems 8-character prepaid codes against the WordPress "app-translation"
/// API. The code walks a two-step lifecycle: [verify] locks it
/// (active -> processing), then [finalize] commits it (processing -> used).
///
/// Configuration comes from `.env` (also add these to the GitHub `DOTENV`
/// secret so iOS builds pick them up):
///   PREPAID_API_BASE_URL  e.g. https://example.com/wp-json/app-translation/v1
///   PREPAID_API_KEY       shared secret; omit the header when empty
///
/// If PREPAID_API_BASE_URL is empty the service throws [PrepaidErrorKind.config],
/// so the feature stays dormant until the real values are filled in.
class PrepaidTokenService {
  static final RegExp _codePattern = RegExp(r'^[A-Za-z0-9]{8}$');

  String get _baseUrl => (dotenv.env['PREPAID_API_BASE_URL'] ?? '').trim();
  String get _apiKey => (dotenv.env['PREPAID_API_KEY'] ?? '').trim();

  /// True when [code] is exactly 8 alphanumeric characters. The docs ask the
  /// client to check this first to avoid pointless calls.
  bool isValidFormat(String code) => _codePattern.hasMatch(code.trim());

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) headers['X-Api-Key'] = _apiKey;
    return headers;
  }

  /// Verifies then finalizes [rawCode], returning the integer token value that
  /// was redeemed. Throws [PrepaidTokenException] on any failure.
  Future<int> redeem(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (!isValidFormat(code)) {
      throw PrepaidTokenException(
        PrepaidErrorKind.invalidCode,
        'Code must be 8 alphanumeric characters',
      );
    }
    final value = await _verify(code);
    await _finalize(code);
    return value;
  }

  /// active -> processing. Returns the code's integer token value.
  Future<int> _verify(String code) async {
    final body = await _post('verify', code);
    final value = body['value'];
    if (value is num) return value.toInt();
    throw PrepaidTokenException(
      PrepaidErrorKind.invalidCode,
      'Response had no token value',
    );
  }

  /// processing -> used.
  Future<void> _finalize(String code) => _post('finalize', code);

  Future<Map<String, dynamic>> _post(String endpoint, String code) async {
    if (_baseUrl.isEmpty) {
      throw PrepaidTokenException(
        PrepaidErrorKind.config,
        'PREPAID_API_BASE_URL is not set',
      );
    }

    final uri = Uri.parse('$_baseUrl/$endpoint');
    final payload = jsonEncode({'code': code});

    // The host intermittently returns 5xx (observed: 507 Insufficient Storage),
    // so retry a few times before surfacing a network error.
    for (var attempt = 1; ; attempt++) {
      http.Response res;
      try {
        res = await http
            .post(uri, headers: _headers, body: payload)
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw PrepaidTokenException(
          PrepaidErrorKind.network,
          'Request timed out',
        );
      } catch (e) {
        throw PrepaidTokenException(
          PrepaidErrorKind.network,
          'Network error: $e',
        );
      }

      if (res.statusCode >= 500 && attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      if (res.statusCode == 429) {
        throw PrepaidTokenException(
          PrepaidErrorKind.rateLimited,
          'Too many attempts',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw PrepaidTokenException(
          PrepaidErrorKind.config,
          'Missing or invalid API key',
        );
      }
      if (res.statusCode >= 500) {
        throw PrepaidTokenException(
          PrepaidErrorKind.network,
          'Server error ${res.statusCode}',
        );
      }

      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = const {};
      }

      if (res.statusCode == 200 && body['status'] == 'success') {
        return body;
      }

      // 400 and anything else: treat as an invalid/unusable code per the docs.
      throw PrepaidTokenException(
        PrepaidErrorKind.invalidCode,
        (body['message'] as String?) ?? 'Code invalid or already in use',
      );
    }
  }
}
