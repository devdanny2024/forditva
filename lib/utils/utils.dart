import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client

Future<bool> isTextInLanguage(
  String text,
  String langCode,
  GeminiTranslator gemini,
) async {
  final detected = await gemini.detectLanguage(text);
  return detected == langCode.toUpperCase();
}
