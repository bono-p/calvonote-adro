import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transcription_entry.dart';
import '../services/settings_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _settings = SettingsService.instance;
  List<TranscriptionEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _entries = _settings.history
          .map((e) => TranscriptionEntry.fromJson(e))
          .toList();
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _settings.clearHistory();
      _load();
    }
  }

  Future<void> _delete(String id) async {
    await _settings.deleteHistoryEntry(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Tout effacer',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('Aucune transcription enregistrée',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = _entries[i];
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(e.id),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  e.language.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(e.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copier',
                                onPressed: e.translation.isEmpty &&
                                        e.transcription.isEmpty
                                    ? null
                                    : () {
                                        Clipboard.setData(ClipboardData(
                                            text:
                                                '${e.transcription}\n\n→ ${e.translation}'));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text('Copié'),
                                          duration: Duration(seconds: 1),
                                        ));
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined,
                                    size: 18),
                                tooltip: 'Partager',
                                onPressed: e.translation.isEmpty &&
                                        e.transcription.isEmpty
                                    ? null
                                    : () {
                                        final buffer = StringBuffer();
                                        if (e.transcription.isNotEmpty) {
                                          buffer.writeln(
                                              '=== Transcription ${e.language.toUpperCase()} ===');
                                          buffer.writeln(e.transcription);
                                          buffer.writeln();
                                        }
                                        if (e.translation.isNotEmpty) {
                                          buffer.writeln(
                                              '=== Traduction Fulfulde ===');
                                          buffer.writeln(e.translation);
                                        }
                                        Share.share(buffer.toString().trim(),
                                            subject: 'CalvoNote');
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.transcription.isEmpty
                                ? '(transcription vide)'
                                : e.transcription,
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (e.translation.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            Text(
                              e.translation,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                          ],
                          if (e.errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.error_outline,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
