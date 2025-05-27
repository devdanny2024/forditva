import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiTranslator {
  final GenerativeModel _model;

  GeminiTranslator()
    : _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
      );
  Future<String> translate(
    String inputText,
    String fromLang,
    String toLang, {
    bool explain = false,
    String level = 'A2',
  }) async {
    String prompt;

    if (explain) {
      switch (level) {
        case 'A1':
          prompt =
              "Act like a basic language tutor. Provide a simple and minimal explanation of this sentence in $fromLang translated to $toLang: $inputText. "
              "Do not include any bold, underline, or other formatting—just the explanation text.";
          break;
        case 'A2':
          prompt =
              "You are a helpful language teacher. Explain the structure and vocabulary moderately for this $fromLang sentence translated to $toLang: $inputText. "
              "Do not include any styling or extra commentary—just the explanation text.";
          break;
        case 'A3':
          prompt =
              "Be a detailed linguistics coach. Break down the grammar, vocabulary, and meaning thoroughly for this sentence in $fromLang translated to $toLang: $inputText. "
              "Output only the explanation itself without any formatting.";
          break;
        default:
          // fallback to plain translation if level is unexpected
          prompt =
              "Translate the following text from $fromLang to $toLang. "
              "Output only the translated text with no styling or extra words: $inputText";
      }
    } else {
      prompt =
          "Translate the following text from $fromLang to $toLang. "
          "Output only the translated text with no bold, no styling, and no additional explanation: $inputText";
    }

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
  }

  Stream<String> streamTranslate(
    String input,
    String from,
    String to, {
    bool explain = false,
  }) async* {
    final full = await translate(input, from, to, explain: explain);
    for (int i = 0; i < full.length; i++) {
      await Future.delayed(Duration(milliseconds: 30)); // typing speed
      yield full[i];
    }
  }

  Future<String> detectLanguage(String inputText) async {
    final prompt = '''
Detect the language of the following text and reply with exactly the ISO 639-1 code (two uppercase letters), no other words:
$inputText
''';
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text?.trim().toUpperCase() ?? '';
  }
}
