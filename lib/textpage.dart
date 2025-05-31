import 'dart:math' as math; // ← Add this at the top of your file

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:google_fonts/google_fonts.dart';

import 'RecordingPage.dart'; // correct path & casing

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

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

class TextPage extends StatefulWidget {
  const TextPage({super.key});

  @override
  _TextPageState createState() => _TextPageState();
}

/// ==================== TextPage ====================
class _TextPageState extends State<TextPage> {
  final TextEditingController _inputController = TextEditingController();

  // ▶︎ what we spoke (bottom card)
  final String _transcript = '';
  // ▶︎ what Gemini translated (top card)
  String _translation = '';
  // ▶︎ spinner while Gemini runs
  bool _isTranslating = false;
  // ▶︎ your Gemini client
  final GeminiTranslator _gemini = GeminiTranslator();
  // ▶︎ map your Language enum into its two-letter codes
  final Map<Language, String> _langLabels = {
    Language.hungarian: 'HU',
    Language.german: 'DE',
    Language.english: 'EN',
  };
  Future<void> _openRecording() async {
    final transcript = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) =>
                RecordingPage(fromLang: _leftLanguage, toLang: _rightLanguage),
      ),
    );
    if (transcript == null || transcript.isEmpty) return;

    setState(() {
      _inputController.text = transcript;
      _isTranslating = true;
    });

    // Now translate...
    final geminiResult = await _gemini.translate(
      transcript,
      _leftLanguage.code,
      _rightLanguage.code,
    );

    setState(() {
      _translation = geminiResult;
      _isTranslating = false;
    });
  }

  Future<void> _openRecordingCustom({
    required Language from,
    required Language to,
  }) async {
    final transcript = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecordingPage(fromLang: from, toLang: to),
      ),
    );
    if (transcript == null || transcript.isEmpty) return;

    setState(() {
      _inputController.text = transcript;
      _isTranslating = true;
    });

    final geminiResult = await _gemini.translate(
      transcript,
      from.code,
      to.code,
    );

    setState(() {
      _translation = geminiResult;
      _isTranslating = false;
    });
  }

  Future<void> _editTranscript({required bool top}) async {
    // Use the correct text for editing
    final textToEdit = top ? _translation : _inputController.text;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => RecordingPage(
              fromLang: _leftLanguage,
              toLang: _rightLanguage,
              initialTranscript: textToEdit,
              autoStart: false,
            ),
      ),
    );
    if (edited == null) return;
    setState(() {
      if (top) {
        _translation = edited;
      } else {
        _inputController.text = edited;
        _isTranslating = true;
      }
    });
    if (!top) {
      final geminiResult = await _gemini.translate(
        edited,
        _leftLanguage.code,
        _rightLanguage.code,
      );
      setState(() {
        _translation = geminiResult;
        _isTranslating = false;
      });
    }
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

  final GlobalKey _leftLangKey = GlobalKey();
  final GlobalKey _rightLangKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    // existing init...
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

  // For edit icon (output card)
  void _editInputFromOutput(String text) {
    setState(() {
      _inputController.text = text;
      // Optionally clear translation
      //_translation = '';
    });
    // Optionally focus the input box if you have one
  }

  void _explainTranslation({String level = 'A2'}) async {
    final text = _translation;
    if (text.isEmpty) return;

    // Show a loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Use GeminiTranslator.translate with explain: true
    final explanation = await _gemini.translate(
      text,
      _leftLanguage.code,
      _rightLanguage.code,
      explain: true,
      level: level, // Pass the chosen explanation level (A1, A2, A3)
    );

    // Close the loader dialog
    if (context.mounted) Navigator.of(context).pop();

    // Show the explanation in an AlertDialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Explanation'),
            content: Text(explanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  Future<void> _speak(String text, Language lang) async {
    // pick locale string
    final locale =
        lang == Language.hungarian
            ? 'hu-HU'
            : lang == Language.german
            ? 'de-DE'
            : 'en-US';
    await _flutterTts.setLanguage(locale);
    await _flutterTts.speak(text);
  }

  // 5) Map each enum to its flag asset path
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

  // 6) Map each enum to its label‐image asset path
  String _labelAsset(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return 'assets/images/HU-EN.png';
      case Language.german:
        return 'assets/images/DE-EN.png';
      case Language.english:
        return 'assets/images/EN-EN.png';
    }
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
        final flagSize = 24.0;
        final halfH = constraints.maxHeight / 2;
        // 2) Inside your build, get the UI language code:
        final uiLangCode =
            Localizations.localeOf(context).languageCode.toUpperCase();
        // e.g. 'en','de','hu' → 'EN','DE','HU'
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
                text: _translation,
                isBusy: _isTranslating,
                onEditTap: () => _editTranscript(top: true),
                onMicTap:
                    () => _openRecordingCustom(
                      from: _rightLanguage,
                      to: _leftLanguage,
                    ),
                onPlaySound:
                    () => _playSound(_inputController.text, _leftLanguage),
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
            // Output card_editTranscript
            Positioned(
              top: halfH - 20,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationOutputCard(
                toLang: _rightLanguage,
                fromLang: _leftLanguage,
                controller: _inputController, // <-- ADD this line
                onMicTap:
                    () => _openRecordingCustom(
                      from: _leftLanguage,
                      to: _rightLanguage,
                    ),
                onEditTap: () => _editTranscript(top: false),
                onCopy: () => _copyText(_inputController.text),
                onPlaySound:
                    () => _playSound(
                      _inputController.text,
                      _leftLanguage,
                    ), // <-- new
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
                                  _flagAsset(_leftLanguage),
                                  width: flagSize,
                                  height: flagSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 5),
                              Image.asset(
                                'assets/images/${_leftLanguage.code}-$uiLangCode.png',
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
                                  _rightLanguage, // start from current right
                                  _leftLanguage, // skip the left one
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
                                    _flagAsset(_rightLanguage),
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
                                  'assets/images/${_rightLanguage.code}-$uiLangCode.png',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Scrollable, upside-down text, taking all space except for icons/mic
          Positioned.fill(
            top: 100, // Give space at top for mic/icons
            bottom: 70,
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
                                  text,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.roboto(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 30,
                                    color: Colors.white,
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
                      image: AssetImage(_flagAsset(toLang)),
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
    // Estimate how much space the mic row uses (including icons), then pad bottom accordingly
    const double bottomReserved = 110; // mic + icons area
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
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
                child: Text(
                  controller.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 30,
                    color: Colors.black,
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
                  Image.asset(_flagAsset(fromLang), width: 80, height: 80),
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
          // Instead of const Image (edit), use GestureDetector:
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
                Image.asset('assets/images/copy.png', width: 40, height: 40),
                const SizedBox(width: 10),
                Image.asset(
                  'assets/images/play-sound.png',
                  width: 40,
                  height: 40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
