import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Server-side guard for the one-time WIU welcome bonus, so uninstalling and
/// reinstalling the app on Android can't re-claim it (Markus, 2026-07-12;
/// see TokenBalance.grantWelcomeIfFirstRun). Uses the same app-translation/v1
/// API and X-Api-Key auth as PrepaidTokenService's verify/finalize.
class WelcomeGrantService {
  String get _baseUrl => (dotenv.env['PREPAID_API_BASE_URL'] ?? '').trim();
  String get _apiKey => (dotenv.env['PREPAID_API_KEY'] ?? '').trim();

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) headers['X-Api-Key'] = _apiKey;
    return headers;
  }

  /// True if [deviceId] already claimed the bonus. Throws on any network,
  /// config, or server error — callers should treat that as "unknown" and
  /// fall back to the local-only flag rather than block the app on startup.
  Future<bool> checkGranted(String deviceId) async {
    final body = await _post('welcome-grant/check', deviceId);
    return body['granted'] == true;
  }

  /// Records that [deviceId] just claimed the bonus. Safe to call more than
  /// once — the server treats it as idempotent.
  Future<void> claim(String deviceId) =>
      _post('welcome-grant/claim', deviceId);

  Future<Map<String, dynamic>> _post(String endpoint, String deviceId) async {
    if (_baseUrl.isEmpty) {
      throw Exception('PREPAID_API_BASE_URL is not set');
    }
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final payload = jsonEncode({'device_id': deviceId});
    final res = await http
        .post(uri, headers: _headers, body: payload)
        .timeout(const Duration(seconds: 10));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      body = const {};
    }
    if (res.statusCode == 200 && body['status'] == 'success') return body;
    throw Exception('welcome-grant/$endpoint failed: HTTP ${res.statusCode}');
  }
}
