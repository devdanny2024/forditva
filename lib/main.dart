import 'dart:math' as math; // ← Add this at the top of your file

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'help_support_page.dart';
import 'license_credit_page.dart';
import 'settings_page.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hungarian, german, english }

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ← add this
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<Locale?> _localeNotifier = ValueNotifier<Locale?>(null);

  void setLocale(Locale locale) {
    _localeNotifier.value = locale;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          locale: locale,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          title: 'Lang Translator App',
          theme: ThemeData(primarySwatch: Colors.green),
          home: MainScreen(
            key: ValueKey(locale?.languageCode), // <- this forces rebuild
            onLocaleChanged: setLocale,
          ),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;

  const MainScreen({super.key, required this.onLocaleChanged});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentPage = 1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("Current locale: ${Localizations.localeOf(context)}");
  }

  final List<Widget> _pages = [
    SizedBox.shrink(), // 0: drawer/menu placeholder
    TextPage(), // 1: Conversation
    LearningListPage(), // 2: Learning List
    FavoritePage(),
    HistoryPage(), // 4: History (was placeholder)
    DocumentPlaceholderPage(), // 5: Document
    ImagePlaceholderPage(), // 6: Image
  ];

  String _getPageName(int idx) {
    switch (idx) {
      case 1:
        return AppLocalizations.of(context)!.conversation;
      case 2:
        return AppLocalizations.of(context)!.learningList;
      case 3:
        return AppLocalizations.of(context)!.favorites;
      case 4:
        return AppLocalizations.of(context)!.history;
      case 5:
        return AppLocalizations.of(context)!.documentMode;
      case 6:
        return AppLocalizations.of(context)!.imageMode;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(child: Text(AppLocalizations.of(context)!.menu)),
            ListTile(
              leading: Icon(Icons.attach_money, color: navGreen),
              title: Text(AppLocalizations.of(context)!.licenseCredit),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicenseCreditPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: navGreen),
              title: Text(AppLocalizations.of(context)!.settings),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => SettingsPage(
                          onLocaleChanged: (locale) {
                            widget.onLocaleChanged(locale);
                          },
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: navGreen),
              title: Text(AppLocalizations.of(context)!.helpSupport),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight - 20),
        child: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          toolbarHeight: kToolbarHeight - 20,
          elevation: 0,
        ),
      ),
      body: _pages[_currentPage],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 20,
                top: 0,
                bottom: 0,
                child: Container(color: navRed),
              ),
              Positioned(
                left: 20,
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(color: navGreen),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        top: BorderSide(color: Colors.black, width: 1),
                        bottom: BorderSide(color: Colors.black, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          flex: 1,
                          child: Builder(
                            builder:
                                (ctx) => GestureDetector(
                                  onTap: () => Scaffold.of(ctx).openDrawer(),
                                  child: Container(
                                    color: navRed,
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'assets/images/menu_w.png',
                                      width: 35,
                                      height: 35,
                                      color: Colors.white,
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: GestureDetector(
                            onTap:
                                () => setState(() {
                                  if (_currentPage == 1)
                                    _currentPage = 5;
                                  else if (_currentPage == 5)
                                    _currentPage = 6;
                                  else
                                    _currentPage = 1;
                                }),
                            child: Container(
                              color: navRed,
                              alignment: Alignment.center,
                              child: Image.asset(
                                _currentPage == 1
                                    ? 'assets/images/w_discussion.png'
                                    : _currentPage == 5
                                    ? 'assets/images/document-mode_w.png'
                                    : 'assets/images/photo_mode_w.png',
                                width: 35,
                                height: 35,
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          child: GestureDetector(
                            onTap:
                                () => setState(() {
                                  if (_currentPage == 1)
                                    _currentPage = 5;
                                  else if (_currentPage == 5)
                                    _currentPage = 6;
                                  else
                                    _currentPage = 1;
                                }),
                            child: Container(
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _getPageName(_currentPage),
                                  maxLines: 1,
                                  style: GoogleFonts.robotoCondensed(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 25,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          child: Container(
                            color: navGreen,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _currentPage = 2),
                                  child: Image.asset(
                                    'assets/images/learning_list_w.png',
                                    width: 35,
                                    height: 35,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(() => _currentPage = 3),
                                  child: Image.asset(
                                    'assets/images/favorit_w.png',
                                    width: 35,
                                    height: 35,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => setState(() => _currentPage = 4),
                                  child: Image.asset(
                                    'assets/images/history_1.png',
                                    width: 35,
                                    height: 35,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}

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

class LearningListPage extends StatelessWidget {
  const LearningListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Learning List',
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 24,
          color: Colors.black,
        ),
      ),
    );
  }
}

class DocumentPlaceholderPage extends StatelessWidget {
  const DocumentPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    const double boxW = 486;
    const double switcherW = 350;
    const double switcherH = 55;
    const double flagSize = 50; // smaller
    const double switchSize = 50;
    final media = MediaQuery.of(context);
    final totalH = media.size.height;
    final topBarH = media.padding.top + kToolbarHeight; // status + AppBar
    const bottomNavH = kBottomNavigationBarHeight; // your 56px nav bar
    final usableH = totalH - topBarH - bottomNavH; // screen minus bars
    final boxH = usableH / 2 - 80; // half minus 80

    return Container(
      color: textGrey, // full-screen grey background
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ─── Two white boxes, one above the other ─────────────────
          SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              children: [
                // white background with black outline
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // centered German text
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    'Ich möchte zum Bahnhof, kenne mich hier jedoch nicht aus. Wo muss ich hingehen und wie lange dauert das?',
                    textAlign: TextAlign.start,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),

                // mic icon bottom‐left
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Image.asset(
                    'assets/images/microphone.png',
                    width: 40,
                    height: 40,
                  ),
                ),

                // delete icon bottom‐right
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Image.asset(
                    'assets/images/delete.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ─── Transparent language switcher ────────────────────────
          SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              children: [
                // white background with black outline
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                // centered Hungarian text
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    'Szeretnék elmenni a vasútállomásra, de nem ismerem az utat. Hová kell mennem, és mennyi idôbe telik az ut?',
                    textAlign: TextAlign.start,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Left side: copy + share + zoom
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/copy.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/share.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/zoom.png',
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                ),

                // Right side: play-sound
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Image.asset(
                    'assets/images/play-sound.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ─── Language switcher ───────────────────────────────────
          SizedBox(
            width: switcherW,
            height: switcherH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // DE label
                Text(
                  'DE',
                  style: GoogleFonts.roboto(
                    fontSize: 35,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                // German flag
                Image.asset(
                  'assets/flags/DE_BW_LS.png',
                  width: flagSize,
                  height: flagSize,
                ),
                const SizedBox(width: 25),

                // Switch icon
                Image.asset(
                  'assets/images/switch.png',
                  width: switchSize,
                  height: switchSize,
                ),
                const SizedBox(width: 25),

                // Hungarian flag
                Image.asset(
                  'assets/flags/HU_BW_LS.png',
                  width: flagSize,
                  height: flagSize,
                ),
                const SizedBox(width: 8),

                // HU label
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  static const List<Map<String, String>> translations = <Map<String, String>>[
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt, rengeteg emléket hagyott bennem.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und hinterließ viele Erinnerungen.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    // … your other items …
  ];

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Set<int> _favoritedIndices = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search history...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.mic, color: Colors.black),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // scrollable list
            Expanded(
              child: ListView.builder(
                itemCount: HistoryPage.translations.length,
                itemBuilder: (context, index) {
                  final item = HistoryPage.translations[index];
                  final isFav = _favoritedIndices.contains(index);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // text
                        Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['source']!,
                                style: const TextStyle(
                                  color: navGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['translation']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // star toggle
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                if (isFav) {
                                  _favoritedIndices.remove(index);
                                } else {
                                  _favoritedIndices.add(index);
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isFav
                                        ? 'Removed from favorites'
                                        : 'Saved to favorites',
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                isFav ? Icons.star : Icons.star_border,
                                color: isFav ? gold : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key});

  static const List<Map<String, String>>
  favoriteTranslations = <Map<String, String>>[
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
    {
      'source':
          'A dunai hajókirándulás lenyűgöző volt és felejthetetlen élményt nyújtott.',
      'translation':
          'Die Donauschifffahrt war beeindruckend und unvergesslich.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search favorites...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: const Icon(Icons.mic, color: Colors.black),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // favorites list
            Expanded(
              child: ListView.builder(
                itemCount: favoriteTranslations.length,
                itemBuilder: (context, index) {
                  final item = favoriteTranslations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['source']!,
                                style: const TextStyle(
                                  color: navGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['translation']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // gold star indicator
                        const Icon(Icons.star, color: gold, size: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
