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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // Reduced margins
      child: Row(
        children: [
          // Play/Pause
          StreamBuilder<bool>(
             stream: mixer.dirtyStream,
             initialData: mixer.isDirty,
             builder: (context, snapshot) {
                final isDirty = snapshot.data ?? false;
                final bool pendingRender = mixer.isOfflineMode && isDirty;
                
                return _TransportButton(
                  icon: mixer.isPlaying ? Icons.pause : (pendingRender ? Icons.downloading : Icons.play_arrow),
                  isActive: mixer.isPlaying || pendingRender,
                  activeColor: pendingRender ? Colors.orange : AppColors.accentCyan,
                  onPressed: () {
                     if (pendingRender) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Rendering changes..."), duration: Duration(seconds: 1)),
                        );
                     }
                     mixer.togglePlay();
                  },
                );
             }
          ),
          const SizedBox(width: 8), // Reduced
          
          // Stop
          _TransportButton(
            icon: Icons.stop,
            isActive: false, 
            activeColor: Colors.red, // Not used when inactive but consistent
            onPressed: () => mixer.stop(),
          ),
          const SizedBox(width: 4), // Reduced

          // Loop Toggle
          _TransportButton(
             icon: Icons.loop,
             isActive: mixer.isLooping,
             activeColor: AppColors.accentCyan,
             onPressed: () => mixer.toggleLoop(),
          ),
          const SizedBox(width: 8), // Reduced

          // Speed / Master Control
          Expanded(
            child: MasterControl(
              currentSpeed: mixer.globalSpeed,
              onSpeedChanged: mixer.setGlobalSpeed,
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

  const _TransportButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, // Slightly smaller to fit 3 buttons nicely
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? activeColor : Colors.black54,
            width: 1.5,
          ),
          boxShadow: isActive 
            ? [BoxShadow(color: activeColor.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
            : [],
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white70,
          size: 22, // Slightly smaller icon
        ),
      ),
    );
  }
}
