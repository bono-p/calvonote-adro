import 'package:flutter/material.dart';
import '../services/fuv_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  ÉCRAN TRADUCTION MANUELLE FR ↔ Fulfulde
//  Reproduit le panneau fuv_window.py du desktop
// ─────────────────────────────────────────────────────────────

class TranslateScreen extends StatefulWidget {
  final FuvService fuvService;
  const TranslateScreen({super.key, required this.fuvService});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _srcCtrl   = TextEditingController();
  final _audio     = AudioService();

  bool   _frToFuv     = true;
  bool   _translating = false;
  bool   _synthesizing = false;
  bool   _playing     = false;
  String _result      = '';
  String _audioPath   = '';
  String _status      = '';

  @override
  void initState() {
    super.initState();
    _audio.init();
  }

  @override
  void dispose() {
    _srcCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _srcCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _translating = true;
      _result      = '';
      _audioPath   = '';
      _status      = '⏳ Traduction en cours…';
    });

    final r = await widget.fuvService.translate(
      text,
      src: _frToFuv ? 'fr'  : 'fuv',
      tgt: _frToFuv ? 'fuv' : 'fr',
    );

    setState(() {
      _translating = false;
      _result      = r.success ? r.text : '';
      _status      = r.success ? '✓ Traduction terminée' : '❌ ${r.error}';
    });
  }

  Future<void> _speakResult() async {
    if (_result.isEmpty) return;

    if (_audioPath.isNotEmpty && _frToFuv) {
      setState(() { _playing = true; });
      await _audio.playWav(
        _audioPath,
        onComplete: () => setState(() { _playing = false; }),
      );
      return;
    }

    if (_frToFuv) {
      setState(() { _synthesizing = true; _status = '⏳ Génération audio…'; });
      final r = await widget.fuvService.synthesize(_result);
      setState(() { _synthesizing = false; });

      if (!r.success) {
        setState(() { _status = '❌ ${r.error}'; });
        return;
      }
      _audioPath = r.audioPath ?? '';
      setState(() { _playing = true; _status = '🔊 Lecture…'; });
      await _audio.playWav(
        _audioPath,
        onComplete: () => setState(() { _playing = false; _status = ''; }),
      );
    } else {
      setState(() { _playing = true; });
      await _audio.speak(
        _result,
        language: 'fr-FR',
        onComplete: () => setState(() { _playing = false; }),
      );
      setState(() { _playing = false; });
    }
  }

  void _swap() {
    final srcText = _srcCtrl.text;
    setState(() {
      _frToFuv  = !_frToFuv;
      _srcCtrl.text = _result;
      _result   = srcText;
      _audioPath = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Traduction FR ↔ Fulfulde'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Barre direction
              _buildDirectionBar(),
              const SizedBox(height: 16),
              // Zone source
              _buildSourceField(),
              const SizedBox(height: 12),
              // Bouton traduire
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _translating ? null : _translate,
                  icon: _translating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.translate_rounded, size: 18),
                  label: Text(_translating ? 'Traduction…' : 'Traduire'),
                ),
              ),
              const SizedBox(height: 16),
              // Zone résultat
              if (_result.isNotEmpty) _buildResultField(),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: 12,
                    color: _status.startsWith('❌')
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Text(
            _frToFuv ? '🇫🇷 Français' : '🌍 Fulfulde',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            color: AppColors.textMuted,
            onPressed: _swap,
            tooltip: 'Inverser',
          ),
          const Spacer(),
          Text(
            _frToFuv ? '🌍 Fulfulde' : '🇫🇷 Français',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.fuv,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller:   _srcCtrl,
        maxLines:     5,
        minLines:     3,
        style: const TextStyle(color: AppColors.text, fontSize: 15),
        decoration: InputDecoration(
          hintText:   _frToFuv
              ? 'Saisir le texte en français…'
              : 'Saisir le texte en Fulfulde…',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          border:     InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          suffixIcon: _srcCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18,
                      color: AppColors.textMuted),
                  onPressed: () {
                    _srcCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildResultField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fuvDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fuv.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _frToFuv ? 'FULFULDE' : 'FRANÇAIS',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.fuv, letterSpacing: 1,
                ),
              ),
              const Spacer(),
              // Lecture
              if (_frToFuv)
                _synthesizing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.fuv,
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _playing
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_rounded,
                          size: 20,
                          color: _playing ? AppColors.recording : AppColors.fuv,
                        ),
                        onPressed: _playing
                            ? () async {
                                await _audio.stopPlayback();
                                setState(() { _playing = false; });
                              }
                            : _speakResult,
                        tooltip: _playing ? 'Arrêter' : 'Lire en Fulfulde',
                      ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            _result,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textFuv,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
