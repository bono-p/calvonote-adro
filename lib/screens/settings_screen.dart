import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  ÉCRAN PARAMÈTRES
//  Clés API Groq + HuggingFace, modèle LLM, préférences
// ─────────────────────────────────────────────────────────────

const _groqModels = [
  'llama-3.3-70b-versatile',
  'llama-3.1-8b-instant',
  'llama3-70b-8192',
  'llama3-8b-8192',
  'mixtral-8x7b-32768',
  'gemma2-9b-it',
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings   = SettingsService();
  final _groqCtrl   = TextEditingController();
  final _hfCtrl     = TextEditingController();

  String _selectedModel = _groqModels.first;
  String _defaultLang   = 'fr';
  bool   _autoTranslate = true;
  bool   _autoSpeak     = false;
  bool   _testing       = false;
  String _testResult    = '';
  bool   _saving        = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _groqCtrl.dispose();
    _hfCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _settings.loadAll();
    setState(() {
      _groqCtrl.text  = s.groqKey;
      _hfCtrl.text    = s.hfToken;
      _selectedModel  = s.groqModel;
      _defaultLang    = s.defaultLanguage;
      _autoTranslate  = s.autoTranslateFuv;
      _autoSpeak      = s.autoSpeakFuv;
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; });
    await _settings.setGroqKey(_groqCtrl.text.trim());
    await _settings.setHfToken(_hfCtrl.text.trim());
    await _settings.setGroqModel(_selectedModel);
    await _settings.setDefaultLanguage(_defaultLang);
    await _settings.setAutoTranslateFuv(_autoTranslate);
    await _settings.setAutoSpeakFuv(_autoSpeak);
    setState(() { _saving = false; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Paramètres enregistrés')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testGroq() async {
    final key = _groqCtrl.text.trim();
    if (key.isEmpty) {
      setState(() { _testResult = '❌ Clé Groq vide'; });
      return;
    }
    setState(() { _testing = true; _testResult = '⏳ Test en cours…'; });
    final client = GroqService(apiKey: key, model: _selectedModel);
    final r      = await client.runAction('correct', 'Bonjour, comment tu vas ?');
    setState(() {
      _testing    = false;
      _testResult = r.success ? '✓ Groq OK — modèle : $_selectedModel' : '❌ ${r.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent,
                    ),
                  )
                : const Text(
                    'Enregistrer',
                    style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('API GROQ', [
              _ApiField(
                label:       'Clé API Groq',
                hint:        'gsk_…',
                controller:  _groqCtrl,
                helpUrl:     'console.groq.com',
              ),
              const SizedBox(height: 12),
              // Sélecteur modèle
              const Text(
                'Modèle LLM',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:       _selectedModel,
                    dropdownColor: AppColors.card,
                    isExpanded:  true,
                    style: const TextStyle(
                      color: AppColors.text, fontSize: 14,
                    ),
                    items: _groqModels.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedModel = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bouton test
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testGroq,
                    icon: _testing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent,
                            ),
                          )
                        : const Icon(Icons.wifi_tethering_rounded,
                            size: 16, color: AppColors.accent),
                    label: const Text(
                      'Tester la connexion',
                      style: TextStyle(color: AppColors.accent, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                  if (_testResult.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testResult,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testResult.startsWith('✓')
                              ? AppColors.ok
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ]),

            const SizedBox(height: 20),

            _section('HUGGINGFACE', [
              _ApiField(
                label:       'Token HuggingFace',
                hint:        'hf_…',
                controller:  _hfCtrl,
                helpUrl:     'huggingface.co/settings/tokens',
              ),
              const SizedBox(height: 6),
              const Text(
                'Requis pour la traduction Fulfulde et le TTS Fulfulde',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ]),

            const SizedBox(height: 20),

            _section('PRÉFÉRENCES', [
              // Langue par défaut
              const Text(
                'Langue de transcription par défaut',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ('fr', '🇫🇷 Français'),
                  ('en', '🇬🇧 English'),
                ].map((l) {
                  final selected = _defaultLang == l.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l.$2),
                      selected: selected,
                      selectedColor: AppColors.accent.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.accent : AppColors.textMuted,
                        fontSize: 13,
                      ),
                      onSelected: (_) => setState(() => _defaultLang = l.$1),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _Toggle(
                label:    'Traduction auto FR→Fulfulde',
                subtitle: 'Traduit automatiquement après chaque transcription',
                value:    _autoTranslate,
                onChanged: (v) => setState(() => _autoTranslate = v),
              ),
              const SizedBox(height: 8),
              _Toggle(
                label:    'Lecture auto Fulfulde',
                subtitle: 'Lit le texte traduit dès que la traduction est prête',
                value:    _autoSpeak,
                onChanged: (v) => setState(() => _autoSpeak = v),
              ),
            ]),

            const SizedBox(height: 20),

            // Info version
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CalvoNote v1.0 — Phase 1',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  SizedBox(height: 4),
                  Text('DevLab · Transcription FR / EN / Fulfulde Adamawa',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  SizedBox(height: 4),
                  Text('Modèles : Groq Whisper large-v3-turbo · NLLB bonopassale · MMS-TTS-ful',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.accent, letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ── Champ API avec masquage ───────────────────────────────────

class _ApiField extends StatefulWidget {
  final String             label;
  final String             hint;
  final TextEditingController controller;
  final String             helpUrl;

  const _ApiField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.helpUrl,
  });

  @override
  State<_ApiField> createState() => _ApiFieldState();
}

class _ApiFieldState extends State<_ApiField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Spacer(),
            Text(
              widget.helpUrl,
              style: const TextStyle(
                fontSize: 11, color: AppColors.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 18, color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Toggle préférence ─────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final String   label;
  final String   subtitle;
  final bool     value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppColors.fuv,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
