import 'dart:ffi';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:native_audio_engine/live_mixer.dart';
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';

void initializeMixerTracks(LiveMixer mixer, List<TrackModel> tracks) {
    debugPrint("MixerUtils: Initializing Native Mixer with ${tracks.length} tracks (Float32 Optimized)");
    for (var track in tracks) {
        if (track.samples != null && track.samples!.isNotEmpty) {
           
           int channels = track.samples!.length;
           
           // Direct Float32List handling for MEMORY OPTIMIZATION.
           // Note: LiveMixerBindings now expects us to handle pointers or TypedLists more efficiently.
           
           if (channels == 1) {
               // MONO: Direct Pass
               // The samples[0] is already Float32List.
               mixer.addTrackFloat32(track.id, track.samples![0], 1);
           } else {
               // STEREO: Interleave
               // Unfortunate copy, but necessary for mixing. 
               // However, we can create a single Float32List for the interleaved data.
               
               int len = track.samples![0].length;
               final interleaved = Float32List(len * 2);
               
               for (int i=0; i<len; i++) {
                   interleaved[i*2] = track.samples![0][i];
                   interleaved[i*2+1] = track.samples![1][i];
               }
               
               mixer.addTrackFloat32(track.id, interleaved, 2);
           }
           
           mixer.setVolume(track.id, track.volume);
           mixer.setPan(track.id, track.pan);
           mixer.setMute(track.id, track.isMuted);
           mixer.setSolo(track.id, track.isSolo);
        }
    }
    debugPrint("MixerUtils: Native Tracks Initialized");
}

/// Helper to convert Float List back to ByteData (16-bit PCM)
Uint8List floatToBytes(List<double> samples) {
  final buffer = Uint8List(samples.length * 2);
  final view = ByteData.view(buffer.buffer);
  
  for (int i = 0; i < samples.length; i++) {
      double s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      
      int pcm = (s * 32767).toInt();
      view.setInt16(i * 2, pcm, Endian.little);
  }
  
  return buffer;
}
