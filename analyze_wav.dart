import 'dart:io';
import 'dart:typed_data';

void main() async {
  final file = File('debug_vocoder.wav');
  if (!file.existsSync()) {
    print('ERROR: debug_vocoder.wav not found in current directory.');
    return;
  }

  final bytes = await file.readAsBytes();
  print('WAV Size: ' + bytes.length.toString() + ' bytes');

  if (bytes.length < 44) {
    print('ERROR: File too small to be a valid WAV.');
    return;
  }

  // Basic WAV header parse
  final numChannels = bytes[22] | (bytes[23] << 8);
  final sampleRate = bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);
  final bitsPerSample = bytes[34] | (bytes[35] << 8);

  print('Channels: ' + numChannels.toString());
  print('Sample Rate: ' + sampleRate.toString() + ' Hz');
  print('Bits Per Sample: ' + bitsPerSample.toString());

  if (bitsPerSample != 32) {
    print('WARNING: Expected 32-bit Float WAV, got ' + bitsPerSample.toString() + ' bits.');
  }

  // Parse float samples
  final dataBytes = bytes.sublist(44);
  final floatList = Float32List.view(dataBytes.buffer, dataBytes.offsetInBytes, dataBytes.length ~/ 4);

  int nanCount = 0;
  int infCount = 0;
  int clipCount = 0;
  double maxVal = 0.0;
  double energy = 0.0;
  
  int count = floatList.length;

  for (int i = 0; i < count; i++) {
    double val = floatList[i];
    if (val.isNaN) {
      nanCount++;
    } else if (val.isInfinite) {
      infCount++;
    } else {
      double absVal = val.abs();
      if (absVal > 1.0) clipCount++;
      if (absVal > maxVal) maxVal = absVal;
      energy += absVal * absVal;
    }
  }

  double rms = 0.0;
  if (count > 0) {
      rms = energy / count;
  }

  print('\n--- DSP Analysis (' + count.toString() + ' samples) ---');
  print('Max Amplitude: ' + maxVal.toStringAsFixed(6));
  print('RMS Energy: ' + rms.toStringAsFixed(6));
  print('NaNs: ' + nanCount.toString());
  print('Infs: ' + infCount.toString());
  print('Over 1.0 (Clipping): ' + clipCount.toString());
  
  print('\nDIAGNOSIS:');
  if (nanCount > 0 || infCount > 0) {
      print('CRITICAL: Math explosion (NaN/Inf) detected in the Vocoder output.');
  } else if (clipCount > 10) {
      print('CRITICAL: Audio is severely clipping (Values > 1.0). The Vocoder overlap-add scale is wrong.');
  } else if (maxVal <= 0.000000) {
      print('CRITICAL: Audio is strictly mathematical 0.0. Complete digital silence.');
  } else if (maxVal < 0.0001) {
      print('WARNING: Audio contains values but is virtually silent (Max: ' + maxVal.toString() + '). Check amplitude scaling.');
  } else {
      print('Math looks clean. The amplitude does not explode. Issue might be phase distortion/flanging.');
  }
}
