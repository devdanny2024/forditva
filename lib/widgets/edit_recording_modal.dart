import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditTextModal extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onEdited;
  final Future<bool> Function(String text) isTextInLanguage;

  const EditTextModal({
    super.key,
    required this.controller,
    required this.onEdited,
    required this.isTextInLanguage,
  });

  @override
  State<EditTextModal> createState() => _EditTextModalState();
}

class _EditTextModalState extends State<EditTextModal> {
  bool _loading = false;

  Future<void> _onCheckPressed() async {
    setState(() => _loading = true);
    bool isValid = await widget.isTextInLanguage(widget.controller.text.trim());
    setState(() => _loading = false);

    if (isValid) {
      widget.onEdited(widget.controller.text.trim());
    } else {
      // Show dialog and keep editing
      if (!mounted) return;
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("Wrong Language"),
              content: const Text("Please put in the correct language."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
      // Stay on edit page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.only(left: 18, right: 18, top: 18, bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 5),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minHeight: 220,
        maxHeight: 220, // Fixed height for text box
      ),
      child: Stack(
        children: [
          // Fixed-height, scrollable text area
          Positioned.fill(
            bottom: 60, // Space for buttons
            child: SingleChildScrollView(
              child: TextField(
                controller: widget.controller, // Use the passed controller!
                autofocus: true,
                maxLines: null,
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  fontSize: 30,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: false,
                  contentPadding: EdgeInsets.zero,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          // Loader overlay (center)
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          // Tick button at bottom left
          Positioned(
            left: 0,
            bottom: 0,
            child: IconButton(
              icon: Image.asset(
                'assets/images/check.png',
                width: 40,
                height: 40,
              ),
              onPressed: _loading ? null : _onCheckPressed,
            ),
          ),
          // Close button at bottom right
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              icon: Image.asset(
                'assets/images/close.png',
                width: 40,
                height: 40,
              ),
              onPressed:
                  _loading
                      ? null
                      : () {
                        Navigator.of(context).maybePop();
                      },
            ),
          ),
        ],
      ),
    );
  }
}
