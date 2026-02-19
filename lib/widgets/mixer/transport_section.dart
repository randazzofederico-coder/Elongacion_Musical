import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/waveform_seek_bar.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
          const SizedBox(width: 16),
          
          // Stop
          _TransportButton(
            icon: Icons.stop,
            isActive: false, 
            activeColor: Colors.red, // Not used when inactive but consistent
            onPressed: () => mixer.stop(),
          ),
          const SizedBox(width: 16),

          // Waveform Seek Bar
          Expanded(
            child: StreamBuilder<Duration?>(
              stream: mixer.durationStream,
              initialData: mixer.duration,
              builder: (context, durationSnap) {
                final duration = durationSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: mixer.positionStream,
                  builder: (context, posSnap) {
                     final position = posSnap.data ?? Duration.zero;
                     
                     // Use the cached master waveform
                     return WaveformSeekBar(
                        duration: duration,
                        position: position,
                        waveformData: mixer.masterWaveformData,
                        isLoopEnabled: mixer.isLooping,
                        loopStart: mixer.loopStart,
                        loopEnd: mixer.loopEnd,
                        onSeek: (pos) => mixer.seek(pos),
                        onLoopToggle: (_) => mixer.toggleLoop(),
                        onLoopRangeChanged: (start, end) => mixer.setLoopRange(start, end),
                        onLoopRangeChangeEnd: (start, end) {
                           mixer.setLoopRange(start, end);
                           mixer.commitLoopRange();
                        },
                     );
                  }
                );
              }
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
        width: 48,
        height: 48,
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
          size: 28,
        ),
      ),
    );
  }
}
