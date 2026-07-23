import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/gemini_image_service.dart';

const Color _navRed = Color(0xFFCD2A3E);
const Color _navGreen = Color(0xFF436F4D);

/// Modal for asking a free-text question about the currently loaded
/// image/PDF (Markus, 2026-07-23 voice note: after translating a document,
/// tap a "?" button and type a question about it). Shown the same way as
/// [PdfPageSelectorDialog] — a dialog over the dimmed Image page.
class DocumentQuestionDialog extends StatefulWidget {
  const DocumentQuestionDialog({
    super.key,
    required this.file,
    required this.answerLangCode,
    this.pdfPages,
  });

  final File file;
  final String answerLangCode;
  final String? pdfPages;

  @override
  State<DocumentQuestionDialog> createState() =>
      _DocumentQuestionDialogState();
}

class _DocumentQuestionDialogState extends State<DocumentQuestionDialog> {
  final _service = GeminiImageService();
  final _controller = TextEditingController();
  bool _loading = false;
  bool _failed = false;
  String? _answer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _answer = null;
      _failed = false;
    });
    try {
      final answer = await _service.askAboutDocument(
        documentFile: widget.file,
        question: question,
        answerLangCode: widget.answerLangCode,
        pdfPages: widget.pdfPages,
      );
      if (mounted) setState(() => _answer = answer);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.documentQuestionTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.robotoCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                enabled: !_loading,
                style: GoogleFonts.robotoCondensed(fontSize: 18),
                decoration: InputDecoration(
                  hintText: loc.documentQuestionHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    loc.documentQuestionError,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 16,
                      color: _navRed,
                    ),
                  ),
                )
              else if (_answer != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      _answer!,
                      style: GoogleFonts.robotoCondensed(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      label: loc.cancel,
                      color: _navRed,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _pillButton(
                      label: loc.documentQuestionAsk,
                      color: _navGreen,
                      onTap: _loading ? null : _ask,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoCondensed(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
