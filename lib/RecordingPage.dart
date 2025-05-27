import 'package:flutter/material.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // ← your Gemini client
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
  List<stt.LocaleName> _locales = [];
  String? _localeId;
  bool _isRecording = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _localeReady = false;
  bool _ready = false;
  final GeminiTranslator _gemini = GeminiTranslator();

  final TextEditingController _textController = TextEditingController();
  String _fullTranscription = '';

  @override
  void initState() {
    super.initState();

    // ← ADD THIS
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // END ADD

    _speech = stt.SpeechToText();
    _speech.initialize(onStatus: _statusListener, onError: (_) {}).then((
      avail,
    ) {
      setState(() => _speechAvailable = avail);
      if (avail) {
        _loadLocales().then((_) {
          setState(() {
            _localeReady = true;
            _ready = true;
          });
        });
      }
    });
  }

  Future<void> _loadLocales() async {
    _locales = await _speech.locales();

    // map our enum → locale prefix
    final map = {
      Language.english: 'en',
      Language.german: 'de',
      Language.hungarian: 'hu',
    };
    final desiredPrefix = map[widget.fromLang]!;

    _localeId =
        _locales
            .firstWhere(
              (l) => l.localeId.startsWith(desiredPrefix),
              orElse: () => _locales.first,
            )
            .localeId;
  }

  void _statusListener(String status) {
    // The plugin has auto-stopped (e.g. user fell silent)
    if (status == 'notListening' && _isRecording) {
      // Stop the pulsation
      _pulseController.stop();
      // Update the icon back to a mic
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (r) {
        final text = r.recognizedWords.trim();

        if (r.finalResult) {
          // Append the final chunk
          _fullTranscription = '$_fullTranscription$text ';
        }

        // Show everything so far (full + interim)
        setState(() {
          _textController.text =
              _fullTranscription + (r.finalResult ? '' : text);
        });
      },
      localeId: _localeId,
      partialResults: true, // <-- allow interim updates
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false, // <-- keep going on transient errors
      listenFor: const Duration(hours: 1), // <-- very long session
      // pauseFor: remove entirely so silence doesn't auto-stop
    );
  }

  void _toggleRecording() {
    if (!_speechAvailable) return;
    if (!_speechAvailable || _localeId == null) return;
    setState(() => _isRecording = !_isRecording);

    if (_isRecording) {
      _pulseController.repeat(reverse: true);
      _startListening();
    } else {
      _pulseController.stop();
      _speech.stop();
    }
  }

  void _stopRecording() {
    if (_isRecording) {
      _pulseController.stop();
      _speech.stop();
      setState(() => _isRecording = false);
    }
  }

  @override
  void dispose() {
    _stopRecording(); // ensure mic is off

    _pulseController.dispose();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outlineColor = _isRecording ? recordingColor : gold;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top section: mic/pause toggle
              SizedBox(
                height: height * 0.3,
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

              // Middle section: at least 50% height for editable transcript
              SizedBox(
                height: height * 0.5,
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
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom section: Translate button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ElevatedButton(
                  onPressed: () async {
                    // 1️⃣ Show a simple full-screen loader
                    if (_fullTranscription.trim().isEmpty) {
                      Navigator.of(context).pop('');
                      return;
                    }
                    final detectedCode = await _gemini.detectLanguage(
                      _fullTranscription,
                    );
                    // normalize to two‐letter code, e.g. "EN","DE","HU"
                    final expectedCode = widget.fromLang.code;

                    if (detectedCode.toUpperCase() != expectedCode) {
                      // mismatch → ask them to speak the right language
                      showDialog(
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
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (_) =>
                              const Center(child: CircularProgressIndicator()),
                    );

                    Navigator.of(context).pop(_fullTranscription.trim());

                    // 2️⃣ Pop back, returning the transcript
                    Navigator.of(context).pop(_fullTranscription);

                    // 3️⃣ Loader will be dismissed by the caller
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
              ),
            ],
          ),

          // Transparent X button to close
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () {
                _stopRecording(); // stop mic & animation
                Navigator.of(context).pop(); // then close
              },
              child: Icon(Icons.close, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
