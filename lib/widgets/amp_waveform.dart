import 'package:flutter/material.dart';

/// A row of vertical bars driven by recent microphone amplitude levels
/// (0..1 each). Shared by every recording panel in the app so they all look
/// and behave the same (edit-text panel, Document page, conversation panel).
class AmpWaveform extends StatelessWidget {
  final List<double> levels;
  const AmpWaveform({super.key, required this.levels});

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
