import 'package:flutter/material.dart';
import 'package:forditva/services/gemini_translation_service.dart'; // your Gemini client
import 'package:forditva/utils/utils.dart';

import '../models/language_enum.dart';
import 'edit_recording_modal.dart';
import 'recording_modal.dart';

class EditRecordingSheet extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onEdited;
  final Language lang;
  final String expectedLangCode; // e.g. 'HU', 'DE', 'EN'
  final GeminiTranslator gemini;

  const EditRecordingSheet({
    super.key,
    required this.initialText,
    required this.onEdited,
    required this.lang,
    required this.expectedLangCode,
    required this.gemini,
  });

  @override
  State<EditRecordingSheet> createState() => _EditRecordingSheetState();
}

class _EditRecordingSheetState extends State<EditRecordingSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConcatRecording(String newText) {
    setState(() {
      _controller.text = newText;
    });
  }

  void _handleEdited(String editedText) {
    setState(() {
      _controller.text = editedText;
    });
    widget.onEdited(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 10,
            right: 10,
            top: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RecordingModal(
                  lang: widget.lang,
                  isTopPanel: true,
                  editMode: true,
                  textController: _controller, // <-- pass controller
                  onConcatRecording: _handleConcatRecording,
                  onTranscribed: (_) {},
                ),
                SizedBox(height: 8),
                EditTextModal(
                  controller: _controller, // <-- pass same controller
                  onEdited: _handleEdited,
                  isTextInLanguage:
                      (text) => isTextInLanguage(
                        text,
                        widget.expectedLangCode,
                        widget.gemini,
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
