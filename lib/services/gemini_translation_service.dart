import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'token_usage.dart';

class GeminiTranslator {
  final GenerativeModel _model;

  GeminiTranslator()
    : _model = GenerativeModel(
        // flash-lite is markedly faster and does little/no "thinking",
        // which is what was adding latency to every translation.
        model: 'gemini-2.5-flash-lite',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
      );

  /// Adds this response's token cost to the global tally.
  void _recordUsage(GenerateContentResponse response) {
    TokenUsage.instance.add(response.usageMetadata?.totalTokenCount ?? 0);
  }

  static const Map<String, String> _uiLanguageNames = {
    'DE': 'German',
    'EN': 'English',
    'HU': 'Hungarian',
  };

  Future<String> translate(
    String inputText,
    String fromLang,
    String toLang, {
    bool explain = false,
    String level = 'A2',
    // Language the Tutor explanation itself is written in. Must be the app's
    // UI language (e.g. German), not the content languages being translated
    // (fromLang/toLang), which is what was causing explanations to come out
    // in whatever the document's input language happened to be.
    String uiLanguage = 'EN',
  }) async {
    if (!explain) {
      // Dedicated stateless translation engine. Strict rules live in the
      // systemInstruction (a hard boundary from the data), temperature 0 makes
      // it deterministic, and the raw text is sent as the user message with no
      // surrounding quotes — all to stop flash-lite "chatting" or adding quotes.
      final translateModel = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
        systemInstruction: Content.system('''
You are a precise literal translation engine.
Task: Translate the user's text from $fromLang to $toLang.

Rules:
- Translate exactly what is written. Do NOT omit any words, adjectives, or conversational elements present in the source text.
- Do NOT add quotation marks, commentary, punctuation, or formatting.
- Output ONLY the raw translation string.
'''),
        generationConfig: GenerationConfig(temperature: 0.0),
      );

      final response = await translateModel.generateContent([
        Content.text(inputText),
      ]);
      _recordUsage(response);
      return response.text?.trim() ?? '';
    } else {
      // Explanation mode with level adaptation
      final explanationLanguage = _uiLanguageNames[uiLanguage] ?? uiLanguage;
      final prompt = '''
You are a highly skilled Hungarian language tutor specialized in CEFR levels. The student is at level $level.

Your task: Analyze and explain the following Hungarian sentence:
"$inputText"

Write your entire explanation (grammar_explanation and key_vocabulary) in $explanationLanguage, since that is the student's own language. Only Hungarian words/phrases being explained should stay in Hungarian; everything else must be in $explanationLanguage.

Step-by-step process for your analysis:
1. First, identify the main verb and its tense/mood.
2. Identify the word order and whether it follows the default (topic-comment) structure or has an emphasis.
3. Identify all suffixes (case endings, possessive, plural, verb conjugations) and explain their function.
4. Note any vowel harmony changes or linking vowels.
5. Identify if any verb prefixes are present and whether they are attached or separated.

Adapt explanations based on the student's level:

- If level is A1:
    - Use extremely simple and clear language.
    - Focus only on: basic word order, present tense, definite vs. indefinite conjugation (only if present), singular/plural, and the most basic suffixes (-ban/-ben, -nál/-nél).
    - Avoid terminology like "accusative", "dative", "mood", "prefix". Instead say "object form", "to/for whom", "direction".
    - Introduce only 2–3 new vocabulary words from the sentence. Ignore the rest.

- If level is A2:
    - Use simple but more detailed explanations.
    - Cover: accusative (-t), dative (-nak/-nek), basic past tense, common suffixes (-ból/-ből, -hoz/-hez/-höz, -on/-en/-ön).
    - Explain basic verb conjugation (definite/indefinite) if relevant.
    - Introduce 3–5 new words with simple example sentences for each.

- If level is B1:
    - Provide comprehensive grammar explanations.
    - Cover: multiple cases in one sentence, verb prefixes (meg-, el-, ki-, be-) and their meaning, conditional mood, subjunctive, participles (-ó/-ő, -t/-tt), complex word order with emphasis.
    - Explain idiomatic phrases and offer 1–2 synonyms for key vocabulary.
    - Mention if the sentence is formal or informal.

Additional rules for ALL levels (critical):
- Never use linguistic jargon without immediate plain-language translation (e.g., say "this is the object form" not "accusative case").
- Always explain WHY a suffix or word order is used, not just WHAT it is.
- Provide 1 short, level-appropriate example for the most important grammar point.
- Do NOT explain words the learner likely already knows at their level (e.g., basic greetings, numbers, common verbs like van/lesz).
- Always mention if the sentence is neutral, formal, or colloquial, because this is often not obvious to learners.
- If the sentence contains a common mistake trap (e.g., similarity to German/English), warn the student.

Output format (strict JSON, no extra text, no markdown formatting inside the JSON values):
{
  "grammar_explanation": "...",
  "key_vocabulary": "...",
  "translation": "..."
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      _recordUsage(response);
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
    _recordUsage(response);
    return response.text?.trim().toUpperCase() ?? '';
  }
}
