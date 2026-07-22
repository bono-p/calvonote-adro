import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  BOUTON D'ENREGISTREMENT
//  Grand bouton circulaire avec halo pulsant en mode recording
// ─────────────────────────────────────────────────────────────

class RecordButton extends StatefulWidget {
  final bool      isRecording;
  final bool      isLoading;
  final VoidCallback onTap;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRec = widget.isRecording;
    final color = isRec ? AppColors.recording : AppColors.accent;
    final glow  = isRec ? AppColors.recGlow   : AppColors.accentGlow;

    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale = isRec ? _pulse.value : 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Halo externe
              if (isRec)
                Transform.scale(
                  scale: scale * 1.35,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glow.withValues(alpha: 0.3 * (scale - 1.0) / 0.25),
                    ),
                  ),
                ),
              // Halo interne
              Transform.scale(
                scale: isRec ? scale : 1.0,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glow,
                  ),
                ),
              ),
              // Bouton principal
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: widget.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        isRec ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
