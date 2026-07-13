import 'package:forditva/models/language_enum.dart';

// Survives the Conversation page's own State being disposed when the user
// switches to another tab (main.dart swaps _pages[_currentPage] directly,
// with no IndexedStack, so TextPage is fully torn down and rebuilt). Without
// this, tapping the document icon then returning to Conversation looked like
// the text had been "cut" (Markus, 2026-07-12).
class ConversationState {
  static String inputText = '';
  static String translation = '';
  static Language? leftLang;
  static Language? rightLang;
}
