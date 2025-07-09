import 'package:flutter/material.dart';

import '../main.dart'; // for Language enum

class DocumentLanguageState extends ChangeNotifier {
  Language _leftLang = Language.english;
  Language _rightLang = Language.german;

  Language get leftLang => _leftLang;
  Language get rightLang => _rightLang;

  void setLeftLang(Language lang) {
    _leftLang = lang;
    notifyListeners();
  }

  void setRightLang(Language lang) {
    _rightLang = lang;
    notifyListeners();
  }

  void swapLanguages() {
    final temp = _leftLang;
    _leftLang = _rightLang;
    _rightLang = temp;
    notifyListeners();
  }
}
