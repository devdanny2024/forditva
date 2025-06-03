import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/services/google_speech_to_text_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const Color navGreen = Color(0xFF436F4D);
const Color gold = Colors.yellow;
const Color recordingColor = Colors.red;

String _sttLocale(Language lang) {
  switch (lang) {
    case Language.hungarian:
      return 'hu_HU';
    case Language.german:
      return 'de_DE';
    case Language.english:
      return 'en_US';
  }
}

String _googleLocale(Language lang) {
  switch (lang) {
    case Language.hungarian:
      return 'hu-HU';
    case Language.german:
      return 'de-DE';
    case Language.english:
      return 'en-US';
  }
}

class RecordingPage extends StatefulWidget {
  final Language fromLang;
  final Language toLang;
  final String? initialTranscript; // <-- add this
  final bool autoStart;
  const RecordingPage({
    super.key,
    required this.fromLang,
    required this.toLang,
    this.initialTranscript,
    this.autoStart = true,
  });
  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with TickerProviderStateMixin {
  // STT
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final GeminiTranslator _gemini = GeminiTranslator();
  final GoogleSpeechToTextService _googleStt = GoogleSpeechToTextService(
    'AIzaSyAdaWTSmGidyjI737noAxRYsnSFEzWRf8M',
  );

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _isListening = false;
  bool _continuousListening = false; // mic toggle
  String _fullTranscription = '';
  bool _isTranscribing = false;

  // Record package
  final AudioRecorder _recorder = AudioRecorder();
  File? _audioFile;

  @override
  void initState() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.initialTranscript != null) {
      _textController.text = widget.initialTranscript!;
      _fullTranscription = widget.initialTranscript!;
    }
    if (widget.autoStart) {
      _start();
    }
  }

  Future<void> _start() async {
    if (_continuousListening) {
      await _startRecording();
    } else {
      await _startListening();
    }
  }

  // ========== SPEECH_TO_TEXT MODE ==========
  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (!available) return;
    setState(() {
      _isListening = true;
    });
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) async {
        if (!result.finalResult) return; // Only handle final results!

        String text = result.recognizedWords.trim();
        if (text.isEmpty) return;

        // Language check with Gemini (leave as is)
        final detected = await _gemini.detectLanguage(text);
        final expected =
            _sttLocale(widget.fromLang).split('_')[0].toUpperCase();
        if (detected != expected) {
          _speech.stop();
          setState(() => _isListening = false);
          _pulseController.stop();
          _showWrongLanguageDialog();
          return;
        }

        setState(() {
          // Append to existing content
          _fullTranscription =
              (_textController.text.trim().isEmpty)
                  ? text
                  : '${_textController.text.trim()} $text';
          _textController.text = _fullTranscription.trim();
        });

        // After each result, reset listening state so user can tap mic to record again
        setState(() {
          _isListening = false;
        });
        _pulseController.stop();
      },
      listenMode: stt.ListenMode.dictation,
      localeId: _sttLocale(widget.fromLang),
      partialResults: true,
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 5), // <--- 5s after silence!
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    _pulseController.stop();
  }

  // ========== RECORD PACKAGE MODE (Continuous) ==========
  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );
    setState(() {
      _isListening = true;
      _audioFile = File(filePath);
      // DO NOT reset _fullTranscription so sessions are appended
    });
    _pulseController.repeat(reverse: true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isListening = false);
    _pulseController.stop();

    if (_audioFile != null) {
      await _transcribeAudio(_audioFile!);
    }
  }

  // ========== TRANSCRIBE RECORDED AUDIO ==========
  Future<void> _transcribeAudio(File audioFile) async {
    setState(() => _isTranscribing = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final transcript = await _googleStt.transcribe(
        audioFile,
        languageCode: _googleLocale(widget.fromLang),
      );
      if (transcript == null || transcript.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      final detected = await _gemini.detectLanguage(transcript);
      final expected = _sttLocale(widget.fromLang).split('_')[0].toUpperCase();
      if (detected != expected) {
        _showWrongLanguageDialog();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _fullTranscription =
            (_textController.text.trim().isEmpty)
                ? transcript
                : '${_textController.text.trim()} $transcript';
        _textController.text = _fullTranscription.trim();
      });

      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _textController.text = 'Transcription failed: $e');
      Navigator.of(context).pop();
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  // ========== TOGGLE ==========
  Future<void> _toggle() async {
    if (_isListening) {
      if (_continuousListening) {
        await _stopRecording();
      } else {
        await _stopListening();
      }
    } else {
      if (_continuousListening) {
        await _startRecording();
      } else {
        await _startListening();
      }
    }
  }

  void _toggleMode() async {
    setState(() => _continuousListening = !_continuousListening);
    if (_isListening) {
      await _toggle();
      await Future.delayed(const Duration(milliseconds: 200));
      await _toggle();
    }
  }

  void _showWrongLanguageDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Wrong language', style: GoogleFonts.robotoCondensed()),
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

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _speech.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outlineColor = _isListening ? recordingColor : gold;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Mic button area, fixed height
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: _isTranscribing ? null : _toggle,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) {
                        final scale = _isListening ? _pulseAnim.value : 1.0;
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
                              _isListening ? Icons.pause : Icons.mic,
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
              // Text field that expands/contracts as space changes (keyboard)
              Expanded(
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
                      expands: true,
                      style: GoogleFonts.robotoCondensed(fontSize: 24),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed:
                          _isTranscribing
                              ? null
                              : () async {
                                final textToTranslate =
                                    _textController.text.trim();
                                if (textToTranslate.isEmpty) {
                                  Navigator.of(context).pop('');
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder:
                                      (_) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                );
                                String translated = '';
                                try {
                                  translated = await _gemini.translate(
                                    textToTranslate,
                                    widget.fromLang.name,
                                    widget.toLang.name,
                                  );
                                } catch (e) {
                                  translated = 'Translation failed: $e';
                                }
                                Navigator.of(context).pop(); // Close loader
                                Navigator.of(context).pop(translated);
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
                    IconButton(
                      tooltip:
                          _continuousListening
                              ? 'Continuous Mode (manual stop)'
                              : 'Auto-stop on silence',
                      icon: Icon(
                        _continuousListening ? Icons.mic : Icons.mic_off,
                        color: _continuousListening ? navGreen : Colors.grey,
                        size: 30,
                      ),
                      onPressed: _isTranscribing ? null : _toggleMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () async {
                if (_isListening) await _toggle();
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
