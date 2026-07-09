import 'package:flutter/foundation.dart';

/// Global, session-wide tally of AI tokens consumed.
///
/// Every Gemini request (translation and tutor) reports its
/// `usageMetadata.totalTokenCount` here via [add]. The credit/progress-bar
/// logic can read [total] (and listen to it) to decrement the user's balance.
///
/// This is a single shared instance because the app builds several
/// [GeminiTranslator] objects; all of them must feed the same counter.
class TokenUsage {
  TokenUsage._();
  static final TokenUsage instance = TokenUsage._();

  /// Tokens consumed across all AI requests since the app started.
  final ValueNotifier<int> total = ValueNotifier<int>(0);

  /// Tokens consumed by the most recent request.
  int last = 0;

  /// Records the cost of one request. Ignores non-positive values.
  void add(int tokens) {
    if (tokens <= 0) return;
    last = tokens;
    total.value += tokens;
  }

  /// Resets the running total (e.g. after the balance is synced to the server).
  void reset() {
    last = 0;
    total.value = 0;
  }
}
