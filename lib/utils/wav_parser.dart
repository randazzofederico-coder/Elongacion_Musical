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
  
  // Generate Waveform (Downsample to ~100 points per second for good zoom detail)
  // Previously we used a fixed 2000 points, but that's too low for long tracks when zooming.
  
  // Calculate total seconds to determine dynamic points based on density.
  final double durationInSeconds = wav.channels[0].length / wav.samplesPerSecond;
  
  // 150 points per second gives us roughly 1 point every ~6.6 milliseconds (plenty of detail for zoom).
  // A 5 minute song will generate 45,000 points (acceptable for RAM, highly detailed for drawing).
  final int targetPoints = (durationInSeconds * 150).toInt().clamp(2000, 100000);
  
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
