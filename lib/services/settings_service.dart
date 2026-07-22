import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────
//  SERVICE PARAMÈTRES
//  Stockage sécurisé des clés API via flutter_secure_storage
//  (Android Keystore / iOS Keychain)
// ─────────────────────────────────────────────────────────────

class SettingsService {
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Clés de stockage
  static const _kGroqKey      = 'groq_api_key';
  static const _kHfToken      = 'hf_token';
  static const _kGroqModel    = 'groq_model';
  static const _kDefaultLang  = 'default_language';
  static const _kAutoTranslate = 'auto_translate_fuv';
  static const _kAutoSpeak    = 'auto_speak_fuv';

  // ── Groq ─────────────────────────────────────────────────────

  Future<String> getGroqKey()      async =>
      await _store.read(key: _kGroqKey) ?? '';

  Future<void> setGroqKey(String v) async =>
      _store.write(key: _kGroqKey, value: v.trim());

  Future<String> getGroqModel()    async =>
      await _store.read(key: _kGroqModel) ?? 'llama-3.3-70b-versatile';

  Future<void> setGroqModel(String v) async =>
      _store.write(key: _kGroqModel, value: v);

  // ── HuggingFace ───────────────────────────────────────────────

  Future<String> getHfToken()      async =>
      await _store.read(key: _kHfToken) ?? '';

  Future<void> setHfToken(String v) async =>
      _store.write(key: _kHfToken, value: v.trim());

  // ── Préférences ───────────────────────────────────────────────

  Future<String> getDefaultLanguage() async =>
      await _store.read(key: _kDefaultLang) ?? 'fr';

  Future<void> setDefaultLanguage(String v) async =>
      _store.write(key: _kDefaultLang, value: v);

  Future<bool> getAutoTranslateFuv() async =>
      (await _store.read(key: _kAutoTranslate)) == 'true';

  Future<void> setAutoTranslateFuv(bool v) async =>
      _store.write(key: _kAutoTranslate, value: v.toString());

  Future<bool> getAutoSpeakFuv() async =>
      (await _store.read(key: _kAutoSpeak)) == 'true';

  Future<void> setAutoSpeakFuv(bool v) async =>
      _store.write(key: _kAutoSpeak, value: v.toString());

  // ── Chargement global ─────────────────────────────────────────

  Future<AppSettings> loadAll() async {
    return AppSettings(
      groqKey:          await getGroqKey(),
      groqModel:        await getGroqModel(),
      hfToken:          await getHfToken(),
      defaultLanguage:  await getDefaultLanguage(),
      autoTranslateFuv: await getAutoTranslateFuv(),
      autoSpeakFuv:     await getAutoSpeakFuv(),
    );
  }
}

class AppSettings {
  final String groqKey;
  final String groqModel;
  final String hfToken;
  final String defaultLanguage;
  final bool   autoTranslateFuv;
  final bool   autoSpeakFuv;

  const AppSettings({
    required this.groqKey,
    required this.groqModel,
    required this.hfToken,
    required this.defaultLanguage,
    required this.autoTranslateFuv,
    required this.autoSpeakFuv,
  });

  bool get isGroqConfigured => groqKey.isNotEmpty;
  bool get isHfConfigured   => hfToken.isNotEmpty;
}
