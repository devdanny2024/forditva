import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:forditva/services/chatgpt_service.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _zoomLevel = 1.0; // Default zoom factor (1x)

  final GeminiTranslator _gemini =
      GeminiTranslator(); // Already used in your other pages

  // Language switcher state
  Language _leftLang = Language.de;
  Language _rightLang = Language.hu;

  bool _imageIsUnclear(String result) {
    final clean = result.trim().toLowerCase();
    if (clean.isEmpty) return true;
    // JSON result: look for {unsafe} or illegible
    if (clean.contains('{unsafe}') || clean.contains('illegible')) return true;
    // For HTML, you can check for specific phrases if needed
    return false;
  }

  Future<void> _saveState(File imageFile, String resultText) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lastImagePath', imageFile.path);
    prefs.setString('lastResultText', resultText);
  }

  // Flag/image and label maps
  final Map<Language, String> _flagPaths = {
    Language.en: 'assets/flags/EN_BW_LS.png',
    Language.de: 'assets/flags/DE_BW_LS.png',
    Language.hu: 'assets/flags/HU_BW_LS.png',
  };
  final Map<Language, String> _labelPaths = {
    Language.en: 'assets/images/EN-EN.png',
    Language.de: 'assets/images/DE-DE.png',
    Language.hu: 'assets/images/HU-HU.png',
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
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('lastImagePath');
    final result = prefs.getString('lastResultText');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _imageFile = File(path);
        _croppedImageFile = null; // you could cache cropped version too
        _resultText = result ?? '';
      });
    }
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

  List<dynamic>? extractFirstJsonArray(String input) {
    final arrayMatch = RegExp(r'(\[[\s\S]*\])').firstMatch(input);
    if (arrayMatch != null) {
      try {
        return json.decode(arrayMatch.group(1)!);
      } catch (e) {
        // still not valid JSON, fallback
        return null;
      }
    }
    return null;
  }

  Widget formattedJsonResult(
    String jsonStr,
    double panelH, {
    bool onlyTranslated = false,
  }) {
    final items = robustJsonArrayExtractor(jsonStr);

    if (items == null) {
      return Text(
        jsonStr,
        style: GoogleFonts.robotoCondensed(fontSize: 22, color: Colors.black),
      );
    }

    double calcFont(String text) {
      const double maxFont = 36;
      const double minFont = 18;
      double scale = (panelH / 200).clamp(0.7, 1.0);
      double scaled = maxFont * scale - (text.length * 0.1);
      if (scaled < minFont) return minFont;
      if (scaled > maxFont) return maxFont;
      return scaled * 0.5; // 👈 halve the font
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
                  if (!onlyTranslated && orig.isNotEmpty)
                    Text(
                      orig,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: 24.0 * _zoomLevel,
                        fontWeight: FontWeight.w500,
                        color: navRed,
                      ),
                    ),
                  if (trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trans,
                        style: GoogleFonts.robotoCondensed(
                          fontSize: 24.0 * _zoomLevel,
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
                        fontSize: calculateFontSizes(orig, panelH) * _zoomLevel,
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
                          fontSize:
                              calculateFontSizes(trans, panelH) * _zoomLevel,
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
    await _saveState(_croppedImageFile ?? _imageFile!, _resultText);

    try {
      final out = await _chat.processImage(
        imageFile: imageFile,
        translate: !_interpretMode,
        interpret: _interpretMode,
        fromLangCode: _langCode(_rightLang),
        toLangCode: _langCode(_leftLang),
      );

      String sampleText;
      try {
        final maybeJson = json.decode(out);
        if (maybeJson is List &&
            maybeJson.isNotEmpty &&
            maybeJson[0]['o'] != null) {
          sampleText = maybeJson[0]['o'].toString();
        } else {
          sampleText = out;
        }
      } catch (_) {
        sampleText = out;
      }

      final rawDetected = await _gemini.detectLanguage(sampleText);

      // Normalize Gemini result (this is the KEY PATCH)
      final detected = rawDetected
          .toUpperCase() // make uppercase
          .replaceAll('-', '') // remove hyphens (e.g. "HU-HU" -> "HUHU")
          .substring(0, 2); // take only first 2 letters

      final langCodes = {
        Language.hu: 'HU',
        Language.de: 'DE',
        Language.en: 'EN',
      };

      if (detected != langCodes[_rightLang]) {
        if (mounted) {
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text(
                    "Detected language is $detected but your selected input is ${langCodes[_rightLang]}. Would you like to switch the input language?",
                  ),
                  actionsPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  actions: [
                    // ❌ CLOSE
                    IconButton(
                      icon: Image.asset(
                        'assets/images/close.png',
                        width: 28,
                        height: 28,
                        color: navRed,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // ✅ CHECK = apply detected language
                    IconButton(
                      icon: Image.asset(
                        'assets/images/check.png',
                        width: 28,
                        height: 28,
                        color: navGreen,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _rightLang =
                                langCodes.entries
                                    .firstWhere((e) => e.value == detected)
                                    .key;
                          });
                          if (_imageFile != null) {
                            _processImage(imageFile: _imageFile!);
                          }
                        });
                      },
                    ),
                  ],
                ),
          );
        }
        setState(() {
          _isProcessing = false;
          _resultText = '';
        });
        return;
      }

      final cleaned = out.trim();
      setState(() => _resultText = cleaned);
      await _saveState(_croppedImageFile ?? _imageFile!, cleaned);
      if (cleaned.isNotEmpty && !cleaned.startsWith("Error:")) {
        await _saveState(_croppedImageFile ?? _imageFile!, cleaned);
      }

      if (_imageIsUnclear(out)) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Image Not Clear"),
                content: const Text(
                  "The image is not clear enough for AI to read. Please try another image.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }
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

  bool _laActive = false;

  @override
  Widget build(BuildContext context) {
    const double boxW = 486;
    const double switcherW = 350;
    const double switcherH = 55;
    const double flagSize = 50;
    const double switchSize = 50;
    final screenWidth = MediaQuery.of(context).size.width;
    final double iconSize = (screenWidth * 0.085).clamp(24.0, 48.0);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
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
                    Center(
                      child: SizedBox(
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return InteractiveViewer(
                                                panEnabled: true,
                                                boundaryMargin:
                                                    const EdgeInsets.all(100),
                                                clipBehavior: Clip.none,
                                                minScale: 0.5,
                                                maxScale: 5.0,
                                                constrained: true,
                                                child: SizedBox(
                                                  width: constraints.maxWidth,
                                                  height: constraints.maxHeight,
                                                  child: Image.file(
                                                    _croppedImageFile ??
                                                        _imageFile!,
                                                    fit:
                                                        BoxFit
                                                            .contain, // this ensures it’s zoomed out by default
                                                  ),
                                                ),
                                              );
                                            },
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                  onTap: () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('lastImagePath');
                                    await prefs.remove('lastResultText');

                                    setState(() {
                                      _imageFile = null;
                                      _croppedImageFile = null;
                                      _resultText = '';
                                      _isProcessing = false;
                                      _laActive = false;
                                      _interpretMode = false;
                                      _splitRatio = 0.5;
                                    });
                                  },
                                  child: Image.asset(
                                    'assets/images/close.png',
                                    width: iconSize,
                                    height: iconSize,
                                  ),
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
                            // Compute the *current* top from your state-backed _splitRatio:
                            final currentTop = _splitRatio * usable;
                            final newTop = (currentTop + d.delta.dy).clamp(
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
                                Center(
                                  child: Image.asset(
                                    'assets/images/loader.gif',
                                    width: 100, // or any size you want
                                    height: 100,
                                  ),
                                )
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
                                              onlyTranslated:
                                                  _laActive, // Hide original if LA is active
                                            );
                                          } else if (_isHtmlDoc(htmlStr)) {
                                            return Html(
                                              data: htmlStr,
                                              style: {
                                                "body": Style(
                                                  fontSize: FontSize(
                                                    calculateFontSizes(
                                                          res,
                                                          panelH,
                                                        ) *
                                                        _zoomLevel,
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
                                                        ) *
                                                        _zoomLevel,
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
                                        'assets/png24/black/b_copy.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Image.asset(
                                    //   'assets/images/share.png',
                                    //   width: iconSize,
                                    //   height: iconSize,
                                    // ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Image.asset(
                                    //   'assets/images/zoom.png',
                                    //   width: iconSize,
                                    //   height: iconSize,
                                    // ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Icon(Icons.volume_up, size: iconSize),
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

                                    // Zoom Out Button
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _zoomLevel = (_zoomLevel - 0.1).clamp(
                                            0.5,
                                            2.0,
                                          );
                                        });
                                      },
                                      child: Image.asset(
                                        'assets/images/zoom-minus.png', // ✅ Make sure this path is correct
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),

                                    SizedBox(width: iconSize * 0.5),

                                    // Zoom In Button
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _zoomLevel = (_zoomLevel + 0.1).clamp(
                                            0.5,
                                            2.0,
                                          );
                                        });
                                      },
                                      child: Image.asset(
                                        'assets/images/zoom-plus.png', // ✅ Make sure this path is correct
                                        width: iconSize,
                                        height: iconSize,
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
                                      child:
                                          _interpretMode
                                              ? Icon(
                                                Icons.interpreter_mode,
                                                size: iconSize,
                                              )
                                              : Image.asset(
                                                'assets/png24/black/b_translate.png',
                                                width: iconSize,
                                                height: iconSize,
                                              ),
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    if (!_interpretMode)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _laActive = !_laActive;
                                          });
                                        },
                                        child: Image.asset(
                                          _laActive
                                              ? 'assets/png24/black/b_one_language.png'
                                              : 'assets/png24/black/b_both_languages.png',
                                          width: iconSize,
                                          height: iconSize,
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
                  onTap: () {
                    setState(() {
                      _rightLang = _next(_rightLang, _leftLang);

                      // clear old output
                      _resultText = '';
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });
                    if (_imageFile != null)
                      _processImage(imageFile: _imageFile!);
                  },
                  child: Row(
                    children: [
                      Image.asset(_labelPaths[_rightLang]!, height: 32),
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
                  onTap: () {
                    setState(() {
                      // swap
                      final tmp = _leftLang;
                      _leftLang = _rightLang;
                      _rightLang = tmp;

                      // clear old output
                      _resultText = '';
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });

                    // re-run if we have an image
                    if (_imageFile != null) {
                      _processImage(imageFile: _imageFile!);
                    }
                  },
                  child: Image.asset(
                    'assets/png24/black/b_change_flat.png',
                    width: switchSize,
                  ),
                ),
                const SizedBox(width: 25),
                // Left (output language, flag at top left, tap cycles)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _leftLang = _next(_leftLang, _rightLang);

                      // clear old output
                      _resultText = '';
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });
                    if (_imageFile != null)
                      _processImage(imageFile: _imageFile!);
                  },

                  child: Row(
                    children: [
                      Image.asset(
                        _flagPaths[_leftLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                      const SizedBox(width: 8),
                      Image.asset(_labelPaths[_leftLang]!, height: 32),
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
