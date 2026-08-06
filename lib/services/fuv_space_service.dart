import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service de traduction FR ↔ Fulfulde Adamawa.
///
/// Reproduit fidèlement l'architecture du desktop `fuv_translator.py` :
///   1. HF Inference API (modèle `bonopassale/fr-fuv-translator-tardigrade`)
///   2. Fallback Gradio v4 (Space `bonopassale/fr-fuv-Tardigrade-Eon`,
///      endpoint `/gradio_api/call/predict` + polling SSE)
///
/// Pour la chaîne EN→FUV, l'app doit d'abord pivoter EN→FR via Groq
/// (voir `GroqService.translateEnToFr`), puis appeler `translateFrToFuv`.
class FuvSpaceService {
  FuvSpaceService._();
  static final FuvSpaceService instance = FuvSpaceService._();

  static const String _hfModelId = 'bonopassale/fr-fuv-translator-tardigrade';
  static const String _hfApiUrl =
      'https://api-inference.huggingface.co/models/$_hfModelId';
  static const String _gradioBase =
      'https://bonopassale-fr-fuv-tardigrade-eon.hf.space';

  // Codes NLLB
  static const String _langFr = 'fra_Latn';
  static const String _langFuv = 'fuv_Latn';

  static const int _maxRetries = 2;
  static const Duration _inferenceTimeout = Duration(seconds: 45);
  static const Duration _gradioPostTimeout = Duration(seconds: 30);
  static const Duration _gradioGetTimeout = Duration(seconds: 45);

  /// Traduit FR → FUV via le Space HF.
  /// [hfToken] est optionnel (améliore les quotas).
  Future<String> translateFrToFuv({
    required String text,
    required String hfToken,
  }) async {
    return _translate(text: text, src: 'fr', tgt: 'fuv', hfToken: hfToken);
  }

  /// Traduit FUV → FR via le Space HF.
  Future<String> translateFuvToFr({
    required String text,
    required String hfToken,
  }) async {
    return _translate(text: text, src: 'fuv', tgt: 'fr', hfToken: hfToken);
  }

  Future<String> _translate({
    required String text,
    required String src,
    required String tgt,
    required String hfToken,
  }) async {
    if (text.trim().isEmpty) {
      throw FuvException('Texte vide');
    }

    final srcLang = src == 'fr' ? _langFr : _langFuv;
    final tgtLang = tgt == 'fuv' ? _langFuv : _langFr;

    // 1) Essai HF Inference API (avec retries pour cold start)
    try {
      final result = await _tryInferenceApi(
        text: text,
        srcLang: srcLang,
        tgtLang: tgtLang,
        hfToken: hfToken,
      );
      return result;
    } catch (inferenceErr) {
      // 2) Fallback Gradio v4
      try {
        final result = await _tryGradio(
          text: text,
          src: src,
          tgt: tgt,
        );
        return result;
      } catch (gradioErr) {
        throw FuvException(
          'Les deux méthodes ont échoué.\n'
          '• HF Inference API : ${_safeStr(inferenceErr)}\n'
          '• Gradio Space     : ${_safeStr(gradioErr)}\n\n'
          'Conseils :\n'
          '  - Vérifiez votre connexion internet\n'
          '  - Assurez-vous que le modèle est PUBLIC sur HuggingFace\n'
          '  - Réessayez dans 30 secondes (cold start possible)',
        );
      }
    }
  }

  // ─── Méthode 1 : HF Inference API ──────────────────────────

  Future<String> _tryInferenceApi({
    required String text,
    required String srcLang,
    required String tgtLang,
    required String hfToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (hfToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $hfToken';
    }

    final body = jsonEncode({
      'inputs': text,
      'parameters': {
        'src_lang': srcLang,
        'tgt_lang': tgtLang,
        'max_length': 512,
      },
    });

    String? lastErr;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(Uri.parse(_hfApiUrl), headers: headers, body: body)
            .timeout(_inferenceTimeout);

        if (response.statusCode == 401) {
          String msg = 'Token HF invalide (HTTP 401)';
          if (hfToken.isEmpty) {
            msg +=
                '\n→ Le modèle est sûrement PRIVÉ. Rendez-le public sur HuggingFace.';
          }
          throw FuvException(msg);
        }
        if (response.statusCode == 503) {
          // Modèle en cold start, on attend et on réessaie
          if (attempt < _maxRetries) {
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          throw FuvException('Service HF temporairement indisponible (503)');
        }

        final decoded = jsonDecode(response.body);

        // Format succès : [{"translation_text": "..."}]
        if (decoded is List && decoded.isNotEmpty) {
          final result = decoded[0]['translation_text'];
          if (result is String && result.trim().isNotEmpty) {
            return result.trim();
          }
        }

        // Format erreur avec cold start
        if (decoded is Map) {
          final err = decoded['error'];
          if (err is String) {
            if (err.toLowerCase().contains('loading') ||
                err.toLowerCase().contains('currently loading')) {
              final estimated = decoded['estimated_time'];
              final waitSec = estimated is num
                  ? (estimated.toInt() + 3).clamp(1, 30)
                  : 20;
              if (attempt < _maxRetries) {
                await Future.delayed(Duration(seconds: waitSec));
                continue;
              }
              throw FuvException('Modèle en cours de chargement (~${waitSec}s)');
            }
            if (err.toLowerCase().contains('token') ||
                err.contains('401')) {
              String msg = 'Token HF requis ou invalide (HTTP 401)';
              if (hfToken.isEmpty) {
                msg +=
                    '\n→ Le modèle est sûrement PRIVÉ. Rendez-le public sur HuggingFace.';
              }
              throw FuvException(msg);
            }
            throw FuvException('Erreur API HF : ${err.substring(0, err.length.clamp(0, 100))}');
          }
        }

        lastErr = 'Réponse inattendue';
      } on TimeoutException {
        lastErr = 'Timeout HF Inference API';
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      } on http.ClientException catch (e) {
        lastErr = 'Connexion impossible : ${_safeStr(e)}';
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }
    }

    throw FuvException(lastErr ?? 'Échec HF Inference API après retries');
  }

  // ─── Méthode 2 : Fallback Gradio v4 (2 étapes) ────────────

  Future<String> _tryGradio({
    required String text,
    required String src,
    required String tgt,
  }) async {
    final direction = src == 'fr'
        ? 'Français → Fulfulde'
        : 'Fulfulde → Français';

    // Étape 1 : POST pour soumettre la requête
    final postUrl = '$_gradioBase/gradio_api/call/predict';
    final postResponse = await http
        .post(
          Uri.parse(postUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'data': [text, direction]}),
        )
        .timeout(_gradioPostTimeout);

    if (postResponse.statusCode != 200) {
      throw FuvException(
          'Gradio POST échoué (HTTP ${postResponse.statusCode})');
    }

    final postDecoded = jsonDecode(postResponse.body);
    if (postDecoded is! Map || postDecoded['event_id'] == null) {
      throw FuvException('Gradio : pas d\'event_id dans la réponse');
    }
    final eventId = postDecoded['event_id'] as String;

    // Étape 2 : GET pour récupérer le résultat (polling SSE)
    final getUrl = '$postUrl/$eventId';
    final getResponse = await http
        .get(
          Uri.parse(getUrl),
          headers: {'Accept': 'text/event-stream'},
        )
        .timeout(_gradioGetTimeout);

    if (getResponse.statusCode != 200) {
      throw FuvException(
          'Gradio GET échoué (HTTP ${getResponse.statusCode})');
    }

    final lines = getResponse.body
        .split('\n')
        .where((l) => l.startsWith('data:'))
        .toList();
    if (lines.isEmpty) {
      throw FuvException('Gradio : réponse SSE vide');
    }

    final jsonPart = lines.last.replaceFirst('data:', '').trim();
    final parsed = jsonDecode(jsonPart);
    String result;
    if (parsed is List) {
      result = parsed.isNotEmpty ? (parsed[0]?.toString() ?? '') : '';
    } else {
      result = parsed.toString();
    }
    result = result.trim();
    if (result.isEmpty) {
      throw FuvException('Gradio : résultat vide');
    }
    return result;
  }

  String _safeStr(Object e) {
    final s = e.toString();
    final buf = StringBuffer();
    for (final c in s.runes.take(200)) {
      buf.write(c < 128 ? String.fromCharCode(c) : '?');
    }
    return buf.toString();
  }
}

class FuvException implements Exception {
  final String message;
  FuvException(this.message);
  @override
  String toString() => message;
}
