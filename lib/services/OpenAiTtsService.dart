import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OpenAiTtsService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY']!;

  Future<File> synthesizeSpeech({
    required String text,
    required String voice, // e.g., 'coral', 'onyx', etc.
    String model = "gpt-4o-mini-tts", // Use latest model
    String format = "mp3", // or "wav", "pcm" for lower latency
    String? instructions, // e.g., "Speak in a cheerful tone."
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/speech');
    final reqBody = {
      "model": model,
      "input": text,
      "voice": voice,
      "response_format": format,
      "speed": 1.0,
    };
    if (instructions != null && instructions.isNotEmpty) {
      reqBody['instructions'] = instructions;
    }

    final response = await http.post(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(reqBody),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI TTS failed: ${response.statusCode} ${response.body}',
      );
    }

    // Save the audio file to a temp directory
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/openai_tts_${DateTime.now().millisecondsSinceEpoch}.$format',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }
}
