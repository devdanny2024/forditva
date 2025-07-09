import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:google_fonts/google_fonts.dart';

Future<bool> isTextInLanguage(
  String text,
  String langCode,
  GeminiTranslator gemini,
) async {
  final detected = await gemini.detectLanguage(text);
  return detected == langCode.toUpperCase();
}

Alignment calculateVerticalAlignment(String text, {bool inverted = false}) {
  // Estimate number of lines very roughly based on text length
  final int approxLines = (text.length / 25).ceil();

  Alignment alignment;

  if (approxLines <= 2) {
    alignment = Alignment.center;
  } else if (approxLines <= 5) {
    alignment = inverted ? Alignment(0.0, 0.5) : Alignment(0.0, -0.5);
  } else {
    alignment = inverted ? Alignment(0.0, 1.0) : Alignment(0.0, -1.0);
  }

  return alignment;
}

double calculateFontSize(String text) {
  const double maxFont = 50;
  const double minFont = 30;
  // Tweak the "scaling" divisor as needed
  double scaled = maxFont - (text.length * 0.2);
  if (scaled < minFont) return minFont;
  if (scaled > maxFont) return maxFont;
  return scaled;
}

double calculateFontSizes(String text, double panelH) {
  const double maxFont = 50;
  const double minFont = 25;
  // Tighter font for smaller panels:
  double scaleFactor = (panelH / 200).clamp(0.5, 1.0); // tweak as needed
  double scaled = maxFont * scaleFactor - (text.length * 0.15);
  if (scaled < minFont) return minFont;
  if (scaled > maxFont) return maxFont;
  return scaled;
}

String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

double dynamicInputBottom(double fontSize) {
  // bottom goes from 120 (for min size) to 40 (for max size)
  double minPadding = 225;
  double maxPadding = 20;
  double normalized = (50 - fontSize) / (50 - 20); // fontSize 50→0, 20→1
  return minPadding + (maxPadding - minPadding) * normalized;
}

EdgeInsets dynamicOutputPadding(double fontSize) {
  // top goes from 110 (min size) to 40 (max size)
  double minPadding = 20;
  double maxPadding = 0;
  double normalized = (50 - fontSize) / (50 - 20); // fontSize 50→0, 20→1
  double top = minPadding + (maxPadding - minPadding) * normalized;
  return EdgeInsets.fromLTRB(16, top, 16, 16);
}

double dynamicFontSize(String text) {
  // You can choose a smarter scaling if you want
  int len = text.length;
  // For example, more text = smaller font
  if (len < 20) return 37;
  if (len > 120) return 25;
  // interpolate between 37 and 25
  return 37 - ((len - 20) / 100) * (37 - 25);
}

double dynamicInBottom(double fontSize) {
  // bottom goes from 160 (for min font) to 80 (for max font)
  double minPadding = 160;
  double maxPadding = 80;
  double normalized = (37 - fontSize) / (37 - 25); // 37 → 0, 25 → 1
  return minPadding + (maxPadding - minPadding) * normalized;
}

class ScrollableCard extends StatefulWidget {
  final Widget child;
  final bool upsideDown;
  final double arrowPadding;
  final EdgeInsetsGeometry? padding;

  const ScrollableCard({
    super.key,
    required this.child,
    this.upsideDown = false,
    this.arrowPadding = 0.0,
    this.padding,
  });

  @override
  State<ScrollableCard> createState() => _ScrollableCardState();
}

class _ScrollableCardState extends State<ScrollableCard> {
  final _scrollController = ScrollController();
  bool _showArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrow);
    // Check for overflow after the very first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrow());
  }

  @override
  void didUpdateWidget(ScrollableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Also check for overflow whenever the widget is updated (e.g., text changes).
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrow());
  }

  void _updateArrow() {
    // Ensure the widget is still mounted before attempting to update its state.
    if (!mounted) return;

    if (_scrollController.hasClients) {
      // Content is scrollable if the max scroll extent is greater than the minimum.
      final isScrollable =
          _scrollController.position.maxScrollExtent >
          _scrollController.position.minScrollExtent;

      // Only call setState if the arrow's visibility needs to change.
      // This prevents unnecessary rebuilds.
      if (isScrollable != _showArrow) {
        setState(() {
          _showArrow = isScrollable;
        });
      }
    } else {
      // If there are no scroll clients, it's definitely not scrollable.
      if (_showArrow) {
        setState(() {
          _showArrow = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrow);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  // In your _ScrollableCardState class...
  @override
  Widget build(BuildContext context) {
    // CORRECTED: The padding for the arrow is now conditional.
    // It only adds space if the `_showArrow` flag is true.
    // Determine extra space to make room for the arrow
    final EdgeInsets arrowSpacePadding =
        _showArrow
            ? (widget.upsideDown
                ? EdgeInsets.only(top: 30.0 + widget.arrowPadding)
                : EdgeInsets.only(bottom: 30.0 + widget.arrowPadding))
            : EdgeInsets.zero;

    // Merge with any external padding
    final EdgeInsetsGeometry totalPadding =
        widget.padding?.add(arrowSpacePadding) ?? arrowSpacePadding;

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          reverse: widget.upsideDown,
          physics: const BouncingScrollPhysics(),
          child: Padding(padding: totalPadding, child: widget.child),
        ),
        // The arrow itself is already conditional, which is correct.
        if (_showArrow)
          Positioned(
            bottom: widget.arrowPadding,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.upsideDown ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

int estimateLineCount(String text, TextStyle style, double maxWidth) {
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: null,
  )..layout(maxWidth: maxWidth);

  return (textPainter.height / textPainter.preferredLineHeight).ceil();
}

double calculateTopPadding({
  required String text,
  required bool inverted,
  required double maxWidth,
}) {
  final style = GoogleFonts.robotoCondensed(
    fontWeight: FontWeight.w300,
    fontSize: calculateFontSize(text),
    color: Colors.black, // or white for input
    height: 1.2,
  );

  final lines = estimateLineCount(text, style, maxWidth);
  debugPrint(
    "Detected $lines visual lines for ${inverted ? "Input" : "Output"}",
  );

  if (lines == 1) return 150;
  if (lines == 2) return 130;
  if (lines == 3) return 100;
  if (lines == 4) return 70;
  return 50;
}

double topPaddingToAlign(double topPadding) {
  // Convert your top padding into Flutter's [-1.0, 1.0] alignment range
  if (topPadding >= 150) return 0.0;
  if (topPadding == 130) return -0.3;
  if (topPadding == 100) return -0.6;
  if (topPadding == 70) return -0.85;
  return -1.0;
}

String insertLineBreaksEveryNWords(String text, int n) {
  if (text.isEmpty) return text;
  final words = text.split(' ');
  final buffer = StringBuffer();

  for (int i = 0; i < words.length; i++) {
    buffer.write(words[i]);
    if ((i + 1) % n == 0 && i != words.length - 1) {
      buffer.write('\n');
    } else if (i != words.length - 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

int countLines(String text) {
  if (text.isEmpty) return 1;
  return '\n'.allMatches(text).length + 1;
}

double getInputTopPadding(String text) {
  final adjusted = insertLineBreaksEveryNWords(text, 3);
  final lines = countLines(adjusted);

  if (lines == 1) return 135;
  if (lines == 2) return 135;
  if (lines == 3) return 120;
  if (lines == 4) return 100;
  if (lines == 5) return 100;

  return 100; // for 5+ lines
}

double getOutputTopPadding(String text) {
  final adjusted = insertLineBreaksEveryNWords(text, 3);
  final lines = countLines(adjusted);

  if (lines == 1) return 150;
  if (lines == 2) return 120;
  if (lines == 3) return 100;
  if (lines == 4) return 100;
  if (lines == 5) return 90;

  return 90;
}

class GifLoader extends StatelessWidget {
  final double size;
  const GifLoader({this.size = 60, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/loader.gif', width: size, height: size);
  }
}

String stripCodeFence(String input) {
  final fence = RegExp(
    r'^\s*```[\w]*\s*([\s\S]*?)```$',
    multiLine: true,
    caseSensitive: false,
  );
  final match = fence.firstMatch(input.trim());
  if (match != null) return match.group(1)!.trim();
  if (input.trim().startsWith('```')) {
    return input
        .trim()
        .replaceAll(RegExp(r'^```[\w]*'), '')
        .replaceAll('```', '')
        .trim();
  }
  return input.trim();
}

List<dynamic>? robustJsonArrayExtractor(String input) {
  try {
    // First attempt — try to decode directly
    final decoded = json.decode(input);
    if (decoded is List) return decoded;
    if (decoded is String) {
      // Try decoding again if it's a stringified array
      final innerDecoded = json.decode(decoded);
      if (innerDecoded is List) return innerDecoded;
    }
  } catch (_) {}

  // Second attempt — remove code fences if any
  String cleaned =
      input
          .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

  try {
    final decoded = json.decode(cleaned);
    if (decoded is List) return decoded;
    if (decoded is String) {
      final innerDecoded = json.decode(decoded);
      if (innerDecoded is List) return innerDecoded;
    }
  } catch (_) {}

  // Third attempt — extract first array via regex
  final arrayMatch = RegExp(r'(\[[\s\S]*\])').firstMatch(cleaned);
  if (arrayMatch != null) {
    try {
      return json.decode(arrayMatch.group(1)!);
    } catch (_) {}
  }

  // Fully failed
  return null;
}

double getSymmetricTopPadding(String text) {
  final adjusted = insertLineBreaksEveryNWords(text, 3);
  final lines = countLines(adjusted);

  switch (lines) {
    case 1:
      return 140;
    case 2:
      return 120;
    case 3:
      return 100;
    case 4:
      return 80;
    default:
      return 70;
  }
}
