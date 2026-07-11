import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_usage.dart';

/// The user's prepaid credit, measured in WIUs (wir-in-ungarn units). Redeeming
/// a prepaid code adds its value here; every Gemini request spends WIUs equal
/// to the tokens it consumed (1 WIU = 1 token, and 10,000 WIUs cost about
/// $25 at Gemini's output-token rate). TTS is billed the same way but by
/// character, converted to this same WIU rate via [spendFractional]. The
/// "Current Status" bar in Profile settings reads this. Persisted so the
/// balance survives app restarts.
class TokenBalance {
  TokenBalance._();
  static final TokenBalance instance = TokenBalance._();

  static const _key = 'token_balance_wiu';
  static const _welcomeKey = 'welcome_granted';
  // Stored as remainder*1000 (an int) since SharedPreferences has no double.
  static const _remainderKey = 'token_balance_remainder_x1000';

  /// One-time WIUs credited to every new install on first launch.
  static const welcomeGrant = 500;

  /// Below this, the UI nudges the user to top up soon without blocking yet
  /// (Markus, 2026-07-10: warn under 200 WIUs).
  static const lowBalanceThreshold = 200;

  /// Current balance in WIUs. Listen to rebuild the status bar on change.
  final ValueNotifier<int> value = ValueNotifier<int>(0);

  /// True once the balance has run out — callers must block new AI requests
  /// and tell the user to top up (Markus, 2026-07-10).
  bool get isEmpty => value.value <= 0;

  /// True while there's still balance left but it's running low.
  bool get isLow => value.value > 0 && value.value < lowBalanceThreshold;

  bool _attached = false;
  int _lastSeenUsage = 0;
  // Carries fractional WIU cost (e.g. TTS billed by character) between calls
  // so small per-play costs accumulate correctly instead of rounding to 0.
  double _fractionalRemainder = 0.0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value.value = prefs.getInt(_key) ?? 0;
    _fractionalRemainder = (prefs.getInt(_remainderKey) ?? 0) / 1000.0;
    if (!_attached) {
      _lastSeenUsage = TokenUsage.instance.total.value;
      TokenUsage.instance.total.addListener(_onUsageChanged);
      _attached = true;
    }
  }

  /// Credits the one-time welcome grant on the very first launch of this
  /// install. Stored on-device only (no server), so a reinstall re-grants on
  /// Android; that is acceptable while there are no users. Safe to call every
  /// launch: it grants only once.
  Future<void> grantWelcomeIfFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomeKey) ?? false) return;
    value.value += welcomeGrant;
    await prefs.setBool(_welcomeKey, true);
    await prefs.setInt(_key, value.value);
  }

  /// Adds [amount] WIUs (e.g. after redeeming a code) and persists the total.
  Future<void> add(int amount) async {
    if (amount <= 0) return;
    value.value += amount;
    await _persist();
  }

  /// Subtracts the tokens consumed since the last check from the balance.
  void _onUsageChanged() {
    final total = TokenUsage.instance.total.value;
    final delta = total - _lastSeenUsage;
    _lastSeenUsage = total;
    if (delta <= 0) return; // ignore resets
    value.value = (value.value - delta).clamp(0, value.value);
    _persist();
  }

  /// Spends a fractional WIU cost that isn't a whole Gemini token count, e.g.
  /// TTS, which Google bills by character rather than by token (Markus,
  /// 2026-07-11: TTS wasn't being billed at all). Accumulates the fraction
  /// until a whole WIU is owed, then debits the visible integer balance, so
  /// small per-play costs aren't silently rounded away.
  Future<void> spendFractional(double wiuCost) async {
    if (wiuCost <= 0) return;
    _fractionalRemainder += wiuCost;
    final whole = _fractionalRemainder.floor();
    if (whole > 0) {
      _fractionalRemainder -= whole;
      value.value = (value.value - whole).clamp(0, value.value);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.value);
    await prefs.setInt(_remainderKey, (_fractionalRemainder * 1000).round());
  }
}
