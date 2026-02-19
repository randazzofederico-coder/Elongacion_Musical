import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:elongacion_musical/services/audio_processor.dart';
import 'package:elongacion_musical/services/mixer_stream_source.dart';
import 'package:elongacion_musical/utils/wav_header_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioRenderer {
  final List<TrackModel> tracks;
  final int totalSamples;
  final int sampleRate;
  final double tempo;
  final double masterVolume;

  AudioRenderer({
    required this.tracks,
    required this.totalSamples,
    required this.sampleRate,
    required this.tempo,
    required this.masterVolume,
  });

  Future<File> render({Function(double)? onProgress}) async {
    // Basic WAV header size
    final int headerSize = 44;
    final int numChannels = 2;
    final int bytesPerSample = 2;
    
    // Create temporary file
    final directory = await getTemporaryDirectory();
    final tempFile = File('${directory.path}/render_${DateTime.now().millisecondsSinceEpoch}.wav');
    final sink = tempFile.openWrite();

    // Write placeholder header
    sink.add(Uint8List(headerSize));

    final AudioProcessor processor = AudioProcessor();
    processor.setChannels(numChannels);
    processor.setSampleRate(sampleRate);
    processor.setTempo(tempo);
    
    int currentFrame = 0;
    int samplesWritten = 0;
    
    // Processing chunk size (larger is faster for offline)
    const int chunkSize = 4096;
    
    final List<double> mixBuffer = List.filled(chunkSize * numChannels, 0.0);

    // Pre-calculate track gains
    final List<double> trackLeftGains = List.filled(tracks.length, 0.0);
    final List<double> trackRightGains = List.filled(tracks.length, 0.0);
    final List<bool> trackActive = List.filled(tracks.length, false);
    
    bool anySolo = tracks.any((t) => t.isSolo);

    for (int t = 0; t < tracks.length; t++) {
       final track = tracks[t];
       if (track.isMuted) continue;
       if (anySolo && !track.isSolo) continue;
       if (track.samples == null || track.samples!.isEmpty) continue;
       
       trackActive[t] = true;
       double lGain = 1.0, rGain = 1.0;
       if (track.pan > 0) lGain = 1.0 - track.pan;
       else if (track.pan < 0) rGain = 1.0 + track.pan;
       
       trackLeftGains[t] = track.volume * lGain;
       trackRightGains[t] = track.volume * rGain;
    }

    try {
      while (currentFrame < totalSamples) {
        int framesToProcess = min(chunkSize, totalSamples - currentFrame);
        
        // Zero out mix buffer
        mixBuffer.fillRange(0, framesToProcess * numChannels, 0.0);
        
        // Mix tracks
        for (int i = 0; i < framesToProcess; i++) {
            int frameOffset = currentFrame + i;
            double left = 0.0;
            double right = 0.0;
            
            for (int t = 0; t < tracks.length; t++) {
              if (!trackActive[t]) continue;
              
              final track = tracks[t];
               if (frameOffset >= track.samples![0].length) continue; // Should check length safely
               
               double valL = track.samples![0][frameOffset];
               double valR = (track.samples!.length > 1) ? track.samples![1][frameOffset] : valL;

               left += valL * trackLeftGains[t];
               right += valR * trackRightGains[t];
            }
            
            mixBuffer[i * 2] = left * masterVolume;
            mixBuffer[i * 2 + 1] = right * masterVolume;
        }
        
        // Time Stretch Processing
        List<double> inputSlice = mixBuffer;
        if (framesToProcess < chunkSize) {
            inputSlice = mixBuffer.sublist(0, framesToProcess * numChannels);
        }
        
        List<double> processed = processor.process(inputSlice);
        
        if (processed.isNotEmpty) {
           sink.add(AudioProcessor.floatToBytes(processed));
           samplesWritten += processed.length ~/ numChannels;
        }
        
        currentFrame += framesToProcess;
        
        if (onProgress != null) {
           onProgress(currentFrame / totalSamples);
        }
        
        // Yield to event loop occasionally to allow progress UI updates
        if (currentFrame % (chunkSize * 10) == 0) {
           await Future.delayed(Duration.zero);
        }
      }
      
      // Flush processor
      // processor.flush()? SoundTouch might have residual samples.
      // For now we assume process() extracts most. 
      // If we needed perfect tail, we'd feed empty samples until output stops.
      
    } finally {
      processor.dispose();
    }
    
    await sink.close();
    
    // Re-open to write correct header
    final raf = await tempFile.open(mode: FileMode.append); // RandomAccessFile
    await raf.setPosition(0);
    final header = buildWavHeader(samplesWritten, sampleRate, numChannels);
    await raf.writeFrom(header);
    await raf.close();

    return tempFile;
  }
}
