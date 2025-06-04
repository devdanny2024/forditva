import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/services/google_speech_to_text_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/language_enum.dart';

typedef OnEditAndTranslate =
    void Function({required String edited, required String translated});

class EditTextModal extends StatefulWidget {
  final TextEditingController controller;
  final Future<bool> Function(String text) isTextInLanguage;
  final Language fromLang;
  final Language toLang;
  final GeminiTranslator gemini;
  final OnEditAndTranslate onEdited;

  const EditTextModal({
    super.key,
    required this.controller,
    required this.onEdited,
    required this.isTextInLanguage,
    required this.fromLang,
    required this.toLang,
    required this.gemini,
  });

  @override
  State<EditTextModal> createState() => _EditTextModalState();
}

class _EditTextModalState extends State<EditTextModal> {
  late final AudioRecorder _audioRecorder;

  bool _loading = false;
  bool _isRecording = false;
  final String _error = '';
  late RecorderController _recorderController;
  String? _audioPath;
  final String _sttTranscript = '';
  final _sttService = GoogleSpeechToTextService(
    dotenv.env['GOOGLE_STT_KEY']!,
  ); // Make sure to pass your key!
  bool _isSttLoading = false;

  double _calculateFontSize(String text) {
    final len = text.length;
    if (len <= 30) return 35;
    if (len >= 100) return 20;
    return 42 - ((len - 30) * (22 / 70));
  }

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _recorderController.dispose();
    super.dispose();
  }

  Future<void> _onMicTap() async {
    setState(() {
      _isRecording = true;
      _isSttLoading = false;
    });
    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/edit_rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Start robust audio recording just like _switchToContinuous()
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioPath!,
    );
    _recorderController.record(); // For waveform visualization
  }

  Future<void> _onStopTap() async {
    setState(() => _isSttLoading = true);
    await _recorderController.stop(); // stops waveform
    await _audioRecorder.stop(); // stops the actual file recording

    final path = _audioPath;
    if (path != null && File(path).existsSync()) {
      print('DEBUG: Audio file length: ${File(path).lengthSync()} bytes');
    }
    if (path != null && File(path).existsSync()) {
      String langCode;
      switch (widget.fromLang) {
        case Language.hungarian:
          langCode = 'hu-HU';
          break;
        case Language.german:
          langCode = 'de-DE';
          break;
        default:
          langCode = 'en-US';
      }
      print('DEBUG: Using langCode: $langCode');

      String? transcript = await _sttService.transcribe(
        File(path),
        languageCode: langCode,
      );
      print('DEBUG: Transcript from Google STT: "$transcript"');

      setState(() {
        _isRecording = false;
        _isSttLoading = false;
      });
      if (transcript != null && transcript.trim().isNotEmpty) {
        // Concatenate transcript to edit field
        widget.controller.text =
            ('${widget.controller.text.trim()} ${transcript.trim()}').trim();

        // Force cursor to end of field (nice UX)
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );

        setState(() {}); // Refresh font size, etc.

        print('Updated text: "${widget.controller.text}"');
      }
    } else {
      setState(() {
        _isRecording = false;
        _isSttLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Recording failed.")));
    }
  }

  Future<void> _onCheckPressed() async {
    setState(() => _loading = true);
    final inputText = widget.controller.text.trim();
    bool isValid = await widget.isTextInLanguage(inputText);
    if (!isValid) {
      setState(() => _loading = false);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("Wrong Language"),
              content: const Text("Please put in the correct language."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
      return;
    }
    final translated = await widget.gemini.translate(
      inputText,
      widget.fromLang.code,
      widget.toLang.code,
    );
    setState(() => _loading = false);
    widget.onEdited(edited: inputText, translated: translated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final modalHeight = MediaQuery.of(context).size.height / 1.8;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Stack(
              children: [
                // White modal
                Container(
                  width: width,
                  height: modalHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Text input
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 62),
                        child: TextField(
                          controller: widget.controller,
                          autofocus: true,
                          maxLines: null,
                          style: GoogleFonts.robotoCondensed(
                            fontSize: _calculateFontSize(
                              widget.controller.text,
                            ),
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Edit text...',
                            isDense: true,
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      ),
                      // Check and Close at bottom inside box (corners)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Image.asset(
                                'assets/images/close.png',
                                width: 38,
                                height: 38,
                              ),
                              onPressed:
                                  _loading
                                      ? null
                                      : () => Navigator.of(context).maybePop(),
                            ),
                            IconButton(
                              icon: Image.asset(
                                'assets/images/check.png',
                                width: 38,
                                height: 38,
                              ),
                              onPressed: _loading ? null : _onCheckPressed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Mic and audio wave at very bottom, centered side by side
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Audio waveform (left)
                      SizedBox(
                        width: 90,
                        height: 50,
                        child:
                            _isRecording
                                ? AudioWaveforms(
                                  enableGesture: false,
                                  size: const Size(90, 50),
                                  recorderController: _recorderController,
                                  waveStyle: const WaveStyle(
                                    waveColor: Colors.green,
                                    showMiddleLine: false,
                                    extendWaveform: true,
                                    spacing: 4,
                                    scaleFactor: 60,
                                  ),
                                )
                                : _StaticWave(),
                      ),
                      const SizedBox(width: 1),
                      // Mic or stop button (right)
                      if (!_isSttLoading)
                        GestureDetector(
                          onTap: _isRecording ? _onStopTap : _onMicTap,
                          child:
                              _isRecording
                                  ? Image.asset(
                                    'assets/images/stoprec.png',
                                    width: 50,
                                    height: 50,
                                  )
                                  : Icon(
                                    Icons.mic,
                                    color: Colors.black,
                                    size: 50,
                                  ),
                        ),
                      if (_isSttLoading)
                        const SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white60,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom static wave (green bars)
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
