import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../studio/models/beat_pattern.dart';

/// An unsaved beat stashed on this device while the user signs in, so going to
/// the login page never throws their work away. Contains no personal data.
class PendingDraft {
  const PendingDraft({
    required this.pattern,
    required this.bpm,
    required this.title,
    required this.description,
    required this.genre,
    required this.allowRemix,
  });

  final BeatPattern pattern;
  final int bpm;
  final String title;
  final String description;
  final String genre;
  final bool allowRemix;

  Map<String, dynamic> toJson() => {
    'pattern': pattern.toJson(),
    'bpm': bpm,
    'title': title,
    'description': description,
    'genre': genre,
    'allowRemix': allowRemix,
  };

  factory PendingDraft.fromJson(Map<String, dynamic> json) => PendingDraft(
    pattern: BeatPattern.fromJson(json['pattern']),
    bpm: clampBpm(json['bpm'] as num),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    genre: json['genre'] as String? ?? 'hip-hop',
    allowRemix: json['allowRemix'] as bool? ?? false,
  );
}

class PendingDraftStore {
  const PendingDraftStore();

  static const _key = 'beatgrid.pending_draft.v1';

  Future<void> save(PendingDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  /// Returns the stashed draft, or null if none/unreadable (never throws).
  Future<PendingDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return PendingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('pending draft unreadable: $e');
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
