import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const Color navGreen = Color(0xFF436F4D);
const Color navRed = Color(0xFFCD2A3E);

// Replace with your real purchase URL
const String purchaseUrl = 'https://your-token-purchase-page.example.com';

class LicenseCreditPage extends StatefulWidget {
  const LicenseCreditPage({super.key});

  @override
  _LicenseCreditPageState createState() => _LicenseCreditPageState();
}

class _LicenseCreditPageState extends State<LicenseCreditPage> {
  double _credit = 42.50; // placeholder starting credit
  final TextEditingController _tokenController = TextEditingController();
  bool _isRedeeming = false;

  Future<void> _redeemToken() async {
    final code = _tokenController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token code')),
      );
      return;
    }

    setState(() => _isRedeeming = true);
    // TODO: call your API to validate/redeem `code`
    await Future.delayed(const Duration(seconds: 1)); // simulate network

    // on success:
    setState(() {
      _credit += 10; // simulate adding credit
      _isRedeeming = false;
      _tokenController.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token redeemed!')));

    // on failure, catch and show error SnackBar instead
  }

  Future<void> _buyTokens() async {
    if (await canLaunchUrl(Uri.parse(purchaseUrl))) {
      await launchUrl(Uri.parse(purchaseUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open purchase page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navGreen,
        title: Text('License & Credit', style: GoogleFonts.robotoCondensed()),
        leading: BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current Credit Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Credit: €${_credit.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: navGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Redeem Token
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Enter token code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: navRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isRedeeming ? null : _redeemToken,
                child:
                    _isRedeeming
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text('Redeem', style: TextStyle(fontSize: 16)),
              ),
            ),

            const Spacer(),

            // Buy Tokens
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: navGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _buyTokens,
                child: Text(
                  'Buy Tokens',
                  style: TextStyle(color: navGreen, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
