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
  final bool editMode;
  final TextEditingController? textController;
  final Function(String)? onConcatRecording;
  final TextEditingController? controller; // <--- ADD THIS

  const RecordingModal({
    super.key,
    required this.lang,
    required this.onTranscribed,
    required this.isTopPanel,
    this.onPartialTranscript,
    this.editMode = false,
    this.textController,
    this.onConcatRecording,
    this.controller, // <--- ADD THIS
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
  bool _switchingToContinuous = false; // NEW: tracks if user switched
  bool _loadingConcat = false;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _recorder = AudioRecorder();
    if (!widget.editMode) {
      _startAutodetect();
    }
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
        localeId = 'en_US'; // Fallback
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
      _sttTranscript = _transcript.trim(); // Save for concatenation!
      if (!_switchingToContinuous) {
        // Only call onTranscribed and close if NOT switching modes!
        widget.onTranscribed(_sttTranscript);
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _error = "";
      });
      if (!_switchingToContinuous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please make a recording"),
            duration: Duration(seconds: 2),
          ),
        );
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

    // **ALWAYS** call onTranscribed and close
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

  Future<String> _endContinuousForEdit() async {
    _isRecording = false;
    String? path = await _recorder.stop();
    _recorderController.stop();

    print('Recording stopped. File path: $path');

    if (path == null || !File(path).existsSync()) {
      setState(() {
        _error = "[RECORDING_DEBUG] Recording failed. Try again.";
      });
      print('[RECORDING_DEBUG]Recording file missing or not found');
      return '';
    }

    String transcript = await _transcribeAudio(File(path), widget.lang);

    print('Transcript from Google STT: "$transcript"');

    String combinedTranscript = '';
    if (_sttTranscript.trim().isNotEmpty && transcript.trim().isNotEmpty) {
      combinedTranscript = '${_sttTranscript.trim()} ${transcript.trim()}';
    } else if (_sttTranscript.trim().isNotEmpty) {
      combinedTranscript = _sttTranscript.trim();
    } else {
      combinedTranscript = transcript.trim();
    }

    print('Combined transcript: "$combinedTranscript"');

    // DO NOT pop the modal here—just return the transcript!
    if (combinedTranscript.isEmpty) {
      setState(() {
        _error = "Couldn't transcribe audio. Try again.";
      });
    }
    return combinedTranscript;
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

  void _handleButtonPress() {
    if (mode == RecordingMode.autodetect) {
      _switchToContinuous();
    } else {
      _endContinuous();
    }
  }

  @override
  Widget build(BuildContext context) {
    String buttonAsset;
    if (mode == RecordingMode.autodetect) {
      buttonAsset = 'assets/images/record_pause.png';
    } else {
      buttonAsset = 'assets/images/record_x.png';
    }

    return Material(
      // <--- replaces Dialog for elevation & rounded corners
      elevation: 24,
      color: Colors.white,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 150,
        width: 350, // or 400, or whatever fixed width you want
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.black, // Border color
            width: 5, // Border width, adjust as needed
          ),
          borderRadius: BorderRadius.circular(5), // Match the Dialog
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
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
                      if (widget.editMode) {
                        if (!_isRecording) {
                          // Start continuous recording in edit mode
                          await _switchToContinuous();
                        } else {
                          // End continuous, concat, show loader, don't close modal
                          setState(() => _loadingConcat = true);
                          String transcript = await _endContinuousForEdit();
                          setState(() => _loadingConcat = false);

                          final textToSend = [
                            (widget.textController?.text ?? '').trim(),
                            transcript.trim(),
                          ].where((e) => e.isNotEmpty).join(' ');
                          if (widget.onConcatRecording != null) {
                            widget.onConcatRecording!(textToSend);
                          }
                          // Optionally reset local state for another round
                          setState(() {
                            _transcript = '';
                            _sttTranscript = '';
                          });
                          // DO NOT pop the modal!
                        }
                      } else {
                        // Not edit mode: legacy behavior
                        if (!_isRecording) {
                          if (mode == RecordingMode.autodetect) {
                            await _switchToContinuous();
                          }
                        } else {
                          await _endContinuous();
                        }
                      }
                    },

                    child:
                        widget.editMode
                            ? (!_isRecording
                                ? Image.asset(
                                  'assets/images/record_green.jpeg',
                                  width: 80,
                                  height: 80,
                                )
                                : Image.asset(
                                  'assets/images/record_x.png',
                                  width: 100,
                                  height: 100,
                                ))
                            : Image.asset(
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
            if (_loadingConcat)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.7),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
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
                  height:
                      _height.value *
                      (1 + (i % 3) * 0.2), // make it a bit varied
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
