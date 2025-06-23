import 'package:flutter/material.dart';
import 'package:forditva/utils/utils.dart';

class SmartScrollableText extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool inverted;
  final TextAlign textAlign;
  final TextStyle style;

  const SmartScrollableText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.style,
    this.inverted = false,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final lines = estimateLineCount(
      text,
      style,
      MediaQuery.of(context).size.width - 30, // or any appropriate maxWidth
    );

    final textWidget = Text(
      capitalizeFirst(text),
      textAlign: textAlign,
      style: style,
    );

    final alignment =
        inverted
            ? calculateVerticalAlignment(text, inverted: true)
            : calculateVerticalAlignment(text, inverted: false);

    final aligned = Align(alignment: alignment, child: textWidget);

    if (lines <= 5) {
      return aligned;
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: aligned,
      );
    }
  }
}
