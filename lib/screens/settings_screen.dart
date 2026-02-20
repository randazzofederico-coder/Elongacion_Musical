import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsScreen({super.key, required this.settingsService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Consumer<MixerProvider>(
        builder: (context, mixer, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'User Interface',
                style: TextStyle(
                  color: AppColors.primary, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Show Waveforms', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Disabling improves performance on older devices.', style: TextStyle(color: AppColors.textSecondary)),
                value: mixer.showWaveforms,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: AppColors.surface,
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onChanged: (val) {
                  mixer.toggleShowWaveforms();
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Lock Portrait Orientation', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Prevent screen rotation.', style: TextStyle(color: AppColors.textSecondary)),
                value: mixer.lockPortrait,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: AppColors.surface,
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onChanged: (val) {
                   mixer.toggleLockPortrait();
                },
              ),

              const Divider(color: AppColors.border, height: 32),

              const Text(
                'Audio Engine',
                style: TextStyle(
                  color: AppColors.primary, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 16),
              _buildModeOption(
                mode: AudioEngineMode.realtime,
                title: 'Realtime (Experimental)',
                description: 'Best experience. Instant feedback. Requires a powerful device.',
                icon: Icons.flash_on,
                currentMode: mixer.isOfflineMode ? AudioEngineMode.offline : AudioEngineMode.realtime, 
                onTap: (m) => mixer.setAudioMode(m),
              ),
              const SizedBox(height: 12),
              _buildModeOption(
                mode: AudioEngineMode.offline,
                title: 'Pre-Render (Safe Mode)',
                description: 'Best for older devices. Renders audio before playing to prevent glitches.',
                icon: Icons.save_alt,
                currentMode: mixer.isOfflineMode ? AudioEngineMode.offline : AudioEngineMode.realtime,
                onTap: (m) => mixer.setAudioMode(m),
              ),

              const Divider(color: AppColors.border, height: 32),

              const Text(
                'SoundTouch Tuning (Debug)',
                style: TextStyle(
                  color: AppColors.primary, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ajusta estos valores si la música suena robótica o metálica al cambiar la velocidad.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.piano, size: 16),
                    label: const Text('Ritmo / Piano'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => mixer.applyRhythmicProfile(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.water_drop, size: 16),
                    label: const Text('Melódico / Flauta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () => mixer.applyMelodicProfile(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildTuningSlider(
                title: 'Sequence (Tamaño de Bloque)',
                // Sequence is typically set in milliseconds but internally mapped.
                // However, SoundTouch requires Sequence to be a multiple of 8 for SIMD optimizations in FIR.
                // It's safer to just provide a discrete number of steps or force it to be even.
                value: mixer.stSequenceMs.toDouble(),
                min: 10, max: 150, divisions: 140, // Allow 1ms steps, but wait, the crash is about AAFilter
                onChanged: (val) => mixer.setStSequenceMs((val / 2).round() * 2), // Ensure even numbers just in case? Or no, wait
                description: 'Corto: Evita ecos rítmicos. Largo: Suaviza voces.',
              ),
              
              _buildTuningSlider(
                title: 'Seek Window (Ventana de Búsqueda)',
                value: mixer.stSeekWindowMs.toDouble(),
                min: 5, max: 60, divisions: 55,
                onChanged: (val) => mixer.setStSeekWindowMs(val.round()),
                description: 'Espacio para buscar el cruce perfecto.',
              ),
              
              _buildTuningSlider(
                title: 'AA Filter Length (Taps)', // We'll repurpose Overlap to AAFilter to fix the crash
                value: mixer.stOverlapMs.toDouble(), // We will use overlap variable for now
                min: 8, max: 128, divisions: 15, // Steps of 8 (8*15 = 120 + 8 = 128)
                onChanged: (val) {
                  // Must be multiple of 8!
                  int taps = (val / 8).round() * 8;
                  if (taps < 8) taps = 8;
                  mixer.setStOverlapMs(taps);
                },
                description: 'Filtro Anti-Aliasing (Debe ser múltiplo de 8).',
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTuningSlider({
    required String title, 
    required double value, 
    required double min, 
    required double max, 
    required int divisions,
    required Function(double) onChanged,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            Text('${value.round()}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.surfaceHighlight,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModeOption({
    required AudioEngineMode mode,
    required String title,
    required String description,
    required IconData icon,
    required AudioEngineMode currentMode,
    required Function(AudioEngineMode) onTap,
  }) {
    final isSelected = currentMode == mode;
    
    return GestureDetector(
      onTap: () => onTap(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
} // End Class
// Removed _currentMode state logic since we use Provider now.
