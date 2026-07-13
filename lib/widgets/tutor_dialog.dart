import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/gemini_translation_service.dart';
import '../services/learning_store.dart';
import '../utils/utils.dart';

const Color _navGreen = Color(0xFF436F4D);

/// Runs the Tutor (light-bulb) explanation for [hungarianText]: shows a loader,
/// asks Gemini for the grammar/vocabulary breakdown, saves it to the Learning
/// history, and shows it in a dialog. Reused from History and Favorites so the
/// user can revisit the grammar of any past translation (Markus's request).
Future<void> showTutorExplanation({
  required BuildContext context,
  required String hungarianText,
  String uiLang = 'DE',
  String level = 'A2',
}) async {
  final text = hungarianText.trim();
  if (text.isEmpty) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  String explanation;
  try {
    explanation = await GeminiTranslator().translate(
      text,
      'HU',
      uiLang,
      explain: true,
      level: level,
      uiLanguage: uiLang,
    );
    await LearningStore.add(sentence: text, explanation: explanation);
  } catch (_) {
    explanation = 'Failed to load explanation.';
  }

  if (!context.mounted) return;
  Navigator.of(context).pop(); // remove the loader

  Map<String, dynamic> parsed = {};
  try {
    final decoded = jsonDecode(stripCodeFence(explanation));
    if (decoded is Map<String, dynamic>) parsed = decoded;
  } catch (_) {}

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder:
        (_) => _TutorDialog(sentence: text, parsed: parsed, raw: explanation),
  );
}

class _TutorDialog extends StatelessWidget {
  final String sentence;
  final Map<String, dynamic> parsed;
  final String raw;

  const _TutorDialog({
    required this.sentence,
    required this.parsed,
    required this.raw,
  });

  Widget _section(String title, dynamic content) {
    if (content == null || (content is String && content.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.toString(),
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(width: 2, color: Colors.black),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/bulb.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tutor',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _navGreen,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Image.asset(
                      'assets/images/close_red.png',
                      width: 28,
                      height: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    parsed.isEmpty
                        ? Text(raw)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _section(
                              AppLocalizations.of(context)!.grammarExplanation,
                              parsed['grammar_explanation'],
                            ),
                            _section(
                              AppLocalizations.of(context)!.keyVocabulary,
                              parsed['key_vocabulary'],
                            ),
                            _section(
                              AppLocalizations.of(context)!.translationHeading,
                              parsed['translation'],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
