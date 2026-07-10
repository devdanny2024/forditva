import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../models/language_enum.dart';

/// Central recording panel shown when the user taps the mic on a
/// conversation card.
///
/// Behaviour (per spec):
/// - Live on-device speech recognition runs the whole time; the waveform
///   reacts to the real microphone level (greyscale bars).
/// - By default, 1.5 seconds of silence after the last recognized word
///   auto-finalizes the recording and hands it off for translation.
/// - The infinity button disables that auto-finalize, so the user can keep
///   talking through longer pauses; only a manual action ends the session.
/// - Trash cancels and discards everything, no translation.
/// - Pencil stops the recording and hands the transcript to the text editor
///   (via [onEditRequested]) instead of translating immediately.
/// - Checkmark manually finalizes now and translates, same as the automatic
///   1.5s path.
class RecordingModal extends StatefulWidget {
  final Language lang;
  final Function(String) onTranscribed;
  final bool isTopPanel;
  final Function(String)? onPartialTranscript;
  final Function(String)? onEditRequested;
  final VoidCallback? onCancel;

  const RecordingModal({
    super.key,
    required this.lang,
    required this.onTranscribed,
    required this.isTopPanel,
    this.onPartialTranscript,
    this.onEditRequested,
    this.onCancel,
  });

  @override
  State<RecordingModal> createState() => _RecordingModalState();
}

class _RecordingModalState extends State<RecordingModal> {
  static const _silenceTimeout = Duration(milliseconds: 1500);
  // If the recognizer hasn't produced any signal (sound level or result)
  // within this window, it's likely hung, so restart rather than let the
  // panel sit frozen indefinitely.
  static const _stallTimeout = Duration(seconds: 5);
  // Rolling window of recent mic levels driving the waveform bars.
  static const int _levelWindow = 24;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;
  bool _isFinishing = false;
  // Once the user taps OK/trash/edit the panel hides immediately (Markus: it
  // must not stay open while the transcript/translation is still computing);
  // the recording still finalizes in the background.
  bool _dismissed = false;
  bool _continuousMode = false; // infinity toggle
  String _transcript = '';
  // Transcript kept across listen-session restarts, so continuous/infinity
  // mode accumulates words instead of losing them each time the recognizer
  // restarts after a pause.
  String _committed = '';
  Timer? _silenceTimer;
  Timer? _stallTimer;
  final List<double> _levels = [];
  // Current mic "energy" (0..1). Spiked by sound-level callbacks AND by newly
  // recognized words, so the waveform still reacts to the voice on devices
  // where onSoundLevelChange never fires. A ticker scrolls it into _levels.
  double _energy = 0.0;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _stallTimer?.cancel();
    _waveTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  String get _localeId {
    switch (widget.lang) {
      case Language.hungarian:
        return 'hu_HU';
      case Language.german:
        return 'de_DE';
      case Language.english:
        return 'en_US';
      case Language.dutch:
        return 'nl_NL';
      case Language.french:
        return 'fr_FR';
      case Language.spanish:
        return 'es_ES';
      case Language.russian:
        return 'ru_RU';
      case Language.italian:
        return 'it_IT';
    }
  }

  Future<void> _start() async {
    setState(() {
      _isRecording = true;
      _transcript = '';
      _committed = '';
      _levels.clear();
    });

    // Steady ticker that scrolls the current energy into the waveform and lets
    // it decay, so the bars keep moving while speaking and settle in silence.
    _waveTimer ??= Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _levels.add(_energy);
        if (_levels.length > _levelWindow) _levels.removeAt(0);
        _energy *= 0.72;
      });
    });

    final available = await _speech.initialize(
      onStatus: (status) {
        // If the OS-level recognizer stops itself (session limits, etc.)
        // while we're still meant to be recording, restart it seamlessly so
        // continuous mode genuinely keeps listening through long pauses.
        if ((status == 'notListening' || status == 'done') &&
            _isRecording &&
            mounted) {
          _restartListening();
        }
      },
      onError: (e) {
        // error_client (and the timeout/no-match variants) are transient,
        // self-recovering conditions the recognizer throws routinely; the
        // stall timer and retry-on-empty-result already handle the real
        // consequences, so showing the raw code here is just noise.
        // These transient codes (error_busy included) are self-recovering and
        // must never surface to the user; the stall timer and retry-on-empty
        // handle the real consequences. Raw codes are noise, so we ignore them.
      },
    );
    if (!available) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotTranscribe)),
        );
      }
      return;
    }
    _listen();
  }

  void _listen() {
    _armStallTimer();
    _speech.listen(
      localeId: _localeId,
      partialResults: true,
      onSoundLevelChange: (level) {
        if (!mounted) return;
        _stallTimer?.cancel();
        // Normalize the device's sound level into 0..1 energy (the ticker
        // renders it). Range is device-dependent, so this is approximate.
        final e = ((level + 2) / 12).clamp(0.0, 1.0);
        if (e > _energy) _energy = e;
      },
      onResult: (res) {
        if (!mounted) return;
        _stallTimer?.cancel();
        // Newly recognized speech also drives the waveform, so it reacts even
        // when the device never reports sound levels.
        _energy = 1.0;
        setState(() {
          // Prepend anything committed from earlier sessions (infinity mode).
          final words = res.recognizedWords;
          _transcript = _committed.isEmpty ? words : '$_committed $words';
        });
        if (widget.onPartialTranscript != null &&
            _transcript.trim().isNotEmpty) {
          widget.onPartialTranscript!(_transcript);
        }
        // Reset the 1.5s silence timer on every new bit of speech, unless
        // the user has switched to continuous (infinity) mode.
        _silenceTimer?.cancel();
        if (!_continuousMode) {
          _silenceTimer = Timer(_silenceTimeout, _finishAndTranslate);
        }
      },
      cancelOnError: true,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(minutes: 5),
    );
  }

  /// If the recognizer produces no signal at all within [_stallTimeout], it
  /// has likely hung: show an error and restart the recording session.
  void _armStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, () {
      if (!mounted || !_isRecording) return;
      // The recognizer went quiet (normal during pauses, especially in infinity
      // mode and on devices that never report sound levels): restart it.
      _restartListening();
    });
  }

  /// Single, debounced+delayed restart path for the recognizer. Both the
  /// self-stop (onStatus) and the stall timer funnel through here. Without the
  /// guard and delay, the recognizer was being restarted so fast during silence
  /// that it stopped picking up voice at all (the infinity-mode bug). The
  /// transcript so far is committed so words accumulate across sessions.
  bool _restarting = false;
  Future<void> _restartListening() async {
    if (_restarting || !mounted || !_isRecording) return;
    // Restarting mid-utterance is only meant to keep infinity mode listening
    // through long pauses. In normal mode, once real words have already been
    // recognized, restarting re-hears trailing/buffered audio and duplicates
    // the transcript (Markus: sentence showing twice). Safe to restart only
    // if continuous mode is on, or nothing has been captured yet (a stalled,
    // silent start).
    if (!_continuousMode && _transcript.trim().isNotEmpty) return;
    _restarting = true;
    _silenceTimer?.cancel();
    _stallTimer?.cancel();
    _committed = _transcript.trim();
    try {
      await _speech.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted && _isRecording) _listen();
    _restarting = false;
  }

  void _toggleContinuous() {
    setState(() => _continuousMode = !_continuousMode);
    if (_continuousMode) _silenceTimer?.cancel();
  }

  /// Checkmark, or the automatic 1.5s-silence path: stop and translate now.
  Future<void> _finishAndTranslate() async {
    if (!_isRecording || _isFinishing) return;
    _isFinishing = true;
    // Hide the panel right away; keep transcribing in the background.
    if (mounted) setState(() => _dismissed = true);
    _silenceTimer?.cancel();
    _stallTimer?.cancel();
    // The recognizer trails the actual audio noticeably; stopping too soon was
    // still cutting the last 2-3 words (Markus). Give it a longer moment to
    // catch up before stopping.
    await Future.delayed(const Duration(milliseconds: 1200));
    _isRecording = false;
    await _speech.stop();
    if (!mounted) return;

    final text = _transcript.trim();
    if (text.isEmpty) {
      // Nothing understandable was captured: ask the user to try again
      // instead of closing the panel with an empty result. Bring it back.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotTranscribe)),
      );
      _isFinishing = false;
      setState(() => _dismissed = false);
      _start();
      return;
    }
    widget.onTranscribed(text);
  }

  /// Trash: cancel and discard, no translation.
  Future<void> _cancelAndDiscard() async {
    if (mounted) setState(() => _dismissed = true);
    _silenceTimer?.cancel();
    _stallTimer?.cancel();
    _isRecording = false;
    await _speech.cancel();
    widget.onCancel?.call();
  }

  /// Pencil: stop and hand the transcript to the text editor.
  Future<void> _editInstead() async {
    if (mounted) setState(() => _dismissed = true);
    _silenceTimer?.cancel();
    _stallTimer?.cancel();
    // Same trailing-audio catch-up as confirm, so edit doesn't drop the last
    // words either.
    await Future.delayed(const Duration(milliseconds: 1200));
    _isRecording = false;
    await _speech.stop();
    widget.onEditRequested?.call(_transcript.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Hidden the moment the user commits; the async work continues behind it.
    if (_dismissed) return const SizedBox.shrink();
    return Material(
      elevation: 24,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 50,
              child: Center(child: _LevelWaveform(levels: _levels)),
            ),
            // No raw error codes shown in the panel (Markus): genuine failures
            // surface via a friendly dialog elsewhere, not as red text here.
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  assetPath: 'assets/images/record_trash.png',
                  onTap: _cancelAndDiscard,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_infinity.png',
                  active: _continuousMode,
                  onTap: _toggleContinuous,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_edit.png',
                  onTap: _editInstead,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_confirm.png',
                  onTap: _finishAndTranslate,
                  emphasized: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of grey vertical bars reacting to recent microphone sound levels.
class _LevelWaveform extends StatelessWidget {
  final List<double> levels;
  const _LevelWaveform({required this.levels});

  @override
  Widget build(BuildContext context) {
    const barCount = 20;
    // levels are already 0..1 energy values (see _RecordingModalState).
    double heightFor(double level) {
      return 6 + level.clamp(0.0, 1.0) * 34;
    }

    final bars = List<double>.generate(barCount, (i) {
      final idx = levels.length - barCount + i;
      return idx >= 0 ? heightFor(levels[idx]) : 6.0;
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          bars
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

/// One bordered square control button (trash / infinity / pencil / confirm),
/// using Markus's dedicated icon set for the recording panel. Matches the
/// reference screenshot: thin black-bordered squares, the confirm button
/// noticeably larger with a bolder border. The infinity toggle's active state
/// is shown by filling the square black and tinting its icon white.
class _ControlButton extends StatelessWidget {
  final String assetPath;
  final bool active;
  final bool emphasized;
  final VoidCallback onTap;

  const _ControlButton({
    required this.assetPath,
    this.active = false,
    this.emphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = emphasized ? 58.0 : 50.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          border: Border.all(
            color: Colors.black,
            width: emphasized ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: boxSize * 0.55,
            height: boxSize * 0.55,
            color: active ? Colors.white : null,
            colorBlendMode: active ? BlendMode.srcIn : null,
          ),
        ),
      ),
    );
  }
}
