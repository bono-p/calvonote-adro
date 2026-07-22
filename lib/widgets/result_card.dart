import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  CARTE RÉSULTAT
//  Affiche un bloc de texte (transcription ou traduction)
//  avec actions : copier, lire, effacer
// ─────────────────────────────────────────────────────────────

class ResultCard extends StatelessWidget {
  final String   title;
  final String   text;
  final Color    accentColor;
  final bool     isFuv;
  final bool     isPlaying;
  final bool     isLoading;
  final VoidCallback? onSpeak;
  final VoidCallback? onStop;
  final VoidCallback? onClear;
  final List<Widget>? extraActions;

  const ResultCard({
    super.key,
    required this.title,
    required this.text,
    this.accentColor  = AppColors.accent,
    this.isFuv        = false,
    this.isPlaying    = false,
    this.isLoading    = false,
    this.onSpeak,
    this.onStop,
    this.onClear,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = text.trim().isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isFuv ? AppColors.fuvDim : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFuv ? AppColors.fuv.withOpacity(0.3) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isFuv
                      ? AppColors.fuv.withOpacity(0.2)
                      : AppColors.cardBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (!isEmpty) ...[
                  // Copier
                  _IconBtn(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copier',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$title copié'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  // Lire / Stop
                  if (onSpeak != null)
                    isLoading
                        ? const SizedBox(
                            width: 28, height: 28,
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : _IconBtn(
                            icon: isPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_rounded,
                            tooltip: isPlaying ? 'Arrêter' : 'Lire',
                            color: isPlaying ? AppColors.recording : null,
                            onTap: isPlaying ? onStop : onSpeak,
                          ),
                  // Effacer
                  if (onClear != null)
                    _IconBtn(
                      icon: Icons.close_rounded,
                      tooltip: 'Effacer',
                      onTap: onClear,
                    ),
                  // Actions supplémentaires
                  if (extraActions != null) ...extraActions!,
                ],
              ],
            ),
          ),

          // ── Corps ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: isEmpty
                ? Text(
                    isFuv
                        ? 'La traduction Fulfulde apparaîtra ici'
                        : 'La transcription apparaîtra ici',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : SelectableText(
                    text,
                    style: TextStyle(
                      fontSize: isFuv ? 16 : 15,
                      color: isFuv ? AppColors.textFuv : AppColors.text,
                      height: 1.6,
                      fontWeight: isFuv ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData   icon;
  final String     tooltip;
  final VoidCallback? onTap;
  final Color?     color;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 18,
            color: color ?? AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
