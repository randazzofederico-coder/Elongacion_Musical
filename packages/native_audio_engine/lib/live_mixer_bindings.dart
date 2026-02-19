import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Type definitions
typedef LiveMixerCreateC = Pointer<Void> Function();
typedef LiveMixerCreateDart = Pointer<Void> Function();

typedef LiveMixerDestroyC = Void Function(Pointer<Void>);
typedef LiveMixerDestroyDart = void Function(Pointer<Void>);

typedef LiveMixerAddTrackC = Void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Float>, Int32, Int32);
typedef LiveMixerAddTrackDart = void Function(Pointer<Void>, Pointer<Utf8>, Pointer<Float>, int, int);

typedef LiveMixerRemoveTrackC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef LiveMixerRemoveTrackDart = void Function(Pointer<Void>, Pointer<Utf8>);

typedef LiveMixerSetVolumeC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef LiveMixerSetVolumeDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef LiveMixerSetPanC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef LiveMixerSetPanDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef LiveMixerSetMuteC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef LiveMixerSetMuteDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef LiveMixerSetSoloC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef LiveMixerSetSoloDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef LiveMixerSetLoopC = Void Function(Pointer<Void>, Int64, Int64, Bool);
typedef LiveMixerSetLoopDart = void Function(Pointer<Void>, int, int, bool);

typedef LiveMixerSeekC = Void Function(Pointer<Void>, Int64);
typedef LiveMixerSeekDart = void Function(Pointer<Void>, int);

typedef LiveMixerGetPositionC = Int64 Function(Pointer<Void>);
typedef LiveMixerGetPositionDart = int Function(Pointer<Void>);

typedef LiveMixerProcessC = Int32 Function(Pointer<Void>, Pointer<Float>, Int32);
typedef LiveMixerProcessDart = int Function(Pointer<Void>, Pointer<Float>, int);

class LiveMixerBindings {
  late DynamicLibrary _lib;
  
  late LiveMixerCreateDart _create;
  late LiveMixerDestroyDart _destroy;
  late LiveMixerAddTrackDart _addTrack;
  late LiveMixerRemoveTrackDart _removeTrack;
  late LiveMixerSetVolumeDart _setVolume;
  late LiveMixerSetPanDart _setPan;
  late LiveMixerSetMuteDart _setMute;
  late LiveMixerSetSoloDart _setSolo;
  late LiveMixerSetLoopDart _setLoop;
  late LiveMixerSeekDart _seek;
  late LiveMixerGetPositionDart _getPosition;
  late LiveMixerProcessDart _process;

  LiveMixerBindings() {
      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('native_audio_engine_plugin.dll');
      } else if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libnative_audio_engine_plugin.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process(); 
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('native_audio_engine_plugin.framework/native_audio_engine_plugin');
      } else {
        // Fallback or throw?
        // Try linking to process for Linux/etc if loaded implicitly
        try {
             _lib = DynamicLibrary.process();
        } catch (_) {
             throw UnsupportedError('Unsupported platform or library not found');
        }
      }

      _create = _lib.lookupFunction<LiveMixerCreateC, LiveMixerCreateDart>('live_mixer_create');
      _destroy = _lib.lookupFunction<LiveMixerDestroyC, LiveMixerDestroyDart>('live_mixer_destroy');
      _addTrack = _lib.lookupFunction<LiveMixerAddTrackC, LiveMixerAddTrackDart>('live_mixer_add_track');
      _removeTrack = _lib.lookupFunction<LiveMixerRemoveTrackC, LiveMixerRemoveTrackDart>('live_mixer_remove_track');
      _setVolume = _lib.lookupFunction<LiveMixerSetVolumeC, LiveMixerSetVolumeDart>('live_mixer_set_volume');
      _setPan = _lib.lookupFunction<LiveMixerSetPanC, LiveMixerSetPanDart>('live_mixer_set_pan');
      _setMute = _lib.lookupFunction<LiveMixerSetMuteC, LiveMixerSetMuteDart>('live_mixer_set_mute');
      _setSolo = _lib.lookupFunction<LiveMixerSetSoloC, LiveMixerSetSoloDart>('live_mixer_set_solo');
      _setLoop = _lib.lookupFunction<LiveMixerSetLoopC, LiveMixerSetLoopDart>('live_mixer_set_loop');
      _seek = _lib.lookupFunction<LiveMixerSeekC, LiveMixerSeekDart>('live_mixer_seek');
      _getPosition = _lib.lookupFunction<LiveMixerGetPositionC, LiveMixerGetPositionDart>('live_mixer_get_position');
      _process = _lib.lookupFunction<LiveMixerProcessC, LiveMixerProcessDart>('live_mixer_process');
  }

  Pointer<Void> create() => _create();
  void destroy(Pointer<Void> handle) => _destroy(handle);
  
  void addTrack(Pointer<Void> mixer, String id, List<double> data, int channels) {
      final idPtr = id.toNativeUtf8();
      
      final dataPtr = calloc<Float>(data.length);
      for (int i=0; i<data.length; i++) {
          dataPtr[i] = data[i];
      }
      
      _addTrack(mixer, idPtr, dataPtr, data.length, channels);
      
      calloc.free(dataPtr);
      calloc.free(idPtr);
  }

  // --- OPTIMIZED FLOAT32 PATH ---
  void addTrackFloat32(Pointer<Void> mixer, String id, Float32List data, int channels) {
      final idPtr = id.toNativeUtf8();
      
      // Get pointer directly from Float32List?
      // No, Dart TypedData is not directly a pointer in FFI without `ffi` package helpers or careful casting.
      // Easiest is using `calloc` again? NO, that defeats the purpose.
      // We want to scope the pointer. 
      // ACTUALLY: FFI's `Allocator` or `Arena` is good, but here we just need to pass the pointer.
      // If we use `calloc`, we copy.
      // If the C++ side copies immediately (which it does: `vector::assign`), we just need a temporary pointer.
      
      // Best way in Dart FFI to get Pointer<Float> from Float32List WITHOUT copying?
      // Use `calloc` and `asTypedList`? No.
      // Use `malloc` from `ffi`?
      
      // WAIT. If we want AVOID copy, we need `data.address`? Dart GC might move it.
      // Safe way: Allocate natively once, and assume C++ copies it.
      
      // Optimization: We still need to copy from Dart Heap (Float32List) to Native Heap (Pointer<Float>).
      // BUT `Float32List` to `Pointer<Float>` copy is faster than `List<double>` to `Pointer<Float>` loop.
      
      final ptr = calloc<Float>(data.length);
      final list = ptr.asTypedList(data.length); 
      list.setAll(0, data); // Fast memcpy
      
      _addTrack(mixer, idPtr, ptr, data.length, channels);
      
      calloc.free(ptr);
      calloc.free(idPtr);
  }
  
  void removeTrack(Pointer<Void> mixer, String id) {
      final idPtr = id.toNativeUtf8();
      _removeTrack(mixer, idPtr);
      calloc.free(idPtr);
  }

  void setVolume(Pointer<Void> mixer, String id, double volume) {
      final idPtr = id.toNativeUtf8();
      _setVolume(mixer, idPtr, volume);
      calloc.free(idPtr);
  }
  
  void setPan(Pointer<Void> mixer, String id, double pan) {
      final idPtr = id.toNativeUtf8();
      _setPan(mixer, idPtr, pan);
      calloc.free(idPtr);
  }

  void setMute(Pointer<Void> mixer, String id, bool muted) {
      final idPtr = id.toNativeUtf8();
      _setMute(mixer, idPtr, muted);
      calloc.free(idPtr);
  }

  void setSolo(Pointer<Void> mixer, String id, bool solo) {
      final idPtr = id.toNativeUtf8();
      _setSolo(mixer, idPtr, solo);
      calloc.free(idPtr);
  }

  void setLoop(Pointer<Void> mixer, int start, int end, bool enabled) {
      _setLoop(mixer, start, end, enabled);
  }
  
  void seek(Pointer<Void> mixer, int position) {
      _seek(mixer, position);
  }

  int getPosition(Pointer<Void> mixer) {
      return _getPosition(mixer);
  }

  // Returns number of frames provided in output (which should be pre-allocated).
  int process(Pointer<Void> mixer, Pointer<Float> output, int frames) {
      return _process(mixer, output, frames);
  }
  
  // --- NATIVE OUTPUT BINDINGS ---
  late final _start = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('live_mixer_start');
  late final _stop = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('live_mixer_stop');
  late final _getAtomicPosition = _lib.lookupFunction<Int64 Function(Pointer<Void>), int Function(Pointer<Void>)>('live_mixer_get_atomic_position');

  void start(Pointer<Void> mixer) => _start(mixer);
  void stop(Pointer<Void> mixer) => _stop(mixer);
  int getAtomicPosition(Pointer<Void> mixer) => _getAtomicPosition(mixer);
}
