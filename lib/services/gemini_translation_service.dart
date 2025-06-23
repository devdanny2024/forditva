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
    if (!explain) {
      // Regular translation logic
      final prompt = '''
Translate the following text from $fromLang to $toLang.

Output only the translated sentence. Do not include any additional notes, formatting, titles, markdown, or explanations.

Text to translate:
"$inputText"
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } else {
      // Explanation mode with level adaptation
      final prompt = '''
You are a highly skilled Hungarian language tutor specialized in CEFR levels. The student is at level $level.

Your task: Analyze and explain the following sentence:
"$inputText"

Adapt explanations based on the student's level:

- If level is A1:
    - Use extremely simple and clear language.
    - Focus only on very basic grammar: word order, present tense, simple suffixes, singular/plural.
    - Avoid complex grammatical structures like cases, moods, or exceptions.
    - Introduce only absolutely necessary new vocabulary.

- If level is A2:
    - Use simple but more detailed explanations.
    - Cover common grammar topics like cases (accusative, dative), basic verb conjugations, tenses, and typical suffixes.
    - Introduce useful vocabulary that helps understand the sentence, with simple definitions.

- If level is B1:
    - Provide more comprehensive grammar explanations.
    - Cover more complex Hungarian structures: multiple cases, verb prefixes, complex word order, conditional, subjunctive, participles.
    - Introduce more nuanced vocabulary, idiomatic phrases, and synonyms.

- For all levels:
    - Do NOT use complex linguistic jargon.
    - Keep the tone as if explaining to an actual language learner.
    - Provide simple examples for grammar points where possible.
    - Never explain words the learner likely already knows at their level.

Output format (strict JSON, no extra text):
{
  "grammar_explanation": "...",
  "key_vocabulary": "...",
  "translation": "..."
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      return text;
    }
  }

  Stream<String> streamTranslate(
    String input,
    String from,
    String to, {
    bool explain = false,
  }) async* {
    final full = await translate(input, from, to, explain: explain);
    for (int i = 0; i < full.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
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
