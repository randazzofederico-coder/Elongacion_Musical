
import 'dart:io';
import 'dart:typed_data';
import 'package:wav/wav.dart';

void main() async {
  final dir = Directory('assets/audio/instrumento/capitulo_1');
  if (!await dir.exists()) {
    print('Directory not found: ${dir.path}');
    return;
  }

  print('Scanning ${dir.path} for mono conversion candidates...');

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.wav')) {
      final filename = entity.uri.pathSegments.last.toLowerCase();
      
      // Skip Piano - it should remain stereo
      if (filename == 'piano.wav') {
        print('Skipping Piano (Stereo): ${entity.path}');
        continue;
      }

      try {
        await _processFile(entity);
      } catch (e) {
        print('Error processing ${entity.path}: $e');
      }
    }
  }
  print('Conversion complete.');
}

Future<void> _processFile(File file) async {
  final wav = await Wav.readFile(file.path);
  
  // Check if already mono
  if (wav.channels.length == 1) {
    // print('Already Mono: ${file.path}');
    return;
  }

  print('Converting to Mono: ${file.path} (${wav.channels.length} channels)');

  // Mix down to mono
  final int numSamples = wav.channels[0].length;
  final monoChannel = Float64List(numSamples);

  for (int i = 0; i < numSamples; i++) {
    double sum = 0;
    for (int c = 0; c < wav.channels.length; c++) {
      sum += wav.channels[c][i];
    }
    monoChannel[i] = sum / wav.channels.length;
  }

  // Create new Wav object
  final newWav = Wav(
    [monoChannel], 
    wav.samplesPerSecond,
    wav.format,
  );

  // Overwrite file
  await newWav.writeFile(file.path);
  print('  -> Saved.');
}
