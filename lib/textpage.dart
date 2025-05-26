import 'dart:math' as math; // ← Add this at the top of your file

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hungarian, german, english }

class TextPage extends StatefulWidget {
  const TextPage({super.key});

  @override
  _TextPageState createState() => _TextPageState();
}

/// ==================== TextPage ====================
class _TextPageState extends State<TextPage> {
  final Map<Language, String> _leftTranslations = {};
  final Map<Language, String> _rightTranslations = {};

  // 3) State fields for left/right languages
  Language _leftLanguage = Language.hungarian;
  Language _rightLanguage = Language.german;

  // 4) Helper to pick the next language, skipping the one on the other side
  Language _nextLanguage(Language current, Language other) {
    final all = [Language.hungarian, Language.german, Language.english];
    var idx = all.indexOf(current);
    var next = all[(idx + 1) % all.length];
    if (next == other) next = all[(idx + 2) % all.length];
    return next;
  }

  final GlobalKey _leftLangKey = GlobalKey();
  final GlobalKey _rightLangKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();

  // 5) Map each enum to its flag asset path
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

  // 6) Map each enum to its label‐image asset path
  String _labelAsset(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return 'assets/images/HU-EN.png';
      case Language.german:
        return 'assets/images/DE-EN.png';
      case Language.english:
        return 'assets/images/EN-EN.png';
    }
  }

  String _pairLabelAsset(Language from, Language to) {
    if (from == Language.hungarian && to == Language.english) {
      return 'assets/images/HU-EN.png';
    }
    if (from == Language.hungarian && to == Language.german) {
      return 'assets/images/HU-DE.png';
    }
    if (from == Language.german && to == Language.english) {
      return 'assets/images/DE-EN.png';
    }
    if (from == Language.german && to == Language.hungarian) {
      return 'assets/images/DE-HU.png';
    }
    if (from == Language.english && to == Language.german) {
      return 'assets/images/EN-DE.png';
    }
    if (from == Language.english && to == Language.hungarian) {
      return 'assets/images/EN-HU.png';
    }
    return ''; // fallback
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final switchSize = 70.0;
        final flagSize = 24.0;
        final halfH = constraints.maxHeight / 2;

        return Stack(
          children: [
            // Input card
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationInputCard(),
            ),
            // Left overlay
            Positioned(
              top: halfH - switchSize / 2,
              left: 16,
              width: constraints.maxWidth / 2 + switchSize / 2 - 16,
              child: Container(
                height: switchSize,
                decoration: BoxDecoration(
                  color: textGrey,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            ),
            // Output card
            Positioned(
              top: halfH - 20,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationOutputCard(),
            ),
            // Right overlay
            Positioned(
              top: halfH - switchSize / 2,
              left: constraints.maxWidth / 2 - switchSize / 4,
              right: 16,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: textGrey,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
            ),

            // 4) Switch + flags row
            Positioned(
              top: halfH - switchSize / 2,
              left: 16,
              right: 16,
              child: SizedBox(
                height: switchSize,
                child: Stack(
                  children: [
                    // Left language toggle
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: GestureDetector(
                          onTap:
                              () => setState(() {
                                _leftLanguage = _nextLanguage(
                                  _leftLanguage,
                                  _rightLanguage,
                                );
                              }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                child: Image.asset(
                                  _flagAsset(_leftLanguage),
                                  width: flagSize,
                                  height: flagSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(width: 10),
                              Image.asset(
                                _pairLabelAsset(_leftLanguage, _rightLanguage),
                                height: flagSize,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Center switch
                    Center(
                      child: Container(
                        width: switchSize,
                        height: switchSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/switch.png',
                            width: switchSize * 0.6,
                            height: switchSize * 0.6,
                          ),
                        ),
                      ),
                    ),

                    // Right language toggle
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20.0, bottom: 8),
                        child: GestureDetector(
                          onTap:
                              () => setState(() {
                                _rightLanguage = _nextLanguage(
                                  _rightLanguage,
                                  _leftLanguage,
                                );
                              }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              RotatedBox(
                                quarterTurns: 2,
                                child: ClipRRect(
                                  child: Image.asset(
                                    _flagAsset(_rightLanguage),
                                    width: flagSize,
                                    height: flagSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              RotatedBox(
                                quarterTurns: 2,
                                child: Image.asset(
                                  _pairLabelAsset(
                                    _rightLanguage,
                                    _leftLanguage,
                                  ),
                                  height: flagSize,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TranslationInputCard extends StatelessWidget {
  const TranslationInputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(32), //
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(
                'Ich muss wissen, wie ich zum Bahnhof komme.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500, // Medium
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: 9,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/flags/DE_BW.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: Image.asset(
                    'assets/images/microphone-white-border.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
          // 1) Light-bulb at top-left
          Positioned(
            top: 8,
            left: 8,
            child: Transform.rotate(
              angle: math.pi, // 180° rotation
              child: Image.asset(
                'assets/images/bulb.png',
                width: 40,
                height: 40,
              ),
            ),
          ),
          // 2) Copy + Play-sound upside-down
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: math.pi,
                  child: Image.asset(
                    'assets/images/copy.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                SizedBox(width: 10),
                Transform.rotate(
                  angle: math.pi,
                  child: Image.asset(
                    'assets/images/play-sound.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TranslationOutputCard extends StatelessWidget {
  const TranslationOutputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 80, // ← distance from top of this Container
            left: 16,
            right: 16,
            child: Text(
              'Tudom kell, hogyan megyek a vasútállomásra?',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 30,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            bottom: 43,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/flags/HU_BB.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/microphone-white-border.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 43,
            left: 8,
            child: Image.asset('assets/images/edit.png', width: 40, height: 40),
          ),
          Positioned(
            bottom: 43,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/copy.png', width: 40, height: 40),
                SizedBox(width: 10),
                Image.asset(
                  'assets/images/play-sound.png',
                  width: 40,
                  height: 40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
