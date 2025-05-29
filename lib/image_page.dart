import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forditva/services/chatgpt_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hu, de, en }

class ImagePlaceholderPage extends StatefulWidget {
  const ImagePlaceholderPage({super.key});
  @override
  State<ImagePlaceholderPage> createState() => _ImagePlaceholderPageState();
}

class _ImagePlaceholderPageState extends State<ImagePlaceholderPage> {
  // Image picking
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  // AI service & state
  final ChatGptService _chat = ChatGptService();
  bool _isProcessing = false;
  String _resultText = '';

  // Split/drag state
  double _splitRatio = 0.5;
  static const double _dividerH = 10.0;
  static const double _minTopPanel = 400.0;
  static const double _minBotPanel = 100.0;

  // Language switcher state
  Language _leftLang = Language.de;
  Language _rightLang = Language.hu;

  // Flag/image and label maps
  final Map<Language, String> _flagPaths = {
    Language.en: 'assets/flags/EN_BW_LS.png',
    Language.de: 'assets/flags/DE_BW_LS.png',
    Language.hu: 'assets/flags/HU_BW_LS.png',
  };
  final Map<Language, String> _langLabels = {
    Language.en: 'EN',
    Language.de: 'DE',
    Language.hu: 'HU',
  };

  // Placeholder text for preview
  static const String _placeholderText =
      'Szeretnék elmenni a vasútállomásra, de nem ismerem az utat. Hová kell mennem';

  bool _zoomable = false;
  bool _interpretMode = false; // false = translate, true = interpret
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

  // Utility for getting language code for ChatGptService
  String _langCode(Language lang) {
    switch (lang) {
      case Language.en:
        return "EN";
      case Language.de:
        return "DE";
      case Language.hu:
        return "HU";
    }
  }

  // Get next language in the enum, skipping the 'other'
  Language _next(Language current, Language other) {
    final list = [Language.hu, Language.de, Language.en];
    int i = list.indexOf(current);
    Language next = list[(i + 1) % list.length];
    if (next == other) {
      next = list[(i + 2) % list.length];
    }
    return next;
  }

  void _switchLanguages() {
    setState(() {
      final temp = _leftLang;
      _leftLang = _rightLang;
      _rightLang = temp;
      // Optionally swap result direction (not strictly needed for image)
    });
    if (_imageFile != null) _processImage();
  }

  Future<void> _processImage() async {
    final File? file = _imageFile;
    if (file == null) return;

    setState(() {
      _isProcessing = true;
      _resultText = '';
    });

    try {
      final out = await _chat.processImage(
        imageFile: file,
        translate: !_interpretMode,
        interpret: _interpretMode,
        fromLangCode: _langCode(_rightLang), // right is input lang!
        toLangCode: _langCode(_leftLang), // left is output lang!
      );
      setState(() => _resultText = out.trim());
    } catch (e) {
      setState(() => _resultText = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
      await _processImage();
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
      await _processImage();
    }
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
              builder: (ctx, constraints) {
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
                      child: Stack(
                        children: [
                          // ─── The white rounded box (image or placeholder) ─────────
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  _imageFile != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _imageFile!,
                                          width: boxW,
                                          height: topH,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: _takePhoto,
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 200,
                                              color: navRed,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2.0,
                                            ),
                                            child: Text.rich(
                                              TextSpan(
                                                style:
                                                    GoogleFonts.robotoCondensed(
                                                      fontSize: 25,
                                                      color: navRed,
                                                    ),
                                                children: [
                                                  const TextSpan(
                                                    text:
                                                        'CLICK TO TAKE A PHOTO OR\n',
                                                  ),
                                                  TextSpan(
                                                    text: 'LOAD UP FROM',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      decoration:
                                                          TextDecoration
                                                              .underline,
                                                    ),
                                                    recognizer:
                                                        TapGestureRecognizer()
                                                          ..onTap =
                                                              _pickFromGallery,
                                                  ),
                                                  const TextSpan(
                                                    text: ' YOUR DEVICE.',
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                            ),
                          ),

                          // ─── The cancel “X” button, only when there’s an image ──────
                          if (_imageFile != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imageFile = null;
                                    _resultText = '';
                                    _isProcessing = false;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

                    // ─── Bottom panel with auto-sized AI response ───
                    SizedBox(
                      width: boxW,
                      height: bottomH,
                      child: LayoutBuilder(
                        builder: (ctx2, panelConstraints) {
                          final panelH = panelConstraints.maxHeight;
                          final panelW = panelConstraints.maxWidth;
                          final iconSize = (panelH * 0.15).clamp(16.0, 32.0);
                          const iconRowH = 48.0;
                          final availH = panelH - iconRowH - 16;

                          // pick a font size that fits (same logic)
                          final sizes = [40.0, 35.0, 30.0, 25.0];
                          double chosenSize = sizes.last;
                          for (final s in sizes) {
                            final tp = TextPainter(
                              text: TextSpan(
                                text:
                                    _resultText.isNotEmpty
                                        ? _resultText
                                        : _placeholderText,
                                style: TextStyle(fontSize: s),
                              ),
                              textDirection: TextDirection.ltr,
                              maxLines: null,
                            )..layout(maxWidth: panelW);
                            if (tp.height <= availH) {
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

                              // show loader or AI text
                              if (_isProcessing)
                                const Center(child: CircularProgressIndicator())
                              else
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  bottom: iconRowH + 8,
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      child: Text(
                                        _resultText.isNotEmpty
                                            ? _resultText
                                            : _placeholderText,
                                        style: GoogleFonts.robotoCondensed(
                                          fontSize: chosenSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // icon row (copy/share/zoom/etc)
                              Positioned(
                                bottom: 8,
                                left: 16,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final textToCopy =
                                            _resultText.isNotEmpty
                                                ? _resultText
                                                : _placeholderText;
                                        Clipboard.setData(
                                          ClipboardData(text: textToCopy),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Copied to clipboard',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Image.asset(
                                        'assets/images/copy.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
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
                                          () => setState(() {
                                            _interpretMode = !_interpretMode;
                                            if (_imageFile != null) {
                                              _processImage();
                                            }
                                          }),
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

          // ─── Language switcher (BOTTOM, just like Document page) ──────────
          SizedBox(
            width: switcherW,
            height: switcherH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Right (input language, flag at bottom right, tap cycles)
                GestureDetector(
                  onTap:
                      () => setState(() {
                        _rightLang = _next(_rightLang, _leftLang);
                        if (_imageFile != null) _processImage();
                      }),
                  child: Row(
                    children: [
                      Text(
                        _langLabels[_rightLang]!,
                        style: GoogleFonts.roboto(
                          fontSize: 35,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset(
                        _flagPaths[_rightLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 25),
                // Swap button
                GestureDetector(
                  onTap: _switchLanguages,
                  child: Image.asset(
                    'assets/images/switch.png',
                    width: switchSize,
                  ),
                ),
                const SizedBox(width: 25),
                // Left (output language, flag at top left, tap cycles)
                GestureDetector(
                  onTap:
                      () => setState(() {
                        _leftLang = _next(_leftLang, _rightLang);
                        if (_imageFile != null) _processImage();
                      }),
                  child: Row(
                    children: [
                      Image.asset(
                        _flagPaths[_leftLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _langLabels[_leftLang]!,
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
          ),
        ],
      ),
    );
  }
}
