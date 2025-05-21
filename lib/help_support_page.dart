// lib/help_support_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const Color navGreen = Color(0xFF436F4D);

// TODO: replace with your real support email and app store URLs
const String supportEmail = 'support@yourcompany.com';
const String appStoreUrl = 'https://example.com/your-app-store-page';
const String playStoreUrl = 'https://example.com/your-play-store-page';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  Future<void> _sendFeedback(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Feedback for Forditva App v1.0.0'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final uri = Uri.parse(
      appStoreUrl,
    ); // choose store based on platform if you like
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open store page')),
      );
    }
  }

  void _showQuickGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quick Guide',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Tap the mic to start speaking\n'
                  '• Swipe left/right to switch screens\n'
                  '• Long-press a translation to copy/share\n\n'
                  '…more tips here…',
                  style: GoogleFonts.roboto(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: navGreen),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Forditva',
      applicationVersion: 'v1.0.0',
      applicationLegalese: '© 2025 Your Company Name',
      children: [
        const SizedBox(height: 8),
        Text(
          'A simple translator app with pay-as-you-go tokens.',
          style: GoogleFonts.roboto(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap:
              () => launchUrl(
                Uri.parse('https://your-privacy-policy.example.com'),
              ),
          child: Text(
            'Privacy Policy',
            style: TextStyle(
              color: navGreen,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navGreen,
        leading: BackButton(color: Colors.white),
        title: Text('Help & Support', style: GoogleFonts.robotoCondensed()),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: navGreen),
            title: Text(
              'Quick Guide',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            onTap: () => _showQuickGuide(context),
          ),
          Divider(),

          ListTile(
            leading: Icon(Icons.feedback_outlined, color: navGreen),
            title: Text(
              'Send Feedback / Report Issue',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            onTap: () => _sendFeedback(context),
          ),
          Divider(),

          ListTile(
            leading: Icon(Icons.star_border, color: navGreen),
            title: Text(
              'Rate App in Store',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            onTap: () => _rateApp(context),
          ),
          Divider(),

          ListTile(
            leading: Icon(Icons.info, color: navGreen),
            title: Text(
              'About This App',
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }
}
