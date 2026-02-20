import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/master_control.dart';
import 'package:elongacion_musical/widgets/studio_header.dart';
import 'package:elongacion_musical/widgets/mixer/track_list_section.dart';
import 'package:elongacion_musical/widgets/mixer/master_section.dart';
import 'package:elongacion_musical/widgets/mixer/transport_section.dart';
import 'package:elongacion_musical/widgets/waveform_seek_bar.dart';
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
      context.read<MixerProvider>().loadExercise(widget.exercise);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0), // Added lateral margin
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
            
            // Top: Console Area (Tracks + Master)
            Expanded(
              flex: 1,
              child: mixer.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : mixer.tracks.isEmpty
                      ? const Center(child: Text("No tracks loaded"))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final bool showWaveform = (width > 600) && mixer.showWaveforms;
                            
                            // Calculate Strip Widths
                            double trackWidth;
                            double? masterWidth;
                            
                            if (showWaveform) {
                               // DESKTOP/TABLET: Comfortable sizes, Master fixed
                               double masterOccupied = 120 + 8;
                               masterWidth = 120;
                               
                               double remaining = width - masterOccupied;
                               if (remaining < 0) remaining = 0;
                               
                               double slotWidth = remaining / mixer.tracks.length;
                               trackWidth = slotWidth - 4; // Subtract margins
                               
                               if (trackWidth < 80) trackWidth = 80; // Min width for desktop
                            } else {
                               // MOBILE: Fit Everything
                               int totalStrips = mixer.tracks.length + 1; // +1 for Master
                               if (totalStrips < 1) totalStrips = 1; 
                               
                               double slotWidth = width / totalStrips; 
                               
                               // The TrackStrip itself has `margin: EdgeInsets.symmetric(horizontal: 1)` => 2px
                               trackWidth = slotWidth - 2; 
                               
                               // The MasterSection doesn't have an internal margin the same way in its main container,
                               // But it often expects some width. Let's give it the same slot width.
                               masterWidth = slotWidth;
                               
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
                                      useKnobForVolume: false, // Always use faders
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
            
            const SizedBox(height: 16), // Subtle margin between Stems and Ruler

            // Middle: Waveform Area (Fixed height, full width)
            StreamBuilder<Duration?>(
                stream: mixer.durationStream,
                initialData: mixer.duration,
                builder: (context, durationSnap) {
                  final duration = durationSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: mixer.positionStream,
                    builder: (context, posSnap) {
                       final position = posSnap.data ?? Duration.zero;
                       
                       return WaveformSeekBar(
                          duration: duration,
                          position: position,
                          waveformData: mixer.masterWaveformData,
                          isLoopEnabled: mixer.isLooping,
                          loopStart: mixer.loopStart,
                          loopEnd: mixer.loopEnd,
                          bpm: mixer.currentExercise?.bpm,
                          timeSignatureNumerator: mixer.currentExercise?.timeSignatureNumerator,
                          preWaitMeasures: mixer.currentExercise?.preWaitMeasures ?? 0,
                          countInMeasures: mixer.currentExercise?.countInMeasures ?? 0,
                          onSeek: (pos) => mixer.seek(pos),
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

            // Bottom: Transport Controls
            const TransportSection(),
          ],
        ),
      ),
    ),
    );
  }
}

// Sections have been moved to separate files in lib/widgets/mixer/
