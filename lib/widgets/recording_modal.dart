import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/language_enum.dart';
import '../services/google_speech_to_text_service.dart';

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

enum RecordingMode { autodetect, continuous }

class RecordingModal extends StatefulWidget {
  final Language lang;
  final Function(String) onTranscribed;
  final bool isTopPanel;
  final Function(String)? onPartialTranscript;
  // Removed editMode, textController, onConcatRecording, and controller as they are no longer needed for this modal.

  const RecordingModal({
    super.key,
    required this.lang,
    required this.onTranscribed,
    required this.isTopPanel,
    this.onPartialTranscript,
  });

  @override
  State<RecordingModal> createState() => _RecordingModalState();
}

class _RecordingModalState extends State<RecordingModal> {
  RecordingMode mode = RecordingMode.autodetect;
  final stt.SpeechToText _speech = stt.SpeechToText();
  late RecorderController _recorderController;
  late final AudioRecorder _recorder;
  bool _isRecording = false;
  String _transcript = '';
  String _error = '';
  String? _audioPath;
  final _sttService = GoogleSpeechToTextService(dotenv.env['GOOGLE_STT_KEY']!);
  Timer? _fakeWaveTimer;
  String _sttTranscript = ''; // Holds STT result before switching modes
  bool _switchingToContinuous = false; // Tracks if user switched
  final String _continuousTranscript = '';

  // Removed _loadingConcat as it was related to editMode.

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _recorder = AudioRecorder();
    // Start autodetect immediately, as editMode is gone.
    _startAutodetect();
  }

  @override
  void dispose() {
    _fakeWaveTimer?.cancel();
    _speech.stop();
    _recorderController.dispose();
    super.dispose();
  }

  void _startFakeWave() {
    _fakeWaveTimer?.cancel();
    _fakeWaveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) _recorderController.refresh();
    });
  }

  void _stopFakeWave() {
    _fakeWaveTimer?.cancel();
  }

  Future<void> _startAutodetect() async {
    setState(() {
      mode = RecordingMode.autodetect;
      _isRecording = true;
      _transcript = '';
      _error = '';
      _switchingToContinuous = false;
      _sttTranscript = '';
    });
    _startFakeWave();

    List<stt.LocaleName> locales = await _speech.locales();
    print(locales.map((l) => '${l.localeId} - ${l.name}').toList());
    String localeId;
    switch (widget.lang) {
      case Language.hungarian:
        localeId = 'hu_HU';
        break;
      case Language.german:
        localeId = 'de_DE';
        break;
      case Language.english:
      default:
        localeId = 'en_US';
    }

    bool available = await _speech.initialize();
    if (!available) {
      setState(() {
        _error = 'Speech recognition unavailable';
      });
      return;
    }

    _speech.listen(
      localeId: localeId,
      partialResults: true,
      onResult: (res) {
        if (!mounted) return;
        setState(() {
          _transcript = res.recognizedWords;
          _error = '';
        });
        if (widget.onPartialTranscript != null &&
            _transcript.trim().isNotEmpty) {
          widget.onPartialTranscript!(_transcript);
        }
        if (res.finalResult) {
          _finalizeSTT();
        }
      },
      cancelOnError: true,
    );
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _finalizeSTT() async {
    await _speech.stop();
    _stopFakeWave();
    _isRecording = false;
    if (_transcript.trim().isNotEmpty) {
      _sttTranscript = _transcript.trim();
      if (!_switchingToContinuous) {
        // User did NOT switch to continuous: just return this transcript
        widget.onTranscribed(_sttTranscript);
        if (mounted) Navigator.of(context).pop();
      }
      // If switchingToContinuous, wait for audio part to finish
    } else {
      setState(() => _error = "No speech detected. Try again.");
      if (!_switchingToContinuous && mounted) {
        widget.onTranscribed('');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please make a recording")),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _switchToContinuous() async {
    _switchingToContinuous = true;
    await _speech.stop();
    _stopFakeWave();
    setState(() {
      mode = RecordingMode.continuous;
      _isRecording = true;
      _error = '';
    });
    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/cont_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioPath!,
    );
    _recorderController.record();
  }

  Future<void> _endContinuous() async {
    _isRecording = false;
    String? path = await _recorder.stop();
    _recorderController.stop();

    String transcript = '';
    if (path != null && File(path).existsSync()) {
      transcript = await _transcribeAudio(File(path), widget.lang);
    }

    String combinedTranscript = '';
    // Always concatenate, even if transcript is empty
    if (_sttTranscript.trim().isNotEmpty && transcript.trim().isNotEmpty) {
      combinedTranscript = '${_sttTranscript.trim()} ${transcript.trim()}';
    } else if (_sttTranscript.trim().isNotEmpty) {
      combinedTranscript = _sttTranscript.trim();
    } else if (transcript.trim().isNotEmpty) {
      combinedTranscript = transcript.trim();
    } else {
      combinedTranscript = '';
    }

    // ALWAYS call onTranscribed and close
    widget.onTranscribed(combinedTranscript);

    if (combinedTranscript.isEmpty) {
      // Optionally show a snackbar before closing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't transcribe audio. Try again."),
          ),
        );
      }
    }

    // Close the modal regardless
    if (mounted) Navigator.of(context).pop();
  }

  Future<String> _transcribeAudio(File audioFile, Language lang) async {
    String langCode;
    switch (lang) {
      case Language.hungarian:
        langCode = 'hu-HU';
        break;
      case Language.german:
        langCode = 'de-DE';
        break;
      default:
        langCode = 'en-US';
    }

    try {
      final result = await _sttService.transcribe(
        audioFile,
        languageCode: langCode,
      );
      return result ?? '';
    } catch (e) {
      setState(() {
        _error = 'Google STT Error: $e';
      });
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 24,
      color: Colors.white,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 150,
        width: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 5),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Close (X) button at top right
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  // Always call onTranscribed with empty, as per your modal logic
                  widget.onTranscribed('');
                  Navigator.of(context).pop();
                },
                child: Image.asset(
                  'assets/images/close.png',
                  width: 28,
                  height: 28,
                ),
              ),
            ),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  mode == RecordingMode.continuous
                      ? AudioWaveforms(
                        enableGesture: false,
                        size: const Size(80, 50),
                        recorderController: _recorderController,
                        waveStyle: const WaveStyle(
                          waveColor: Colors.green,
                          extendWaveform: true,
                          showMiddleLine: false,
                        ),
                      )
                      : const FakeWaveform(),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () async {
                      // Streamlined logic for non-edit mode
                      if (mode == RecordingMode.autodetect) {
                        // If in autodetect, tapping means "switch to continuous"
                        await _switchToContinuous();
                      } else {
                        // If in continuous, tapping means "end recording"
                        await _endContinuous();
                      }
                    },
                    child: Image.asset(
                      mode == RecordingMode.autodetect
                          ? 'assets/images/record_pause.png'
                          : 'assets/images/record_x.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                ],
              ),
            ),
            // Flag at bottom right
            Positioned(
              bottom: 16,
              right: 16,
              child: Image.asset(
                _flagAsset(widget.lang),
                width: 20,
                height: 20,
              ),
            ),
            // Error text (if any)
            if (_error.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: Text(
                  _error,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            // Removed _loadingConcat spinner as it was for editMode.
          ],
        ),
      ),
    );
  }
}

class FakeWaveform extends StatefulWidget {
  const FakeWaveform({super.key});
  @override
  State<FakeWaveform> createState() => _FakeWaveformState();
}

class _FakeWaveformState extends State<FakeWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _height = Tween<double>(
      begin: 10,
      end: 40,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _height,
      builder:
          (context, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              7,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 6,
                  height: _height.value * (1 + (i % 3) * 0.2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
