import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One saved Tutor (light-bulb) query: the Hungarian sentence the user asked
/// about and the explanation JSON returned for it.
class LearningEntry {
  final String id;
  final String sentence;
  final String explanation; // raw JSON string from the Tutor
  final DateTime createdAt;

  LearningEntry({
    required this.id,
    required this.sentence,
    required this.explanation,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sentence': sentence,
    'explanation': explanation,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LearningEntry.fromJson(Map<String, dynamic> j) => LearningEntry(
    id: j['id'] as String,
    sentence: j['sentence'] as String? ?? '',
    explanation: j['explanation'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Persistent history of Tutor queries, backing the Learning page. Stored in
/// shared_preferences as a JSON list (newest first), so no database migration
/// is needed.
class LearningStore {
  static const _key = 'learning_entries';
  static const _maxEntries = 200;

  static Future<List<LearningEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LearningEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a query to the front. Skips empty sentences and collapses a repeat of
  /// the same sentence to a single (most recent) entry.
  static Future<void> add({
    required String sentence,
    required String explanation,
  }) async {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty) return;

    final entries = await getAll();
    entries.removeWhere((e) => e.sentence.trim() == trimmed);
    entries.insert(
      0,
      LearningEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sentence: trimmed,
        explanation: explanation,
        createdAt: DateTime.now(),
      ),
    );
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _save(entries);
  }

  static Future<void> delete(String id) async {
    final entries = await getAll();
    entries.removeWhere((e) => e.id == id);
    await _save(entries);
  }

  static Future<void> _save(List<LearningEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
