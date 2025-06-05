import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/db/database.dart';
import 'package:forditva/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/gemini_translation_service.dart';
import '../services/lingvanex_translation_service.dart';

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
  late final KeyboardVisibilityController _keyboardVisibilityController;
  late StreamSubscription<bool> _keyboardSubscription;
  bool _keyboardIsVisible = false;

  late final FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ScrollController _scrollController = ScrollController();
  final String _explanationText = '';
  final LingvanexTranslationService _lingvanex = LingvanexTranslationService();
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
    _keyboardVisibilityController = KeyboardVisibilityController();
    _keyboardSubscription = _keyboardVisibilityController.onChange.listen((
      bool visible,
    ) {
      setState(() {
        _keyboardIsVisible = visible;
      });
    });
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
    _keyboardSubscription.cancel();

    super.dispose();
  }

  void _onInputChanged() {
    // Cancel any pending translation
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    // Immediately clear the old translation and show the "Translating…" text
    setState(() {
      _translatedText = '';
      _isTranslating = true;
    });

    // Wait 1 second after the last keystroke, then actually translate
    _debounce = Timer(const Duration(seconds: 1), () {
      final currentText = _inputController.text.trim();

      if (currentText.isNotEmpty) {
        _translateText(currentText);
      } else {
        // No input → stop the translating indicator
        setState(() {
          _isTranslating = false;
        });
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
                  _langLabels[_leftLang]!,
                  _langLabels[_rightLang]!,
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

            return Dialog(
              backgroundColor: Colors.white, // white background
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 0.5, color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
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

                    // Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child:
                            isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : SingleChildScrollView(
                                  child: Text(
                                    explanationText,
                                    style: GoogleFonts.roboto(fontSize: 16),
                                  ),
                                ),
                      ),
                    ),

                    const Divider(thickness: 1),

                    // Level selector
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
                                    color:
                                        active ? const Color(0xFFCD2A3E) : null,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
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

  Language _next(Language current, Language other) {
    final list = [Language.hu, Language.de, Language.en];
    int i = list.indexOf(current);
    Language next = list[(i + 1) % list.length];
    if (next == other) {
      next = list[(i + 2) % list.length];
    }
    return next;
  }

  /// Map our Language enum into Lingvanex’s `xx_XX` codes
  String _lingvanexCode(Language lang) {
    // reuse your existing _localeFor() which returns "en-US", "de-DE", etc.
    return _localeFor(lang).replaceAll('-', '_');
  }

  Future<void> _translateText(String input) async {
    final from = _langLabels[_leftLang]!;
    final to = _langLabels[_rightLang]!;
    final String currentText = _inputController.text.trim();

    setState(() {
      _isTranslating = true;
      if (!_explain) _translatedText = '';
    });

    try {
      final dynamic raw = await _lingvanex.translate(
        data: currentText, // ← use currentText
        fromLang: _lingvanexCode(_leftLang),
        toLang: _lingvanexCode(_rightLang),
      );
      final String result =
          raw is List ? (raw).first.toString() : raw.toString();
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
    final media = MediaQuery.of(context);
    print('viewInsets.bottom: ${media.viewInsets.bottom}');
    final bool keyboardIsOpen = media.viewInsets.bottom > 50;

    final double cardWidth = 486;
    final double cardHeight = media.size.height * 0.8;
    String inputText = _inputController.text;
    String outText = _translatedText;

    double inputFontSize = dynamicFontSize(inputText);
    double outputFontSize = dynamicFontSize(outText);

    return Center(
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // --- Top section: always at least 500px ---
            SizedBox(
              height: _keyboardIsVisible ? 420 : 300,
              child: Stack(
                children: [
                  // Autosizing scrollable text field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      56,
                    ), // Leave space at bottom for controls
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 40, // minimum height
                            maxHeight: 200, // maximum height for input field
                          ),
                          child: SingleChildScrollView(
                            // This scrolls only if text overflows
                            child: TextField(
                              controller: _inputController,
                              maxLines: null,
                              style: GoogleFonts.robotoCondensed(
                                fontSize: inputFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration.collapsed(
                                hintText: _placeholderForLang(_leftLang),
                                hintStyle: GoogleFonts.robotoCondensed(
                                  fontSize: 25,
                                  color: Colors.grey,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                FocusScope.of(context).unfocus();
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // The controls row is pinned to the bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.mic,
                              color: _isListening ? Colors.red : Colors.black,
                            ),
                            onPressed: () async {
                              if (await Permission.microphone
                                  .request()
                                  .isGranted) {
                                _listen();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Microphone permission denied",
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap:
                                () => setState(
                                  () =>
                                      _leftLang = _next(_leftLang, _rightLang),
                                ),
                            child: Row(
                              children: [
                                Image.asset(
                                  _flagPaths[_leftLang]!,
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _langLabels[_leftLang]!,
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _switchLanguages,
                            child: Image.asset(
                              'assets/images/switch.png',
                              width: 32,
                              height: 32,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap:
                                () => setState(
                                  () =>
                                      _rightLang = _next(_rightLang, _leftLang),
                                ),
                            child: Row(
                              children: [
                                Text(
                                  _langLabels[_rightLang]!,
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Image.asset(
                                  _flagPaths[_rightLang]!,
                                  width: 32,
                                  height: 32,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Image.asset(
                              'assets/images/delete.png',
                              width: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _inputController.clear();
                                _translatedText = '';
                                _explain = false;
                                _scrollController.jumpTo(0);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Divider ---
            const Divider(height: 1, thickness: 1),
            // --- Output panel: only when keyboard is closed ---
            if (!_keyboardIsVisible)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Text(
                            _isTranslating
                                ? _translatingText(_rightLang)
                                : _translatedText,
                            style: GoogleFonts.robotoCondensed(
                              fontSize: outputFontSize,
                              fontWeight: FontWeight.w500,
                              color:
                                  _isTranslating ? Colors.grey : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Image.asset(
                              'assets/images/copy.png',
                              width: 28,
                            ),
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
                          IconButton(
                            icon: Image.asset(
                              'assets/images/share.png',
                              width: 28,
                            ),
                            onPressed: () {
                              if (_translatedText.isNotEmpty) {
                                Share.share(_translatedText);
                              }
                            },
                          ),
                          IconButton(
                            icon: Image.asset(
                              'assets/images/zoom.png',
                              width: 34,
                            ),
                            onPressed: () {
                              if (_translatedText.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder:
                                      (_) => LandscapeZoomModal(
                                        text: _translatedText,
                                      ),
                                );
                              }
                            },
                          ),
                          Tooltip(
                            message:
                                _explain ? 'Explanation ON' : 'Explanation OFF',
                            child: IconButton(
                              icon: Icon(
                                _explain
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline,
                                color: _explain ? Colors.amber : Colors.black54,
                                size: 32,
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
                                            try {
                                              return await _gemini.translate(
                                                currentText,
                                                _langLabels[_leftLang]!,
                                                _langLabels[_rightLang]!,
                                                explain: true,
                                                level: _explanationLevel,
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                'Explanation error: $e',
                                              );
                                              return 'Failed to load explanation.';
                                            } finally {
                                              if (mounted)
                                                setState(
                                                  () => _isTranslating = false,
                                                );
                                            }
                                          });
                                        } else {
                                          setState(
                                            () => _isTranslating = false,
                                          );
                                        }
                                      },
                            ),
                          ),
                          Spacer(),
                          GestureDetector(
                            onTap: () async {
                              if (_translatedText.isNotEmpty) {
                                await _speak();
                              }
                            },
                            child:
                                _isSpeaking
                                    ? Transform.scale(
                                      scale: _pulseAnim.value,
                                      child: SizedBox(
                                        width: 34,
                                        height: 34,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            navRed,
                                          ),
                                        ),
                                      ),
                                    )
                                    : Image.asset(
                                      'assets/images/play-sound.png',
                                      width: 34,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
