import 'dart:typed_data';
import 'package:native_audio_engine/soundtouch_processor.dart';
import 'package:wav/wav.dart';

class AudioProcessor {
  final SoundTouchProcessor _soundTouch = SoundTouchProcessor();
  
  // Settings
  double _tempo = 1.0;
  double _pitch = 1.0;
  
  AudioProcessor() {
    // Default setup
    _soundTouch.setChannels(2);
    _soundTouch.setSampleRate(44100);
  }
  
  void setTempo(double tempo) {
    _tempo = tempo;
    _soundTouch.setTempo(tempo);
  }
  
  void setPitch(double pitch) {
    _pitch = pitch;
    _soundTouch.setPitch(pitch);
  }

  void setChannels(int channels) {
    _soundTouch.setChannels(channels);
  }

  void setSampleRate(int sampleRate) {
    _soundTouch.setSampleRate(sampleRate);
  }
  
  void clear() {
    _soundTouch.clear();
  }
  
  void dispose() {
    _soundTouch.dispose();
  }
  
  /// Processes a chunk of interleaved stereo float samples.
  /// Returns processed samples.
  List<double> process(List<double> input) {
    if ((_tempo - 1.0).abs() < 0.001 && (_pitch - 1.0).abs() < 0.001) {
       return input;
    }
    return _soundTouch.process(input, 2);
  }
  
  /// Helper to convert ByteData (WAV bytes) to Float List
  /// Note: This is expensive if done on UI thread. Should be in Isolate.
  static List<double> bytesToFloat(Uint8List bytes) {
    // Determine bit depth/format from header?
    // Assume 16-bit PCM for now (standard).
    final data = ByteData.view(bytes.buffer);
    final List<double> floats = [];
    
    for (int i = 0; i < bytes.length; i += 2) {
      int sample = data.getInt16(i, Endian.little);
      floats.add(sample / 32768.0);
    }
    
    return floats;
  }
  
  /// Helper to convert Float List back to ByteData (16-bit PCM)
  static Uint8List floatToBytes(List<double> samples) {
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
}
