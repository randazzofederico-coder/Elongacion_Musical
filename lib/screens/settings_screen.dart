import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/providers/theme_provider.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/widgets/knob_control.dart';
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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface(context),
        foregroundColor: AppColors.textPrimary(context),
      ),
      body: Consumer<MixerProvider>(
        builder: (context, mixer, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Metrónomo',
                    style: TextStyle(
                      color: AppColors.primary(context), 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Configura los patrones rítmicos. Toca cada paso para ciclar entre: Mudo, Alto, Bajo, y Medio.',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsTrackStrip(
                        context: context,
                        label: 'MASTER',
                        value: mixer.masterVolume,
                        onChanged: (val) => mixer.setMasterVolume(val),
                        isMuted: mixer.isMasterMuted,
                        onMuteToggle: mixer.toggleMasterMute,
                        isSolo: mixer.isMasterSolo,
                        onSoloToggle: mixer.toggleMasterSolo,
                        isActive: true
                    ),
                    _buildSettingsTrackStrip(
                        context: context,
                        label: '3/4',
                        value: mixer.metronomeVol34,
                        onChanged: (val) => mixer.setMetronomeVolume(val, mixer.metronomeVol68),
                        isMuted: mixer.isMetronome34Muted,
                        onMuteToggle: mixer.toggleMetronome34Mute,
                        isSolo: mixer.isMetronome34Solo,
                        onSoloToggle: mixer.toggleMetronome34Solo,
                        isActive: mixer.metronomeVol34 > 0,
                    ),
                    _buildSettingsTrackStrip(
                        context: context,
                        label: '6/8',
                        value: mixer.metronomeVol68,
                        onChanged: (val) => mixer.setMetronomeVolume(mixer.metronomeVol34, val),
                        isMuted: mixer.isMetronome68Muted,
                        onMuteToggle: mixer.toggleMetronome68Mute,
                        isSolo: mixer.isMetronome68Solo,
                        onSoloToggle: mixer.toggleMetronome68Solo,
                        isActive: mixer.metronomeVol68 > 0,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              _MetronomeSequencer(
                 title: 'Patrón 3/4 (o compás simple)',
                 pattern: widget.settingsService.metronomePattern34,
                 onChange: (newPat) async {
                    await widget.settingsService.setMetronomePattern34(newPat);
                    mixer.reloadMetronomePatterns();
                 },
              ),
              const SizedBox(height: 16),
              _MetronomeSequencer(
                 title: 'Patrón 6/8 (o compás compuesto)',
                 pattern: widget.settingsService.metronomePattern68,
                 onChange: (newPat) async {
                    await widget.settingsService.setMetronomePattern68(newPat);
                    mixer.reloadMetronomePatterns();
                 },
              ),

              Divider(color: AppColors.border(context), height: 32),

              Text(
                'User Interface',
                style: TextStyle(
                  color: AppColors.primary(context), 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('Show Waveforms', style: TextStyle(color: AppColors.textPrimary(context))),
                subtitle: Text('Disabling improves performance on older devices.', style: TextStyle(color: AppColors.textSecondary(context))),
                value: mixer.showWaveforms,
                activeTrackColor: AppColors.primary(context),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: AppColors.surface(context),
                tileColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onChanged: (val) {
                  mixer.toggleShowWaveforms();
                },
              ),

              const SizedBox(height: 8),
              SwitchListTile(
                title: Text('Tema Oscuro', style: TextStyle(color: AppColors.textPrimary(context))),
                subtitle: Text('Cambia la apariencia a tonos oscuros de inmediato.', style: TextStyle(color: AppColors.textSecondary(context))),
                value: Provider.of<ThemeProvider>(context).isDarkMode,
                activeTrackColor: AppColors.primary(context),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: AppColors.surface(context),
                tileColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onChanged: (val) async {
                   await Provider.of<ThemeProvider>(context, listen: false).toggleTheme(val);
                   mixer.notifyListeners(); 
                },
              ),



              const SizedBox(height: 24),
              Text(
                'SoundTouch Tuning (Debug)',
                style: TextStyle(
                  color: AppColors.primary(context), 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajusta estos valores si la música suena robótica o metálica al cambiar la velocidad.',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.piano, size: 16),
                      label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text('Ritmo / Piano')
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface(context),
                        foregroundColor: AppColors.primary(context),
                      ),
                      onPressed: () => mixer.applyRhythmicProfile(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.water_drop, size: 16),
                      label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text('Melódico / Flauta')
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface(context),
                        foregroundColor: AppColors.primary(context),
                      ),
                      onPressed: () => mixer.applyMelodicProfile(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildTuningSlider(
                context: context,
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
                context: context,
                title: 'Seek Window (Ventana de Búsqueda)',
                value: mixer.stSeekWindowMs.toDouble(),
                min: 5, max: 60, divisions: 55,
                onChanged: (val) => mixer.setStSeekWindowMs(val.round()),
                description: 'Espacio para buscar el cruce perfecto.',
              ),
              
              _buildTuningSlider(
                context: context,
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

  Widget _buildSettingsTrackStrip({
      required BuildContext context,
      required String label,
      required double value,
      required Function(double) onChanged,
      required bool isMuted,
      required VoidCallback onMuteToggle,
      required bool isSolo,
      required VoidCallback onSoloToggle,
      required bool isActive,
      bool hideSolo = false,
  }) {
      return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              KnobControl(
                  value: value,
                  onChanged: onChanged,
                  min: 0,
                  max: 1,
                  label: label,
                  labelColor: isActive ? AppColors.accentGreen(context) : AppColors.accentRed(context),
              ),
              const SizedBox(height: 8),
              Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      // Mute Button
                      GestureDetector(
                          onTap: onMuteToggle,
                          child: Container(
                              width: 30,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: isMuted ? AppColors.accentRed(context) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                  'M',
                                  style: TextStyle(
                                      color: isMuted ? Colors.white : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                  ),
                              ),
                          ),
                      ),
                      if (!hideSolo) ...[
                          const SizedBox(width: 6),
                          // Solo Button
                          GestureDetector(
                              onTap: onSoloToggle,
                              child: Container(
                                  width: 30,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      color: isSolo ? AppColors.accentCyan(context) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                      'S',
                                      style: TextStyle(
                                          color: isSolo ? Colors.black : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                      ),
                                  ),
                              ),
                          ),
                      ],
                  ],
              )
          ],
      );
  }

  Widget _buildTuningSlider({
    required BuildContext context,
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
            Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
            Text('${value.round()}', style: TextStyle(color: AppColors.primary(context), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primary(context),
          inactiveColor: AppColors.surfaceHighlight(context),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }


} // End Class

class _MetronomeSequencer extends StatelessWidget {
  final List<int> pattern;
  final String title;
  final Function(List<int>) onChange;

  const _MetronomeSequencer({
    Key? key,
    required this.pattern,
    required this.title,
    required this.onChange,
  }) : super(key: key);

  Color _getColorForType(BuildContext context, int type) {
     switch (type) {
        case 1: return AppColors.accentRed(context);
        case 2: return AppColors.accentCyan(context);
        case 3: return AppColors.accentGreen(context);
        default: return AppColors.surfaceHighlight(context);
     }
  }
  
  String _getLabelForType(int type) {
     switch (type) {
        case 1: return "ALTO";
        case 2: return "BAJO";
        case 3: return "MEDIO";
        default: return "OFF";
     }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            int currentType = pattern.length > index ? pattern[index] : 0;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                   List<int> newPat = List.from(pattern);
                   // cycle 0 -> 1 -> 2 -> 3 -> 0
                   newPat[index] = (currentType + 1) % 4;
                   onChange(newPat);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 45,
                  decoration: BoxDecoration(
                    color: currentType == 0 ? AppColors.surface(context) : _getColorForType(context, currentType).withOpacity(0.2),
                    border: Border.all(
                      color: currentType == 0 ? AppColors.border(context) : _getColorForType(context, currentType),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index + 1}', 
                        style: TextStyle(
                          color: currentType == 0 ? AppColors.textSecondary(context) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        )
                      ),
                      if (currentType != 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                             _getLabelForType(currentType),
                             style: TextStyle(
                                color: _getColorForType(context, currentType),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                             )
                          ),
                        )
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
