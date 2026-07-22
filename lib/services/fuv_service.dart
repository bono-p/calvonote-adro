import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────
//  SERVICE FULFULDE
//  - Traduction FR ↔ Fulfulde via HuggingFace NLLB (online)
//  - TTS Fulfulde via facebook/mms-tts-ful HF Inference (online Phase 1)
// ─────────────────────────────────────────────────────────────

const _hfBase       = 'https://api-inference.huggingface.co/models';
const _nllbModel    = 'bonopassale/nllb-fra-fuv-finetuned';
const _ttsModel     = 'facebook/mms-tts-ful';
const _gradioSpace  = 'bonopassale-fr-fulfulde-translator';
const _gradioBase   = 'https://$_gradioSpace.hf.space';

const _langFr       = 'fra_Latn';
const _langFuv      = 'fuv_Latn';
const _timeoutSec   = 50;
const _maxRetries   = 2;

class FuvResult {
  final bool    success;
  final String  text;
  final String? audioPath; // pour le TTS
  final String? error;
  const FuvResult({
    required this.success,
    required this.text,
    this.audioPath,
    this.error,
  });
}

class FuvService {
  String _hfToken;

  FuvService({required String hfToken}) : _hfToken = hfToken;

  void updateToken(String token) => _hfToken = token.trim();
  bool get hasToken => _hfToken.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_hfToken.isNotEmpty) 'Authorization': 'Bearer $_hfToken',
  };

  // ── Traduction FR → Fulfulde (ou inverse) ────────────────────

  Future<FuvResult> translate(
    String text, {
    String src = 'fr',
    String tgt = 'fuv',
  }) async {
    if (text.trim().isEmpty) {
      return const FuvResult(success: false, text: '', error: 'Texte vide');
    }

    final srcLang = src == 'fr' ? _langFr : _langFuv;
    final tgtLang = tgt == 'fuv' ? _langFuv : _langFr;

    // Tentative 1 — HF Inference API
    final r1 = await _tryInferenceApi(text, srcLang, tgtLang);
    if (r1.success) return r1;

    // Tentative 2 — Gradio Space fallback
    final r2 = await _tryGradio(text, src, tgt);
    if (r2.success) return r2;

    return FuvResult(
      success: false,
      text: '',
      error: 'HF API: ${r1.error}\nGradio: ${r2.error}',
    );
  }

  Future<FuvResult> _tryInferenceApi(
    String text,
    String srcLang,
    String tgtLang,
  ) async {
    final url     = Uri.parse('$_hfBase/$_nllbModel');
    final payload = jsonEncode({
      'inputs': text,
      'parameters': {
        'src_lang': srcLang,
        'tgt_lang': tgtLang,
        'max_length': 512,
      },
    });

    String lastErr = 'Erreur inconnue';

    for (int attempt = 1; attempt <= _maxRetries + 1; attempt++) {
      try {
        final response = await http
            .post(url, headers: _headers, body: payload)
            .timeout(Duration(seconds: _timeoutSec));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            final result = (data[0]['translation_text'] as String? ?? '').trim();
            if (result.isNotEmpty) return FuvResult(success: true, text: result);
          }
          return const FuvResult(success: false, text: '', error: 'Réponse vide');
        }

        if (response.statusCode == 503) {
          // Modèle en cours de chargement
          try {
            final err   = jsonDecode(response.body) as Map<String, dynamic>;
            final wait  = (err['estimated_time'] as num?)?.toInt() ?? 20;
            if (attempt <= _maxRetries) {
              await Future.delayed(Duration(seconds: wait.clamp(5, 30)));
              continue;
            }
            return FuvResult(
              success: false, text: '',
              error: 'Modèle en chargement (~${wait}s), réessaie',
            );
          } catch (_) {
            lastErr = 'Service indisponible (503)';
          }
        }

        if (response.statusCode == 401) {
          return const FuvResult(
            success: false, text: '', error: 'Token HF invalide (401)',
          );
        }

        lastErr = 'HTTP ${response.statusCode}';

      } on SocketException {
        return const FuvResult(
          success: false, text: '', error: 'Pas de connexion internet',
        );
      } catch (e) {
        lastErr = e.toString();
        if (attempt <= _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    return FuvResult(success: false, text: '', error: lastErr);
  }

  Future<FuvResult> _tryGradio(String text, String src, String tgt) async {
    final direction =
        src == 'fr' ? 'Français → Fulfulde' : 'Fulfulde → Français';

    // Étape 1 — POST
    try {
      final postUrl = Uri.parse('$_gradioBase/gradio_api/call/translate');
      final postResp = await http
          .post(
            postUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': [text, direction]}),
          )
          .timeout(const Duration(seconds: 30));

      final postData = jsonDecode(postResp.body) as Map<String, dynamic>;
      final eventId  = postData['event_id'] as String? ?? '';
      if (eventId.isEmpty) {
        return const FuvResult(
          success: false, text: '', error: 'Gradio: pas d\'event_id',
        );
      }

      // Étape 2 — GET résultat SSE
      final getUrl  = Uri.parse('$_gradioBase/gradio_api/call/translate/$eventId');
      final getResp = await http
          .get(getUrl, headers: {'Accept': 'text/event-stream'})
          .timeout(Duration(seconds: _timeoutSec));

      final lines = getResp.body
          .split('\n')
          .where((l) => l.startsWith('data:'))
          .toList();

      if (lines.isEmpty) {
        return const FuvResult(
          success: false, text: '', error: 'Gradio: réponse SSE vide',
        );
      }

      final parsed = jsonDecode(lines.last.replaceFirst('data:', '').trim());
      final result = (parsed is List ? parsed[0] : parsed.toString()).trim();

      return result.isNotEmpty
          ? FuvResult(success: true, text: result)
          : const FuvResult(success: false, text: '', error: 'Gradio: résultat vide');

    } on SocketException {
      return const FuvResult(
        success: false, text: '', error: 'Pas de connexion internet',
      );
    } catch (e) {
      return FuvResult(success: false, text: '', error: 'Gradio: ${e.toString()}');
    }
  }

  // ── TTS Fulfulde — HF Inference API (Phase 1 online) ─────────

  Future<FuvResult> synthesize(String text) async {
    if (text.trim().isEmpty) {
      return const FuvResult(success: false, text: '', error: 'Texte vide');
    }

    final url     = Uri.parse('$_hfBase/$_ttsModel');
    final payload = jsonEncode({'inputs': text});

    try {
      final response = await http
          .post(url, headers: _headers, body: payload)
          .timeout(Duration(seconds: _timeoutSec));

      if (response.statusCode == 200) {
        // La réponse est un fichier WAV binaire
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          return const FuvResult(
            success: false, text: '', error: 'TTS: réponse audio vide',
          );
        }
        final path = await _saveTempWav(bytes);
        return FuvResult(success: true, text: text, audioPath: path);
      }

      if (response.statusCode == 503) {
        // Cold start — réessayer après attente
        try {
          final err  = jsonDecode(response.body) as Map<String, dynamic>;
          final wait = (err['estimated_time'] as num?)?.toInt() ?? 20;
          await Future.delayed(Duration(seconds: wait.clamp(5, 30)));

          final retry = await http
              .post(url, headers: _headers, body: payload)
              .timeout(Duration(seconds: _timeoutSec));

          if (retry.statusCode == 200 && retry.bodyBytes.isNotEmpty) {
            final path = await _saveTempWav(retry.bodyBytes);
            return FuvResult(success: true, text: text, audioPath: path);
          }
        } catch (_) {}
        return const FuvResult(
          success: false, text: '', error: 'TTS Fulfulde: modèle en chargement',
        );
      }

      if (response.statusCode == 401) {
        return const FuvResult(
          success: false, text: '', error: 'Token HF requis pour TTS (401)',
        );
      }

      return FuvResult(
        success: false, text: '',
        error: 'TTS HTTP ${response.statusCode}',
      );

    } on SocketException {
      return const FuvResult(
        success: false, text: '', error: 'Pas de connexion internet',
      );
    } catch (e) {
      return FuvResult(success: false, text: '', error: 'TTS: ${e.toString()}');
    }
  }

  // ── Sauvegarde WAV temporaire ─────────────────────────────────

  Future<String> _saveTempWav(Uint8List bytes) async {
    final dir  = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/fuv_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
