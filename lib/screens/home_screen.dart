import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/groq_service.dart';
import '../services/fuv_service.dart';
import '../services/settings_service.dart';
import '../widgets/record_button.dart';
import '../widgets/result_card.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'translate_screen.dart';
import 'ai_screen.dart';

// ─────────────────────────────────────────────────────────────
//  ÉCRAN PRINCIPAL — CalvoNote
//  Enregistrement → Transcription → Traduction Fulfulde → Lecture
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = SettingsService();
  late GroqService  _groq;
  late FuvService   _fuv;
  final _audio      = AudioService();

  // État
  bool   _recording        = false;
  bool   _transcribing     = false;
  bool   _translating      = false;
  bool   _synthesizing     = false;
  bool   _playingFuv       = false;
  bool   _playingFr        = false;
  String _transcription    = '';
  String _fuvTranslation   = '';
  String _fuvAudioPath     = '';
  String _selectedLang     = 'fr';
  bool   _autoTranslateFuv = true;
  bool   _autoSpeakFuv     = false;
  String _status           = '';

  // Langues disponibles
  static const _langs = [
    ('fr', '🇫🇷 Français'),
    ('en', '🇬🇧 English'),
    ('fuv', '🌍 Fulfulde'),
  ];

  @override
  void initState() {
    super.initState();
    _groq = GroqService(apiKey: '');
    _fuv  = FuvService(hfToken: '');
    _init();
  }

  Future<void> _init() async {
    await _audio.init();
    final s = await _settings.loadAll();
    _groq.updateCredentials(s.groqKey, model: s.groqModel);
    _fuv.updateToken(s.hfToken);
    setState(() {
      _selectedLang     = s.defaultLanguage;
      _autoTranslateFuv = s.autoTranslateFuv;
      _autoSpeakFuv     = s.autoSpeakFuv;
    });
  }

  Future<void> _reloadSettings() async {
    final s = await _settings.loadAll();
    _groq.updateCredentials(s.groqKey, model: s.groqModel);
    _fuv.updateToken(s.hfToken);
    setState(() {
      _autoTranslateFuv = s.autoTranslateFuv;
      _autoSpeakFuv     = s.autoSpeakFuv;
    });
  }

  // ── Enregistrement ────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final ok = await _audio.startRecording();
    if (!ok) {
      _setStatus('❌ Permission micro refusée ou enregistrement impossible');
      return;
    }
    setState(() {
      _recording     = true;
      _transcription = '';
      _fuvTranslation = '';
      _fuvAudioPath  = '';
      _status        = '🎙️ Enregistrement en cours…';
    });
  }

  Future<void> _stopAndProcess() async {
    final path = await _audio.stopRecording();
    setState(() {
      _recording    = false;
      _transcribing = true;
      _status       = '⏳ Transcription en cours…';
    });

    if (path == null) {
      setState(() {
        _transcribing = false;
        _status = '❌ Fichier audio introuvable';
      });
      return;
    }

    // Transcription via Groq Whisper
    final result = await _groq.transcribe(
      path,
      language: _selectedLang == 'fuv' ? 'fr' : _selectedLang,
    );

    setState(() {
      _transcribing  = false;
      _transcription = result.success ? result.text : '';
      _status        = result.success
          ? '✓ Transcription terminée'
          : '❌ ${result.error}';
    });

    if (!result.success) return;

    // Traduction automatique vers Fulfulde si activée
    if (_autoTranslateFuv && _selectedLang == 'fr') {
      await _translateToFuv();
    }
  }

  // ── Traduction vers Fulfulde ──────────────────────────────────

  Future<void> _translateToFuv() async {
    if (_transcription.isEmpty) return;

    setState(() {
      _translating    = true;
      _fuvTranslation = '';
      _fuvAudioPath   = '';
      _status         = '⏳ Traduction Fulfulde en cours…';
    });

    final result = await _fuv.translate(_transcription, src: 'fr', tgt: 'fuv');

    setState(() {
      _translating    = false;
      _fuvTranslation = result.success ? result.text : '';
      _status         = result.success
          ? '✓ Traduction terminée'
          : '❌ ${result.error}';
    });

    if (result.success && _autoSpeakFuv) {
      await _speakFuv();
    }
  }

  // ── Lecture Fulfulde ──────────────────────────────────────────

  Future<void> _speakFuv() async {
    if (_fuvTranslation.isEmpty) return;

    // Utiliser le cache audio si disponible
    if (_fuvAudioPath.isNotEmpty) {
      setState(() { _playingFuv = true; });
      await _audio.playWav(
        _fuvAudioPath,
        onComplete: () => setState(() { _playingFuv = false; }),
      );
      return;
    }

    setState(() {
      _synthesizing = true;
      _status       = '⏳ Génération audio Fulfulde…';
    });

    final result = await _fuv.synthesize(_fuvTranslation);

    setState(() {
      _synthesizing = false;
    });

    if (!result.success) {
      _setStatus('❌ TTS Fulfulde : ${result.error}');
      return;
    }

    _fuvAudioPath = result.audioPath ?? '';
    setState(() { _playingFuv = true; _status = '🔊 Lecture Fulfulde…'; });

    await _audio.playWav(
      _fuvAudioPath,
      onComplete: () => setState(() { _playingFuv = false; _status = ''; }),
    );
  }

  Future<void> _stopFuv() async {
    await _audio.stopPlayback();
    setState(() { _playingFuv = false; });
  }

  // ── Lecture transcription (TTS natif) ────────────────────────

  Future<void> _speakTranscription() async {
    if (_transcription.isEmpty) return;
    setState(() { _playingFr = true; });
    final lang = _selectedLang == 'en' ? 'en-US' : 'fr-FR';
    await _audio.speak(
      _transcription,
      language: lang,
      onComplete: () => setState(() { _playingFr = false; }),
    );
    setState(() { _playingFr = false; });
  }

  Future<void> _stopFr() async {
    await _audio.stopTts();
    setState(() { _playingFr = false; });
  }

  // ── Utilitaires ───────────────────────────────────────────────

  void _setStatus(String msg) => setState(() => _status = msg);

  bool get _isBusy =>
      _transcribing || _translating || _synthesizing;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'Calvo',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
            TextSpan(
              text: 'Note',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w400,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Accès traduction manuelle
        IconButton(
          icon: const Icon(Icons.translate_rounded),
          tooltip: 'Traduction FR ↔ Fulfulde',
          color: AppColors.fuv,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TranslateScreen(fuvService: _fuv),
            ),
          ),
        ),
        // Accès IA
        IconButton(
          icon: const Icon(Icons.auto_awesome_rounded),
          tooltip: 'Outils IA',
          color: AppColors.accent,
          onPressed: _transcription.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiScreen(
                        groqService: _groq,
                        initialText: _transcription,
                      ),
                    ),
                  ),
        ),
        // Paramètres
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Paramètres',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
            await _reloadSettings();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildLangSelector(),
            const SizedBox(height: 20),
            _buildRecordSection(),
            const SizedBox(height: 20),
            if (_transcription.isNotEmpty || _transcribing)
              _buildTranscriptionCard(),
            if (_transcription.isNotEmpty || _transcribing)
              const SizedBox(height: 12),
            if (_selectedLang == 'fr')
              _buildFuvSection(),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildStatusBar(),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Sélecteur de langue ───────────────────────────────────────

  Widget _buildLangSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: _langs.map((lang) {
          final selected = _selectedLang == lang.$1;
          return Expanded(
            child: GestureDetector(
              onTap: _isBusy || _recording
                  ? null
                  : () => setState(() => _selectedLang = lang.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  lang.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section enregistrement ────────────────────────────────────

  Widget _buildRecordSection() {
    return Column(
      children: [
        RecordButton(
          isRecording: _recording,
          isLoading:   _isBusy,
          onTap:       _isBusy ? () {} : _toggleRecording,
        ),
        const SizedBox(height: 14),
        Text(
          _recording
              ? 'Appuie pour arrêter'
              : _isBusy
                  ? 'Traitement en cours…'
                  : 'Appuie pour parler',
          style: TextStyle(
            color: _recording ? AppColors.recording : AppColors.textMuted,
            fontSize: 13,
            fontWeight: _recording ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Carte transcription ───────────────────────────────────────

  Widget _buildTranscriptionCard() {
    return ResultCard(
      title:       'TRANSCRIPTION',
      text:        _transcribing ? '' : _transcription,
      isPlaying:   _playingFr,
      isLoading:   _transcribing || _playingFr && false,
      onSpeak:     _transcription.isEmpty ? null : _speakTranscription,
      onStop:      _stopFr,
      onClear:     () => setState(() {
        _transcription  = '';
        _fuvTranslation = '';
        _fuvAudioPath   = '';
      }),
      extraActions: _selectedLang == 'fr' && _transcription.isNotEmpty
          ? [
              _TranslateBtn(
                loading: _translating,
                onTap:   _translateToFuv,
              ),
            ]
          : null,
    );
  }

  // ── Section Fulfulde ──────────────────────────────────────────

  Widget _buildFuvSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle auto-traduction
        Row(
          children: [
            const Text(
              'Traduction automatique',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Spacer(),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value:         _autoTranslateFuv,
                activeColor:   AppColors.fuv,
                onChanged: (v) async {
                  setState(() => _autoTranslateFuv = v);
                  await _settings.setAutoTranslateFuv(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ResultCard(
          title:      'FULFULDE ADAMAWA',
          text:       _translating ? '' : _fuvTranslation,
          accentColor: AppColors.fuv,
          isFuv:      true,
          isPlaying:  _playingFuv,
          isLoading:  _translating || _synthesizing,
          onSpeak:    _fuvTranslation.isEmpty ? null : _speakFuv,
          onStop:     _stopFuv,
          onClear:    () => setState(() {
            _fuvTranslation = '';
            _fuvAudioPath   = '';
          }),
        ),
        const SizedBox(height: 8),
        // Toggle lecture auto
        Row(
          children: [
            const Text(
              'Lecture automatique après traduction',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Spacer(),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value:         _autoSpeakFuv,
                activeColor:   AppColors.fuv,
                onChanged: (v) async {
                  setState(() => _autoSpeakFuv = v);
                  await _settings.setAutoSpeakFuv(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Barre de statut ───────────────────────────────────────────

  Widget _buildStatusBar() {
    final isError = _status.startsWith('❌');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.error.withOpacity(0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? AppColors.error.withOpacity(0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Text(
        _status,
        style: TextStyle(
          fontSize: 12,
          color: isError ? AppColors.error : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Mini widget bouton Traduire ───────────────────────────────

class _TranslateBtn extends StatelessWidget {
  final bool         loading;
  final VoidCallback onTap;

  const _TranslateBtn({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Traduire en Fulfulde',
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.fuv,
                  ),
                )
              : const Icon(Icons.translate_rounded,
                  size: 18, color: AppColors.fuv),
        ),
      ),
    );
  }
}
