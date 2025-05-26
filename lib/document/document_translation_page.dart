import 'dart:async'; // for Timer
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard & SystemChrome
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/db/database.dart'; // adjust the path if needed
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // for Share.share()
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/gemini_translation_service.dart'; // adjust path if needed

enum Language { hu, en, de }

const Color navRed = Color(0xFFCD2A3E);

bool _explain = false;
Timer? _debounce;
bool _isTranslating = false;
const Color textGrey = Color(0xFF898888);

class DocumentPlaceholderPage extends StatefulWidget {
  const DocumentPlaceholderPage({super.key});

  @override
  State<DocumentPlaceholderPage> createState() =>
      _DocumentPlaceholderPageState();
}

class _DocumentPlaceholderPageState extends State<DocumentPlaceholderPage>
    with SingleTickerProviderStateMixin {
  late final FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ScrollController _scrollController = ScrollController();
  final String _explanationText = '';
  final GeminiTranslator _gemini = GeminiTranslator();
  String _explanationLevel = 'A2'; // default level
  late final AppDatabase _db;
  final bool _skipDebounce = false;

  String _localeFor(Language lang) {
    switch (lang) {
      case Language.en:
        return 'en-US';
      case Language.de:
        return 'de-DE';
      case Language.hu:
        return 'hu-HU';
    }
  }

  String _translatingText(Language lang) {
    switch (lang) {
      case Language.hu:
        return 'Fordítás…';
      case Language.de:
        return 'Übersetzen…';
      case Language.en:
      default:
        return 'Translating…';
    }
  }

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  bool _isSpeaking = false;
  Future<void> _speak() async {
    if (_translatedText.isEmpty) return;
    final locale = _localeFor(_rightLang);
    await _flutterTts.setLanguage(locale);
    await _flutterTts.speak(_translatedText);
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _inputController.addListener(_onInputChanged);
    _db = AppDatabase(); // ← initialize the DB

    _flutterTts = FlutterTts();
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    // 1. Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. TTS event hooks
    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _db.close(); // ← close the DB when the page is torn down

    _pulseController.dispose();
    _debounce?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      final currentText = _inputController.text.trim();
      if (currentText.isNotEmpty) {
        _translateText(currentText);
      }
    });
  }

  Future<void> _listen() async {
    // If we’re already listening, cancel that session so the recognizer releases.
    if (_speech.isListening) {
      await _speech.cancel(); // ← fully tear down prior session
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // give the system a moment
    }

    // (Re-)initialize if needed; returns false if mic permission denied
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _isListening = status == 'listening');
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (!available) return;

    _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        // always update interim text
        setState(() => _inputController.text = result.recognizedWords);

        // only fire translation & DB write on the final result
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _speech.cancel(); // free the recognizer again
            _translateText(text);
          }
        }
      },
      partialResults: true, // show live interim transcripts
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
  }

  final TextEditingController _inputController = TextEditingController();
  String _translatedText = '';

  Language _leftLang = Language.en;
  Language _rightLang = Language.hu;

  final Map<Language, String> _flagPaths = {
    Language.en: 'assets/flags/EN_BW_LS.png',
    Language.de: 'assets/flags/DE_BW_LS.png',
    Language.hu: 'assets/flags/HU_BW_LS.png',
  };

  final Map<Language, String> _langLabels = {
    Language.en: 'EN',
    Language.de: 'DE',
    Language.hu: 'HU',
  };
  void _switchLanguages() {
    setState(() {
      final tempLang = _leftLang;
      _leftLang = _rightLang;
      _rightLang = tempLang;

      final tempText = _inputController.text;
      _inputController.text = _translatedText;
      _translatedText = tempText;
    });
  }

  void _showExplanationModal(String explanation) {
    String selectedLevel = _explanationLevel;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 0.5, color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.85, // adjust height
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Explanation",
                            style: TextStyle(fontSize: 18),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() => _explain = false);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Body: scrollable
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child:
                            _isTranslating
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : SingleChildScrollView(
                                  child: Text(
                                    explanation,
                                    style: GoogleFonts.roboto(fontSize: 16),
                                  ),
                                ),
                      ),
                    ),

                    const Divider(thickness: 1),

                    // Bottom level bar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.grey[200],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children:
                            ['Level', 'A1', 'A2', 'B1'].map((level) {
                              final isActive = _explanationLevel == level;
                              return GestureDetector(
                                onTap: () {
                                  if (level != 'Level') {
                                    setModalState(
                                      () => _explanationLevel = level,
                                    );
                                    setState(() => _explanationLevel = level);
                                    final currentText =
                                        _inputController.text.trim();
                                    if (currentText.isNotEmpty) {
                                      _translateText(currentText);
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isActive
                                            ? const Color(0xFFCD2A3E)
                                            : null,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color:
                                          isActive
                                              ? Colors.white
                                              : Colors.black,
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

  Language _next(Language current, Language other) {
    final list = [Language.hu, Language.de, Language.en];
    int i = list.indexOf(current);
    Language next = list[(i + 1) % list.length];
    if (next == other) {
      next = list[(i + 2) % list.length];
    }
    return next;
  }

  Future<void> _translateText(String input) async {
    final from = _langLabels[_leftLang]!;
    final to = _langLabels[_rightLang]!;

    setState(() {
      _isTranslating = true;
      if (!_explain) _translatedText = '';
    });

    try {
      final result = await _gemini.translate(
        input,
        from,
        to,
        explain: _explain,
        level: _explanationLevel,
      );

      if (!mounted) return;

      if (_explain) {
        _showExplanationModal(result);
      } else {
        setState(() => _translatedText = result);

        // 3. Insert into the database now that you have `result`
        await _db.translationDao.insertTranslation(
          TranslationsCompanion.insert(
            input: input,
            output: result,
            fromLang: from,
            toLang: to,
            // timestamp and isFavorite have defaults
          ),
        );
      }
    } catch (e) {
      debugPrint('Translation error: $e');
      if (_explain) {
        _showExplanationModal('Failed to load explanation.');
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _showLoaderBeforeModal(
    Future<String> Function() loadExplanation,
  ) async {
    // Show fullscreen loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Run the translation and close loader when done
    final explanation = await loadExplanation();

    if (!mounted) return;

    Navigator.of(context).pop(); // Close the loader

    _showExplanationModal(explanation); // Show modal
  }

  @override
  Widget build(BuildContext context) {
    const double boxW = 486;
    const double switcherW = 350;
    const double switcherH = 55;
    const double flagSize = 50;
    const double switchSize = 50;
    final media = MediaQuery.of(context);
    final totalH = media.size.height;
    final topBarH = media.padding.top + kToolbarHeight;
    const bottomNavH = kBottomNavigationBarHeight;
    final usableH = totalH - topBarH - bottomNavH;
    final boxH = usableH / 2 - 80;

    return Container(
      color: textGrey,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ───── Editable Input (TOP) ─────
          SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
                    child: TextField(
                      controller: _inputController,
                      maxLines: null,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: _placeholderForLang(_leftLang),
                        hintStyle: GoogleFonts.robotoCondensed(
                          fontSize: 25,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: IconButton(
                    icon: Icon(
                      Icons.mic,
                      color: _isListening ? Colors.red : Colors.black,
                    ),
                    onPressed: () async {
                      if (await Permission.microphone.request().isGranted) {
                        _listen();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Microphone permission denied"),
                          ),
                        );
                      }
                    },
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: IconButton(
                    icon: Image.asset('assets/images/delete.png', width: 40),
                    onPressed: () {
                      setState(() {
                        // clear both text fields
                        _inputController.clear();
                        _translatedText = '';
                        // reset explanation mode if you had it on
                        _explain = false;
                        // if you want the scroll back to top:
                        _scrollController.jumpTo(0);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ───── Translated Output (BOTTOM) ─────
          SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Text(
                        _isTranslating
                            ? _translatingText(_rightLang)
                            : (_translatedText.isEmpty
                                ? _placeholderForLang(_rightLang)
                                : _translatedText),
                        style: GoogleFonts.robotoCondensed(
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          color: _isTranslating ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Row(
                    children: [
                      // Copy
                      IconButton(
                        icon: Image.asset('assets/images/copy.png', width: 30),
                        onPressed: () {
                          if (_translatedText.isNotEmpty) {
                            Clipboard.setData(
                              ClipboardData(text: _translatedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 5),

                      // Share
                      IconButton(
                        icon: Image.asset('assets/images/share.png', width: 30),
                        onPressed: () {
                          if (_translatedText.isNotEmpty) {
                            Share.share(_translatedText);
                          }
                        },
                      ),
                      const SizedBox(width: 5),

                      IconButton(
                        icon: Image.asset('assets/images/zoom.png', width: 40),
                        onPressed: () {
                          if (_translatedText.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder:
                                  (_) =>
                                      LandscapeZoomModal(text: _translatedText),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 4,
                  left: 160, // Adjust for layout balance
                  child: Tooltip(
                    message: _explain ? 'Explanation ON' : 'Explanation OFF',
                    child: IconButton(
                      icon: Icon(
                        _explain ? Icons.lightbulb : Icons.lightbulb_outline,
                        color: _explain ? Colors.amber : Colors.black54,
                        size: 50,
                      ),
                      onPressed:
                          _isTranslating
                              ? null
                              : () {
                                setState(() {
                                  _explain = true;
                                  _isTranslating = true;
                                  _translatedText = '';
                                });

                                final currentText =
                                    _inputController.text.trim();
                                if (currentText.isNotEmpty) {
                                  _showLoaderBeforeModal(() async {
                                    final from = _langLabels[_leftLang]!;
                                    final to = _langLabels[_rightLang]!;

                                    try {
                                      final result = await _gemini.translate(
                                        currentText,
                                        from,
                                        to,
                                        explain: true,
                                        level: _explanationLevel,
                                      );
                                      return result;
                                    } catch (e) {
                                      debugPrint('Explanation error: $e');
                                      return 'Failed to load explanation.';
                                    } finally {
                                      if (mounted)
                                        setState(() => _isTranslating = false);
                                    }
                                  });
                                } else {
                                  setState(() => _isTranslating = false);
                                }
                              },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () async {
                      if (_translatedText.isNotEmpty) {
                        await _speak();
                      }
                    },
                    child:
                        _isSpeaking
                            // pulsing loader
                            ? Transform.scale(
                              scale: _pulseAnim.value,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(navRed),
                                ),
                              ),
                            )
                            // normal speaker icon
                            : Image.asset(
                              'assets/images/play-sound.png',
                              width: 40,
                            ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          // ───── Flag Switcher ─────
          SizedBox(
            width: switcherW,
            height: switcherH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _rightLang = _next(_rightLang, _leftLang));
                  },
                  child: Row(
                    children: [
                      Text(
                        _langLabels[_rightLang]!,
                        style: GoogleFonts.roboto(
                          fontSize: 35,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        _flagPaths[_rightLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 25),
                GestureDetector(
                  onTap: _switchLanguages,
                  child: Image.asset(
                    'assets/images/switch.png',
                    width: switchSize,
                  ),
                ),
                const SizedBox(width: 25),
                GestureDetector(
                  onTap: () {
                    setState(() => _leftLang = _next(_leftLang, _rightLang));
                  },
                  child: Row(
                    children: [
                      Image.asset(
                        _flagPaths[_leftLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _langLabels[_leftLang]!,
                        style: GoogleFonts.roboto(
                          fontSize: 35,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _placeholderForLang(Language lang) {
    switch (lang) {
      case Language.hu:
        return "Kezdje el a beírást...";
      case Language.de:
        return "Beginnen Sie mit der Eingabe...";
      default:
        return "Begin typing...";
    }
  }
}

class LandscapeZoomModal extends StatelessWidget {
  final String text;
  const LandscapeZoomModal({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // Dialog with transparent background so only our white box shows
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotated box: portrait device → looks landscape
          RotatedBox(
            quarterTurns: 1, // 90° clockwise
            child: Container(
              // after rotation, width comes from screen height
              width: MediaQuery.of(context).size.height - 40,
              // and height comes from screen width
              height: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.start, // left-aligned
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // A close button that undoes the rotation so it appears upright
          Positioned(
            top: 0,
            right: 0,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
