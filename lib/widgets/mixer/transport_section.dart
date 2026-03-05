import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/master_control.dart';

class TransportSection extends StatelessWidget {
  const TransportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8), // Lifted slightly off the bottom, aligns with 16px pad
      decoration: BoxDecoration(
        color: AppColors.surface(context), // Warm card color
        borderRadius: BorderRadius.circular(12), // Matches Waveform and Stems
        border: Border.all(color: AppColors.border(context).withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.surfaceHighlight(context).withOpacity(0.3), // Inner lip responsive to theme
            spreadRadius: -2,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Play/Pause
              _TransportButton(
                icon: mixer.isPlaying ? Icons.pause : Icons.play_arrow,
                isActive: mixer.isPlaying,
                activeColor: AppColors.accentCyan(context),
                size: 44, // Slightly larger
                onPressed: () => mixer.togglePlay(),
              ),
              const SizedBox(width: 8), 
              
              // Stop
              _TransportButton(
                icon: Icons.stop,
                isActive: false, 
                activeColor: Colors.red, 
                size: 36,
                onPressed: () => mixer.stop(),
              ),
              const SizedBox(width: 8), 

              // Loop Toggle
              _TransportButton(
                 icon: Icons.loop,
                 isActive: mixer.isLooping,
                 activeColor: AppColors.accentCyan(context),
                 size: 36,
                 onPressed: () => mixer.toggleLoop(),
              ),
            ],
          ),
          const SizedBox(width: 8), 

          // Speed / Master Control
          Expanded(
            child: MasterControl(
              currentSpeed: mixer.globalSpeed,
              onSpeedChanged: mixer.setGlobalSpeed,
              onResetAll: mixer.resetAll,
              isCompact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onPressed;
  final double size;

  const _TransportButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.background(context),
          shape: BoxShape.circle,
          border: Border.all(
             color: isActive ? activeColor.withOpacity(0.8) : AppColors.border(context).withOpacity(0.8),
             width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4)),
                  const BoxShadow(color: Colors.white30, offset: Offset(0, 2), blurRadius: 2), // Inner highlight
                ]
              : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : AppColors.textPrimary(context).withOpacity(0.8),
          size: size * 0.55, 
          shadows: isActive ? [Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 6)] : [],
        ),
      ),
    );
  }
}
