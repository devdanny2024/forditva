// lib/settings_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color navGreen = Color(0xFF436F4D);
const List<String> _languages = ['Deutsch', 'English', 'Magyar'];
const List<String> _themes = ['Classic', 'Ocean Blue', 'Forest Green'];

class SettingsPage extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;

  const SettingsPage({super.key, required this.onLocaleChanged});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();

    final localeCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    if (localeCode == 'de') {
      _selectedLanguage = 'Deutsch';
    } else if (localeCode == 'hu') {
      _selectedLanguage = 'Magyar';
    } else {
      _selectedLanguage = 'English';
    }
  }

  String _selectedTheme = _themes[0]; // Classic by default
  bool _saveHistory = true; // default On

  void _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Clear Entire History',
              style: GoogleFonts.robotoCondensed(),
            ),
            content: Text(
              'Are you sure you want to delete all translation history? '
              'This action cannot be undone.',
              style: GoogleFonts.roboto(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (ok == true) {
      // TODO: actually clear your history data here
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('History cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navGreen,
        leading: BackButton(color: Colors.white),
        title: Text('Settings', style: GoogleFonts.robotoCondensed()),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Language
          Text(
            'App Language',
            style: GoogleFonts.robotoCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            items:
                _languages
                    .map(
                      (lang) =>
                          DropdownMenuItem(value: lang, child: Text(lang)),
                    )
                    .toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (val) {
              setState(() => _selectedLanguage = val!);
              if (val == 'Deutsch') {
                widget.onLocaleChanged(const Locale('de'));
              } else if (val == 'Magyar') {
                widget.onLocaleChanged(const Locale('hu'));
              } else {
                widget.onLocaleChanged(const Locale('en'));
              }

              // Close the settings page so rebuild happens at root
              Navigator.of(context).pop();
            },
          ),

          const SizedBox(height: 24),
          // Theme
          Text(
            'Theme',
            style: GoogleFonts.robotoCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTheme,
            items:
                _themes
                    .map((th) => DropdownMenuItem(value: th, child: Text(th)))
                    .toList(),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (val) => setState(() => _selectedTheme = val!),
          ),

          const SizedBox(height: 24),
          // History toggle
          SwitchListTile(
            title: Text(
              'Save History',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            value: _saveHistory,
            activeColor: navGreen,
            onChanged: (v) => setState(() => _saveHistory = v),
          ),

          const SizedBox(height: 8),
          // Clear history
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Clear Entire History',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            trailing: Icon(Icons.delete, color: Colors.red),
            onTap: _clearHistory,
          ),
        ],
      ),
    );
  }
}
