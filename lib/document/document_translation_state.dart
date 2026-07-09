import 'package:forditva/models/language_enum.dart';

class DocumentTranslationState {
  static String inputText = '';
  static String translatedText = '';

  // Languages carried over from the conversation page when content is copied
  // in, so the document panel speaks each side in the correct language. Without
  // this, Dutch text was read with the document's default (German) voice.
  static Language? leftLang;
  static Language? rightLang;
}
