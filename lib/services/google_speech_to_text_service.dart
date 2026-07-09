import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GoogleSpeechToTextService {
  final String apiKey;

  GoogleSpeechToTextService(this.apiKey);

  Future<String?> transcribe(
    File audioFile, {
    String languageCode = 'en-US',
  }) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final url = 'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';
    final requestBody = {
      "config": {
        "encoding": "LINEAR16", // Use "FLAC" for .flac files
        "sampleRateHertz": 16000,
        "languageCode": languageCode,
      },
      "audio": {"content": base64Audio},
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'];
      if (results != null && results.isNotEmpty) {
        return results[0]['alternatives'][0]['transcript'];
      }
      return '';
    } else {
      throw Exception('Google STT Error: ${response.body}');
    }
  }

  /// Like [transcribe] but also returns the recognizer's confidence (0–1).
  /// When the wrong language is spoken for the requested [languageCode],
  /// confidence comes back low — we use that to prompt the user.
  Future<({String text, double confidence})> transcribeWithConfidence(
    File audioFile, {
    String languageCode = 'en-US',
  }) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final url = 'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';
    final requestBody = {
      "config": {
        "encoding": "LINEAR16",
        "sampleRateHertz": 16000,
        "languageCode": languageCode,
      },
      "audio": {"content": base64Audio},
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Google STT Error: ${response.body}');
    }
    final data = jsonDecode(response.body);
    final results = data['results'];
    if (results == null || results.isEmpty) {
      return (text: '', confidence: 0.0);
    }
    final alt = results[0]['alternatives'][0];
    final text = (alt['transcript'] ?? '') as String;
    final conf = (alt['confidence'] ?? 0.0) as num;
    return (text: text, confidence: conf.toDouble());
  }
}
