import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_usage.dart';

/// The user's prepaid credit, measured in WIUs (wir-in-ungarn units). Redeeming
/// a prepaid code adds its value here; every AI request spends WIUs equal to the
/// tokens it consumed (1 WIU = 1 token, and 10,000 WIUs cost about $25). The
/// "Current Status" bar in Profile settings reads this. Persisted so the balance
/// survives app restarts.
class TokenBalance {
  TokenBalance._();
  static final TokenBalance instance = TokenBalance._();

  static const _key = 'token_balance_wiu';
  static const _welcomeKey = 'welcome_granted';

  /// One-time WIUs credited to every new install on first launch.
  static const welcomeGrant = 500;

  /// Current balance in WIUs. Listen to rebuild the status bar on change.
  final ValueNotifier<int> value = ValueNotifier<int>(0);

  bool _attached = false;
  int _lastSeenUsage = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value.value = prefs.getInt(_key) ?? 0;
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.value);
  }
}
