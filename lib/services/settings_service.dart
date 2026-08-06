import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de stockage local pour :
/// - clé API Groq
/// - historique des transcriptions
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kGroqApiKey = 'groq_api_key';
  static const _kHistory = 'transcription_history';
  static const _kDefaultLang = 'default_language';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Groq API Key ──────────────────────────────────────────
  String get groqApiKey => _prefs.getString(_kGroqApiKey) ?? '';
  Future<void> setGroqApiKey(String key) =>
      _prefs.setString(_kGroqApiKey, key);

  // ─── Langue par défaut ─────────────────────────────────────
  String get defaultLanguage => _prefs.getString(_kDefaultLang) ?? 'fr';
  Future<void> setDefaultLanguage(String lang) =>
      _prefs.setString(_kDefaultLang, lang);

  // ─── Historique (stocké en JSON) ───────────────────────────
  List<Map<String, dynamic>> get history {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addHistory(Map<String, dynamic> entry) async {
    final list = history;
    list.insert(0, entry);
    await _prefs.setString(_kHistory, jsonEncode(list));
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_kHistory);
  }

  Future<void> deleteHistoryEntry(String id) async {
    final list = history.where((e) => e['id'] != id).toList();
    await _prefs.setString(_kHistory, jsonEncode(list));
  }
}
