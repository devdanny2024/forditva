import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/db/database.dart';
import 'package:forditva/document/document_translation_state.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/OpenAiTtsService.dart'; // already used in TextPage
import 'package:forditva/services/google_speech_to_text_service.dart';
import 'package:forditva/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart'; // getTemporaryDirectory
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; // AudioRecorder, RecordConfig, AudioEncoder
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/gemini_translation_service.dart';

const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);

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
  bool _isRecording = false;
  late final RecorderController _recorderController;
  late final AudioRecorder _audioRecorder;
  String? _recordPath;
  bool _isInputLoading = false;
  final _ttsService = OpenAiTtsService(); // 👈 Gemini/OpenAI TTS wrapper
  ap.AudioPlayer? _ttsAudioPlayer; // 👈 audio player instance
  double _zoomLevel = 1.0; // Default zoom factor

  late final FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  final bool _isListening = false;
  final ScrollController _scrollController = ScrollController();
  final GeminiTranslator _gemini = GeminiTranslator();
  late TextEditingController _inputController;
  late FocusNode _inputFocusNode;

  String _explanationLevel = 'A2'; // default level
  late final AppDatabase _db;

  Language _leftLang = Language.english;
  Language _rightLang = Language.hungarian;

  final Map<Language, String> _flagPaths = {
    Language.english: 'assets/flags/EN_BW_LS.png',
    Language.german: 'assets/flags/DE_BW_LS.png',
    Language.hungarian: 'assets/flags/HU_BW_LS.png',
  };

  final Map<Language, String> _langLabels = {
    Language.english: 'EN',
    Language.german: 'DE',
    Language.hungarian: 'HU',
  };
  String instructionForLang(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return "Speak as this dialect: Hungarian";
      case Language.german:
        return "Speak as this dialect: German";
      case Language.english:
      default:
        return "Speak as this dialect: English";
    }
  }

  String _localeFor(Language lang) {
    switch (lang) {
      case Language.english:
        return 'en-US';
      case Language.german:
        return 'de-DE';
      case Language.hungarian:
        return 'hu-HU';
    }
  }

  String _translatingText(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return 'Fordítás…';
      case Language.german:
        return 'Übersetzen…';
      case Language.english:
      default:
        return 'Translating…';
    }
  }

  String _detectedLangDialog(Language lang, String detectedLangName) {
    switch (lang) {
      case Language.hungarian:
        return "Az észlelt nyelv: $detectedLangName. Szeretné módosítani a beállítást erre?";
      case Language.german:
        return "Die erkannte Sprache ist $detectedLangName. Sollen wir deine Einstellung darauf anpassen?";
      case Language.english:
      default:
        return "The detected language is $detectedLangName. Should we change your setting to this?";
    }
  }

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  bool _isSpeaking = false;
  Future<void> _speak() async {
    if (_translatedText.isEmpty) return;

    try {
      final instructions = instructionForLang(_leftLang);
      final file = await _ttsService.synthesizeSpeech(
        text: _translatedText,
        voice: "onyx",
        instructions: instructions,
      );

      if (!await file.exists() || (await file.length()) == 0) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("TTS failed: ${file.path}")));
        }
        return;
      }

      _ttsAudioPlayer ??= ap.AudioPlayer();
      await _ttsAudioPlayer!.stop();

      late final StreamSubscription sub;
      sub = _ttsAudioPlayer!.onPlayerStateChanged.listen((state) {
        if (!mounted) return;

        if (state == ap.PlayerState.playing) {
          setState(() => _isSpeaking = true);
        } else if (state == ap.PlayerState.completed ||
            state == ap.PlayerState.stopped) {
          setState(() => _isSpeaking = false);
          sub.cancel();
        }
      });

      await _ttsAudioPlayer!.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("TTS failed: $e")));
        setState(() => _isSpeaking = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _inputFocusNode = FocusNode();

    final locale =
        WidgetsBinding.instance.window.locale; // safer than waiting for context
    final pair = getInitialLangPair(locale);

    // Only set if not manually overridden before
    _leftLang = pair[0];
    _rightLang = pair[1];
    _recorderController = RecorderController();
    _audioRecorder = AudioRecorder();
    _inputController = TextEditingController(
      text: DocumentTranslationState.inputText,
    );
    _translatedText = DocumentTranslationState.translatedText;
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
    _inputController.addListener(_onInputChanged);

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

  Language _langFromCode(String code) {
    return Language.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => _leftLang, // fallback to current
    );
  }

  @override
  void dispose() {
    _recorderController.dispose();
    _inputFocusNode.dispose();

    _db.close(); // ← close the DB when the page is torn down
    _ttsAudioPlayer?.dispose();

    _pulseController.dispose();
    _debounce?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _keyboardSubscription.cancel();

    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _isRecording = true);

    final dir = await getTemporaryDirectory();
    _recordPath =
        '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Start actual audio recording (for STT)
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordPath!,
    );

    // Start waveform visualization
    _recorderController.record();
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isInputLoading = true;
    });

    await _recorderController.stop();
    if (_recordPath == null) return;

    await _audioRecorder.stop(); // Optional if also using AudioRecorder in doc

    final file = File(_recordPath!);
    if (!file.existsSync()) {
      setState(() => _isInputLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Recording failed.")));
      }
      return;
    }

    try {
      final sttService = GoogleSpeechToTextService(
        dotenv.env['GOOGLE_STT_KEY']!,
      );
      final transcript = await sttService.transcribe(
        file,
        languageCode: _localeFor(_rightLang),
      );

      debugPrint('DEBUG: Transcript from Google STT: "$transcript"');

      if (transcript != null && transcript.trim().isNotEmpty) {
        final old = _inputController.text.trim();
        final newText = ('$old ${transcript.trim()}').trim();

        setState(() {
          _inputController.text = newText;
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
        });

        debugPrint('Updated text: "$newText"');
      } else {
        debugPrint('Transcript was empty or null');
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Transcription failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isInputLoading = false);
    }
  }

  void _onInputChanged() {
    // Update global state
    DocumentTranslationState.inputText = _inputController.text;

    if (_debounce?.isActive ?? false) _debounce?.cancel();

    setState(() {
      _translatedText = '';
      _isTranslating = true;
    });

    _debounce = Timer(const Duration(seconds: 1), () {
      final currentText = _inputController.text.trim();
      if (currentText.isNotEmpty) {
        _translateText(currentText);
      } else {
        setState(() {
          _isTranslating = false;
        });
      }
    });
  }

  Widget _buildSection(String title, String content) {
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

  String _translatedText = '';

  void _switchLanguages() {
    setState(() {
      final tempLang = _rightLang;
      _rightLang = _leftLang;
      _leftLang = tempLang;

      final tempText = _inputController.text;
      _inputController.text = _translatedText;
      _translatedText = tempText;

      final input = _inputController.text.trim();
      if (input.isNotEmpty) _translateText(input);
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

            // parsing logic for structured Gemini JSON
            Map<String, dynamic> parsed = {};
            try {
              final cleanJson = stripCodeFence(explanationText);
              parsed = cleanJson.isNotEmpty ? jsonDecode(cleanJson) : {};
            } catch (e) {
              parsed = {};
            }

            return Dialog(
              backgroundColor: Colors.white,
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
                    // --- HEADER WITH LOGO & TUTOR ---
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
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
                                ? const Center(child: GifLoader(size: 80))
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
                                    color: active ? navRed : null,
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
    final list = [Language.hungarian, Language.german, Language.english];
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
    final from = _langLabels[_rightLang]!; // used to be _leftLang
    final to = _langLabels[_leftLang]!; // used to be _rightLang

    final String currentText = _inputController.text.trim();

    setState(() {
      _isTranslating = true;
      if (!_explain) _translatedText = '';
    });

    try {
      final result = await _gemini.translate(
        currentText,
        from,
        to,
        explain: false,
      );

      if (!mounted) return;

      if (_explain) {
        _showExplanationModal(result);
      } else {
        setState(() {
          _translatedText = result;
          DocumentTranslationState.translatedText = result;
        });
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
      builder: (_) => const Center(child: GifLoader(size: 80)),
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
    final bool keyboardIsOpen = media.viewInsets.bottom > 50;

    final double cardWidth = 486;
    final double cardHeight = media.size.height * 0.8;
    String inputText = _inputController.text;
    String outText = _translatedText;

    double inputFontSize = dynamicFontSize(inputText);
    double outputFontSize = dynamicFontSize(outText);

    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
      ), // 👈 prevents overlap with status bar
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: cardWidth,
          height: MediaQuery.of(context).size.height - 10, // 👈 fills to bottom
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // 🔲 TOP PANEL
              Expanded(
                flex: 45,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 0.5),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/bg-bright.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 0, 5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: _keyboardIsVisible ? 60 : 0,
                            ),
                            child: SingleChildScrollView(
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_inputFocusNode);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      constraints: const BoxConstraints(
                                        minHeight: 180,
                                      ),
                                      width: double.infinity,
                                      child: TextField(
                                        controller: _inputController,
                                        focusNode: _inputFocusNode,
                                        maxLines: null,
                                        style: GoogleFonts.robotoCondensed(
                                          fontSize:
                                              dynamicFontSize(
                                                _inputController.text,
                                              ) *
                                              _zoomLevel,
                                          height:
                                              1.2, // <-- This increases line spacing

                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          isCollapsed: false,
                                        ),
                                        textInputAction: TextInputAction.done,
                                        onEditingComplete:
                                            () =>
                                                FocusScope.of(
                                                  context,
                                                ).unfocus(),
                                      ),
                                    ),
                                  ),

                                  // 👇 Dynamic language-based hint overlay
                                  if (!_inputFocusNode.hasFocus &&
                                      _inputController.text.trim().isEmpty)
                                    Positioned(
                                      top: 12,
                                      left: 0,
                                      right: 0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: IgnorePointer(
                                          child: Text(
                                            _placeholderForLang(
                                              _rightLang,
                                            ), // ← restored dynamic hint
                                            style: GoogleFonts.robotoCondensed(
                                              fontSize: 25 * _zoomLevel,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  if (_isInputLoading)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            navRed,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // 📋 Paste Icon – bottom left when keyboard is hidden
                          if (!_keyboardIsVisible)
                            Positioned(
                              bottom: 8,
                              left: 45,
                              right: 0,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          final data = await Clipboard.getData(
                                            'text/plain',
                                          );
                                          if (data?.text != null &&
                                              data!.text!.trim().isNotEmpty) {
                                            setState(() {
                                              final current =
                                                  _inputController.text.trim();
                                              final pasted = data.text!.trim();
                                              final updated =
                                                  ('$current $pasted').trim();
                                              _inputController.text = updated;
                                              _inputController.selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset:
                                                          _inputController
                                                              .text
                                                              .length,
                                                    ),
                                                  );
                                            });
                                          }
                                        },
                                        child: Image.asset(
                                          'assets/images/paste.png',
                                          width: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () async {
                                          if (_isRecording) {
                                            await _stopRecording();
                                          } else {
                                            if (await Permission.microphone
                                                .request()
                                                .isGranted) {
                                              await _startRecording();
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "Microphone permission denied",
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Image.asset(
                                          _isRecording
                                              ? 'assets/images/stoprec.png'
                                              : 'assets/images/microphone-white-border.png',
                                          width: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_isRecording)
                                        SizedBox(
                                          width: 90,
                                          height: 20,
                                          child: AudioWaveforms(
                                            enableGesture: false,
                                            size: const Size(90, 20),
                                            recorderController:
                                                _recorderController,
                                            waveStyle: const WaveStyle(
                                              waveColor: navGreen,
                                              showMiddleLine: false,
                                              extendWaveform: true,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          // 🎙 Only show when keyboard is visible
                          if (_keyboardIsVisible)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Group ❌ | 📋 | 🎙 with spacing
                                    Row(
                                      children: [
                                        // ❌ Close icon
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _inputController.text = '';
                                              _translatedText = '';
                                              DocumentTranslationState
                                                  .inputText = '';
                                              DocumentTranslationState
                                                  .translatedText = '';
                                            });
                                          },
                                          child: Image.asset(
                                            'assets/images/close.png',
                                            width: 40,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // 📋 Paste icon
                                        GestureDetector(
                                          onTap: () async {
                                            final data =
                                                await Clipboard.getData(
                                                  'text/plain',
                                                );
                                            if (data?.text != null &&
                                                data!.text!.trim().isNotEmpty) {
                                              setState(() {
                                                final current =
                                                    _inputController.text
                                                        .trim();
                                                final pasted =
                                                    data.text!.trim();
                                                final updated =
                                                    ('$current $pasted').trim();
                                                _inputController.text = updated;
                                                _inputController.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            _inputController
                                                                .text
                                                                .length,
                                                      ),
                                                    );
                                              });
                                            }
                                          },
                                          child: Image.asset(
                                            'assets/images/paste.png',
                                            width: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // 🎙 Mic icon with waveform
                                        Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                if (_isRecording) {
                                                  await _stopRecording();
                                                } else {
                                                  if (await Permission
                                                      .microphone
                                                      .request()
                                                      .isGranted) {
                                                    await _startRecording();
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Microphone permission denied",
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Image.asset(
                                                _isRecording
                                                    ? 'assets/images/stoprec.png'
                                                    : 'assets/images/microphone-white-border.png',
                                                width: 28,
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            if (_isRecording)
                                              SizedBox(
                                                width: 50,
                                                height: 20,
                                                child: AudioWaveforms(
                                                  enableGesture: false,
                                                  size: const Size(50, 20),
                                                  recorderController:
                                                      _recorderController,
                                                  waveStyle: const WaveStyle(
                                                    waveColor: navGreen,
                                                    showMiddleLine: false,
                                                    extendWaveform: true,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // ✅ Check icon (flush right)
                                    GestureDetector(
                                      onTap: () async {
                                        final input =
                                            _inputController.text.trim();
                                        if (input.isEmpty) return;

                                        final detected = await _gemini
                                            .detectLanguage(input);
                                        final expected = _rightLang.code;

                                        if (!context.mounted) return;

                                        if (detected != expected) {
                                          final detectedLang = _langFromCode(
                                            detected,
                                          );
                                          final currentLocale =
                                              Localizations.localeOf(
                                                context,
                                              ).languageCode;

                                          String dialogText;
                                          switch (currentLocale) {
                                            case 'de':
                                              dialogText =
                                                  'Die erkannte Sprache ist ${detectedLang.label}. Sollen wir deine Einstellung darauf anpassen?';
                                              break;
                                            case 'hu':
                                              dialogText =
                                                  'A felismerte nyelv: ${detectedLang.label}. Szeretné, hogy ehhez igazítsuk a beállítást?';
                                              break;
                                            case 'en':
                                            default:
                                              dialogText =
                                                  'The detected language is ${detectedLang.label}. Should we change your setting to this?';
                                              break;
                                          }

                                          showDialog(
                                            context: context,
                                            builder: (_) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                content: Text(dialogText),
                                                actions: [
                                                  IconButton(
                                                    icon: Image.asset(
                                                      'assets/images/close.png',
                                                      width: 40,
                                                      color: navRed,
                                                    ),
                                                    onPressed:
                                                        () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                  ),
                                                  IconButton(
                                                    icon: Image.asset(
                                                      'assets/images/check.png',
                                                      width: 28,
                                                      color: navGreen,
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      WidgetsBinding.instance.addPostFrameCallback((
                                                        _,
                                                      ) async {
                                                        if (mounted) {
                                                          setState(
                                                            () =>
                                                                _rightLang =
                                                                    detectedLang,
                                                          );

                                                          // ✅ Save after user confirms
                                                          try {
                                                            final inputText =
                                                                _inputController
                                                                    .text
                                                                    .trim();
                                                            final outputText =
                                                                _translatedText
                                                                    .trim();
                                                            if (inputText
                                                                    .isNotEmpty &&
                                                                outputText
                                                                    .isNotEmpty &&
                                                                inputText !=
                                                                    outputText) {
                                                              final exists = await _db
                                                                  .translationDao
                                                                  .findExactMatch(
                                                                    inputText,
                                                                    outputText,
                                                                  );
                                                              if (exists ==
                                                                  null) {
                                                                await _db.translationDao.insertTranslation(
                                                                  TranslationsCompanion.insert(
                                                                    input:
                                                                        inputText,
                                                                    output:
                                                                        outputText,
                                                                    fromLang:
                                                                        _langLabels[_rightLang]!,
                                                                    toLang:
                                                                        _langLabels[_leftLang]!,
                                                                  ),
                                                                );
                                                              } else {
                                                                debugPrint(
                                                                  '⚠️ Already saved. Skipping DB insert.',
                                                                );
                                                              }
                                                            }
                                                          } catch (e) {
                                                            debugPrint(
                                                              'DB insert failed: $e',
                                                            );
                                                          }
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          return;
                                        }

                                        // ✅ Save if no correction needed
                                        FocusScope.of(context).unfocus();
                                        try {
                                          final inputText =
                                              _inputController.text.trim();
                                          final outputText =
                                              _translatedText.trim();
                                          if (inputText.isNotEmpty &&
                                              outputText.isNotEmpty &&
                                              inputText != outputText) {
                                            final exists = await _db
                                                .translationDao
                                                .findExactMatch(
                                                  inputText,
                                                  outputText,
                                                );
                                            if (exists == null) {
                                              await _db.translationDao
                                                  .insertTranslation(
                                                    TranslationsCompanion.insert(
                                                      input: inputText,
                                                      output: outputText,
                                                      fromLang:
                                                          _langLabels[_rightLang]!,
                                                      toLang:
                                                          _langLabels[_leftLang]!,
                                                    ),
                                                  );
                                            } else {
                                              debugPrint(
                                                '⚠️ Already saved. Skipping DB insert.',
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint('DB insert failed: $e');
                                        }
                                      },
                                      child: Image.asset(
                                        'assets/images/check.png',
                                        width: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 🔁 SWITCHER PANEL
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap:
                          () => setState(() {
                            _rightLang = _next(_rightLang, _leftLang);
                            final input = _inputController.text.trim();
                            if (input.isNotEmpty) _translateText(input);
                          }),
                      child: Row(
                        children: [
                          Text(
                            _langLabels[_rightLang]!,
                            style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Image.asset(
                            _flagPaths[_rightLang]!,
                            width: 60,
                            height: 40,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _switchLanguages,
                      child: Image.asset(
                        'assets/png24/black/b_change_flat.png',
                        width: 60,
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap:
                          () => setState(() {
                            _leftLang = _next(_leftLang, _rightLang);
                            final input = _inputController.text.trim();
                            if (input.isNotEmpty) _translateText(input);
                          }),

                      child: Row(
                        children: [
                          Image.asset(
                            _flagPaths[_leftLang]!,
                            width: 60,
                            height: 40,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _langLabels[_leftLang]!,
                            style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),

              // 🔳 BOTTOM PANEL
              if (!_keyboardIsVisible)
                Expanded(
                  flex: 45,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 0.5),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/bg-bright.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),

                    padding: const EdgeInsets.all(10),
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
                                fontSize:
                                    dynamicFontSize(_translatedText) *
                                    _zoomLevel,
                                height: 1.2, // <-- This increases line spacing
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
                                'assets/png24/black/b_copy.png',
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
                                'assets/png24/black/b_share.png',
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
                                'assets/png24/black/b_fullscreen.png',
                                width: 24,
                              ),
                              onPressed: () {
                                if (_translatedText.isNotEmpty) {
                                  // 👇 Unfocus the input to prevent cursor from reappearing later
                                  FocusScope.of(context).unfocus();

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
                              message: 'Show Explanation',
                              child: IconButton(
                                icon: Image.asset(
                                  'assets/png24/black/b_lightbulb.png', // Make sure this path matches where the image is placed
                                  width: 28,
                                  height: 28,
                                ),
                                onPressed:
                                    _isTranslating
                                        ? null
                                        : () {
                                          setState(() {
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
                                                if (mounted) {
                                                  setState(
                                                    () =>
                                                        _isTranslating = false,
                                                  );
                                                }
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
                            // Corrected: Zoom In
                            IconButton(
                              icon: Image.asset(
                                'assets/images/zoom-plus.png',
                                width: 26,
                              ),
                              onPressed: () {
                                setState(() {
                                  _zoomLevel = (_zoomLevel + 0.1).clamp(
                                    0.5,
                                    2.0,
                                  );
                                });
                              },
                            ),

                            // Corrected: Zoom Out
                            IconButton(
                              icon: Image.asset(
                                'assets/images/zoom-minus.png',
                                width: 26,
                              ),
                              onPressed: () {
                                setState(() {
                                  _zoomLevel = (_zoomLevel - 0.1).clamp(
                                    0.5,
                                    2.0,
                                  );
                                });
                              },
                            ),

                            const Spacer(),
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
                                        child: const SizedBox(
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
                                        'assets/png24/black/b_speaker.png',
                                        width: 24,
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
      ),
    );
  }

  String _placeholderForLang(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return "Írja be ide a szöveget, vagy illessze be a vágólapról.";
      case Language.german:
        return "Hier tippen oder aus Zwischenablage einfügen.";
      default:
        return "Type the text here or paste it from the clipboard.";
    }
  }
}

class LandscapeZoomModal extends StatelessWidget {
  final String text;
  const LandscapeZoomModal({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.height - 40;
    final height = MediaQuery.of(context).size.width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: RotatedBox(
        quarterTurns: 1,
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, left: 20),
                  child: Text(
                    text,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              bottom: 8, // 👈 bottom of landscape = left in portrait
              right:
                  8, // 👈 left side of the rotated box (i.e. bottom-left in portrait)
              child: IconButton(
                icon: Image.asset(
                  'assets/images/close.png',
                  width: 40,
                  height: 40,
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(90, 50), painter: _GreenWavePainter());
  }
}

class _GreenWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final dx = 8 + i * 14.0;
      final waveHeight = (i % 2 == 0) ? 20.0 : 35.0;
      canvas.drawLine(
        Offset(dx, size.height / 2 - waveHeight / 2),
        Offset(dx, size.height / 2 + waveHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
