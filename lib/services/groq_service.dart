import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service d'intégration avec l'API Groq.
/// 1) transcription via Whisper Large v3 Turbo
/// 2) pivot EN→FR via Llama 3.3 70B (utilisé pour EN→FUV via le Space HF)
class GroqService {
  GroqService._();
  static final GroqService instance = GroqService._();

  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  // whisper-large-v3-turbo : rapide + précis (recommandé par le desktop)
  static const String _sttModel = 'whisper-large-v3-turbo';
  static const String _llmModel = 'llama-3.3-70b-versatile';

  /// Transcrit un fichier audio en texte.
  /// [audioPath] : chemin local du fichier .m4a
  /// [language]  : 'fr' ou 'en' (code ISO 639-1)
  /// [apiKey]    : clé API Groq
  ///
  /// Retourne le texte transcrit. Lève [GroqException] en cas d'erreur.
  Future<String> transcribe({
    required String audioPath,
    required String language,
    required String apiKey,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw GroqException('Fichier audio introuvable : $audioPath');
    }

    final uri = Uri.parse('$_baseUrl/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = _sttModel
      ..fields['language'] = language
      ..fields['response_format'] = 'json'
      ..files.add(await http.MultipartFile.fromPath('file', audioPath,
          filename: audioPath.split('/').last));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () =>
          throw GroqException('Timeout : la transcription a pris trop de temps'),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401) {
      throw GroqException(
          'Clé API Groq invalide (401). Vérifiez Paramètres → Clé API Groq.');
    }
    if (response.statusCode == 429) {
      throw GroqException(
          'Quota Groq temporairement dépassé (429). Réessayez dans quelques minutes.');
    }
    if (response.statusCode != 200) {
      throw GroqException(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['text'] == null) {
      throw GroqException('Réponse Whisper inattendue : ${response.body}');
    }
    return (decoded['text'] as String).trim();
  }

  /// Pivot EN→FR via Groq LLM (llama-3.3-70b-versatile).
  /// Utilisé pour la chaîne EN→FR→FUV (FR traduit en FUV via le Space HF).
  ///
  /// Retourne le texte français. Lève [GroqException] en cas d'erreur.
  Future<String> translateEnToFr({
    required String text,
    required String apiKey,
  }) async {
    if (text.trim().isEmpty) return '';

    final systemPrompt = '''
Tu es un traducteur professionnel anglais → français.
Tu reçois un texte en anglais et tu dois le traduire en français standard, fidèlement et naturellement.
- Ne renvoie QUE la traduction, sans commentaire, sans note, sans texte source.
- Ne mets pas la traduction entre guillemets.
- Conserve la ponctuation de fin de phrase.
''';

    final userPrompt =
        "Traduis le texte suivant de l'anglais vers le français :\n\n\"\"\"\n$text\n\"\"\"";

    final uri = Uri.parse('$_baseUrl/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _llmModel,
        'temperature': 0.2,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      }),
    ).timeout(
      const Duration(seconds: 90),
      onTimeout: () =>
          throw GroqException('Timeout : la traduction a pris trop de temps'),
    );

    if (response.statusCode == 401) {
      throw GroqException(
          'Clé API Groq invalide (401). Vérifiez Paramètres → Clé API Groq.');
    }
    if (response.statusCode != 200) {
      throw GroqException(_extractError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw GroqException('Réponse LLM inattendue : ${response.body}');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw GroqException('Aucun choix renvoyé par le LLM');
    }
    final content = choices[0]['message']?['content'];
    if (content == null) {
      throw GroqException('Contenu vide renvoyé par le LLM');
    }
    return (content as String).trim();
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final msg = decoded['error']['message'];
        if (msg is String && msg.isNotEmpty) {
          return 'Erreur Groq ($statusCode) : $msg';
        }
      }
    } catch (_) {
      // ignore
    }
    return 'Erreur Groq ($statusCode) : ${body.isEmpty ? "réponse vide" : body}';
  }
}

class GroqException implements Exception {
  final String message;
  GroqException(this.message);
  @override
  String toString() => message;
}
