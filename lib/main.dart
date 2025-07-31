import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:forditva/document/document_language_state.dart';
import 'package:forditva/document/translationstate.dart';
import 'package:forditva/widgets/splash_screen.dart'; // Adjust path!
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'document/document_translation_page.dart';
import 'favorite.dart';
import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'help_support_page.dart';
import 'history.dart';
import 'image_page.dart';
import 'license_credit_page.dart';
import 'settings_page.dart';
import 'textpage.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hungarian, german, english }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load();
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

  void setLocale(Locale locale) {
    _localeNotifier.value = locale;
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
    const double navBarHeight = 56.0;
    final double iconSize = navBarHeight * 0.5; // 60% of nav-bar height
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
      appBar: null,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          // keep your top padding of 20, but only reserve
          // the exact nav height (56) at the bottom
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: _pages[_currentPage],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: SizedBox(
            height: navBarHeight,
            child: Stack(
              children: [
                // red half
                Positioned(
                  left: 0,
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Container(color: navRed),
                ),
                // green half
                Positioned(
                  left: 20,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: navGreen),
                ),
                // icons & label
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
                          // menu
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

                          // conversation / document / image toggle
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
                                      ? 'assets/png24/white/w_conversation.png'
                                      : _currentPage == 5
                                      ? 'assets/png24/white/w_document.png'
                                      : 'assets/png24/white/w_explain_image.png',
                                  width: iconSize,
                                  height: iconSize,
                                ),
                              ),
                            ),
                          ),

                          // page title
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Text(
                                      _getPageName(_currentPage),
                                      maxLines: 1,
                                      style: GoogleFonts.robotoCondensed(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
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
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap:
                                          () =>
                                              setState(() => _currentPage = 2),
                                      child: Image.asset(
                                        'assets/png24/white/w_learninglist.png',
                                        width: iconSize,
                                        height: iconSize,
                                        colorBlendMode: BlendMode.srcIn,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap:
                                          () =>
                                              setState(() => _currentPage = 3),
                                      child: Image.asset(
                                        'assets/png24/white/w_favorit.png',
                                        width: iconSize,
                                        height: iconSize,
                                        colorBlendMode: BlendMode.srcIn,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap:
                                          () =>
                                              setState(() => _currentPage = 4),
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
