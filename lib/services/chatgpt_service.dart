import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChatGptService {
  ChatGptService();

  String get _apiKey => dotenv.env['OPENAI_API_KEY']!;
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  // Language name maps
  static const Map<String, String> _langNames = {
    "EN": "English",
    "DE": "German",
    "HU": "Hungarian",
  };

  static const Map<String, String> _dateFormats = {
    "EN": "MM/DD/YYYY",
    "DE": "DD.MM.YYYY",
    "HU": "YYYY.MM.DD",
  };

  String _buildTranslationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;
    final targetDateFormat = _dateFormats[toLang] ?? "YYYY-MM-DD";

    return '''
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

    final messages = [
      {
        "role": "system",
        "content": [
          {
            "type": "text",
            "text":
                "You are an AI assistant for image translation & document interpretation.",
          },
        ],
      },
      {
        "role": "user",
        "content": [
          {"type": "text", "text": prompt},
          {
            "type": "image_url",
            "image_url": {"url": "data:$mimeType;base64,$base64Image"},
          },
        ],
      },
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4.1',
        'messages': messages,
        'temperature': 0.2,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final result = data['choices'][0]['message']['content'] as String;

    return result.trim();
  }
}
