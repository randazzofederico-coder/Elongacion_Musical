import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/models/track_model.dart';
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
    // Only rebuild top-level on isLoading changes — child widgets have their own listeners
    final isLoading = context.select<MixerProvider, bool>((m) => m.isLoading);
    final mixer = context.read<MixerProvider>();

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
            if (isLoading)
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
                child: Selector<MixerProvider, ({List<TrackModel> tracks, bool showWaveforms})>(
                  selector: (_, m) => (tracks: m.tracks, showWaveforms: m.showWaveforms),
                  builder: (context, state, child) {
                    if (state.tracks.isEmpty) {
                      return const Center(child: Text("No tracks loaded"));
                    }
                    return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final bool showWaveform = (width > 600) && state.showWaveforms;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // TRACKS
                                Expanded(
                                  flex: state.tracks.length > 0 ? state.tracks.length : 1,
                                  child: RepaintBoundary(
                                    child: TrackListSection(
                                      showWaveform: showWaveform,
                                      itemWidth: double.infinity,
                                      useKnobForVolume: false, 
                                    ),
                                  ),
                                ),
                                
                                // MASTER STRIP
                                Expanded(
                                  flex: 1,
                                  child: RepaintBoundary(
                                    child: MasterSection(
                                      showWaveform: showWaveform,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      );
                  },
                ),
              ),
              
              const SizedBox(height: 4),

            // Middle: Waveform Area — own Selector, only rebuilds on relevant changes
            RepaintBoundary(
              child: Selector<MixerProvider, ({
                Duration position, Duration? duration, List<List<double>> waveformData,
                bool isPlaying, bool isLooping, Duration loopStart, Duration loopEnd,
                int? bpm, int? tsNum, int preWait, int countIn,
              })>(
                selector: (_, m) => (
                  position: m.currentPosition, duration: m.duration,
                  waveformData: m.masterWaveformData,
                  isPlaying: m.isPlaying,
                  isLooping: m.isLooping, loopStart: m.loopStart, loopEnd: m.loopEnd,
                  bpm: m.currentExercise?.bpm, tsNum: m.currentExercise?.timeSignatureNumerator,
                  preWait: m.currentExercise?.preWaitMeasures ?? 0,
                  countIn: m.currentExercise?.countInMeasures ?? 0,
                ),
                builder: (context, s, child) {
                  final mixer = context.read<MixerProvider>();
                  final duration = s.duration ?? Duration.zero;

                  return WaveformSeekBar(
                     duration: duration,
                     position: s.position,
                     waveformData: s.waveformData,
                     isLoopEnabled: s.isLooping,
                     loopStart: s.loopStart,
                     loopEnd: s.loopEnd,
                     bpm: s.bpm,
                     timeSignatureNumerator: s.tsNum,
                     preWaitMeasures: s.preWait,
                     countInMeasures: s.countIn,
                     onSeek: (pos) => mixer.seek(pos),
                     onLoopRangeChanged: (start, end) => mixer.setLoopRange(start, end),
                     onLoopRangeChangeEnd: (start, end) {
                        mixer.setLoopRange(start, end);
                        mixer.commitLoopRange();
                     },
                  );
                },
              ),
            ),

              // Bottom: Transport Controls
              const RepaintBoundary(child: TransportSection()),
            ],
          ],
        ),
      ),
    );
  }
}
