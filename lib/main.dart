import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:forditva/document/document_language_state.dart';
import 'package:forditva/document/translationstate.dart';
import 'package:forditva/widgets/splash_screen.dart'; // Adjust path!
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document/document_translation_page.dart';
import 'favorite.dart';
import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'history.dart';
import 'image_page.dart';
import 'learning_list.dart';
import 'profile_settings_page.dart';
import 'services/level_pref.dart';
import 'services/third_language_pref.dart';
import 'services/token_balance.dart';
import 'textpage.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load();
  await ThirdLanguagePref.load();
  await LevelPref.load();
  await TokenBalance.instance.load();
  await TokenBalance.instance.grantWelcomeIfFirstRun();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranslationState()),
        ChangeNotifierProvider(create: (_) => DocumentLanguageState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<Locale?> _localeNotifier = ValueNotifier<Locale?>(null);
  static const _localePrefKey = 'app_locale';

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  // Restore the language the user last picked in Settings, so it (and the
  // preset translation pair derived from it) survives an app restart.
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefKey);
    if (code != null && code.isNotEmpty) {
      _localeNotifier.value = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    _localeNotifier.value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          // <-- INSIDE THIS WIDGET
          locale: locale,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          title: 'Forditva',
          theme: ThemeData(primarySwatch: Colors.green),

          // ✅ ADD THESE LINES
          initialRoute: '/',
          routes: {
            '/':
                (context) =>
                    SplashScreenWithLocaleSetter(onLocaleChanged: setLocale),
            '/home': (context) => MainScreen(onLocaleChanged: setLocale),
          },
        );
      },
    );
  }
}
// In the same file or a new one, but after SplashScreen is defined

class SplashScreenWithLocaleSetter extends StatelessWidget {
  final void Function(Locale) onLocaleChanged;
  const SplashScreenWithLocaleSetter({
    super.key,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SplashScreenRedirect(onLocaleChanged: onLocaleChanged);
  }
}

class SplashScreenRedirect extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const SplashScreenRedirect({super.key, required this.onLocaleChanged});

  @override
  State<SplashScreenRedirect> createState() => _SplashScreenRedirectState();
}

class _SplashScreenRedirectState extends State<SplashScreenRedirect> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // The actual splash visuals
    return const SplashScreen();
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
  void initState() {
    super.initState();
    // The page GlobalKeys have no currentState during the first build, so the
    // Tutor bulb initially binds to the disabled notifier and never lights up.
    // Rebuild once after the first frame so it binds to the active page's
    // hasHungarianText notifier and reacts to Hungarian text appearing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // Lets the nav bar's bulb button reach into each page's state to open the
  // Tutor modal for whatever Hungarian text is currently on screen there.
  // The bulb sits at the same nav-bar position on all three pages now.
  final GlobalKey<State<TextPage>> _textPageKey = GlobalKey<State<TextPage>>();
  final GlobalKey<State<DocumentPlaceholderPage>> _documentPageKey =
      GlobalKey<State<DocumentPlaceholderPage>>();
  final GlobalKey<State<ImagePlaceholderPage>> _imagePageKey =
      GlobalKey<State<ImagePlaceholderPage>>();

  late final List<Widget> _pages = [
    SizedBox.shrink(), // 0: drawer/menu placeholder
    TextPage(
      key: _textPageKey,
      onOpenDocument: () => setState(() => _currentPage = 5),
    ), // 1: Conversation
    LearningListPage(), // 2: Learning List
    FavoritePage(),
    HistoryPage(), // 4: History (was placeholder)
    DocumentPlaceholderPage(key: _documentPageKey), // 5: Document
    ImagePlaceholderPage(key: _imagePageKey), // 6: Image
  ];

  dynamic get _activePageState {
    switch (_currentPage) {
      case 1:
        return _textPageKey.currentState;
      case 5:
        return _documentPageKey.currentState;
      case 6:
        return _imagePageKey.currentState;
      default:
        return null;
    }
  }

  void _openTutor() {
    (_activePageState as dynamic)?.openTutor();
  }

  // Enabled only while there's actually Hungarian text to explain on the
  // currently active page.
  static final ValueNotifier<bool> _disabled = ValueNotifier(false);

  ValueListenable<bool> get _bulbEnabledListenable {
    final state = _activePageState;
    if (state != null) return state.hasHungarianText as ValueListenable<bool>;
    return _disabled;
  }

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
    const double navBarHeight = 56.0;
    final double iconSize = navBarHeight * 0.5; // 60% of nav-bar height
    return Scaffold(
      appBar: null,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          // Keep a safe top clearance under the status bar, but drop the bottom
          // gap so the cards sit lower, closer to the menu (Markus: move the
          // cards down toward the menu, too much space).
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          child: _pages[_currentPage],
        ),
      ),

      bottomNavigationBar: Padding(
        // Lift the bar above the Android system navigation/gesture bar.
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Container(
          // antiAliasWithSaveLayer composites the rounded-corner children
          // cleanly against the border; the plain antiAlias clip was
          // leaving a hairline red fringe bleeding past the black border
          // at the left corner.
          clipBehavior: Clip.antiAliasWithSaveLayer,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: SizedBox(
            height: navBarHeight,
            child: Row(
              children: [
                // menu
                Flexible(
                  flex: 1,
                  child: Builder(
                    builder:
                        (ctx) => GestureDetector(
                          onTap:
                              () => Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileSettingsPage(
                                        onLocaleChanged: widget.onLocaleChanged,
                                      ),
                                ),
                              ),
                          child: Container(
                            color: navRed,
                            alignment: Alignment.center,
                            // Nudge the icon off the rounded left corner —
                            // it was sitting flush against the curve.
                            padding: const EdgeInsets.only(left: 8),
                            child: Image.asset(
                              'assets/png24/white/w_menu.png',
                              width: iconSize,
                              height: iconSize,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                        ),
                  ),
                ),

                // Tutor bulb: same nav-bar position on all three pages now,
                // always opens the Tutor for whatever Hungarian text is on
                // the currently active page. Page switching between
                // Conversation/Document/Image happens via the title area
                // (below) and the card's own document-mode icon.
                Flexible(
                  flex: 1,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _bulbEnabledListenable,
                    builder: (context, enabled, _) {
                      return GestureDetector(
                        onTap: !enabled ? null : _openTutor,
                        child: Container(
                          color: navRed,
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: enabled ? 1.0 : 0.4,
                            child: Image.asset(
                              'assets/png24/white/w_lightbulb.png',
                              width: iconSize,
                              height: iconSize,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // page title
                Flexible(
                  flex: 3,
                  child: GestureDetector(
                    onTap:
                        () => setState(() {
                          if (_currentPage == 1) {
                            _currentPage = 5;
                          } else if (_currentPage == 5)
                            _currentPage = 6;
                          else
                            _currentPage = 1;
                        }),
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                          ),
                          child: Text(
                            _getPageName(_currentPage),
                            maxLines: 1,
                            // Was 18 — Markus, 2026-07-11: text looked too
                            // reduced. The surrounding FittedBox still
                            // scales the longest label (e.g. "Beszélgetés",
                            // "Tanulási lista") down if it doesn't fit, so
                            // this is safe to raise; shorter labels now
                            // render visibly larger.
                            style: GoogleFonts.robotoCondensed(
                              fontWeight: FontWeight.w500,
                              fontSize: 21,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // learning / favorite / history
                Flexible(
                  flex: 3,
                  child: Container(
                    color: navGreen,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap:
                              () => setState(() => _currentPage = 2),
                          child: Image.asset(
                            'assets/png24/white/w_learninglist.png',
                            width: iconSize,
                            height: iconSize,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => setState(() => _currentPage = 3),
                          child: Image.asset(
                            'assets/png24/white/w_favorit.png',
                            width: iconSize,
                            height: iconSize,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => setState(() => _currentPage = 4),
                          child: Image.asset(
                            'assets/png24/white/w_history.png',
                            width: iconSize,
                            height: iconSize,
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
    );
  }
}

