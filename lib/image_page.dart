import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hungarian, german, english }

class ImagePlaceholderPage extends StatefulWidget {
  const ImagePlaceholderPage({super.key});

  @override
  _ImagePlaceholderPageState createState() => _ImagePlaceholderPageState();
}

class _ImagePlaceholderPageState extends State<ImagePlaceholderPage> {
  // ─── Split/drag state ───────────────────────────────────────
  double _splitRatio = 0.5;
  static const double _dividerH = 10.0;
  static const double _minTopPanel = 400.0;
  static const double _minBotPanel = 100.0;

  // ─── Placeholder text & toggles ────────────────────────────
  static const String _placeholderText =
      'Szeretnék elmenni a vasútállomásra, de nem ismerem az utat. '
      'Hová kell mennem';
  bool _zoomable = false;
  bool _interpretMode = false;

  // ─── Scroll controller for the bottom text area ─────────────
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double boxW = 486;
    const double switcherW = 350;
    const double switcherH = 55;
    const double flagSize = 50;
    const double switchSize = 50;

    return Container(
      color: textGrey,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── Top & Bottom panels separated by draggable divider ───
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final usable = (totalH - _dividerH).clamp(
                  _minTopPanel + _minBotPanel,
                  totalH - _dividerH,
                );
                final topH = (_splitRatio * usable).clamp(
                  _minTopPanel,
                  usable - _minBotPanel,
                );
                final bottomH = usable - topH;

                return Column(
                  children: [
                    // ─── Top panel ──────────────────────────────
                    SizedBox(
                      width: boxW,
                      height: topH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, size: 200),
                            const SizedBox(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.0,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.robotoCondensed(
                                    fontSize: 25,
                                    color: navRed,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'CLICK TO TAKE A PHOTO OR\n',
                                    ),
                                    TextSpan(
                                      text: 'LOAD UP FROM',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    TextSpan(text: ' YOUR DEVICE.'),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Draggable divider ────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate:
                          (d) => setState(() {
                            final newTop = (topH + d.delta.dy).clamp(
                              _minTopPanel,
                              usable - _minBotPanel,
                            );
                            _splitRatio = newTop / usable;
                          }),
                      child: Container(
                        width: boxW,
                        height: _dividerH,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: boxW * 0.5,
                            height: 4,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ),

                    // ─── Bottom panel with multi-stage autosize text & scrollbar ─────
                    SizedBox(
                      width: boxW,
                      height: bottomH,
                      child: LayoutBuilder(
                        builder: (context, panelConstraints) {
                          final panelH = panelConstraints.maxHeight;
                          final panelW = panelConstraints.maxWidth;
                          final iconSize = (panelH * 0.15).clamp(16.0, 32.0);
                          const iconRowHeight = 48.0;
                          final availableH = panelH - iconRowHeight - 16;

                          // pick the largest font that fits
                          final sizes = [40.0, 35.0, 30.0, 25.0];
                          double chosenSize = sizes.last;
                          for (final s in sizes) {
                            final tp = TextPainter(
                              text: TextSpan(
                                text: _placeholderText,
                                style: TextStyle(fontSize: s),
                              ),
                              textDirection: TextDirection.ltr,
                              maxLines: null,
                            )..layout(maxWidth: panelW);
                            if (tp.height <= availableH) {
                              chosenSize = s;
                              break;
                            }
                          }

                          return Stack(
                            children: [
                              // white background
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),

                              // autosized text with scrollbar
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: iconRowHeight + 8,
                                child: Scrollbar(
                                  controller: _scrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    child: Text(
                                      _placeholderText,
                                      style: GoogleFonts.robotoCondensed(
                                        fontSize: chosenSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // icon row
                              Positioned(
                                bottom: 8,
                                left: 16,
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/copy.png',
                                      width: iconSize,
                                      height: iconSize,
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    Image.asset(
                                      'assets/images/share.png',
                                      width: iconSize,
                                      height: iconSize,
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    Image.asset(
                                      'assets/images/zoom.png',
                                      width: iconSize,
                                      height: iconSize,
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    Icon(Icons.volume_up, size: iconSize),
                                    SizedBox(width: iconSize * 0.5),
                                    GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => _zoomable = !_zoomable,
                                          ),
                                      child: Icon(
                                        _zoomable
                                            ? Icons.fullscreen
                                            : Icons.zoom_in_map,
                                        size: iconSize,
                                      ),
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    GestureDetector(
                                      onTap:
                                          () => setState(
                                            () =>
                                                _interpretMode =
                                                    !_interpretMode,
                                          ),
                                      child: Icon(
                                        _interpretMode
                                            ? Icons.interpreter_mode
                                            : Icons.translate,
                                        size: iconSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ─── Language switcher ─────────────────────────────────
          SizedBox(
            width: switcherW,
            height: switcherH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'DE',
                  style: GoogleFonts.roboto(
                    fontSize: 35,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/flags/DE_BW_LS.png',
                  width: flagSize,
                  height: flagSize,
                ),
                const SizedBox(width: 25),
                Image.asset(
                  'assets/images/switch.png',
                  width: switchSize,
                  height: switchSize,
                ),
                const SizedBox(width: 25),
                Image.asset(
                  'assets/flags/HU_BW_LS.png',
                  width: flagSize,
                  height: flagSize,
                ),
                const SizedBox(width: 8),
                Text(
                  'HU',
                  style: GoogleFonts.roboto(
                    fontSize: 35,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
