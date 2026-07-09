import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/services/google_speech_to_text_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
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
  String? _audioPath;
  // Waveform is driven by the single recorder's amplitude stream (0..1),
  // avoiding a second microphone recorder that would starve it of audio.
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _ampSub;
  // final String _sttTranscript = ''; // This variable is not used
  final _sttService = GoogleSpeechToTextService(
    dotenv.env['GOOGLE_STT_KEY']!,
  ); // Make sure to pass your key!
  bool _isSttLoading = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    widget.controller.addListener(_moveCursorToEnd);

    // Use addPostFrameCallback to set cursor after the initial build and focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure the widget is still in the tree
        _moveCursorToEnd();
      }
    });
  }

  void _moveCursorToEnd() {
    // Only update selection if the text is not empty and the current selection is not already at the end.
    // This helps prevent unnecessary rebuilds and potential cursor jumpiness.
    final text = widget.controller.text;
    if (text.isNotEmpty) {
      final currentSelection = widget.controller.selection;
      if (currentSelection.baseOffset != text.length ||
          currentSelection.extentOffset != text.length) {
        widget.controller.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    widget.controller.removeListener(_moveCursorToEnd);
    _audioRecorder.dispose(); // Dispose of the audio recorder
    super.dispose();
  }

  Future<void> _onMicTap() async {
    setState(() {
      _isRecording = true;
      _isSttLoading = false;
      _levels.clear();
    });
    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/edit_rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioPath!,
    );

    // Drive the waveform from the same recorder's amplitude (dBFS ~ -45..0),
    // so no second microphone recorder is needed.
    _ampSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amp) {
          if (!mounted) return;
          final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          setState(() {
            _levels.add(norm);
            if (_levels.length > 60) _levels.removeAt(0);
          });
        });
  }

  Future<void> _onStopTap() async {
    setState(() => _isSttLoading = true);
    await _ampSub?.cancel();
    _ampSub = null;
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
      if ((transcript?.trim().isNotEmpty ?? false)) {
        widget.controller.text =
            ('${widget.controller.text.trim()} ${transcript?.trim() ?? ""}')
                .trim();

        // Force cursor to end of field (nice UX)
        // This is handled by the listener, but an explicit call here after text change is also fine
        _moveCursorToEnd();

        setState(() {}); // Refresh font size, etc.

        print('Updated text: "${widget.controller.text}"');
      }
    } else {
      setState(() {
        _isRecording = false;
        _isSttLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingFailed),
          ),
        );
      }
    }
  }

  /// Trash: empty the whole text field (Markus: "throw everything to the
  /// garbage tin"). The red X still cancels/closes the panel.
  void _clearText() {
    widget.controller.clear();
    setState(() {});
  }

  /// Paste: append clipboard text into the field at the end.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isEmpty) return;
    final base = widget.controller.text.trim();
    widget.controller.text = base.isEmpty ? pasted : '$base $pasted';
    _moveCursorToEnd();
    setState(() {});
  }

  /// Compact icon button for the control bar (tight padding so all controls
  /// fit on one row without overlapping).
  Widget _iconBtn(String asset, double size, VoidCallback? onTap) {
    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(),
      icon: Image.asset(asset, width: size, height: size),
      onPressed: onTap,
    );
  }

  /// Stop recording and discard the audio without transcribing (the X shown
  /// while recording).
  Future<void> _discardRecording() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isSttLoading = false;
        _levels.clear();
      });
    }
  }

  Future<void> _onCheckPressed() async {
    // Tapping confirm while a sub-recording is still running used to just
    // discard it and close the panel. Treat confirm as "done recording"
    // too: stop and append the transcript first, then proceed.
    if (_isRecording) {
      await _onStopTap();
    }
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
              title: Text(AppLocalizations.of(context)!.wrongLanguage),
              content: Text(AppLocalizations.of(context)!.wrongLanguageBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppLocalizations.of(context)!.ok),
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
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Size against the space actually left above the keyboard, not the full
    // screen height, so the card never overlaps it once the keyboard is up.
    final availableHeight = MediaQuery.of(context).size.height - keyboardHeight;
    // Fill the space above the keyboard, minus the 25px top offset below and
    // a 20px breathing gap at the bottom — was leaving roughly half the
    // available height as dead grey space above the keyboard.
    final modalHeight = availableHeight - 25 - 20;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          // Push the whole card up above the keyboard as it rises.
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Stack(
              children: [
                // White modal — inset from the screen edges so it reads as a
                // centered card over the dimmed conversation, not full-screen.
                Container(
                  width: width - 32,
                  height: modalHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Text input
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 70),
                        child: TextField(
                          controller: widget.controller,
                          autofocus: true,
                          // Fixed font size that never shrinks; the field fills
                          // the card and scrolls when the text gets long, so no
                          // text is hidden when the keyboard is toggled (Markus).
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context)!.editTextHint,
                            isDense: true,
                          ),
                        ),
                      ),
                      // All edit controls on ONE row so nothing overlaps:
                      // cancel, clear, paste, waveform (while recording),
                      // mic/stop, confirm.
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 10,
                        child: Row(
                          children: [
                            _iconBtn(
                              'assets/images/close_red.png',
                              48,
                              _loading
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                            ),
                            _iconBtn(
                              'assets/png24/black/b_garbage.png',
                              30,
                              _loading ? null : _clearText,
                            ),
                            _iconBtn(
                              'assets/png24/black/b_paste.png',
                              30,
                              _loading ? null : _pasteFromClipboard,
                            ),
                            // Middle fills all remaining width: mic centred
                            // when idle; X + tick + a wide waveform (filling the
                            // rest) when recording.
                            Expanded(
                              child:
                                  _isSttLoading
                                      ? const Center(
                                        child: SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : _isRecording
                                      ? Row(
                                        children: [
                                          _iconBtn(
                                            'assets/png24/black/b_close.png',
                                            30,
                                            _discardRecording,
                                          ),
                                          _iconBtn(
                                            'assets/png24/black/b_check.png',
                                            30,
                                            _onStopTap,
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                                right: 10,
                                              ),
                                              child: _AmpWaveform(
                                                levels: _levels,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                      : Center(
                                        child: _iconBtn(
                                          'assets/images/b_microphone.png',
                                          30,
                                          _onMicTap,
                                        ),
                                      ),
                            ),
                            _iconBtn(
                              'assets/images/check_green.png',
                              48,
                              _loading ? null : _onCheckPressed,
                            ),
                          ],
                        ),
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
      ),
    );
  }
}


/// Full-width grey waveform for the edit panel, driven by the recorder's
/// amplitude levels (0..1). Fills whatever width it is given.
class _AmpWaveform extends StatelessWidget {
  final List<double> levels;
  const _AmpWaveform({required this.levels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const barW = 4.0;
        const gap = 4.0;
        const maxBar = 36.0;
        final count = (constraints.maxWidth / (barW + gap)).floor().clamp(1, 200);
        final bars = List<double>.generate(count, (i) {
          final idx = levels.length - count + i;
          final v = idx >= 0 ? levels[idx] : 0.0;
          return 4 + v * (maxBar - 4);
        });
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              bars
                  .map(
                    (h) => Container(
                      width: barW,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: gap / 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}
