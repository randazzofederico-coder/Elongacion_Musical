import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:native_audio_engine/live_mixer.dart';
import 'package:elongacion_musical/utils/wav_header_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioRenderer {
  final LiveMixer liveMixer;
  final int totalSamples;
  final int sampleRate;

  AudioRenderer({
    required this.liveMixer,
    required this.totalSamples,
    required this.sampleRate,
  });

  Future<File> render({Function(double)? onProgress}) async {
    final int headerSize = 44;
    final int numChannels = 2;
    
    final directory = await getTemporaryDirectory();
    final tempFile = File('${directory.path}/render_${DateTime.now().millisecondsSinceEpoch}.wav');
    final sink = tempFile.openWrite();

    // Escribimos header vacío de momento
    sink.add(Uint8List(headerSize));
    
    // Guardamos la posición del usuario en caso de estar sonando algo
    int originalPos = liveMixer.getPosition();
    
    liveMixer.seek(0);
    
    int currentFrame = 0;
    int samplesWritten = 0;
    const int chunkSize = 4096;
    
    try {
      while (currentFrame < totalSamples) {
          int framesToProcess = min(chunkSize, totalSamples - currentFrame);
          
          List<double> processed = liveMixer.process(framesToProcess);
          
          if (processed.isNotEmpty) {
             sink.add(floatToBytes(processed));
             samplesWritten += processed.length ~/ numChannels;
          } else {
             break; 
          }
          
          currentFrame += framesToProcess;
          
          if (onProgress != null) {
             onProgress((currentFrame / totalSamples).clamp(0.0, 1.0));
          }
          
          // Entregar control al UI cada tanto (no estancar el Event Loop)
          if (currentFrame % (chunkSize * 10) == 0) {
             await Future.delayed(Duration.zero);
          }
      }
    } finally {
        // Restaurar
        liveMixer.seek(originalPos);
    }
    
    await sink.close();
    
    // Reescribimos encima el Header final real con su filesize correcto
    final raf = await tempFile.open(mode: FileMode.append);
    await raf.setPosition(0);
    final header = buildWavHeader(samplesWritten, sampleRate, numChannels);
    await raf.writeFrom(header);
    await raf.close();

    return tempFile;
  }
}
