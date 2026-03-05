import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:native_audio_engine/live_mixer.dart';
import 'package:elongacion_musical/utils/wav_header_utils.dart';

class MetronomeStreamSource extends StreamAudioSource {
  final LiveMixer _liveMixer;
  final int sampleRate = 44100;
  final int _numChannels = 2;
  final int _bytesPerSample = 2; 

  MetronomeStreamSource(this._liveMixer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    
    // Very large virtual size (24 hours of audio)
    final int totalSamples = sampleRate * 3600 * 24;
    final int sourceFileSize = 44 + (totalSamples * _numChannels * _bytesPerSample); 

    if (end == null || end > sourceFileSize) {
       end = sourceFileSize;
    }

    final stream = _generateParams(start, end, totalSamples);

    return StreamAudioResponse(
      sourceLength: sourceFileSize,
      contentLength: (end - start),
      offset: start,
      stream: stream,
      contentType: 'audio/wav',
    );
  }

  Stream<List<int>> _generateParams(int startByte, int? endByte, int totalSamples) async* {
     int offset = startByte;

     if (offset < 44) {
        final header = buildWavHeader(totalSamples, sampleRate, _numChannels);
        int headerEnd = header.length;
        if (endByte != null) headerEnd = min(header.length, endByte);

        int headerLen = headerEnd - offset;
        yield header.sublist(offset, headerEnd);
        offset += headerLen;
     }

     try {
       while (endByte == null || offset < endByte) {
          int inputFramesNeeded = 1024;
          List<double> mixedChunk = _liveMixer.process(inputFramesNeeded);

          if (mixedChunk.isNotEmpty) {
             Uint8List outputBytes = _floatToBytes(mixedChunk);

             if (endByte != null) {
                int remaining = endByte - offset;
                if (outputBytes.length > remaining) {
                   final sub = outputBytes.sublist(0, remaining);
                   yield sub;
                   offset += remaining;
                   break;
                }
             }

             yield outputBytes;
             offset += outputBytes.length;
          } else {
             // Avoid busy-waiting if native engine bugs out
             await Future.delayed(const Duration(milliseconds: 10));
          }
       }
     } catch (e) {
        debugPrint("Metronome Generate error: \$e");
     }
  }

  Uint8List _floatToBytes(List<double> floatData) {
     final byteData = ByteData(floatData.length * 2);
     for (int i = 0; i < floatData.length; i++) {
         int sample = (floatData[i] * 32767).round().clamp(-32768, 32767);
         byteData.setInt16(i * 2, sample, Endian.little);
     }
     return byteData.buffer.asUint8List();
  }
}
