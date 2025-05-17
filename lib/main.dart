import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  int _selectedIndex = 1;
  static final List<Widget> _pages = <Widget>[
    SizedBox.shrink(),
    ConversationPage(),
    PlaceholderPage(title: 'Photo Page'),
    TextPage(),
    PlaceholderPage(title: 'Favorites'),
    PlaceholderPage(title: 'History'),
  ];

  void _onItemTapped(int index) {
    if (index == 0) Scaffold.of(context).openDrawer();
    else setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(child: Text('Menu')),
            ListTile(title: Text('Settings'))
          ],
        ),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb),
            SizedBox(width: 8),
            FlutterLogo(size: 32),
            Spacer(),
            Icon(Icons.description),
            SizedBox(width: 16),
            Icon(Icons.volume_up),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Conversation'),
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Photo'),
          BottomNavigationBarItem(icon: Icon(Icons.text_fields), label: 'Text'),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({Key? key, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: TextStyle(fontSize: 24)),
    );
  }
}

/// ==================== ConversationPage ====================
class ConversationPage extends StatefulWidget {
  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: 'Translated: $text', isUser: false));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Align(
                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: msg.isUser ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(msg.text),
                ),
              );
            },
          ),
        ),
        Divider(height: 1),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.mic), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: 'Type or speak...'),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, this.isUser = true});
}

/// ==================== TextPage ====================
class TextPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(child: TranslationInputCard()),
              Expanded(child: TranslationOutputCard()),
            ],
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                // TODO: swap input and output boxes
              },
              child: Container(
                width: 56, // adjust switch container width
                height: 56, // adjust switch container height
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12), // rounded corners
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/switch.png',
                    width: 32, // adjust switch icon size
                    height: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TranslationInputCard extends StatelessWidget {
  const TranslationInputCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(
                'Tudom kell, hogyan megyek a vasútállomásra?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: AssetImage('assets/flags/HU_L.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: Image.asset(
                    'assets/images/microphone.png',
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TranslationOutputCard extends StatelessWidget {
  const TranslationOutputCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(8),
      ),
      // TODO: Add translation output here
    );
  }
}