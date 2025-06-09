import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:forditva/services/chatgpt_service.dart';
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/cropper.dart';
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
  File? _croppedImageFile; // The cropped image (if any)

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
  String stripHtmlCodeFence(String input) {
    // Remove leading ```html or ```HTML and trailing ```
    final regex = RegExp(
      r'^```html\s*([\s\S]*?)```$',
      multiLine: true,
      caseSensitive: false,
    );
    final match = regex.firstMatch(input.trim());
    if (match != null) {
      return match.group(1)!.trim();
    }
    // If not a code fence but starts with ```html or ends with ```
    if (input.trim().startsWith('```html')) {
      return input
          .trim()
          .substring(7)
          .trim()
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    if (input.trim().startsWith('```')) {
      return input
          .trim()
          .substring(3)
          .trim()
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    return input.trim();
  }

  // Placeholder text for preview
  static const String _placeholderText = '';

  bool _zoomable = false;
  bool _interpretMode = false; // false = translate, true = interpret
  late final ScrollController _scrollController;
  bool _isJsonArray(String str) {
    try {
      final decoded = json.decode(str);
      return decoded is List;
    } catch (_) {
      return false;
    }
  }

  bool _isHtmlDoc(String str) {
    final s = str.trim();
    return s.startsWith('<') && s.endsWith('>');
  }

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
    if (_imageFile != null) _processImage(imageFile: _imageFile!);
  }

  String stripCodeFence(String input) {
    // Removes any kind of triple-backtick code block, including ```json, ```html, etc.
    final fence = RegExp(
      r'^\s*```[\w]*\s*([\s\S]*?)```$',
      multiLine: true,
      caseSensitive: false,
    );
    final match = fence.firstMatch(input.trim());
    if (match != null) return match.group(1)!.trim();
    // Handles just starting with ```
    if (input.trim().startsWith('```')) {
      return input
          .trim()
          .replaceAll(RegExp(r'^```[\w]*'), '')
          .replaceAll('```', '')
          .trim();
    }
    return input.trim();
  }

  Widget formattedJsonResult(String jsonStr, double panelH) {
    final clean = stripCodeFence(jsonStr);
    List<dynamic> items;
    try {
      items = json.decode(clean) as List;
    } catch (_) {
      // fallback: show raw (bad) output
      return Text(
        clean,
        style: GoogleFonts.robotoCondensed(fontSize: 22, color: Colors.black),
      );
    }

    // Pick a dynamic font size based on panel height or text length
    double calcFont(String text) {
      const double maxFont = 36;
      const double minFont = 18;
      double scale = (panelH / 200).clamp(0.7, 1.0);
      double scaled = maxFont * scale - (text.length * 0.1);
      if (scaled < minFont) return minFont;
      if (scaled > maxFont) return maxFont;
      return scaled;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items.map<Widget>((item) {
            final orig = (item['o'] ?? '').toString().trim();
            final trans = (item['t'] ?? '').toString().trim();
            if (orig.isEmpty && trans.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orig.isNotEmpty)
                    Text(
                      orig,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: calcFont(orig),
                        fontWeight: FontWeight.bold,
                        color: navRed,
                      ),
                    ),
                  if (trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trans,
                        style: GoogleFonts.robotoCondensed(
                          fontSize: calcFont(trans),
                          fontWeight: FontWeight.w500,
                          color: navGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _formattedResult(String resultJson, double panelH) {
    final cleanJson = stripCodeFence(resultJson);
    List<dynamic> items;
    try {
      items = json.decode(cleanJson) as List;
      // ...format your output as widgets...
    } catch (e) {
      // Fallback: show plain text
      return Text(
        cleanJson,
        style: GoogleFonts.robotoCondensed(fontSize: 22, color: Colors.black),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items.map<Widget>((item) {
            final orig = (item['o'] ?? '').toString().trim();
            final trans = (item['t'] ?? '').toString().trim();

            if (orig.isEmpty && trans.isEmpty) return SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orig.isNotEmpty)
                    Text(
                      orig,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: calculateFontSizes(orig, panelH),
                        fontWeight: FontWeight.bold,
                        color: navRed,
                      ),
                    ),
                  if (trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trans,
                        style: GoogleFonts.robotoCondensed(
                          fontSize: calculateFontSizes(trans, panelH),
                          fontWeight: FontWeight.w500,
                          color: navGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Future<void> _processImage({required File imageFile}) async {
    setState(() {
      _isProcessing = true;
      _resultText = '';
    });

    try {
      final out = await _chat.processImage(
        imageFile: imageFile,
        translate: !_interpretMode,
        interpret: _interpretMode,
        fromLangCode: _langCode(_rightLang),
        toLangCode: _langCode(_leftLang),
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
      File file = File(picked.path);
      final cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => ImageCropperPage(imageFile: file)),
      );

      setState(() {
        _imageFile = file;
        _croppedImageFile = cropped;
      });
      await _processImage(imageFile: cropped ?? file);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 70,
    );
    if (picked != null) {
      File file = File(picked.path);
      final cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => ImageCropperPage(imageFile: file)),
      );

      setState(() {
        _imageFile = file;
        _croppedImageFile = cropped;
      });
      await _processImage(imageFile: cropped ?? file);
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
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          // ─── Top & Bottom panels separated by draggable divider ───
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                const double minPanel = 80.0;

                final totalH = constraints.maxHeight;
                final usable = (totalH - _dividerH).clamp(
                  minPanel * 2,
                  totalH - _dividerH,
                );

                final topH = (_splitRatio * usable).clamp(
                  minPanel,
                  usable - minPanel,
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
                          // White rounded box with image or placeholder
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
                                  (_croppedImageFile ?? _imageFile) != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: InteractiveViewer(
                                          minScale: 1,
                                          maxScale: 4,
                                          child: Image.file(
                                            _croppedImageFile ?? _imageFile!,
                                            width: boxW,
                                            height: topH,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      )
                                      : /* ... your placeholder content here ... */ Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: _takePhoto,
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 80,
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
                                                      fontSize: 20,
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
                          // New "Close" (X) button at bottom left when there's an image
                          if ((_croppedImageFile ?? _imageFile) != null)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _imageFile = null;
                                    _croppedImageFile = null;
                                    _resultText = '';
                                    _isProcessing = false;
                                  });
                                },
                                child: Image.asset(
                                  'assets/images/close.png',
                                  width: 32,
                                  height: 32,
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
                            // Calculate new top height by adding the drag delta
                            final newTop = (topH + d.delta.dy).clamp(
                              minPanel,
                              usable - minPanel,
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
                          final sizes = [40.0, 35.0, 30.0, 25.0, 18.0, 12.0];
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

                          // ...rest of your bottom panel widget...
                          // (keep as in your code, passing chosenSize)
                          return Stack(
                            children: [
                              // white background
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: AssetImage(
                                      'assets/images/bg-bright.jpg',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // ... keep your other bottom panel widgets ...
                              // just make sure you use chosenSize in the HTML/Text!
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
                                      child: Builder(
                                        builder: (_) {
                                          final panelH =
                                              panelConstraints.maxHeight;
                                          final panelW =
                                              panelConstraints.maxWidth;
                                          final res =
                                              _resultText.isNotEmpty
                                                  ? _resultText
                                                  : _placeholderText;
                                          final htmlStr = stripHtmlCodeFence(
                                            res,
                                          );
                                          if (_isJsonArray(res)) {
                                            return formattedJsonResult(
                                              res,
                                              panelH,
                                            ); // <- use panelH for font sizing
                                          } else if (_isHtmlDoc(htmlStr)) {
                                            return Html(
                                              data: htmlStr,
                                              style: {
                                                "body": Style(
                                                  fontSize: FontSize(
                                                    calculateFontSizes(
                                                      res,
                                                      panelH,
                                                    ),
                                                  ),
                                                  fontFamily:
                                                      GoogleFonts.robotoCondensed()
                                                          .fontFamily,
                                                ),
                                              },
                                            );
                                          } else {
                                            return Text(
                                              res,
                                              style:
                                                  GoogleFonts.robotoCondensed(
                                                    fontSize:
                                                        calculateFontSizes(
                                                          res,
                                                          panelH,
                                                        ),
                                                  ),
                                            );
                                          }
                                        },
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
                                              _processImage(
                                                imageFile: _imageFile!,
                                              );
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
                        if (_imageFile != null)
                          _processImage(imageFile: _imageFile!);
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
                        if (_imageFile != null)
                          _processImage(imageFile: _imageFile!);
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
