import 'package:flutter/material.dart';

class MasterControl extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool isCompact;

  const MasterControl({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: isCompact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: isCompact ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: isCompact ? null : BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black54),
      ),
      child: Row(
        children: [
          if (!isCompact) const Icon(Icons.speed, color: Colors.grey, size: 18),
          if (!isCompact) const SizedBox(width: 8),
          Text(
            'TEMPO: ${currentSpeed.toStringAsFixed(2)}x',
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 12, 
              color: Colors.white70,
              letterSpacing: 1.0
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.black45,
                thumbColor: Colors.cyanAccent,
                overlayColor: Colors.cyanAccent.withValues(alpha: 0.1),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: currentSpeed,
                min: 0.5,
                max: 1.5,
                onChanged: onSpeedChanged,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onSpeedChanged(1.0),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('RESET', style: TextStyle(fontSize: 10, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
