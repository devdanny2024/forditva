import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class ChatGptService {
  ChatGptService();

  String get _apiKey => dotenv.env['OPENAI_API_KEY']!;
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  // Maps for pretty names, date formats, etc.
  static const Map<String, String> _langNames = {
    "EN": "English",
    "DE": "German",
    "HU": "Hungarian",
  };

  static const Map<String, String> _langNativeNames = {
    "EN": "angol", // "English" in Hungarian
    "DE": "német", // "German" in Hungarian
    "HU": "magyar", // "Hungarian" in Hungarian
  };

  static const Map<String, String> _dateFormats = {
    "EN": "MM/DD/YYYY",
    "DE": "DD.MM.YYYY",
    "HU": "YYYY.MM.DD",
  };

  // Dynamic translation prompt, fully localized
  String _buildTranslationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;
    final targetDateFormat = _dateFormats[toLang] ?? "YYYY-MM-DD";

    return '''
Attached is an image containing $fromLangName text. The target language is $toLangName.

Your task:
- Extract only the $fromLangName text segments from the image that are fully and clearly visible. Do not include any text that is cut off or only partially visible.
- If a segment is not clearly legible or you are uncertain about it, set its "o" value to "{unsafe}" and its "t" value to "{unsafe}".
- Translate each clearly legible segment individually into the specified target language, preserving the original meaning and context.
- Convert any dates into the locale format of the target language ($targetDateFormat).
- Output a JSON array of objects, where each object has two fields:
  - "o": the original $fromLangName line or segment (or "{unsafe}")
  - "t": the translation in $toLangName (or "{unsafe}")
Do not add any explanations, summaries, or additional information.
''';
  }

  // Dynamic interpretation/summarization prompt, fully localized
  String _buildInterpretationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;
    // Output HTML instructions in the target language if you wish, or in English for now.

    // (For brevity, this is English. For full i18n, you can expand it with switch/case/Map per toLang.)
    return '''
Attached is an image containing $fromLangName text. This text can be from various sources such as official documents (e.g., invoices, bills, notices), signs, advertisements, menus, instructions, or any other kind of informational content.

Important:
- Only provide details that are explicitly and clearly visible in the original image. Never guess, supplement, autocorrect, or assume missing or unclear information—even if it seems obvious.
- If any field (names, addresses, numbers, etc.) is partly illegible or uncertain, write "illegible" or "not clearly identifiable".
- Always reproduce names, addresses, and other data exactly as shown, preserving spelling, special characters, and any peculiarities.

Your task:
- Recognize and extract the main information and key details from the text—**only if clearly legible**.
- Understand the context and purpose (e.g., payment request, product information, directions, promotion).
- Generate a clear, concise, and user-friendly summary explaining what the text is about and what actions or points are important.
- Format the output in $toLangName as HTML, using appropriate structure:
  -- Headings for main sections
  -- Paragraphs for explanations
  -- Lists for instructions or key points
  -- Emphasis (e.g., <strong>) to highlight important facts like dates, amounts, or names

The goal: Provide a helpful explanation for users who might not fully understand the original $fromLangName text, making the information easy to read and act upon, while ensuring all factual details are reported exactly as they appear and only when fully certain.
''';
  }

  /// Main method for processing the image
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

    // DYNAMIC: pick the prompt per requested operation and language
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
                "You are an AI assistant specialized in image translation & interpretation.",
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
        'model': 'gpt-4.1', // Or your vision-capable model
        'messages': messages,
        'temperature': 0.2,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }
}
