import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
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
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
            children: [
              // Status/Header Bar
             StudioHeader(
               title: widget.exercise.title,
               leading: BackButton(
                 color: AppColors.textPrimary(context),
                 onPressed: () {
                   context.read<MixerProvider>().stop();
                   Navigator.pop(context);
                 },
             ),
            ),
            // Rest of the UI or Loading Spinner
            if (mixer.isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.accentCyan(context)),
                      const SizedBox(height: 16),
                      const Text("Cargando pistas...", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              )
            else ...[
              // Top: Console Area (Tracks + Master)
              Expanded(
                flex: 1,
                child: mixer.tracks.isEmpty
                    ? const Center(child: Text("No tracks loaded"))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final bool showWaveform = (width > 600) && mixer.showWaveforms;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0), // Outer padding (12) + strip margin (4) = 16px
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // TRACKS
                                Expanded(
                                  flex: mixer.tracks.length > 0 ? mixer.tracks.length : 1,
                                  child: TrackListSection(
                                    showWaveform: showWaveform,
                                    itemWidth: double.infinity, // Let Expanded enforce width
                                    useKnobForVolume: false, 
                                  ),
                                ),
                                
                                // MASTER STRIP
                                Expanded(
                                  flex: 1,
                                  child: MasterSection(
                                    showWaveform: showWaveform,
                                    width: double.infinity, // Let Expanded enforce width
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
              ),
              
              const SizedBox(height: 4), // Subtle margin between Stems and Ruler

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
          ],
        ),
      ),
    );
  }
}
