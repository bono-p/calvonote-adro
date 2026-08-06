import 'package:flutter/material.dart';

/// Bouton d'enregistrement circulaire avec animation visuelle.
class RecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onPressed;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    required this.onPressed,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isRecording ? Colors.red : Theme.of(context).colorScheme.primary;
    final icon = widget.isProcessing
        ? Icons.hourglass_top
        : (widget.isRecording ? Icons.stop : Icons.mic);

    return GestureDetector(
      onTap: widget.isProcessing ? null : widget.onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo pulsant
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.6;
                final opacity = (1.0 - _pulseController.value) * 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: color.withOpacity(opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          // Bouton principal
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}
