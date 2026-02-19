import 'dart:typed_data';
import 'dart:math';
import 'package:wav/wav.dart';

/// Analyzes audio bytes to extract samples and waveform data.
/// This function is intended to be run in an isolate via [compute].
Future<Map<String, dynamic>> analyzeAudio(Uint8List bytes) async {
    final Wav wav = Wav.read(bytes);
    
    if (wav.channels.isEmpty) {
       return {
         'samples': <Float64List>[], 
         'waveformData': <List<double>>[], 
         'sampleRate': wav.samplesPerSecond
       };
    }

    // Generate Waveform Data (Downsampled for UI)
    const int pointsTarget = 2000;
    int samplesPerChannel = wav.channels[0].length;
    int step = (samplesPerChannel / pointsTarget).ceil();
    if (step < 1) step = 1;

    List<List<double>> waveforms = [];

    for (var channelData in wav.channels) {
      List<double> channelWave = [];
      for (int i = 0; i < samplesPerChannel; i += step) {
         double maxVal = 0;
         int end = min(i + step, samplesPerChannel);
         for (int j = i; j < end; j++) {
            double absVal = channelData[j].abs();
            if (absVal > maxVal) maxVal = absVal;
         }
         channelWave.add(maxVal);
      }
      waveforms.add(channelWave);
    }
    
    return {
      'samples': wav.channels,
      'waveformData': waveforms,
      'sampleRate': wav.samplesPerSecond,
    };
}
