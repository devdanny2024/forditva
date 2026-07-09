import 'package:flutter/material.dart';

const Color _navGreen = Color(0xFF436F4D);

/// Shows a single, app-wide "copied" animation: a small card that pops in with
/// a check mark and fades out. Use this instead of a SnackBar so copy feedback
/// is consistent everywhere.
void showCopiedToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (_) => _CopiedToast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _CopiedToast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _CopiedToast({required this.message, required this.onDone});

  @override
  State<_CopiedToast> createState() => _CopiedToastState();
}

class _CopiedToastState extends State<_CopiedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // pop in (0–18%), hold, fade out (80–100%)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 18,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(_c);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_c);
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: _navGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
