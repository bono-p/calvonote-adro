import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  late TextEditingController _apiKeyController;
  late TextEditingController _hfTokenController;
  bool _obscureGroq = true;
  bool _obscureHf = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: _settings.groqApiKey);
    _hfTokenController = TextEditingController(text: _settings.hfToken);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _hfTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Future.wait([
        _settings.setGroqApiKey(_apiKeyController.text.trim()),
        _settings.setHfToken(_hfTokenController.text.trim()),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration enregistrée')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Clé API Groq (obligatoire) ───────────────
          Text('Configuration API',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, size: 20),
                      const SizedBox(width: 8),
                      Text('Clé API Groq *',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Obligatoire. Obtenez votre clé sur console.groq.com → API Keys.\n'
                    'Utilisée pour : transcription Whisper + pivot EN→FR.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureGroq,
                    decoration: InputDecoration(
                      labelText: 'gsk_...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureGroq
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureGroq = !_obscureGroq),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Token HuggingFace (optionnel) ─────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, size: 20),
                      const SizedBox(width: 8),
                      Text('Token HuggingFace (optionnel)',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Utilisé pour la traduction FR→Fulfulde via le Space\n'
                    'bonopassale/fr-fuv-Tardigrade-Eon.\n'
                    'Optionnel si le modèle est public — améliore les quotas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hfTokenController,
                    obscureText: _obscureHf,
                    decoration: InputDecoration(
                      labelText: 'hf_...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureHf
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureHf = !_obscureHf),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
              onPressed: _saving ? null : _save,
            ),
          ),

          const SizedBox(height: 24),

          // ─── Informations ──────────────────────────────
          Text('À propos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Application', 'CalvoNote v1.1.0'),
                  _infoRow('Transcription', 'Groq Whisper Large v3 Turbo'),
                  _infoRow('Pivot EN→FR', 'Groq Llama 3.3 70B'),
                  _infoRow('Traduction FR→FUV',
                      'Space HF bonopassale/fr-fuv-Tardigrade-Eon'),
                  _infoRow('Modèle NLLB',
                      'bonopassale/fr-fuv-translator-tardigrade'),
                  _infoRow('Langue cible', 'Fulfulde Adamawa (fuv)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
