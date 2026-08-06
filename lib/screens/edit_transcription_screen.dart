import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Écran d'édition de la transcription avant traduction.
/// L'utilisateur peut corriger les erreurs de Whisper avant d'envoyer
/// la traduction vers le Space HF FR→FUV (ou pivot EN→FR→FUV).
class EditTranscriptionScreen extends StatefulWidget {
  final String initialText;
  final String language; // 'fr' ou 'en'

  const EditTranscriptionScreen({
    super.key,
    required this.initialText,
    required this.language,
  });

  @override
  State<EditTranscriptionScreen> createState() =>
      _EditTranscriptionScreenState();
}

class _EditTranscriptionScreenState extends State<EditTranscriptionScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La transcription est vide')),
      );
      return;
    }
    Navigator.of(context).pop(text);
  }

  void _share() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Share.share(text, subject: 'Transcription CalvoNote');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEn = widget.language == 'en';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer la transcription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirmer et traduire',
            onPressed: _confirm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau d'information
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vérifiez et corrigez la transcription '
                        '${isEn ? 'anglaise' : 'française'} avant la traduction '
                        'vers le Fulfulde Adamawa.',
                        style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Compteur de caractères
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${value.text.length} caractères',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Zone d'édition
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Transcription ${isEn ? 'EN' : 'FR'}',
                  hintText: 'Modifiez le texte ici…',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.translate),
                  label: const Text('Traduire en Fulfulde'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
