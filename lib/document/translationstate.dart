import 'package:flutter/material.dart';
import 'package:forditva/models/language_enum.dart';

class TranslationState extends ChangeNotifier {
  String _inputText = '';
  String _translatedText = '';
  Language _fromLang = Language.hungarian;
  Language _toLang = Language.german;

  String get inputText => _inputText;
  String get translatedText => _translatedText;
  Language get fromLang => _fromLang;
  Language get toLang => _toLang;

  void updateInput(String text) {
    _inputText = text;
    notifyListeners();
  }

  void updateTranslation(String text) {
    _translatedText = text;
    notifyListeners();
  }

  void updateLanguages(Language from, Language to) {
    _fromLang = from;
    _toLang = to;
    notifyListeners();
  }

  void reset() {
    _inputText = '';
    _translatedText = '';
    notifyListeners();
  }
}
