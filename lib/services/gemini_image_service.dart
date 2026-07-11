import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'gemini_cost.dart';
import 'token_balance.dart';

/// Image translation / interpretation via Gemini vision.
///
/// Drop-in replacement for the old OpenAI-based ChatGptService: same
/// [processImage] signature, so the Image page is unchanged apart from the
/// service it instantiates.
class GeminiImageService {
  GeminiImageService();

  String get _apiKey => dotenv.env['GEMINI_API_KEY']!;
  static const _model = 'gemini-flash-latest';
  String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

  static const Map<String, String> _langNames = {
    "EN": "English",
    "DE": "German",
    "HU": "Hungarian",
    "NL": "Dutch",
    "FR": "French",
    "ES": "Spanish",
    "RU": "Russian",
    "IT": "Italian",
  };

  static const Map<String, String> _dateFormats = {
    "EN": "MM/DD/YYYY",
    "DE": "DD.MM.YYYY",
    "HU": "YYYY.MM.DD",
    "NL": "DD-MM-YYYY",
    "FR": "DD/MM/YYYY",
    "ES": "DD/MM/YYYY",
    "RU": "DD.MM.YYYY",
    "IT": "DD/MM/YYYY",
  };

  String _buildTranslationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;
    final targetDateFormat = _dateFormats[toLang] ?? "YYYY-MM-DD";

    return '''
You are an AI assistant for image translation & document interpretation.

Attached is an image containing $fromLangName text. The target language is $toLangName.

Your task:
- Extract only fully visible $fromLangName text segments. Skip any partially visible, cut-off, or incomplete text.
- If a segment is not clearly legible, set both "o" and "t" fields to "{unsafe}".
- Translate each clearly legible segment individually into $toLangName.
- Convert any dates into $targetDateFormat.
- Do not add any explanations, summaries, or instructions.

STRICT OUTPUT FORMAT:
Return the result ONLY as valid JSON array, exactly like this:

[
  { "o": "original text here", "t": "translated text here" }
]

Do not add any comments, markdown, explanations, or text outside this JSON array. Only return valid JSON.
If you are unable to detect any text, return: []
''';
  }

  String _buildInterpretationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;

    return '''
You are an AI assistant for image translation & document interpretation.

Attached is an image containing $fromLangName text.

Instructions:
- Carefully extract and analyze the document content.
- Only use information that is fully visible and clearly readable.
- If anything is illegible or incomplete, say "illegible" or "not clearly identifiable".

Output:
Provide a clear summary in $toLangName using valid HTML structure:
- Use paragraphs for explanations.
- Use lists for instructions or key points.
- Use <strong> to highlight important facts (dates, amounts, names).
- Keep output minimal on whitespace.
- Do NOT wrap inside code blocks or markdown.

If nothing can be read, reply only with:
<p><strong>Can't understand the image</strong></p>
''';
  }

  Future<String> processImage({
    required File imageFile,
    required bool translate,
    required bool interpret,
    required String fromLangCode,
    required String toLangCode,
  }) async {
    if (!translate && !interpret) {
      throw Exception('Must select at least one: translate or interpret.');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

    final prompt =
        interpret
            ? _buildInterpretationPrompt(fromLangCode, toLangCode)
            : _buildTranslationPrompt(fromLangCode, toLangCode);

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {"mime_type": mimeType, "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 2048},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final usage = data['usageMetadata'] as Map<String, dynamic>?;
    TokenBalance.instance.spendFractional(
      geminiWiuCost(
        promptTokens: usage?['promptTokenCount'] as int? ?? 0,
        outputTokens: usage?['candidatesTokenCount'] as int? ?? 0,
      ),
    );

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final parts = candidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    final text = parts[0]['text'] as String? ?? '';
    return text.trim();
  }
}
