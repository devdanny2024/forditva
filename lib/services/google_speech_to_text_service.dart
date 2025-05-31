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
}
