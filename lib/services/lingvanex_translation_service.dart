import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class LingvanexTranslationService {
  final String _baseUrl = 'https://api-b2b.backenster.com/b1/api/v3';
  final String _apiKey = dotenv.env['LINGVANEX_API_KEY']!;

  /// Translates [text] (String or List<String>) from [fromLang] to [toLang].
  /// If [fromLang] is null or empty, the API auto-detects the source language.
  /// [translateMode]: 'plain' or 'html'.
  /// [enableTransliteration]: if true, includes transliteration fields in the response.
  Future<dynamic> translate({
    dynamic data,
    String? fromLang,
    required String toLang,
    String translateMode = 'plain',
    bool enableTransliteration = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/translate');

    final bodyMap = <String, dynamic>{
      'to': toLang,
      'data': data,
      'translateMode': translateMode,
      'enableTransliteration': enableTransliteration,
      'platform': 'api',
    };

    if (fromLang != null && fromLang.isNotEmpty) {
      bodyMap['from'] = fromLang;
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(bodyMap),
    );

    switch (response.statusCode) {
      case 200:
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['result'];
      case 403:
        throw LingvanexException(
          'Authorization error: check your API key.',
          statusCode: response.statusCode,
          body: response.body,
        );
      default:
        throw LingvanexException(
          'Unexpected error',
          statusCode: response.statusCode,
          body: response.body,
        );
    }
  }
}

/// Custom exception for Lingvanex service errors.
class LingvanexException implements Exception {
  final String message;
  final int statusCode;
  final String body;

  LingvanexException(
    this.message, {
    required this.statusCode,
    required this.body,
  });

  @override
  String toString() =>
      'LingvanexException: $message (HTTP $statusCode) – $body';
}
