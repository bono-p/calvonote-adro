import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Carte affichant un bloc de texte avec titre, libellé de langue,
/// boutons copier et partager.
class ResultCard extends StatelessWidget {
  final String title;
  final String? languageLabel;
  final String content;
  final bool isLoading;
  final String? errorMessage;

  const ResultCard({
    super.key,
    required this.title,
    this.languageLabel,
    required this.content,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (languageLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      languageLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (content.isNotEmpty && errorMessage == null) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copier',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copié dans le presse-papier'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Partager',
                    onPressed: () {
                      Share.share(content, subject: title);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _buildBody(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Traitement en cours…'),
        ],
      );
    }
    if (errorMessage != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      );
    }
    return Text(
      content.isEmpty ? '—' : content,
      style: theme.textTheme.bodyLarge,
    );
  }
}
