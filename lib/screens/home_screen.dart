import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transcription_entry.dart';
import '../services/audio_recorder_service.dart';
import '../services/fuv_space_service.dart';
import '../services/groq_service.dart';
import '../services/settings_service.dart';
import '../widgets/record_button.dart';
import '../widgets/result_card.dart';
import 'edit_transcription_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Stage { idle, recording, transcribing, translating, done }

class _HomeScreenState extends State<HomeScreen> {
  final _audio = AudioRecorderService.instance;
  final _groq = GroqService.instance;
  final _fuv = FuvSpaceService.instance;
  final _settings = SettingsService.instance;

  String _selectedLang = 'fr';
  _Stage _stage = _Stage.idle;
  String _transcription = '';
  String _translation = '';
  String? _error;
  String? _lastAudioPath;
  Duration _recordDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedLang = _settings.defaultLanguage;
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  bool get _isBusy =>
      _stage == _Stage.transcribing || _stage == _Stage.translating;

  Future<void> _onRecordPressed() async {
    if (_stage == _Stage.recording) {
      await _stopAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _transcription = '';
      _translation = '';
      _lastAudioPath = null;
      _recordDuration = Duration.zero;
    });

    // Vérifie la clé API avant tout
    if (_settings.groqApiKey.isEmpty) {
      setState(() => _error =
          'Clé API Groq manquante. Ouvrez les Paramètres pour la configurer.');
      _openSettings();
      return;
    }

    // Permission micro
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _error = 'Permission micro refusée.');
      return;
    }

    try {
      final path = await _audio.start();
      _lastAudioPath = path;
      setState(() => _stage = _Stage.recording);
      _startTimer();
    } catch (e) {
      setState(() => _error = 'Erreur démarrage enregistrement : $e');
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_stage != _Stage.recording) return false;
      setState(() => _recordDuration += const Duration(seconds: 1));
      return true;
    });
  }

  Future<void> _stopAndProcess() async {
    String? audioPath;
    try {
      audioPath = await _audio.stop();
    } catch (e) {
      setState(() {
        _stage = _Stage.idle;
        _error = 'Erreur arrêt enregistrement : $e';
      });
      return;
    }
    if (audioPath == null) {
      setState(() => _stage = _Stage.idle);
      return;
    }
    _lastAudioPath = audioPath;

    // 1) Transcription
    setState(() {
      _stage = _Stage.transcribing;
      _error = null;
    });
    try {
      final text = await _groq.transcribe(
        audioPath: audioPath,
        language: _selectedLang,
        apiKey: _settings.groqApiKey,
      );
      setState(() {
        _transcription = text;
        _stage = _Stage.done;
      });

      if (text.isEmpty) {
        setState(() => _translation = '(Aucun discours détecté)');
        await _saveHistory(audioPath, text, '', null);
      }
      // L'utilisateur doit confirmer via le bouton "Éditer & Traduire"
    } catch (e) {
      setState(() {
        _stage = _Stage.done;
        _error = 'Transcription échouée : $e';
      });
      await _saveHistory(audioPath, '', '', e.toString());
    }
  }

  /// Ouvre l'écran d'édition, puis lance la traduction avec le texte édité.
  Future<void> _editAndTranslate() async {
    if (_transcription.isEmpty) return;

    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditTranscriptionScreen(
          initialText: _transcription,
          language: _selectedLang,
        ),
      ),
    );

    if (edited == null) return; // utilisateur a annulé

    // Met à jour la transcription éditée
    setState(() => _transcription = edited);
    await _launchTranslation(edited);
  }

  /// Lance la traduction vers le Fulfulde.
  /// - Si la source est FR : appel direct au Space HF FR→FUV
  /// - Si la source est EN : pivot EN→FR via Groq, puis FR→FUV via le Space HF
  Future<void> _launchTranslation(String sourceText) async {
    setState(() {
      _stage = _Stage.translating;
      _error = null;
      _translation = '';
    });

    try {
      String frText = sourceText;

      // Pivot EN→FR via Groq
      if (_selectedLang == 'en') {
        try {
          frText = await _groq.translateEnToFr(
            text: sourceText,
            apiKey: _settings.groqApiKey,
          );
        } catch (e) {
          setState(() {
            _error = 'Pivot EN→FR échoué : $e';
            _stage = _Stage.done;
          });
          await _saveHistory(
              _lastAudioPath ?? '', sourceText, '', e.toString());
          return;
        }
      }

      // FR → FUV via le Space HF
      final fuv = await _fuv.translateFrToFuv(
        text: frText,
        hfToken: _settings.hfToken,
      );

      setState(() {
        _translation = fuv;
        _stage = _Stage.done;
      });
      await _saveHistory(_lastAudioPath ?? '', sourceText, fuv, null);
    } catch (e) {
      setState(() {
        _translation = '';
        _error = 'Traduction échouée : $e';
        _stage = _Stage.done;
      });
      await _saveHistory(_lastAudioPath ?? '', sourceText, '', e.toString());
    }
  }

  Future<void> _saveHistory(
    String audioPath,
    String transcription,
    String translation,
    String? error,
  ) async {
    final entry = TranscriptionEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      audioPath: audioPath,
      language: _selectedLang,
      transcription: transcription,
      translation: translation,
      createdAt: DateTime.now(),
      errorMessage: error,
    );
    await _settings.addHistory(entry.toJson());
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _shareAll() {
    if (_transcription.isEmpty && _translation.isEmpty) return;
    final buffer = StringBuffer();
    if (_transcription.isNotEmpty) {
      buffer.writeln('=== Transcription (${_selectedLang.toUpperCase()}) ===');
      buffer.writeln(_transcription);
      buffer.writeln();
    }
    if (_translation.isNotEmpty) {
      buffer.writeln('=== Traduction Fulfulde ===');
      buffer.writeln(_translation);
    }
    Share.share(buffer.toString().trim(), subject: 'CalvoNote');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = _stage == _Stage.recording;
    final canEditAndTranslate =
        _stage == _Stage.done && _transcription.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CalvoNote'),
        actions: [
          if (_transcription.isNotEmpty || _translation.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Partager tout',
              onPressed: _shareAll,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur de langue
            _buildLanguageSelector(theme),
            const SizedBox(height: 8),

            // Indicateur durée si enregistrement
            if (isRecording)
              Center(
                child: Text(
                  _formatDuration(_recordDuration),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Bouton enregistrement
            Center(
              child: RecordButton(
                isRecording: isRecording,
                isProcessing: _isBusy,
                onPressed: _onRecordPressed,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                isRecording
                    ? 'Enregistrement… touchez pour arrêter'
                    : (_isBusy
                        ? 'Traitement…'
                        : 'Touchez le micro pour enregistrer'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // Résultats
            Expanded(
              child: ListView(
                children: [
                  ResultCard(
                    title: 'Transcription',
                    languageLabel: _selectedLang == 'fr' ? 'FR' : 'EN',
                    content: _transcription,
                    isLoading: _stage == _Stage.transcribing,
                  ),
                  if (canEditAndTranslate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: FilledButton.icon(
                        onPressed: _editAndTranslate,
                        icon: const Icon(Icons.edit),
                        label: Text(
                          _selectedLang == 'en'
                              ? 'Éditer & traduire (pivot EN→FR→FUV)'
                              : 'Éditer & traduire en Fulfulde',
                        ),
                      ),
                    ),
                  ResultCard(
                    title: 'Traduction Fulfulde',
                    languageLabel: 'fuv',
                    content: _translation,
                    isLoading: _stage == _Stage.translating,
                  ),
                  if (_error != null && _stage == _Stage.done) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text('Langue source :',
                style: theme.textTheme.titleMedium),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('Français'),
              selected: _selectedLang == 'fr',
              onSelected: _stage == _Stage.idle || _stage == _Stage.done
                  ? (_) => setState(() => _selectedLang = 'fr')
                  : null,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Anglais'),
              selected: _selectedLang == 'en',
              onSelected: _stage == _Stage.idle || _stage == _Stage.done
                  ? (_) => setState(() => _selectedLang = 'en')
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
