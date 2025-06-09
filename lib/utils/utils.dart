import 'package:flutter/material.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client

Future<bool> isTextInLanguage(
  String text,
  String langCode,
  GeminiTranslator gemini,
) async {
  final detected = await gemini.detectLanguage(text);
  return detected == langCode.toUpperCase();
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

String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

double dynamicInputBottom(double fontSize) {
  // bottom goes from 120 (for min size) to 40 (for max size)
  double minPadding = 160;
  double maxPadding = 80;
  double normalized = (50 - fontSize) / (50 - 20); // fontSize 50→0, 20→1
  return minPadding + (maxPadding - minPadding) * normalized;
}

EdgeInsets dynamicOutputPadding(double fontSize) {
  // top goes from 110 (min size) to 40 (max size)
  double minPadding = 120;
  double maxPadding = 40;
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
