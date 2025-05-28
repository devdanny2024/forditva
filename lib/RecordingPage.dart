import 'package:flutter/material.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const Color navGreen = Color(0xFF436F4D);
const Color gold = Colors.yellow;
const Color recordingColor = Colors.red;

class RecordingPage extends StatefulWidget {
  final Language fromLang;
  final Language toLang;
  const RecordingPage({
    super.key,
    required this.fromLang,
    required this.toLang,
  });
  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  List<stt.LocaleName> _locales = [];
  String? _localeId;
  bool _speechAvailable = false;

  bool _isRecording = false;
  bool _continuousListening = false;

  final TextEditingController _textController = TextEditingController();
  String _fullTranscription = '';
  final GeminiTranslator _gemini = GeminiTranslator();

  @override
  void initState() {
    super.initState();

    // Pulse animation for the record button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize STT
    _speech = stt.SpeechToText();
    _speech.initialize(onStatus: _statusListener, onError: (_) {}).then((
      available,
    ) {
      setState(() => _speechAvailable = available);
      if (available) _loadLocales();
    });

    // If user taps into the text field, immediately stop recording
    _textController.addListener(() {
      if (_isRecording) _stopRecording();
    });
  }

  Future<void> _loadLocales() async {
    _locales = await _speech.locales();
    final map = {
      Language.english: 'en',
      Language.german: 'de',
      Language.hungarian: 'hu',
    };
    final prefix = map[widget.fromLang]!;
    _localeId =
        _locales
            .firstWhere(
              (l) => l.localeId.startsWith(prefix),
              orElse: () => _locales.first,
            )
            .localeId;
  }

  void _statusListener(String status) {
    if (status == 'notListening' && _isRecording) {
      if (_continuousListening) {
        // restart both pulse & listening immediately
        _pulseController.repeat(reverse: true);
        _startListening();
      } else {
        // normal silence-stop
        _pulseController.stop();
        setState(() => _isRecording = false);
      }
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (r) {
        final text = r.recognizedWords.trim();
        if (r.finalResult) _fullTranscription += '$text ';
        setState(() {
          _textController.text =
              _fullTranscription + (r.finalResult ? '' : text);
        });
      },
      localeId: _localeId,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      // In continuous mode, never auto-stop for up to 24h
      listenFor:
          _continuousListening
              ? const Duration(hours: 24)
              : const Duration(hours: 1),
      // Likewise, only auto-pause after 3s of silence in SILENCE mode
      pauseFor:
          _continuousListening
              ? const Duration(hours: 24)
              : const Duration(seconds: 3),
    );
  }

  void _toggleRecording() {
    if (!_speechAvailable || _localeId == null) return;
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      _pulseController.repeat(reverse: true);
      _startListening();
    } else {
      _stopRecording();
    }
  }

  void _toggleMode() {
    setState(() => _continuousListening = !_continuousListening);
    if (_isRecording) {
      // restart with new params immediately
      _speech.stop();
      _pulseController.repeat(reverse: true);
      _startListening();
    }
  }

  void _stopRecording() {
    if (_isRecording) {
      _speech.stop();
      _pulseController.stop();
      setState(() => _isRecording = false);
    }
  }

  @override
  void dispose() {
    _stopRecording();
    _pulseController.dispose();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outlineColor = _isRecording ? recordingColor : gold;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top: big pulse-button
              SizedBox(
                height: h * 0.3,
                child: Center(
                  child: GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) {
                        final scale = _isRecording ? _pulseAnim.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: outlineColor, width: 8),
                            ),
                            child: Icon(
                              _isRecording ? Icons.pause : Icons.mic,
                              size: 70,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Middle: transcript editor
              SizedBox(
                height: h * 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      style: GoogleFonts.robotoCondensed(fontSize: 24),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom: mode toggle + translate
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip:
                          _continuousListening
                              ? 'Continuous Listening'
                              : 'Silence-auto-stop Mode',
                      icon: Icon(
                        _continuousListening ? Icons.mic : Icons.mic_off,
                        size: 30,
                      ),
                      onPressed: _toggleMode,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (_fullTranscription.trim().isEmpty) {
                          Navigator.of(context).pop('');
                          return;
                        }
                        final detected = await _gemini.detectLanguage(
                          _fullTranscription,
                        );
                        if (detected.toUpperCase() != widget.fromLang.code) {
                          return showDialog(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: Text(
                                    'Wrong language',
                                    style: GoogleFonts.robotoCondensed(),
                                  ),
                                  content: Text(
                                    'Please speak in ${widget.fromLang.name}.',
                                    style: GoogleFonts.roboto(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                        }
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        );
                        Navigator.of(context).pop(_fullTranscription.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Translate',
                        style: GoogleFonts.robotoCondensed(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () {
                _stopRecording();
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
