import 'dart:math' as math; // ← Add this at the top of your file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/OpenAiTtsService.dart'; // your Gemini client
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:forditva/utils/debouncer.dart'; // if you created it separately
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/edit_recording_modal.dart';
import 'package:forditva/widgets/recording_modal.dart'; // adjust path as needed
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;
bool _showRecording = false;

String _flagAsset(Language lang) {
  switch (lang) {
    case Language.hungarian:
      return 'assets/flags/HU_BB.png';
    case Language.german:
      return 'assets/flags/DE_BW.png';
    case Language.english:
      return 'assets/flags/EN_BW.png';
  }
}

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
      default:
        return 'Begin recording…';
    }
  }
}

String instructionForLang(Language lang) {
  switch (lang) {
    case Language.hungarian:
      return "Speak as this dialect: Hungarian";
    case Language.german:
      return "Speak as this dialect: German";
    case Language.english:
      return "Speak as this dialect: English";
    default:
      return "Speak as this dialect: English";
  }
}

final Map<Language, String> _labelImages = {
  Language.english: 'assets/images/EN-EN.png',
  Language.german: 'assets/images/DE-DE.png',
  Language.hungarian: 'assets/images/HU-HU.png',
};

// Add this OUTSIDE your classes
String flagAsset(Language lang, {required bool whiteBorder}) {
  switch (lang) {
    case Language.hungarian:
      return whiteBorder ? 'assets/flags/HU_BW.png' : 'assets/flags/HU_BB.png';
    case Language.german:
      return whiteBorder ? 'assets/flags/DE_BW.png' : 'assets/flags/DE_BB.png';
    case Language.english:
      return whiteBorder ? 'assets/flags/EN_BW.png' : 'assets/flags/EN_BB.png';
  }
}

class TextPage extends StatefulWidget {
  const TextPage({super.key});

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
  // ▶︎ your Gemini client
  final GeminiTranslator _gemini = GeminiTranslator();
  final _ttsService = OpenAiTtsService(); // Or inject if you use DI

  // ▶︎ map your Language enum into its two-letter codes
  final Map<Language, String> _langLabels = {
    Language.hungarian: 'HU',
    Language.german: 'DE',
    Language.english: 'EN',
  };

  Future<void> _playSoundWithOpenAI(
    String text,
    Language lang,
    String instructions,
  ) async {
    try {
      // OpenAI voice selection (e.g. 'onyx', you can expand with more logic if desired)
      const voice = "onyx";
      final file = await _ttsService.synthesizeSpeech(
        text: text,
        voice: voice,
        instructions: instructions,
      );

      final player = AudioPlayer();
      await player.setFilePath(file.path);
      await player.play();
      // Dispose player if not persistent
    } catch (e) {
      print("TTS error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('TTS failed: $e')));
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
                  editMode: true,
                  controller: editController, // pass controller
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

  Future<void> _openRecordingCustom({
    required Language from,
    required Language to,
    required bool isTopPanel, // true = output card, false = input card
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 180),
              child: RecordingModal(
                lang: from,
                isTopPanel: isTopPanel,
                onTranscribed: (transcript) async {
                  if (isTopPanel) {
                    // Set translation (output) to transcript, then translate "back" to input
                    setState(() {
                      _translation = transcript;
                      _isTranslating = true;
                    });

                    final geminiResult = await _gemini.translate(
                      transcript,
                      from.code, // from = output language
                      to.code, // to = input language
                    );
                    setState(() {
                      _inputController.text = geminiResult;
                      _isTranslating = false;
                    });
                    await _playSoundWithOpenAI(
                      _inputController.text,
                      _leftLanguage,
                      instructionForLang(_leftLanguage),
                    );
                  } else {
                    // Set input (bottom) to transcript, then translate up to output
                    setState(() {
                      _inputController.text = transcript;
                      _isTranslating = true;
                    });
                    final geminiResult = await _gemini.translate(
                      transcript,
                      from.code, // from = input language
                      to.code, // to = output language
                    );
                    setState(() {
                      _translation = geminiResult;
                      _isTranslating = false;
                    });
                    await _playSoundWithOpenAI(
                      _translation,
                      _rightLanguage,
                      instructionForLang(_rightLanguage),
                    );
                  }
                },
                onPartialTranscript: (partial) {
                  _debouncer.run(() async {
                    if (isTopPanel) {
                      setState(() {
                        _translation = partial;
                        _isTranslating = true;
                      });
                      final geminiResult = await _gemini.translate(
                        partial,
                        from.code,
                        to.code,
                      );
                      setState(() {
                        _inputController.text = geminiResult;
                        _isTranslating = false;
                      });
                    } else {
                      setState(() {
                        _inputController.text = partial;
                        _isTranslating = true;
                      });
                      final geminiResult = await _gemini.translate(
                        partial,
                        from.code,
                        to.code,
                      );
                      setState(() {
                        _translation = geminiResult;
                        _isTranslating = false;
                      });
                    }
                  });
                },
              ),
            ),
          ),
    );
  }

  late final FlutterTts _flutterTts;
  // 3) State fields for left/right languages
  Language _leftLanguage = Language.hungarian;
  Language _rightLanguage = Language.german;

  // 4) Helper to pick the next language, skipping the one on the other side
  Language _nextLanguage(Language current, Language other) {
    final all = [Language.hungarian, Language.german, Language.english];
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final controller = TextEditingController(text: initialText);
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
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final switchSize = 70.0;
        final flagSize = 30.0;
        final halfH = constraints.maxHeight / 2;

        return Stack(
          children: [
            // Input card
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationInputCard(
                fromLang: _leftLanguage,
                toLang: _rightLanguage,
                key: inputKey,
                text: _translation,
                isBusy: _isTranslating,
                // ----- NEW: Stack Modal Editing
                onEditTap: () {
                  showEditTextModal(
                    context: context,
                    initialText: _translation,
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
                      // Play TTS for the translated text (edited or translated as you want)
                      _playSoundWithOpenAI(
                        _inputController
                            .text, // Or edited, depending on which panel
                        _leftLanguage, // The language of the translated output
                        instructionForLang(_leftLanguage),
                      );
                    },
                    isTextInLanguage:
                        (text) => isTextInLanguage(
                          text,
                          _langLabels[_rightLanguage]!,
                          _gemini,
                        ),
                  );
                },

                onMicTap:
                    () => _openRecordingCustom(
                      from: _rightLanguage,
                      to: _leftLanguage,
                      isTopPanel: true,
                    ),

                onPlaySound:
                    () => _playSoundWithOpenAI(
                      _translation,
                      _rightLanguage,
                      instructionForLang(_rightLanguage),
                    ),
              ),
            ),
            // Left overlay
            Positioned(
              top: halfH - switchSize / 2,
              left: 16,
              width: constraints.maxWidth / 2 + switchSize / 2 - 16,
              child: Container(
                height: switchSize,
                decoration: BoxDecoration(
                  color: textGrey,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            ),
            // Output card
            Positioned(
              top: halfH - 20,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationOutputCard(
                toLang: _rightLanguage,
                fromLang: _leftLanguage,
                key: outputKey,
                controller: _inputController,
                onMicTap:
                    () => _openRecordingCustom(
                      from: _leftLanguage,
                      to: _rightLanguage,
                      isTopPanel: false,
                    ),
                // ----- NEW: Stack Modal Editing
                onEditTap: () {
                  showEditTextModal(
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
                        _inputController.text = edited; // The panel you edited
                        _translation =
                            translated; // The opposite panel auto-translate
                      });
                      _playSoundWithOpenAI(
                        _translation, // Or edited, depending on which panel
                        _rightLanguage, // The language of the translated output
                        instructionForLang(_rightLanguage),
                      );
                    },
                    isTextInLanguage:
                        (text) => isTextInLanguage(
                          text,
                          _langLabels[_leftLanguage]!,
                          _gemini,
                        ),
                  );
                },

                onCopy: () => _copyText(_inputController.text),
                onPlaySound:
                    () => _playSoundWithOpenAI(
                      _inputController.text,
                      _leftLanguage,
                      instructionForLang(_leftLanguage),
                    ),
              ),
            ),
            // Right overlay
            Positioned(
              top: halfH - switchSize / 2,
              left: constraints.maxWidth / 2 - switchSize / 4,
              right: 16,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: textGrey,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
            ),
            // 4) Switch + flags row
            Positioned(
              top: halfH - switchSize / 2,
              left: 16,
              right: 16,
              child: SizedBox(
                height: switchSize,
                child: Stack(
                  children: [
                    // Left language toggle
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: GestureDetector(
                          onTap:
                              () => setState(() {
                                _leftLanguage = _nextLanguage(
                                  _leftLanguage,
                                  _rightLanguage,
                                );
                              }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                child: Image.asset(
                                  flagAsset(_leftLanguage, whiteBorder: false),
                                  width: flagSize,
                                  height: flagSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 5),
                              Image.asset(
                                _labelImages[_leftLanguage]!,
                                height: flagSize,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap:
                            () => setState(() {
                              final tmpLang = _leftLanguage;
                              _leftLanguage = _rightLanguage;
                              _rightLanguage = tmpLang;

                              // Swap texts
                              final tmpText = _inputController.text;
                              _inputController.text = _translation;
                              _translation = tmpText;
                            }),
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
                              'assets/images/switch.png',
                              width: switchSize * 0.6,
                              height: switchSize * 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right language toggle
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10.0, bottom: 8),
                        child: GestureDetector(
                          onTap:
                              () => setState(() {
                                // Skip whatever the left side is and advance _rightLanguage to the next
                                _rightLanguage = _nextLanguage(
                                  _rightLanguage,
                                  _leftLanguage,
                                );
                              }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              RotatedBox(
                                quarterTurns: 2,
                                child: ClipRRect(
                                  child: Image.asset(
                                    flagAsset(
                                      _rightLanguage,
                                      whiteBorder: true,
                                    ),
                                    width: flagSize,
                                    height: flagSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5),
                              RotatedBox(
                                quarterTurns: 2,
                                child: Image.asset(
                                  _labelImages[_rightLanguage]!,
                                  height: flagSize,
                                  fit: BoxFit.contain,
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
          ],
        );
      },
    );
  }
}

// ======= Leave your card widgets below unchanged =======

class TranslationInputCard extends StatelessWidget {
  final Language fromLang;
  final Language toLang;
  final String text;
  final bool isBusy;
  final VoidCallback? onExplain;
  final VoidCallback? onCopy;
  final VoidCallback? onPlaySound;
  final VoidCallback? onEditTap; // Add this line
  final VoidCallback? onMicTap;

  const TranslationInputCard({
    super.key,
    required this.fromLang,
    required this.toLang,
    required this.text,
    required this.isBusy,
    this.onExplain,
    this.onCopy,
    this.onPlaySound,
    this.onEditTap,
    this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = calculateFontSize(text);

    return Container(
      decoration: BoxDecoration(
        color: textGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Scrollable, upside-down text, taking all space except for icons/mic
          Positioned.fill(
            top: 100, // Give space at top for mic/icons
            bottom: dynamicInputBottom(fontSize),
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              reverse: true, // So scrolling starts from the bottom
              physics: const BouncingScrollPhysics(),
              child: RotatedBox(
                quarterTurns: 2, // Flip text upside down
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child:
                      isBusy
                          ? const Center(child: CircularProgressIndicator())
                          : (text.isNotEmpty
                              ? GestureDetector(
                                onTap: onEditTap,
                                child: Text(
                                  capitalizeFirst(text),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.robotoCondensed(
                                    fontWeight: FontWeight.w500,
                                    fontSize: calculateFontSize(text),
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              )
                              : const SizedBox.shrink()),
                ),
              ),
            ),
          ),
          // Mic button and icons (overlay)
          Positioned(
            top: 9,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(flagAsset(toLang, whiteBorder: true)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: Image(
                        image: AssetImage(
                          'assets/images/microphone-white-border.png',
                        ),
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bulb icon (left)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: onExplain,
              child: Transform.rotate(
                angle: math.pi,
                child: Image.asset(
                  'assets/images/bulb.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ),
          ),
          // Copy/Play icons (right)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCopy,
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Image.asset(
                      'assets/images/copy.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onPlaySound,
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Image.asset(
                      'assets/images/play-sound.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TranslationOutputCard extends StatelessWidget {
  final Language fromLang;
  final Language toLang;
  final TextEditingController controller;
  final Future<void> Function() onMicTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPlaySound;
  const TranslationOutputCard({
    super.key,
    required this.fromLang,
    required this.toLang,
    required this.controller,
    required this.onMicTap,
    this.onEditTap,
    this.onCopy,
    this.onPlaySound,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = calculateFontSize(controller.text);

    // Estimate how much space the mic row uses (including icons), then pad bottom accordingly
    const double bottomReserved = 110; // mic + icons area
    return Container(
      padding: dynamicOutputPadding(fontSize), // <== dynamic top padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // The scrollable, non-editable transcribed text
          Positioned.fill(
            bottom: bottomReserved, // reserve space for mic/icons row
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: onEditTap,
                child: Center(
                  child: Text(
                    capitalizeFirst(controller.text),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoCondensed(
                      fontWeight: FontWeight.w500,
                      fontSize: calculateFontSize(controller.text),
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Mic+Flag at bottom center (rectangle, not circle)
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onMicTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    flagAsset(fromLang, whiteBorder: false),
                    width: 80,
                    height: 80,
                  ),
                  const Image(
                    image: AssetImage(
                      'assets/images/microphone-white-border.png',
                    ),
                    width: 40,
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
          // Edit/copy/play icons on left/right (unchanged)
          Positioned(
            bottom: 25,
            left: 8,
            child: GestureDetector(
              onTap: onEditTap,
              child: Image.asset(
                'assets/images/edit.png',
                width: 40,
                height: 40,
              ),
            ),
          ),
          Positioned(
            bottom: 25,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCopy,
                  child: Image.asset(
                    'assets/images/copy.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onPlaySound,
                  child: Image.asset(
                    'assets/images/play-sound.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
