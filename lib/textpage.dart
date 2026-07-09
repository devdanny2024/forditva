import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/document/document_translation_state.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_tts_service.dart';
import 'package:forditva/services/learning_store.dart';
import 'package:forditva/services/level_pref.dart';
import 'package:forditva/widgets/error_dialog.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:forditva/services/third_language_pref.dart';
import 'package:forditva/utils/debouncer.dart'; // if you created it separately
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/edit_recording_modal.dart';
import 'package:forditva/widgets/recording_modal.dart'; // adjust path as needed
import 'package:forditva/widgets/copied_toast.dart';
import 'package:forditva/widgets/translation_card.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;
bool _showRecording = false;

typedef OnEditAndTranslate =
    void Function({required String edited, required String translated});

extension LanguageRecordingText on Language {
  String get beginRecording {
    switch (this) {
      case Language.hungarian:
        return 'Kezdje a felvételt…';
      case Language.german:
        return 'Beginnen Sie die Aufnahme…';
      case Language.english:
      case Language.dutch:
      case Language.french:
      case Language.spanish:
      case Language.russian:
      case Language.italian:
        return 'Begin recording…';
    }
  }
}

String instructionForLang(Language lang) {
  // Force the TTS to pronounce in the target language. The soft
  // "speak as this dialect" hint was being ignored, so French text was read
  // with a Hungarian accent (Markus's voice note). Name the language firmly.
  return "The following text is in ${lang.fullName}. "
      "Read it aloud in ${lang.fullName} with a natural native "
      "${lang.fullName} accent and pronunciation. Do not use any other "
      "language's accent.";
}

final Map<Language, String> _labelImages = {
  for (final lang in Language.values) lang: 'assets/images/${lang.label}-${lang.label}.png',
};

// Add this OUTSIDE your classes
// Markus's own bordered square flag: the `_W` (white border) variant on dark
// cards, `_B` (anthracite border) on light ones. Clipped to rounded corners so
// the JPG's opaque corners don't show against the card.
Widget borderedFlag(
  Language lang, {
  required bool whiteBorder,
  double size = 30,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: Image.asset(
      'assets/flags/${lang.label}_${whiteBorder ? 'W' : 'B'}.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

bool _isAudioPlaying = false;

/// Clips a card to a stepped seam that runs through the switch button.
///
/// The seam is flat (horizontal) on both sides at two different heights, with a
/// short step that is hidden behind the switch button in the centre:
///   left side  -> at the TOP of the switch    (bright card reaches up to here)
///   right side -> at the BOTTOM of the switch  (dark card reaches down to here)
///
/// For the top (dark) card [keepTop] is true (keep everything above the seam);
/// for the bottom (bright) card it is false (keep everything below). Both cards
/// use the same seam in screen space, so they tile along it.
class _SeamClipper extends CustomClipper<Path> {
  final double switchSize;
  final bool keepTop;

  const _SeamClipper({required this.switchSize, required this.keepTop});

  @override
  Path getClip(Size size) {
    final centerX = size.width / 2;
    // Width of the slanted transition. Kept narrow enough to sit behind the
    // switch button's flat face so its corners never peek out.
    final stepHalf = switchSize / 2 - 18;

    final path = Path();
    if (keepTop) {
      // Dark card: flat at the top-of-switch level on the left, flat at the
      // bottom-of-switch level on the right, keep everything above.
      final topLevel = size.height - switchSize; // top of switch
      final bottomLevel = size.height; // bottom of switch
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, bottomLevel);
      path.lineTo(centerX + stepHalf, bottomLevel);
      path.lineTo(centerX - stepHalf, topLevel);
      path.lineTo(0, topLevel);
    } else {
      // Bright card: flat at the top-of-switch level (y 0) on the left, flat at
      // the bottom-of-switch level (y switchSize) on the right, keep below.
      // 1px of slack upward so the seam has no anti-aliased hairline.
      path.moveTo(0, -1);
      path.lineTo(centerX - stepHalf, -1);
      path.lineTo(centerX + stepHalf, switchSize - 1);
      path.lineTo(size.width, switchSize - 1);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_SeamClipper oldClipper) =>
      oldClipper.switchSize != switchSize || oldClipper.keepTop != keepTop;
}

class TextPage extends StatefulWidget {
  /// Called when the user taps the document icon on the bottom card, after
  /// both cards' current text has been copied into Document mode.
  final VoidCallback? onOpenDocument;

  const TextPage({super.key, this.onOpenDocument});

  @override
  _TextPageState createState() => _TextPageState();
}

/// ==================== TextPage ====================
class _TextPageState extends State<TextPage> {
  final TextEditingController _inputController = TextEditingController();
  final _debouncer = Debouncer(
    milliseconds: 700,
  ); // Debounce interval for live translation
  String _translation = '';
  // ▶︎ spinner while Gemini runs
  bool _isTranslating = false;
  bool _isAudioLoadingInput = false; // For the input card play button
  bool _isAudioLoadingOutput = false; // For the output card play button
  ap.AudioPlayer? _audioPlayer;
  bool _isInputPlaying = false;
  bool _isOutputPlaying = false;
  ap.AudioPlayer? _inputAudioPlayer;
  ap.AudioPlayer? _outputAudioPlayer;

  // Cache the last synthesized audio per card, keyed by the text it was
  // generated for. Re-pressing play on unchanged text skips the TTS call
  // entirely instead of re-synthesizing (removes the delay before playback).
  String? _inputAudioCacheText;
  File? _inputAudioCacheFile;
  String? _outputAudioCacheText;
  File? _outputAudioCacheFile;

  // ▶︎ your Gemini client
  final GeminiTranslator _gemini = GeminiTranslator();
  final _ttsService = GeminiTtsService();

  // ▶︎ map your Language enum into its two-letter codes
  final Map<Language, String> _langLabels = {
    for (final lang in Language.values) lang: lang.label,
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    final pair = getInitialLangPair(locale);
    setState(() {
      _leftLanguage = pair[0];
      _rightLanguage = pair[1];
    });
  }

  Future<void> _playInputSound() async {
    // Stop the other audio player if playing
    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = false;
    });

    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = true;
    });
    _inputAudioPlayer ??= ap.AudioPlayer();

    File file;
    if (_inputAudioCacheText == _translation && _inputAudioCacheFile != null) {
      file = _inputAudioCacheFile!;
    } else {
      file = await _ttsService.synthesizeSpeech(
        text: _translation,
        voice: "onyx",
        instructions: instructionForLang(_rightLanguage),
        langCode: _rightLanguage.code,
      );
      _inputAudioCacheText = _translation;
      _inputAudioCacheFile = file;
    }

    late final StreamSubscription sub;
    sub = _inputAudioPlayer!.onPlayerStateChanged.listen((state) {
      if (state == ap.PlayerState.completed ||
          state == ap.PlayerState.stopped) {
        setState(() => _isInputPlaying = false);
        sub.cancel();
      }
    });
    await _inputAudioPlayer!.play(ap.DeviceFileSource(file.path));
  }

  Future<void> _stopInputSound() async {
    await _inputAudioPlayer?.stop();
    setState(() => _isInputPlaying = false);
  }

  Future<void> _playOutputSound() async {
    // Stop the other audio player if playing
    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = false;
    });

    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = true;
    });
    _outputAudioPlayer ??= ap.AudioPlayer();

    File file;
    if (_outputAudioCacheText == _inputController.text &&
        _outputAudioCacheFile != null) {
      file = _outputAudioCacheFile!;
    } else {
      file = await _ttsService.synthesizeSpeech(
        text: _inputController.text,
        voice: "onyx",
        instructions: instructionForLang(_leftLanguage),
        langCode: _leftLanguage.code,
      );
      _outputAudioCacheText = _inputController.text;
      _outputAudioCacheFile = file;
    }

    late final StreamSubscription sub;
    sub = _outputAudioPlayer!.onPlayerStateChanged.listen((state) {
      if (state == ap.PlayerState.completed ||
          state == ap.PlayerState.stopped) {
        setState(() => _isOutputPlaying = false);
        sub.cancel();
      }
    });
    await _outputAudioPlayer!.play(ap.DeviceFileSource(file.path));
  }

  Future<void> _stopOutputSound() async {
    await _outputAudioPlayer?.stop();
    setState(() => _isOutputPlaying = false);
  }

  Future<void> _playSoundWithOpenAI(
    String text,
    Language lang,
    String instructions,
    VoidCallback onStart,
    VoidCallback onDone,
  ) async {
    try {
      _audioPlayer ??= ap.AudioPlayer();
      await _audioPlayer!.stop();

      final file = await _ttsService.synthesizeSpeech(
        text: text,
        voice: "onyx",
        instructions: instructions,
        langCode: lang.code,
      );
      if (!await file.exists() || (await file.length()) == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("TTS failed: ${file.path}")));
        }
        setState(() => _isAudioPlaying = false);
        onDone();
        return;
      }

      late final StreamSubscription sub;
      sub = _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (state == ap.PlayerState.playing) {
          setState(() => _isAudioPlaying = true);
          onStart();
        }
        if (state == ap.PlayerState.completed) {
          setState(() => _isAudioPlaying = false);
          onDone();
          sub.cancel();
        }
        if (state == ap.PlayerState.stopped) {
          setState(() => _isAudioPlaying = false);
          onDone();
          sub.cancel();
        }
      });

      await _audioPlayer!.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('TTS failed: $e')));
      }
      setState(() => _isAudioPlaying = false);
      onDone();
    }
  }

  Future<void> _autoPlayInputTTS() async {
    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = true;
      _isOutputPlaying = false;
      _isAudioLoadingInput = true;
    });
    await _playInputSound(); // handles file and plays
    setState(() {
      _isAudioLoadingInput = false;
      _isInputPlaying = false; // will also be set in the listener
    });
  }

  Future<void> _autoPlayOutputTTS() async {
    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = true;
      _isInputPlaying = false;
      _isAudioLoadingOutput = true;
    });
    await _playOutputSound();
    setState(() {
      _isAudioLoadingOutput = false;
      _isOutputPlaying = false; // will also be set in the listener
    });
  }

  Future<void> autoTranslateOnLanguageChange({
    bool leftChanged = true,
    bool playTTS = true,
  }) async {
    setState(() {
      _isTranslating = true;
      if (leftChanged) {
        _isAudioLoadingOutput = true;
      } else {
        _isAudioLoadingInput = true;
      }
    });

    final String sourceText =
        leftChanged ? _translation : _inputController.text;
    final Language fromLang = leftChanged ? _rightLanguage : _leftLanguage;
    final Language toLang = leftChanged ? _leftLanguage : _rightLanguage;

    if (sourceText.trim().isEmpty) {
      setState(() {
        _isTranslating = false;
        _isAudioLoadingOutput = false;
        _isAudioLoadingInput = false;
      });
      return;
    }

    try {
      final result = await _gemini.translate(
        sourceText,
        fromLang.code,
        toLang.code,
      );
      if (!mounted) return;
      setState(() {
        if (leftChanged) {
          _inputController.text = result;
        } else {
          _translation = result;
        }
      });
      if (playTTS) {
        if (leftChanged) {
          await _autoPlayOutputTTS();
        } else {
          await _autoPlayInputTTS();
        }
      }
    } catch (_) {
      // A failed translation used to leave the spinner spinning forever
      // (Markus's "spinner doesn't stop"). Clear it and show a friendly popup.
      if (mounted) showFriendlyError(context);
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _isAudioLoadingOutput = false;
          _isAudioLoadingInput = false;
        });
      }
    }
  }

  Future<void> showEditStackModal({
    required BuildContext context,
    required String initialText,
    required Language lang,
    required ValueChanged<String> onEdited,
    required ValueChanged<String> onTranscribed,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, a1, a2) {
        final keyboard = MediaQuery.of(ctx).viewInsets.bottom;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final availableHeight = screenHeight - keyboard;
        final TextEditingController editController = TextEditingController(
          text: initialText,
        );

        return Center(
          child: SingleChildScrollView(
            // This makes the entire stack move above the keyboard!
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered, not full-screen
                RecordingModal(
                  lang: lang,
                  isTopPanel: true,
                  // pass controller
                  onTranscribed: (txt) {
                    Navigator.of(ctx).pop();
                    onTranscribed(txt);
                  },
                ),
                const SizedBox(height: 16),
                EditTextModal(
                  controller: editController,
                  onEdited: ({
                    required String edited,
                    required String translated,
                  }) {
                    // Update state for both panels!
                    setState(() {
                      _translation =
                          edited; // the text in the panel you just edited
                      _inputController.text =
                          translated; // the translation for the opposite panel
                    });
                  },
                  isTextInLanguage:
                      (text) =>
                          isTextInLanguage(text, _langLabels[lang]!, _gemini),
                  fromLang: lang, // this panel's language
                  toLang:
                      lang == _leftLanguage ? _rightLanguage : _leftLanguage,
                  gemini: _gemini,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> translateFinal(String input, String from, String to) async {
    // Single pass — the previous HU branch translated twice, which doubled
    // latency and re-translated an already-translated result.
    return await _gemini.translate(input, from, to);
  }

  // Default CEFR level derived from the numeric level the user set in Settings
  // (1-33 = A1, 34-66 = A2, 67-99 = B1). Refreshed each time the Tutor opens.
  String _explanationLevel = LevelPref.cefr;

  void _showExplanationModal(String initialExplanation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String explanationText = initialExplanation;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void fetchExplanation(String level) async {
              setModalState(() => isLoading = true);
              try {
                final newExp = await _gemini.translate(
                  _inputController.text.trim(),
                  _langLabels[_leftLanguage]!,
                  _langLabels[_rightLanguage]!,
                  explain: true,
                  level: level,
                );
                setModalState(() {
                  explanationText = newExp;
                });
              } catch (_) {
                setModalState(() {
                  explanationText = 'Failed to load explanation.';
                });
              } finally {
                setModalState(() => isLoading = false);
              }
            }

            Map<String, dynamic> parsed = {};
            try {
              final cleanJson = stripCodeFence(explanationText);
              parsed = cleanJson.isNotEmpty ? jsonDecode(cleanJson) : {};
            } catch (_) {}

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(width: 0.5, color: Colors.black),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 80,
                                height: 80,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Tutor",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: navGreen,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Image.asset(
                              'assets/png24/black/b_close.png',
                              width: 24,
                              height: 24,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child:
                            isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : parsed.isEmpty
                                ? Text(explanationText)
                                : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSection(
                                        "Grammar Explanation",
                                        parsed["grammar_explanation"],
                                      ),
                                      _buildSection(
                                        "Key Vocabulary",
                                        parsed["key_vocabulary"],
                                      ),
                                      _buildSection(
                                        "Translation",
                                        parsed["translation"],
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),
                    const Divider(),
                    Container(
                      color: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children:
                            ['A1', 'A2', 'B1'].map((level) {
                              final active = _explanationLevel == level;
                              return GestureDetector(
                                onTap: () {
                                  setModalState(
                                    () => _explanationLevel = level,
                                  );
                                  fetchExplanation(level);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active ? navRed : null,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color:
                                          active ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.robotoCondensed(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content ?? '',
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoaderBeforeModal(
    Future<String> Function() loadExplanation,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: GifLoader(size: 80)),
    );

    final explanation = await loadExplanation();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showExplanationModal(explanation);
  }

  bool _isTopRecording = false;
  bool _isBottomRecording = false;

  Future<void> _openRecordingCustom({
    required Language from,
    required Language to,
    required bool isTopPanel,
  }) async {
    print('Opening recording modal - top? $isTopPanel');

    setState(() {
      if (isTopPanel) {
        _isTopRecording = true;
      } else {
        _isBottomRecording = true;
      }
    });
  }

  late final FlutterTts _flutterTts;
  // 3) State fields for left/right languages
  Language _leftLanguage = Language.hungarian;
  Language _rightLanguage = Language.german;

  // Public so the nav bar (main.dart, via a GlobalKey) can reactively enable
  // the Tutor bulb only while Hungarian text is actually present on this
  // page. Recomputed once per build() rather than at every individual
  // mutation site, since text/language state changes in many places here.
  final ValueNotifier<bool> hasHungarianText = ValueNotifier(false);

  void _updateHasHungarianText() {
    final hungarianText =
        _leftLanguage == Language.hungarian
            ? _inputController.text
            : _rightLanguage == Language.hungarian
            ? _translation
            : '';
    hasHungarianText.value = hungarianText.trim().isNotEmpty;
  }

  // 4) Helper to pick the next language, skipping the one on the other side.
  // The third slot is whatever the user picked in Settings (defaults to
  // English), not English unconditionally.
  Language _nextLanguage(Language current, Language other) {
    final all = [
      Language.hungarian,
      Language.german,
      ThirdLanguagePref.current,
    ];
    var idx = all.indexOf(current);
    var next = all[(idx + 1) % all.length];
    if (next == other) next = all[(idx + 2) % all.length];
    return next;
  }

  void showEditTextModal({
    required BuildContext context,
    required String initialText,
    required Language fromLang,
    required Language toLang,
    required GeminiTranslator gemini,
    required OnEditAndTranslate onEdited, // <- Use your typedef!
    required Future<bool> Function(String text) isTextInLanguage,
  }) {
    // Interrupt any audio currently playing before the user starts editing,
    // so the TTS voice doesn't keep talking over the correction.
    _inputAudioPlayer?.stop();
    _outputAudioPlayer?.stop();
    _audioPlayer?.stop();
    setState(() {
      _isInputPlaying = false;
      _isOutputPlaying = false;
      _isAudioPlaying = false;
    });

    // Create the controller ONCE, outside the builder. The bottom sheet's
    // builder re-runs on every keyboard toggle; creating the controller inside
    // it rebuilt a fresh controller each time and wiped the recorded/typed text
    // back to initialText (Markus: text disappears after record + keyboard).
    final controller = TextEditingController(text: initialText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: EditTextModal(
            controller: controller,
            onEdited: onEdited, // Pass it directly
            isTextInLanguage: isTextInLanguage,
            fromLang: fromLang,
            toLang: toLang,
            gemini: gemini,
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  final GlobalKey inputKey = GlobalKey();
  final GlobalKey outputKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts
      ..setSpeechRate(0.5)
      ..setVolume(1.0)
      ..setPitch(1.0);
  }

  void _copyText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context, AppLocalizations.of(context)!.copiedToClipboard);
  }

  // Document icon: carries both cards' current text into Document mode
  // (top/dark card -> Document's input box, bottom/bright card -> Document's
  // output box) and switches to that tab.
  void _openInDocumentMode() {
    DocumentTranslationState.inputText = _translation;
    DocumentTranslationState.translatedText = _inputController.text;
    // Carry the languages so the document panel speaks each side in the right
    // voice. inputText is the right-language text, translatedText the left.
    DocumentTranslationState.leftLang = _leftLanguage;
    DocumentTranslationState.rightLang = _rightLanguage;
    widget.onOpenDocument?.call();
  }

  // Tutor: opens the grammar/vocabulary explanation modal for whichever card
  // actually holds the Hungarian text (not always the top card, that was a
  // bug — the Tutor was explaining German text whenever German happened to
  // be on top). Public so the nav bar's bulb button (main.dart) can trigger
  // it via a GlobalKey, now that the bulb no longer lives on the card itself.
  void openTutor() {
    // Pick up the latest level from Settings each time the Tutor opens.
    _explanationLevel = LevelPref.cefr;
    final hungarianText =
        _leftLanguage == Language.hungarian
            ? _inputController.text.trim()
            : _rightLanguage == Language.hungarian
            ? _translation.trim()
            : '';
    if (hungarianText.isNotEmpty) {
      setState(() => _isTranslating = true);
      _showLoaderBeforeModal(() async {
        try {
          final explanation = await _gemini.translate(
            hungarianText,
            _langLabels[_leftLanguage]!,
            _langLabels[_rightLanguage]!,
            explain: true,
            level: _explanationLevel,
            // Explanation must be written in the app's UI language, not
            // whichever content language is currently selected for translation.
            uiLanguage: Localizations.localeOf(context).languageCode.toUpperCase(),
          );
          // Record it in the Learning history so the user can revisit it later.
          await LearningStore.add(
            sentence: hungarianText,
            explanation: explanation,
          );
          return explanation;
        } catch (_) {
          return 'Failed to load explanation.';
        } finally {
          if (mounted) setState(() => _isTranslating = false);
        }
      });
    }
  }

  Future<void> _playSound(String text, Language lang) async {
    if (text.isEmpty) return;
    final locale =
        lang == Language.hungarian
            ? 'hu-HU'
            : lang == Language.german
            ? 'de-DE'
            : 'en-US';
    await _flutterTts.setLanguage(locale);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();

    _inputAudioPlayer?.dispose();
    _outputAudioPlayer?.dispose();
    hasHungarianText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateHasHungarianText();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Symmetric vertical padding so the two cards mirror each other
        // exactly. halfHeight is measured from the *padded* area, so the top
        // and bottom cards come out identical in height and margin. Kept small
        // so the cards fill toward the menu with little wasted space.
        final double vPad = 3.0;
        final halfHeight = (constraints.maxHeight - 2 * vPad) / 2;
        final switchSize = 70.0;
        final switchHalf = switchSize / 2;
        // The two cards are mirror images about the centre line: equal heights,
        // equal margins. They meet along a stepped seam through the switch
        // button (flat on each side, the step hidden behind it).
        final switchRowTop = halfHeight - switchHalf;

        return Container(
          padding: EdgeInsets.symmetric(vertical: vPad),
          child: Stack(
            children: [
              // --- UPDATED: Top (input) card ---
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: halfHeight + switchHalf, // down to the bottom of the switch
                child: TranslationCard(
                  inverted: true,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  edgeClipper: _SeamClipper(
                    switchSize: switchSize,
                    keepTop: true,
                  ),
                  text: _translation,
                  siblingText: _inputController.text,
                  fromLang: _rightLanguage,
                  toLang: _leftLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingInput,
                  isAudioPlaying: _isInputPlaying,
                  isRecording: _isTopRecording,
                  onExplain: openTutor,
                  onCopy: () => _copyText(_translation),
                  onPlay: _playInputSound,
                  onStop: _stopInputSound,
                  onMicTap:
                      () => _openRecordingCustom(
                        from: _rightLanguage,
                        to: _leftLanguage,
                        isTopPanel: true,
                      ),
                  onMicCancel: () => setState(() => _isTopRecording = false),
                  onEdit:
                      () => showEditTextModal(
                        context: context,
                        initialText: _inputController.text,
                        fromLang: _leftLanguage,
                        toLang: _rightLanguage,
                        gemini: _gemini,
                        onEdited: ({
                          required String edited,
                          required String translated,
                        }) {
                          setState(() {
                            _inputController.text =
                                edited; // The panel you edited
                            _translation =
                                translated; // The opposite panel auto-translate
                          });
                          _playSoundWithOpenAI(
                            _translation,
                            _rightLanguage,
                            instructionForLang(_rightLanguage),
                            () {}, // Don't reveal (already visible)
                            () {
                              if (mounted) {
                                setState(() => _isTranslating = false);
                              }
                            },
                          );
                        },
                        isTextInLanguage:
                            (text) => isTextInLanguage(
                              text,
                              _langLabels[_leftLanguage]!,
                              _gemini,
                            ),
                      ),
                ),
              ),

              // --- UPDATED: Bottom (output) card ---
              Positioned(
                top: halfHeight - switchHalf, // up to the top of the switch
                left: 16,
                right: 16,
                bottom: 0, // reach the bottom edge of the screen
                child: TranslationCard(
                  inverted: false,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  edgeClipper: _SeamClipper(
                    switchSize: switchSize,
                    keepTop: false,
                  ),
                  text: _inputController.text,
                  siblingText: _translation,
                  fromLang: _leftLanguage,
                  toLang: _rightLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingOutput,
                  isAudioPlaying: _isOutputPlaying,
                  isRecording: _isBottomRecording,
                  onCopy: () => _copyText(_inputController.text),
                  onPlay: _playOutputSound,
                  onStop: _stopOutputSound,
                  onOpenDocument: _openInDocumentMode,
                  onMicTap:
                      () => _openRecordingCustom(
                        from: _leftLanguage,
                        to: _rightLanguage,
                        isTopPanel: false,
                      ),
                  onMicCancel: () => setState(() => _isBottomRecording = false),
                  onEdit:
                      () => showEditTextModal(
                        context: context,
                        initialText: _inputController.text,
                        fromLang: _leftLanguage,
                        toLang: _rightLanguage,
                        gemini: _gemini,
                        onEdited: ({
                          required String edited,
                          required String translated,
                        }) {
                          setState(() {
                            _inputController.text =
                                edited; // The panel you edited
                            _translation =
                                translated; // The opposite panel auto-translate
                          });
                          _playSoundWithOpenAI(
                            _translation,
                            _rightLanguage,
                            instructionForLang(_rightLanguage),
                            () {}, // Don't reveal (already visible)
                            () {
                              if (mounted) {
                                setState(() => _isTranslating = false);
                              }
                            },
                          );
                        },
                        isTextInLanguage:
                            (text) => isTextInLanguage(
                              text,
                              _langLabels[_leftLanguage]!,
                              _gemini,
                            ),
                      ),
                ),
              ),

              // --- NEW: Restyled Language Switcher ---
              Positioned(
                top: switchRowTop,
                left: 26,
                right: 26,
                child: SizedBox(
                  height: switchSize,
                  child: Stack(
                    children: [
                      // Left language toggle (dark background)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _leftLanguage = _nextLanguage(
                                _leftLanguage,
                                _rightLanguage,
                              );
                            });
                            autoTranslateOnLanguageChange(leftChanged: true);
                          },
                          // No pill: EN sits on the white card, so a
                          // black-outlined label + black-bordered flag.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              borderedFlag(_leftLanguage, whiteBorder: false),
                              const SizedBox(width: 8),
                              Text(
                                _leftLanguage.label,
                                style: GoogleFonts.roboto(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Switch button
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await _inputAudioPlayer?.stop();
                            await _outputAudioPlayer?.stop();
                            await _audioPlayer?.stop();
                            setState(() {
                              _isInputPlaying = false;
                              _isOutputPlaying = false;
                              final tmpLang = _leftLanguage;
                              _leftLanguage = _rightLanguage;
                              _rightLanguage = tmpLang;
                              final tmpText = _inputController.text;
                              _inputController.text = _translation;
                              _translation = tmpText;
                            });
                            autoTranslateOnLanguageChange(
                              leftChanged: true,
                              playTTS: false,
                            );
                            autoTranslateOnLanguageChange(
                              leftChanged: false,
                              playTTS: false,
                            );
                          },
                          child: Container(
                            width: switchSize,
                            height: switchSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/png24/black/b_change_round.png',
                                width: switchSize * 0.6,
                                height: switchSize * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right language toggle (white background)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _rightLanguage = _nextLanguage(
                                _rightLanguage,
                                _leftLanguage,
                              );
                            });
                            autoTranslateOnLanguageChange(leftChanged: false);
                          },
                          // HU pill sits on the inverted (top) card, so it is
                          // rotated 180° to read right-side-up for that speaker.
                          child: RotatedBox(
                            quarterTurns: 2,
                            // No pill: HU sits on the black card, so a
                            // white-outlined label + white-bordered flag.
                            // Flag first in code so that, once flipped 180°,
                            // the Hungarian reader sees the flag first (like DE).
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                borderedFlag(_rightLanguage, whiteBorder: true),
                                const SizedBox(width: 8),
                                Text(
                                  _rightLanguage.label,
                                  style: GoogleFonts.roboto(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // === INLINE RECORDING PANELS (Non-modal) ===
              if (_isTopRecording)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: RecordingModal(
                        lang: _rightLanguage,
                        isTopPanel: true,
                        onTranscribed: (txt) async {
                          setState(() => _isTopRecording = false);
                          if (txt.trim().isEmpty) return;
                          setState(() {
                            _translation = txt;
                            _isTranslating = true;
                          });
                          try {
                            final result = await translateFinal(
                              txt,
                              _rightLanguage.code,
                              _leftLanguage.code,
                            );
                            if (!mounted) return;
                            setState(() {
                              _inputController.text = result;
                              _isTranslating = false;
                            });
                            // Auto-play the translation (parallel, non-blocking).
                            _playOutputSound();
                          } catch (_) {
                            if (mounted) {
                              setState(() => _isTranslating = false);
                              showFriendlyError(context);
                            }
                          }
                        },
                        onEditRequested: (txt) {
                          setState(() => _isTopRecording = false);
                          if (txt.trim().isEmpty) return;
                          showEditTextModal(
                            context: context,
                            initialText: txt,
                            fromLang: _rightLanguage,
                            toLang: _leftLanguage,
                            gemini: _gemini,
                            onEdited: ({
                              required String edited,
                              required String translated,
                            }) {
                              setState(() {
                                _translation = edited;
                                _inputController.text = translated;
                              });
                              _playOutputSound();
                            },
                            isTextInLanguage:
                                (text) => isTextInLanguage(
                                  text,
                                  _langLabels[_rightLanguage]!,
                                  _gemini,
                                ),
                          );
                        },
                        onCancel: () => setState(() => _isTopRecording = false),
                      ),
                    ),
                  ),
                ),

              if (_isBottomRecording)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: RecordingModal(
                        lang: _leftLanguage,
                        isTopPanel: false,
                        onTranscribed: (txt) async {
                          setState(() => _isBottomRecording = false);
                          if (txt.trim().isEmpty) return;
                          setState(() {
                            _inputController.text = txt;
                            _isTranslating = true;
                          });
                          try {
                            final result = await translateFinal(
                              txt,
                              _leftLanguage.code,
                              _rightLanguage.code,
                            );
                            if (!mounted) return;
                            setState(() {
                              _translation = result;
                              _isTranslating = false;
                            });
                            // Auto-play the translation (parallel, non-blocking).
                            _playInputSound();
                          } catch (_) {
                            if (mounted) {
                              setState(() => _isTranslating = false);
                              showFriendlyError(context);
                            }
                          }
                        },
                        onEditRequested: (txt) {
                          setState(() => _isBottomRecording = false);
                          if (txt.trim().isEmpty) return;
                          showEditTextModal(
                            context: context,
                            initialText: txt,
                            fromLang: _leftLanguage,
                            toLang: _rightLanguage,
                            gemini: _gemini,
                            onEdited: ({
                              required String edited,
                              required String translated,
                            }) {
                              setState(() {
                                _inputController.text = edited;
                                _translation = translated;
                              });
                              _playInputSound();
                            },
                            isTextInLanguage:
                                (text) => isTextInLanguage(
                                  text,
                                  _langLabels[_leftLanguage]!,
                                  _gemini,
                                ),
                          );
                        },
                        onCancel:
                            () => setState(() => _isBottomRecording = false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
