import 'dart:io';
import 'dart:typed_data';
import 'package:wav/wav.dart';

void main() async {
  final filesToMono = [
    'assets/audio/Duo 1/ample_bass.wav',
    'assets/audio/Duo 1/bombo.wav', // Bombo Out
    'assets/audio/Duo 1/fl1.wav',
    'assets/audio/Duo 1/fl2.wav',
  ];

  final fileToDelete = 'assets/audio/Duo 1/bombo_1.wav'; // Bombo In

  print('Starting Audio Optimization...');

  // 1. Convert to Mono
  for (final path in filesToMono) {
    try {
      final file = File(path);
      if (!await file.exists()) {
        print('File not found: $path');
        continue;
      }

      print('Processing $path...');
      final bytes = await file.readAsBytes();
      final wav = Wav.read(bytes);

      if (wav.channels.length == 1) {
        print(' - Already Mono. Skipping.');
        continue;
      }

      print(' - Converting Stereo to Mono...');
      final left = wav.channels[0];
      final right = wav.channels[1];
      final mono = Float64List(left.length);

      for (int i = 0; i < left.length; i++) {
        mono[i] = (left[i] + right[i]) / 2.0;
      }

      // Create new Mono Wav
      final newWav = Wav(
        [mono], 
        wav.samplesPerSecond, 
        wav.format,
      );

      // Overwrite
      final newBytes = newWav.write();
      await file.writeAsBytes(newBytes);
      print(' - Saved as Mono. New size: ${(newBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

    } catch (e) {
      print('Error processing $path: $e');
    }
  }

  // 2. Delete unused
  try {
     final delFile = File(fileToDelete);
     if (await delFile.exists()) {
       print('Deleting unused file: $fileToDelete');
       await delFile.delete(); // Or rename to .bak if safer? User said delete.
       print(' - Deleted.');
     } else {
       print('File to delete not found: $fileToDelete');
     }
  } catch (e) {
     print('Error deleting file: $e');
  }

  print('Optimization Complete.');
}
