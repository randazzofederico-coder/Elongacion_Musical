import 'dart:typed_data';
import 'package:wav/wav.dart';

class WavData {
  final List<Float32List> samples;
  final List<List<double>> waveform;
  final int sampleRate; // Add this
  
  WavData(this.samples, this.waveform, this.sampleRate);
}

/// Top-level function for [compute].
/// Parses WAV bytes and returns channel data (Float32List) AND downsampled waveform.
WavData parseWavBytes(Uint8List bytes) {
  final wav = Wav.read(bytes);
  
  // Convert Float64List (wav default) to Float32List
  final samples = wav.channels.map((channel) => Float32List.fromList(channel)).toList();
  
  // Generate Waveform (Downsample to ~100 points per second or fixed width?)
  // For vertical scrolling, we probably want fixed points per pixel height?
  // Or just a fixed number of points to represent the whole file?
  // VerticalWaveform renders the whole list into SizedBox(height).
  // _WaveformPainter uses `points = channelData.length`.
  // If the file is long, we don't want millions of points.
  
  // Let's aim for ~2000 points max for visualization performance?
  const int targetPoints = 2000;
  
  List<List<double>> waveform = [];
  
  // Note: we iterate formatting original channels (Float64) or the new Float32? 
  // wav.channels is Float64List. Let's use that for precision before discarding.
  for (var channel in wav.channels) {
      int len = channel.length;
      int step = (len / targetPoints).ceil();
      if (step < 1) step = 1;
      
      List<double> downsampled = [];
      for (int i = 0; i < len; i += step) {
          double maxVal = 0.0;
          // Find peak in chunk
          for (int j = 0; j < step && i + j < len; j++) {
             double val = channel[i+j].abs();
             if (val > maxVal) maxVal = val;
          }
          downsampled.add(maxVal);
      }
      waveform.add(downsampled);
  }
  
  return WavData(samples, waveform, wav.samplesPerSecond);
}
