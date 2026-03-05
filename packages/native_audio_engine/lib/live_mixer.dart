import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'live_mixer_bindings.dart';

class LiveMixer {
  final LiveMixerBindings _bindings = LiveMixerBindings();
  late Pointer<Void> _handle;
  bool _isDisposed = false;

  LiveMixer() {
    _handle = _bindings.create();
  }

  void dispose() {
    if (!_isDisposed) {
      _bindings.destroy(_handle);
      _isDisposed = true;
    }
  }

  Pointer<WaveformData>? addTrack(String id, String filePath) {
    if (_isDisposed) return null;
    return _bindings.addTrack(_handle, id, filePath);
  }

  void freeWaveformData(Pointer<WaveformData> dataPtr) {
    _bindings.freeWaveformData(dataPtr);
  }

  void removeTrack(String id) {
    if (_isDisposed) return;
    _bindings.removeTrack(_handle, id);
  }

  void setVolume(String id, double volume) {
    if (_isDisposed) return;
    _bindings.setVolume(_handle, id, volume);
  }

  void setMasterVolume(double volume) {
    if (_isDisposed) return;
    _bindings.setMasterVolume(_handle, volume);
  }

  void setMasterMute(bool muted) {
    if (_isDisposed) return;
    _bindings.setMasterMute(_handle, muted);
  }

  void setMasterSolo(bool solo) {
    if (_isDisposed) return;
    _bindings.setMasterSolo(_handle, solo);
  }

  void setPan(String id, double pan) {
    if (_isDisposed) return;
    _bindings.setPan(_handle, id, pan);
  }

  void setMute(String id, bool muted) {
    if (_isDisposed) return;
    _bindings.setMute(_handle, id, muted);
  }

  void setSolo(String id, bool solo) {
    if (_isDisposed) return;
    _bindings.setSolo(_handle, id, solo);
  }

  void setLoop(int startSample, int endSample, bool enabled) {
    if (_isDisposed) return;
    _bindings.setLoop(_handle, startSample, endSample, enabled);
  }

  void seek(int positionSample) {
    if (_isDisposed) return;
    _bindings.seek(_handle, positionSample);
  }

  int getPosition() {
    if (_isDisposed) return 0;
    return _bindings.getPosition(_handle);
  }
  
  /// Process audio.
  /// [frames] is number of stereo frames to request.
  /// Returns a List<double> of interleaved samples (length = frames * 2).
  List<double> process(int frames) {
      if (_isDisposed) return List.filled(frames * 2, 0.0);
      
      final outputPtr = calloc<Float>(frames * 2);
      
      int filled = _bindings.process(_handle, outputPtr, frames);
      
      List<double> result = List<double>.filled(frames * 2, 0.0);
      for (int i = 0; i < frames * 2; i++) {
          result[i] = outputPtr[i];
      }
      
      calloc.free(outputPtr);
      return result;
  }
  
  // Method to allow filling an existing buffer if we want to avoid allocation thrashing?
  // Current Stream implementation in Dart usually yields new lists anyway.
  
  // --- NATIVE OUTPUT CONTROL ---
  void startPlayback() {
     if (_isDisposed) return;
     _bindings.start(_handle);
  }
  
  void stopPlayback() {
     if (_isDisposed) return;
     _bindings.stop(_handle);
  }
  
  int getAtomicPosition() {
     if (_isDisposed) return 0;
     return _bindings.getAtomicPosition(_handle);
  }
  
  void setSpeed(double speed) {
     if (_isDisposed) return;
     _bindings.setSpeed(_handle, speed);
  }
  
  void setSoundTouchSetting(int settingId, int value) {
     if (_isDisposed) return;
     _bindings.setSoundTouchSetting(_handle, settingId, value);
  }

  // --- METRONOME ---
  void setMetronomeConfig(int bpm) {
     if (_isDisposed) return;
     _bindings.setMetronomeConfig(_handle, bpm);
  }

  void setMetronomeSound(int type, Float32List data) {
     if (_isDisposed) return;
     _bindings.setMetronomeSound(_handle, type, data);
  }

  void addMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, double vol, bool mute, bool solo) {
      if (_isDisposed) return;
      _bindings.addMetronomePattern(_handle, id, flatPattern, subdivisions, vol, mute, solo);
  }

  void updateMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, double vol, bool mute, bool solo) {
      if (_isDisposed) return;
      _bindings.updateMetronomePattern(_handle, id, flatPattern, subdivisions, vol, mute, solo);
  }

  void removeMetronomePattern(int id) {
      if (_isDisposed) return;
      _bindings.removeMetronomePattern(_handle, id);
  }

  void clearMetronomePatterns() {
      if (_isDisposed) return;
      _bindings.clearMetronomePatterns(_handle);
  }

  void setMetronomePreviewMode(bool enabled) {
      if (_isDisposed) return;
      _bindings.setMetronomePreviewMode(_handle, enabled);
  }
}
