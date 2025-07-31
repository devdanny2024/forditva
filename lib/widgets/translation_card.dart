import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';

const double _cardVerticalPadding = 80.0;
const double _cardHorizontalPadding = 16.0;

// same helper as in TextPage
String flagAsset(Language lang, {required bool whiteBorder}) {
  switch (lang) {
    case Language.hungarian:
      return whiteBorder ? 'assets/flags/HU_BW.png' : 'assets/flags/HU_BB.png';
    case Language.german:
      return whiteBorder ? 'assets/flags/DE_BW.png' : 'assets/flags/DE_BB.png';
    case Language.english:
      return whiteBorder ? 'assets/flags/EN_BW.png' : 'assets/flags/EN_BB.png';
  }
}

class TranslationCard extends StatelessWidget {
  /// dark/inverted = input card (top icons), bright = output card (bottom icons)
  final bool inverted;

  /// The text to display
  final String text;

  final Language fromLang, toLang;
  final bool isBusy, isAudioLoading, isAudioPlaying, isRecording;
  final VoidCallback? onExplain,
      onCopy,
      onPlay,
      onStop,
      onEdit,
      onMicTap,
      onMicCancel;

  const TranslationCard({
    super.key,
    required this.inverted,
    required this.text,
    required this.fromLang,
    required this.toLang,
    this.isBusy = false,
    this.isAudioLoading = false,
    this.isAudioPlaying = false,
    this.isRecording = false,
    this.onExplain,
    this.onCopy,
    this.onPlay,
    this.onStop,
    this.onEdit,
    this.onMicTap,
    this.onMicCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bgImg =
        inverted ? 'assets/images/bg-dark.jpg' : 'assets/images/bg-bright.jpg';
    final txtColor = inverted ? Colors.white : Colors.black;

    // icon paths
    final bulbIcon = inverted ? 'assets/png24/white/w_lightbulb.png' : null;
    final copyIcon =
        inverted
            ? 'assets/png24/white/w_copy.png'
            : 'assets/png24/black/b_copy.png';
    final speakerIcon =
        inverted
            ? 'assets/png24/white/w_speaker.png'
            : 'assets/png24/black/b_speaker.png';
    final stopIcon = 'assets/images/w_stop.png';
    final micIcon =
        isRecording
            ? 'assets/images/stoprec.png'
            : 'assets/images/microphone-white-border.png';

    final fontSize = calculateFontSize(text).clamp(30.0, 50.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final double iconSize = (screenWidth * 0.085).clamp(24.0, 48.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // background
          Image.asset(bgImg, fit: BoxFit.cover),

          // ─── TEXT PANEL ───────────────────────────
          Positioned(
            top: 80,
            bottom: 100,
            left: _cardHorizontalPadding,
            right: _cardHorizontalPadding,
            child: RotatedBox(
              quarterTurns: inverted ? 2 : 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: onEdit,
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoCondensed(
                              color: txtColor,
                              fontSize: fontSize,
                              height: 1.2,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // busy overlay
          if (inverted) ...[
            // ─── TOP LEFT: bulb ───────────────────
            if (onExplain != null)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: onExplain,
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Image.asset(
                      bulbIcon!,
                      width: iconSize,
                      height: iconSize,
                    ),
                  ),
                ),
              ),

            // ─── TOP RIGHT: copy + speaker ──────────
            Positioned(
              top: 20,
              right: 20,
              child: Row(
                children: [
                  if (onCopy != null)
                    GestureDetector(
                      onTap: onCopy,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: Image.asset(
                          copyIcon,
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: isAudioPlaying ? onStop : onPlay,
                    child:
                        isAudioPlaying
                            ? Image.asset(
                              stopIcon,
                              width: iconSize,
                              height: iconSize,
                            )
                            : Transform.rotate(
                              angle: math.pi,
                              child: Image.asset(
                                speakerIcon,
                                width: iconSize,
                                height: iconSize,
                              ),
                            ),
                  ),
                ],
              ),
            ),

            // ─── TOP CENTER: mic + flag ───────────
            if (onMicTap != null)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (isRecording)
                        onMicCancel?.call();
                      else
                        onMicTap!();
                    },
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              flagAsset(fromLang, whiteBorder: true),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            micIcon,
                            width: iconSize,
                            height: iconSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ] else ...[
            // ─── BOTTOM CENTER: mic + flag ─────────
            if (onMicTap != null)
              Positioned(
                bottom: 35,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (isRecording)
                        onMicCancel?.call();
                      else
                        onMicTap!();
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            flagAsset(fromLang, whiteBorder: false),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          micIcon,
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── BOTTOM LEFT: edit ─────────────────
            if (onEdit != null)
              Positioned(
                bottom: 35,
                left: 20,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Image.asset(
                    'assets/png24/black/b_edit.png',
                    width: iconSize,
                    height: iconSize,
                  ),
                ),
              ),

            // ─── BOTTOM RIGHT: copy + speaker ──────
            Positioned(
              bottom: 35,
              right: 20,
              child: Row(
                children: [
                  if (onCopy != null)
                    GestureDetector(
                      onTap: onCopy,
                      child: Image.asset(
                        'assets/png24/black/b_copy.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: isAudioPlaying ? onStop : onPlay,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Image.asset(
                        'assets/png24/black/b_speaker.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
