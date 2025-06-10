import 'dart:async';
import 'dart:math' as math; // ← Add this at the top of your file

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
import 'package:google_fonts/google_fonts.dart';

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
    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = true;
    });
    _inputAudioPlayer ??= ap.AudioPlayer();

    // <--- THIS is what you need:
    final file = await _ttsService.synthesizeSpeech(
      text: _translation,
      voice: "onyx",
      instructions: instructionForLang(_rightLanguage),
    );
    // <--- ^^^

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

  Future<void> autoTranslateOnLanguageChange({bool leftChanged = true}) async {
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
      await _autoPlayOutputTTS(); // <-- use this!
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
      await _autoPlayInputTTS(); // <-- use this!
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

  Future<void> _playSoundAndReveal({
    required String text,
    required Language lang,
    required String instructions,
    required VoidCallback onReveal,
  }) async {
    try {
      const voice = "onyx";
      final file = await _ttsService.synthesizeSpeech(
        text: text,
        voice: voice,
        instructions: instructions,
      );

      if (!await file.exists() || (await file.length()) == 0) {
        onReveal(); // Reveal anyway if audio fails
        return;
      }

      final player = ap.AudioPlayer();
      StreamSubscription<ap.PlayerState>? stateSub;
      stateSub = player.onPlayerStateChanged.listen((state) {
        if (state == ap.PlayerState.playing) {
          onReveal();
          stateSub?.cancel(); // Cancel the subscription after revealing
        }
      });

      await player.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      onReveal(); // Reveal anyway on error
    }
  }

  Future<void> _openRecordingCustom({
    required Language from,
    required Language to,
    required bool isTopPanel, // true = output/top, false = input/bottom
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
                  if (transcript.trim().isEmpty) {
                    if (mounted) setState(() => _isTranslating = false);
                    return;
                  }
                  if (mounted) setState(() => _isTranslating = true);

                  // Set the transcribed text (user's speech) to the card
                  // where the *translated* text previously appeared.
                  if (isTopPanel) {
                    // If top mic tapped, transcribed text goes to the top card (_translation)
                    setState(() {
                      _translation = transcript;
                    });
                  } else {
                    // If bottom mic tapped, transcribed text goes to the bottom card (_inputController.text)
                    setState(() {
                      _inputController.text = transcript;
                    });
                  }

                  // Always translate from the user's spoken language (`from.code`)
                  // to the target language (`to.code`).
                  final geminiResult = await translateFinal(
                    transcript,
                    from.code,
                    to.code,
                  );

                  // Now, set the translated text to the card
                  // where the *transcribed* text previously appeared.
                  if (isTopPanel) {
                    // Top mic tapped: translated text goes to the bottom card (_inputController.text)
                    setState(() {
                      _inputController.text = geminiResult;
                      _isTranslating =
                          false; // Stop general translation busy indicator
                    });
                    // Play TTS for the translated text (now in _inputController.text, language is _leftLanguage)
                    setState(
                      () => _isAudioLoadingInput = true,
                    ); // Assuming _isAudioLoadingInput is for the bottom card
                    await _playSoundWithOpenAI(
                      _inputController.text, // Text to play
                      _leftLanguage, // Language of the translated text
                      instructionForLang(_leftLanguage),
                      () {}, // onStart: Don't reveal, text is already visible
                      () {
                        if (mounted)
                          setState(() => _isAudioLoadingInput = false);
                      },
                    );
                  } else {
                    // Bottom mic tapped: translated text goes to the top card (_translation)
                    setState(() {
                      _translation = geminiResult;
                      _isTranslating =
                          false; // Stop general translation busy indicator
                    });
                    // Play TTS for the translated text (now in _translation, language is _rightLanguage)
                    setState(
                      () => _isAudioLoadingOutput = true,
                    ); // Assuming _isAudioLoadingOutput is for the top card
                    await _playSoundWithOpenAI(
                      _translation, // Text to play
                      _rightLanguage, // Language of the translated text
                      instructionForLang(_rightLanguage),
                      () {}, // onStart: Don't reveal, text is already visible
                      () {
                        if (mounted)
                          setState(() => _isAudioLoadingOutput = false);
                      },
                    );
                  }
                },
                onPartialTranscript: (partial) {
                  // Optional: If you want live updates as user speaks, handle here
                  // You might need to adjust this logic too if you want partials to swap places
                  // according to the new logic. For now, it's left as is to avoid over-complication.
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
        return Container(
          padding: const EdgeInsets.only(top: 30),
          child: Stack(
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
                  isAudioPlaying: _isInputPlaying,
                  onPlaySound: _playInputSound,
                  onStopSound: _stopInputSound,
                  isAudioLoading: _isAudioLoadingInput,

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
                          _inputController.text,
                          _leftLanguage,
                          instructionForLang(_leftLanguage),
                          () {}, // Don't reveal (already visible)
                          () {
                            if (mounted) setState(() => _isTranslating = false);
                          },
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
                ),
              ),
              // Left overlay

              // Output card
              Positioned(
                top: halfH - 20,
                left: 16,
                right: 16,
                height: halfH + switchSize / 2,
                child: TranslationOutputCard(
                  fromLang: _leftLanguage,
                  toLang: _rightLanguage,
                  key: outputKey,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingOutput,
                  isAudioPlaying: _isOutputPlaying,
                  onPlaySound: _playOutputSound,
                  onStopSound: _stopOutputSound,
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
                            if (mounted) setState(() => _isTranslating = false);
                          },
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
                top: halfH - switchSize / 2,
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
                          padding: const EdgeInsets.only(left: 10.0, top: 20),
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
                          onTap: () {
                            setState(() {
                              final tmpLang = _leftLanguage;
                              _leftLanguage = _rightLanguage;
                              _rightLanguage = tmpLang;
                              final tmpText = _inputController.text;
                              _inputController.text = _translation;
                              _translation = tmpText;
                            });
                            // Only update translations. Do NOT call any _playSoundWithOpenAI here!
                            autoTranslateOnLanguageChange(leftChanged: true);
                            autoTranslateOnLanguageChange(leftChanged: false);
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
                          padding: const EdgeInsets.only(
                            right: 10.0,
                            bottom: 30,
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
            ],
          ),
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
  final bool isAudioLoading; // <-- Add this
  final bool isAudioPlaying;
  final VoidCallback? onStopSound;

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
    required this.isAudioLoading,
    required this.isAudioPlaying,
    this.onStopSound,
    this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = calculateFontSize(text);

    return Container(
      // Keep your border radius and any base color here
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      clipBehavior:
          Clip.antiAlias, // This ensures rounded corners for everything inside!
      child: Stack(
        fit: StackFit.expand,
        children: [
          // --- ZOOMED-IN BACKGROUND IMAGE ---
          Positioned.fill(
            child: Image.asset('assets/images/bg-dark.jpg', fit: BoxFit.cover),
          ),
          // --- FOREGROUND CONTENT (unchanged) ---
          // Scrollable, upside-down text, taking all space except for icons/mic
          Positioned.fill(
            top: 100,
            bottom: dynamicInputBottom(fontSize),
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              reverse: true,
              physics: const BouncingScrollPhysics(),
              child: RotatedBox(
                quarterTurns: 2,
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
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 60,
                  height: 60,
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
            top: 20,
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
            top: 20,
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // if (isAudioLoading)
                    //   SizedBox(
                    //     width: 30,
                    //     height: 30,
                    //     child: CircularProgressIndicator(
                    //       strokeWidth: 2,
                    //       valueColor: AlwaysStoppedAnimation<Color>(
                    //         Colors.amber,
                    //       ),
                    //     ),
                    //   )
                    // else
                    if (isAudioPlaying)
                      GestureDetector(
                        onTap: onStopSound,
                        child: Icon(Icons.stop, size: 40, color: Colors.red),
                      )
                    else
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
  final bool isBusy; // <-- Add this!
  final bool isAudioLoading; // <-- Add this
  final VoidCallback? onCopy;
  final VoidCallback? onPlaySound;
  final bool isAudioPlaying;
  final VoidCallback? onStopSound;

  const TranslationOutputCard({
    super.key,
    required this.fromLang,
    required this.toLang,
    required this.controller,
    required this.isBusy, // <-- Add this!
    required this.onMicTap,
    this.onEditTap,
    this.onCopy,
    this.onPlaySound,
    required this.isAudioPlaying,
    this.onStopSound,
    required this.isAudioLoading,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = calculateFontSize(controller.text);

    // Estimate how much space the mic row uses (including icons), then pad bottom accordingly
    const double bottomReserved = 110; // mic + icons area
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias, // ensures borderRadius works on image!
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg-bright.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // The scrollable, non-editable transcribed text
          Positioned.fill(
            bottom: bottomReserved,
            top: 0, // reserve space for mic/icons row
            child: SingleChildScrollView(
              padding: dynamicOutputPadding(fontSize),
              child: GestureDetector(
                onTap: onEditTap,
                child: Center(
                  child:
                      isBusy
                          ? const Center(child: CircularProgressIndicator())
                          : Text(
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
            bottom: 60,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onMicTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    flagAsset(fromLang, whiteBorder: false),
                    width: 60,
                    height: 60,
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
            bottom: 60,
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
            bottom: 60,
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // if (isAudioLoading)
                    //   SizedBox(
                    //     width: 30,
                    //     height: 30,
                    //     child: CircularProgressIndicator(
                    //       strokeWidth: 2,
                    //       valueColor: AlwaysStoppedAnimation<Color>(
                    //         Colors.amber,
                    //       ),
                    //     ),
                    //   )
                    // else
                    if (isAudioPlaying)
                      GestureDetector(
                        onTap: onStopSound,
                        child: Icon(Icons.stop, size: 40, color: Colors.red),
                      )
                    else
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
