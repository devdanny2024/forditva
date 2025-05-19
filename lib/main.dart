import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;  // ← Add this at the top of your file
const Color navRed   = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lang Translator App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: MainScreen(),
    );
  }
}


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 1: Conversation, 2: Learning List, 3: Favorites, 4: History
  int _currentPage = 1;

final List<Widget> _pages = [
  SizedBox.shrink(),                // 0: drawer/menu placeholder
  TextPage(),                       // 1: Conversation
  LearningListPage(),               // 2: Learning List
  Center(child: Text('Favorites')), // 3: Favorites
  Center(child: Text('History')),   // 4: History
  DocumentPlaceholderPage(), // Added: index 5
  ImagePlaceholderPage(),    // Added: index 6
];

String _getPageName(int idx) {
  switch (idx) {
    case 1:
      return 'Conversation';
    case 2:
      return 'Learning List';
    case 3:
      return 'Favorites';
    case 4:
      return 'History';
    case 5: return 'Document'; // Added
    case 6: return 'Image';    // Added
    default:
      return '';
  }
}




  void _openDrawer() {
    Scaffold.of(context).openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(children: [
          DrawerHeader(child: Text('Menu')),
          ListTile(title: Text('Settings'))
        ]),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(''),
      ),
      body: _pages[_currentPage],
bottomNavigationBar: Container(
  // internal bottom padding
  padding: const EdgeInsets.only(bottom: 8.0),
  child: SizedBox(
    height: 56,
    child: Stack(
      children: [
        // ─── LEFT GREEN PANEL ─────────────────────────────────────────
        Positioned(
          left: 0,
          right: 20,
          top: 0,
          bottom: 0,
          child: Container(color: navRed),
        ),

        // ─── RIGHT RED PANEL ──────────────────────────────────────────
        Positioned(
          left: 20,
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(color: navGreen),
        ),

        // ─── NAV CONTENT, INSET 16PX FROM LEFT ────────────────────────
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  top:    BorderSide(color: Colors.black, width: 1),
                  bottom: BorderSide(color: Colors.black, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // MENU
                  Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _openDrawer,
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

                  // DISCUSSION
Flexible(
  flex: 1,
  child: GestureDetector(
    onTap: () => setState(() {
      if (_currentPage == 1) _currentPage = 5;
      else if (_currentPage == 5) _currentPage = 6;
      else _currentPage = 1;
    }),
    child: Container(
      color: navRed,
      alignment: Alignment.center,
      child: Image.asset(
        // ← swapped to conditional asset path
        _currentPage == 1
          ? 'assets/images/w_discussion.png'
          : _currentPage == 5
            ? 'assets/images/document-mode_w.png'
            : 'assets/images/photo_mode_w.png',
        width: 35,
        height: 35,
        color: (_currentPage == 1 || _currentPage == 5 || _currentPage == 6)
            ? Colors.white
            : Colors.grey,
        colorBlendMode: BlendMode.srcIn,
      ),
    ),
  ),
),

                  // TITLE
Flexible(
  flex: 3,
  child: GestureDetector(                                         // Added
    onTap: () => setState(() {                                    // Added: same toggle logic
      if (_currentPage == 1) _currentPage = 5;
      else if (_currentPage == 5) _currentPage = 6;
      else _currentPage = 1;
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
  flex: 3, // covers the space of 3 icons
  child: Container(
    color: navGreen,           // one shared background
    alignment: Alignment.center,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LEARNING LIST
        GestureDetector(
          onTap: () => setState(() => _currentPage = 2),
          child: Image.asset(
            'assets/images/learning_list_w.png',
            width: 35,
            height: 35,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),

        SizedBox(width: 10),  // fixed gap

        // FAVORITES
        GestureDetector(
          onTap: () => setState(() => _currentPage = 3),
          child: Image.asset(
            'assets/images/favorit_w.png',
            width: 35,
            height: 35,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),

        SizedBox(width: 10),  // fixed gap

        // HISTORY
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

/// ==================== TextPage ====================
class TextPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final switchSize = 70.0;
        final flagSize = 24.0;
        final halfH = constraints.maxHeight / 2;

        return Stack(
          children: [
            // 1) Input card
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              height: halfH + switchSize / 2,
              child: TranslationInputCard(),
            ),
            Positioned(
              top: halfH - switchSize / 2,
              left: 16,
              width: constraints.maxWidth / 2 + switchSize / 2 - 16,
              child: Container(
                height: switchSize,
                decoration: BoxDecoration(
                  color: textGrey,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                ),
              ),
            ),
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
                  borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                ),
              ),
            ),
            
            // 4) Switch + flags row on top
Positioned(
  top: halfH - switchSize / 2,
  left: 16,
  right: 16,
  child: SizedBox(
    height: switchSize,
    child: Stack(
      children: [
        // 1) Hungarian on the left with 20px padding
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,

  children: [
    // shifted down by 8px
    Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          child: Image.asset(
            'assets/flags/HU_BB.png',
            width: flagSize,
            height: flagSize,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),

    SizedBox(width: 10),

    // also shifted down by 8px
    Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Image.asset(
        'assets/images/HU-EN.png',
        height: flagSize,
        fit: BoxFit.contain,
      ),
    ),
  ],

            ),
          ),
        ),

// 2) Switch in the center
Center(
  child: Container(
    width: switchSize,
    height: switchSize,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      border: Border.all(color: Colors.black, width: 2), // ← black outline
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


        // 3) German on the right with 20px padding, rotated upside-down
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
          padding: const EdgeInsets.only(right: 20.0, bottom: 20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl, // flag then text
children: [
    // Rotated flag with white border & 10px radius
    Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: RotatedBox(
        quarterTurns: 2,
        child: ClipRRect(
          child: Image.asset(
            'assets/flags/DE_BW.png',
            width: flagSize,
            height: flagSize,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),

    SizedBox(width: 10),

    // Replace rotated Text with the German label image
    RotatedBox(
      quarterTurns: 2,
      child: Image.asset(
        'assets/images/DE-EN.png',
        height: flagSize,      // match flag height
        fit: BoxFit.contain,
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

          ],
        );
      },
    );
  }
}

class TranslationInputCard extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: textGrey, borderRadius: BorderRadius.circular(8)),
      child: Stack(
        alignment: Alignment.center,
        children: [
        Padding(
        padding: EdgeInsets.all(32),  //
        child: RotatedBox(
      quarterTurns: 2,
      child: Text(
        'Ich muss wissen, wie ich zum Bahnhof komme.',
        textAlign: TextAlign.center,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,  // Medium
          fontSize: 30,
          color: Colors.white,
        ),
      ),
    ),
        ),
          Positioned(
            top: 9,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(      
                image: DecorationImage(image: AssetImage('assets/flags/DE_BW.png'), fit: BoxFit.cover)),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: Image.asset('assets/images/microphone-white-border.png', width: 40, height: 40),
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
  @override Widget build(BuildContext context) {
return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Stack(
        alignment: Alignment.center,
       children: [
          Positioned(
            top: 80,        // ← distance from top of this Container
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
      Image.asset('assets/images/play-sound.png', width: 40, height: 40),
    ],
  ),
),
        ],
      ),
    );
  }
}
class LearningListPage extends StatelessWidget {
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
class DocumentPlaceholderPage extends StatelessWidget { // Added
  @override Widget build(BuildContext context) => Center(
    child: Image.asset('assets/images/document_placeholder.png'),
  );
}

class ImagePlaceholderPage extends StatelessWidget {    // Added
  @override Widget build(BuildContext context) => Center(
    child: Image.asset('assets/images/image_placeholder.png'),
  );
}