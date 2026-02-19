import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/master_control.dart';
import 'package:elongacion_musical/widgets/studio_header.dart';
import 'package:elongacion_musical/widgets/mixer/track_list_section.dart';
import 'package:elongacion_musical/widgets/mixer/master_section.dart';
import 'package:elongacion_musical/widgets/mixer/transport_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MixerScreen extends StatefulWidget {
  final Exercise exercise;
  const MixerScreen({super.key, required this.exercise});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracks = widget.exercise.tracks.map((t) => {
        'id': t.id,
        'name': t.name,
        'path': t.assetPath,
      }).toList();
      context.read<MixerProvider>().loadExercise(tracks);
    });
  }

  late MixerProvider _mixerProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mixerProvider = context.read<MixerProvider>();
  }

  @override
  void dispose() {
    // Ensure playback stops when leaving the screen
    // Using the stored reference to avoid "Looking up a deactivated widget's ancestor is unsafe"
    _mixerProvider.stop(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Status/Header Bar
            StudioHeader(
               title: widget.exercise.title,
               isOfflineMode: mixer.isOfflineMode,
               leading: BackButton(
                 color: Colors.white,
                 onPressed: () {
                   context.read<MixerProvider>().stop();
                   Navigator.pop(context);
                 },
               ),
            ),
            
            // Top: Speed Control

            MasterControl(
              currentSpeed: mixer.globalSpeed,
              onSpeedChanged: mixer.setGlobalSpeed,
            ),
            
            // Middle: Console Area (Tracks + Master)
            Expanded(
              child: mixer.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : mixer.tracks.isEmpty
                      ? const Center(child: Text("No tracks loaded"))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final bool showWaveform = (width > 600) && mixer.showWaveforms;
                            final bool isShortScreen = constraints.maxHeight < 500;
                            
                            // Calculate Strip Widths
                            // Optimization: "Entran 6 faders" -> 5 Track + 1 Master
                            // If Mobile (!showWaveform), force fit all tracks + master
                            
                            double trackWidth;
                            double? masterWidth;
                            
                            if (showWaveform) {
                               // DESKTOP/TABLET: Comfortable sizes, Master fixed
                               // MasterStrip has 8px left margin. So occupies masterWidth + 8.
                               double masterOccupied = 120 + 8;
                               masterWidth = 120;
                               
                               // Remaining for tracks
                               // Each track occupies trackWidth + 4 (2px margin each side)
                               double remaining = width - masterOccupied;
                               if (remaining < 0) remaining = 0;
                               
                               double slotWidth = remaining / mixer.tracks.length;
                               trackWidth = slotWidth - 4; // Subtract margins
                               
                               if (trackWidth < 80) trackWidth = 80; // Min width for desktop
                            } else {
                               // MOBILE: Fit Everything
                               int totalStrips = mixer.tracks.length + 1; // +1 for Master
                               // Avoid division by zero
                               if (totalStrips < 1) totalStrips = 1; 
                               
                               // Calculate equal SLOT width (including margins)
                               double slotWidth = width / totalStrips; 
                               
                               // Subtract margins from the Slot to get the Content Width
                               // Track: margin horizontal 2 => 4px total
                               trackWidth = slotWidth - 4;
                               
                               // Master: margin left 8 => 8px total
                               masterWidth = slotWidth - 8;
                               
                               // Safety Clamp
                               if (trackWidth < 30) trackWidth = 30;
                               if (masterWidth < 30) masterWidth = 30;
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // TRACKS
                                Expanded(
                                    child: TrackListSection(
                                      showWaveform: showWaveform,
                                      itemWidth: trackWidth,
                                      useKnobForVolume: isShortScreen,
                                    ),
                                ),
                                
                                // MASTER STRIP
                                MasterSection(
                                  showWaveform: showWaveform,
                                  width: masterWidth,
                                ),
                              ],
                            );
                          }
                        ),
            ),

            // Bottom: Transport Controls
            const TransportSection(),
          ],
        ),
      ),
    );
  }
}

// Sections have been moved to separate files in lib/widgets/mixer/
