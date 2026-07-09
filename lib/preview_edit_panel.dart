import 'package:flutter/material.dart';

/// Standalone visual preview of the edit-text panel control bar, for design
/// review only. Renders the same layout as edit_recording_modal.dart but with
/// static stand-ins (no recorder plugins), so it runs on Flutter web.
///
/// Run: flutter run -d web-server -t lib/preview_edit_panel.dart
void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF808080),
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _Panel(recording: false, label: 'Idle'),
              _Panel(recording: true, label: 'Recording'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final bool recording;
  final String label;
  const _Panel({required this.recording, required this.label});

  Widget _iconBtn(String asset, double size) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Image.asset(asset, width: size, height: size),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: 360,
          height: 480,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 62),
                child: Text(
                  'und wie funktioniert das mit dem Bearbeiten',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 10,
                child: Row(
                  children: [
                    _iconBtn('assets/images/close_red.png', 48),
                    _iconBtn('assets/png24/black/b_garbage.png', 30),
                    _iconBtn('assets/png24/black/b_paste.png', 30),
                    // Middle fills the rest: mic centred (idle); X + tick + a
                    // wide waveform (recording).
                    Expanded(
                      child:
                          recording
                              ? Row(
                                children: [
                                  _iconBtn('assets/png24/black/b_close.png', 30),
                                  _iconBtn('assets/png24/black/b_check.png', 30),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 6,
                                        right: 10,
                                      ),
                                      child: SizedBox(
                                        height: 36,
                                        child: _StaticBars(),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Center(
                                child: Image.asset(
                                  'assets/images/b_microphone.png',
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                    ),
                    _iconBtn('assets/images/check_green.png', 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Grey bars that fill the available width, like the real amplitude waveform.
class _StaticBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const pattern = [
      0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.25, 0.6, 0.5, 1.0, 0.35, 0.75, 0.45, 0.85,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const barW = 4.0;
        const gap = 4.0;
        const maxBar = 34.0;
        final count = (c.maxWidth / (barW + gap)).floor().clamp(1, 300);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(count, (i) {
            final h = 4 + pattern[i % pattern.length] * (maxBar - 4);
            return Container(
              width: barW,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: gap / 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
