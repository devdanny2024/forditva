// lib/textpage.dart

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart' as ap;
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

bool _isAudioPlaying = false;

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
  bool _isAudioLoadingInput = false; // For the input card play button
  bool _isAudioLoadingOutput = false; // For the output card play button
  ap.AudioPlayer? _audioPlayer;
  bool _isInputPlaying = false;
  bool _isOutputPlaying = false;
  ap.AudioPlayer? _inputAudioPlayer;
  ap.AudioPlayer? _outputAudioPlayer;

  // ▶︎ your Gemini client
  final GeminiTranslator _gemini = GeminiTranslator();
  final _ttsService = OpenAiTtsService(); // Or inject if you use DI

  // ▶︎ map your Language enum into its two-letter codes
  final Map<Language, String> _langLabels = {
    Language.hungarian: 'HU',
    Language.german: 'DE',
    Language.english: 'EN',
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

    final file = await _ttsService.synthesizeSpeech(
      text: _translation,
      voice: "onyx",
      instructions: instructionForLang(_rightLanguage),
    );

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

    final file = await _ttsService.synthesizeSpeech(
      text: _inputController.text,
      voice: "onyx",
      instructions: instructionForLang(_leftLanguage),
    );

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

    String sourceText;
    Language fromLang, toLang;

    if (leftChanged) {
      sourceText = _translation;
      fromLang = _rightLanguage;
      toLang = _leftLanguage;
      if (sourceText.trim().isEmpty) {
        setState(() {
          _isTranslating = false;
          _isAudioLoadingOutput = false;
        });
        return;
      }
      final result = await _gemini.translate(
        sourceText,
        fromLang.code,
        toLang.code,
      );
      setState(() {
        _inputController.text = result;
        _isTranslating = false;
      });
      if (playTTS) await _autoPlayOutputTTS(); // Only play TTS if allowed
    } else {
      sourceText = _inputController.text;
      fromLang = _leftLanguage;
      toLang = _rightLanguage;
      if (sourceText.trim().isEmpty) {
        setState(() {
          _isTranslating = false;
          _isAudioLoadingInput = false;
        });
        return;
      }
      final result = await _gemini.translate(
        sourceText,
        fromLang.code,
        toLang.code,
      );
      setState(() {
        _translation = result;
        _isTranslating = false;
      });
      if (playTTS) await _autoPlayInputTTS(); // Only play TTS if allowed
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
    if (from == 'HU' || to == 'HU') {
      final normalized = await _gemini.translate(input, from, to);
      // Only use the final translation result:
      return await _gemini.translate(normalized, from, to);
    } else {
      return await _gemini.translate(input, from, to);
    }
  }

  String _explanationLevel = 'A2';

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
                            icon: const Icon(Icons.close),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.copyToClipboard)),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final switchSize = 70.0;
        final flagSize = 30.0;

        final halfH = constraints.maxHeight / 2;
        final inputCardTop = 0.0;
        final inputCardHeight = halfH + switchSize / 2;
        final outputCardTop = halfH - switchSize / 2 - 15.0;
        final outputCardHeight = halfH + switchSize / 2;
        final switchRowTop = halfH - switchSize / 2 / 0.7;
        final rightOverlayTop = halfH - switchSize / 2 / 0.7;
        print(
          '_isTopRecording: $_isTopRecording, _isBottomRecording: $_isBottomRecording',
        );

        return Container(
          padding: EdgeInsets.only(top: 30, bottom: 0),
          child: Stack(
            children: [
              // Input card

              // INPUT side (dark/inverted):
              Positioned(
                top: inputCardTop,
                left: 16,
                right: 16,
                height: inputCardHeight,
                child: TranslationCard(
                  inverted: true,
                  text: _translation,
                  fromLang: _rightLanguage,
                  toLang: _leftLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingInput,
                  isAudioPlaying: _isInputPlaying,
                  isRecording: _isTopRecording,
                  onExplain: () {
                    final current = _translation.trim();
                    if (current.isNotEmpty) {
                      setState(() => _isTranslating = true);
                      _showLoaderBeforeModal(() async {
                        try {
                          return await _gemini.translate(
                            current,
                            _langLabels[_rightLanguage]!,
                            _langLabels[_leftLanguage]!,
                            explain: true,
                            level: _explanationLevel,
                          );
                        } catch (_) {
                          return 'Failed to load explanation.';
                        } finally {
                          if (mounted) setState(() => _isTranslating = false);
                        }
                      });
                    }
                  },
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
                              if (mounted)
                                setState(() => _isTranslating = false);
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

              // OUTPUT side (bright):
              Positioned(
                top: outputCardTop,
                left: 16,
                right: 16,
                height: outputCardHeight,
                child: TranslationCard(
                  inverted: false,
                  text: _inputController.text,
                  fromLang: _leftLanguage,
                  toLang: _rightLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingOutput,
                  isAudioPlaying: _isOutputPlaying,
                  isRecording: _isBottomRecording,
                  onCopy: () => _copyText(_inputController.text),
                  onPlay: _playOutputSound,
                  onStop: _stopOutputSound,
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
                              if (mounted)
                                setState(() => _isTranslating = false);
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
              // Right overlay
              Positioned(
                top: rightOverlayTop,
                left: constraints.maxWidth / 2 - switchSize / 4,
                right: 16,
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/bg-dark.jpg',
                      ), // For assets
                      fit: BoxFit.cover,
                    ),
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
                top: switchRowTop,
                left: 26,
                right: 26,
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
                            onTap: () {
                              setState(() {
                                _leftLanguage = _leftLanguage.next(
                                  _rightLanguage,
                                );
                              });
                              autoTranslateOnLanguageChange(leftChanged: true);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  child: Image.asset(
                                    flagAsset(
                                      _leftLanguage,
                                      whiteBorder: false,
                                    ), // White border
                                    width: flagSize,
                                    height: flagSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Image.asset(
                                  'assets/images/${_leftLanguage.label}-${_leftLanguage.label}.png', // e.g. EN-EN.png
                                  height: flagSize,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
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
                            // No TTS auto play after switch
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
                      // Right language toggle
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 10.0,
                            bottom: 10,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _rightLanguage = _rightLanguage.next(
                                  _leftLanguage,
                                );
                              });
                              autoTranslateOnLanguageChange(leftChanged: false);
                            },
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
                                      ), // White border
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
                                    'assets/images/${_rightLanguage.label}-${_rightLanguage.label}.png',
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
                          if (txt.trim().isNotEmpty) {
                            setState(() {
                              _translation = txt;
                              _isTranslating = true;
                            });

                            final result = await translateFinal(
                              txt,
                              _rightLanguage.code,
                              _leftLanguage.code,
                            );

                            setState(() {
                              _inputController.text = result;
                              _isTranslating = false;
                            });
                          }
                          setState(() => _isTopRecording = false);
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
                          if (txt.trim().isNotEmpty) {
                            setState(() {
                              _inputController.text = txt;
                              _isTranslating = true;
                            });

                            final result = await translateFinal(
                              txt,
                              _leftLanguage.code,
                              _rightLanguage.code,
                            );

                            setState(() {
                              _translation = result;
                              _isTranslating = false;
                            });
                          }
                          setState(() => _isBottomRecording = false);
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
