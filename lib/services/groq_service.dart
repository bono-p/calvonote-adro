import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────
//  SERVICE GROQ
//  - Transcription audio via Whisper large-v3-turbo
//  - Actions IA : correction, résumé, reformulation, points clés,
//    titres, traduction FR↔EN, chat
// ─────────────────────────────────────────────────────────────

const _groqBase        = 'https://api.groq.com/openai/v1';
const _whisperModel    = 'whisper-large-v3-turbo';
const _defaultLLM      = 'llama-3.3-70b-versatile';
const _timeoutSeconds  = 60;

// ── Prompts système ───────────────────────────────────────────

const _transcriptionCtx = '''
IMPORTANT : Le texte reçu est le résultat brut d'une transcription vocale (ASR).
Il peut contenir des fautes phonétiques, des mots approximatifs, une ponctuation
absente ou mal placée, des répétitions involontaires.
''';

final Map<String, String> _systemPrompts = {
  'correct': '''
Tu es un correcteur expert de textes transcrits automatiquement (ASR).
$_transcriptionCtx
Ta tâche :
1. Corriger toutes les fautes d'orthographe, grammaire et conjugaison.
2. Rétablir une ponctuation correcte (virgules, points, apostrophes, majuscules).
3. Corriger les confusions homophones (a/à, ou/où, ce/se, son/sont, etc.).
4. Remplacer les mots incohérents par le terme probable dans le contexte.
5. Ne pas reformuler, résumer, ni ajouter de contenu absent.
6. Conserver le style et le registre de l'auteur.
Réponds UNIQUEMENT avec le texte corrigé, sans commentaire ni balise.
''',
  'summarize': '''
Tu es un assistant expert en synthèse de textes francophones.
$_transcriptionCtx
Génère un résumé clair et fidèle en 3 à 5 phrases.
Réponds uniquement avec le résumé, sans introduction ni conclusion.
''',
  'rephrase': '''
Tu es un rédacteur professionnel francophone.
$_transcriptionCtx
Reformule le texte avec un style fluide, naturel et bien structuré.
Conserve scrupuleusement le sens et toutes les informations.
Réponds uniquement avec le texte reformulé.
''',
  'keypoints': '''
Tu es un assistant d'analyse de texte.
$_transcriptionCtx
Extrais les points clés sous forme de liste à puces (•), une idée par ligne.
Réponds uniquement avec la liste.
''',
  'title': '''
Tu es un rédacteur créatif.
$_transcriptionCtx
Génère 3 titres accrocheurs numérotés (1. 2. 3.).
Réponds uniquement avec les 3 titres.
''',
  'translate_fr_en': '''
Tu es un traducteur professionnel français-anglais.
$_transcriptionCtx
Traduis en anglais de manière naturelle et précise.
Réponds uniquement avec la traduction.
''',
  'translate_en_fr': '''
Tu es un traducteur professionnel anglais-français.
Traduis en français de manière naturelle et précise.
Réponds uniquement avec la traduction.
''',
  'chat': '''
Tu es un assistant intelligent intégré dans CalvoNote, logiciel de transcription vocale.
Tu aides l'utilisateur à travailler sur ses textes transcrits.
Note que les textes peuvent contenir des imperfections ASR.
Tu réponds en français par défaut.
Sois concis, utile et direct.
''',
};

// ── Modèle résultat ───────────────────────────────────────────

class GroqResult {
  final bool   success;
  final String text;
  final String? error;
  const GroqResult({required this.success, required this.text, this.error});
}

// ── Classe principale ─────────────────────────────────────────

class GroqService {
  String _apiKey;
  String _model;
  final List<Map<String, String>> _chatHistory = [];

  GroqService({required String apiKey, String model = _defaultLLM})
      : _apiKey = apiKey,
        _model  = model;

  void updateCredentials(String apiKey, {String? model}) {
    _apiKey = apiKey;
    if (model != null) _model = model;
  }

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  // ── Transcription audio (Whisper) ─────────────────────────────

  Future<GroqResult> transcribe(
    String audioPath, {
    String language = 'fr',
  }) async {
    if (!isConfigured) {
      return const GroqResult(success: false, text: '', error: 'Clé API Groq manquante');
    }

    try {
      final file    = File(audioPath);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_groqBase/audio/transcriptions'),
      );
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['model']          = _whisperModel;
      request.fields['language']       = language;
      request.fields['response_format'] = 'json';

      final streamed  = await request.send().timeout(
        Duration(seconds: _timeoutSeconds),
      );
      final response  = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['text'] as String? ?? '').trim();
        return GroqResult(success: text.isNotEmpty, text: text);
      }

      final err = _parseError(response.body);
      return const GroqResult(success: false, text: '', error: 'Groq Whisper : $err');

    } on SocketException {
      return const GroqResult(
        success: false, text: '',
        error: 'Pas de connexion internet',
      );
    } catch (e) {
      return const GroqResult(success: false, text: '', error: e.toString());
    }
  }

  // ── Action IA sur texte ───────────────────────────────────────

  Future<GroqResult> runAction(String actionKey, String text) async {
    if (!isConfigured) {
      return const GroqResult(success: false, text: '', error: 'Clé API Groq manquante');
    }

    final systemPrompt = _systemPrompts[actionKey] ?? _systemPrompts['chat']!;

    try {
      final response = await http.post(
        Uri.parse('$_groqBase/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system',  'content': systemPrompt},
            {'role': 'user',    'content': text},
          ],
          'max_tokens': 4096,
          'temperature': 0.3,
        }),
      ).timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['choices'][0]['message']['content'] as String;
        return GroqResult(success: true, text: result.trim());
      }

      final err = _parseError(response.body);
      return const GroqResult(success: false, text: '', error: 'Groq LLM : $err');

    } on SocketException {
      return const GroqResult(
        success: false, text: '',
        error: 'Pas de connexion internet',
      );
    } catch (e) {
      return const GroqResult(success: false, text: '', error: e.toString());
    }
  }

  // ── Chat avec historique ──────────────────────────────────────

  Future<GroqResult> chat(String message, {String editorContext = ''}) async {
    if (!isConfigured) {
      return const GroqResult(success: false, text: '', error: 'Clé API Groq manquante');
    }

    String fullMessage = message;
    if (editorContext.trim().isNotEmpty) {
      final ctx = editorContext.length > 3000
          ? editorContext.substring(0, 3000)
          : editorContext;
      fullMessage =
          '[Texte dans l\'éditeur CalvoNote]\n---\n$ctx\n---\n\n$message';
    }

    _chatHistory.add({'role': 'user', 'content': fullMessage});

    final history = _chatHistory.length > 20
        ? _chatHistory.sublist(_chatHistory.length - 20)
        : List<Map<String, String>>.from(_chatHistory);

    try {
      final response = await http.post(
        Uri.parse('$_groqBase/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': _systemPrompts['chat']!},
            ...history,
          ],
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      ).timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['choices'][0]['message']['content'] as String;
        _chatHistory.add({'role': 'assistant', 'content': result.trim()});
        return GroqResult(success: true, text: result.trim());
      }

      if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') {
        _chatHistory.removeLast();
      }
      final err = _parseError(response.body);
      return const GroqResult(success: false, text: '', error: 'Chat : $err');

    } on SocketException {
      if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') {
        _chatHistory.removeLast();
      }
      return const GroqResult(
        success: false, text: '',
        error: 'Pas de connexion internet',
      );
    } catch (e) {
      if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'user') {
        _chatHistory.removeLast();
      }
      return const GroqResult(success: false, text: '', error: e.toString());
    }
  }

  void clearChatHistory() => _chatHistory.clear();

  // ── Utilitaire ────────────────────────────────────────────────

  String _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['error']?['message'] as String? ?? body).substring(
        0,
        (data['error']?['message'] as String? ?? body).length.clamp(0, 150),
      );
    } catch (_) {
      return body.length > 150 ? '${body.substring(0, 150)}…' : body;
    }
  }
}

// ── Labels actions IA ─────────────────────────────────────────

class AIAction {
  final String key;
  final String label;
  final String icon;

  const AIAction({required this.key, required this.label, required this.icon});
}

const kAIActions = [
  AIAction(key: 'correct',        label: 'Corriger',    icon: '✏️'),
  AIAction(key: 'summarize',      label: 'Résumer',     icon: '📝'),
  AIAction(key: 'rephrase',       label: 'Reformuler',  icon: '🔄'),
  AIAction(key: 'keypoints',      label: 'Points clés', icon: '🔑'),
  AIAction(key: 'title',          label: 'Titres',      icon: '🏷️'),
  AIAction(key: 'translate_fr_en',label: 'FR → EN',     icon: '🌐'),
  AIAction(key: 'translate_en_fr',label: 'EN → FR',     icon: '🌐'),
];
