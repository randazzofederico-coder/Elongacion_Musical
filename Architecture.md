# PROYECTO: Elongación Musical (App Multipista Educativa)

## 1. TECH STACK & CONFIGURATION
- **Framework:** Flutter (Dart).
- **Core Goal:** A unified high-performance application running flawlessly across Android (APK), Windows (EXE), and eventually Web, all powered by the same deterministic C++ audio engine.
- **Audio Engine:** `just_audio` (Platform) + `native_audio_engine` (Custom C++ Plugin using Miniaudio & SoundTouch).
- **State Management:** `Provider`.
- **Assets:** Audio library migrated to M4A/AAC format in `assets/audio/` for extreme compression without padding artifacts. Decodes to `Float32` RAM arrays during playback initialization for zero-latency mixing. 
  - **Android/Linux:** Uses `ffmpeg_kit_flutter_new_audio` for temporary WAV cache extraction when OS decoding fails.
  - **Windows:** Uses a custom C++ integration with **Media Foundation** (`IMFSourceReader`) to natively extract Float PCM samples from compressed M4A files directly into the native engine.
  - **Web (Future Roadmap):** Targeting WebAssembly (Emscripten) compilation of the C++ engine to run flawlessly in-browser.
- **Content:** The application currently supports 4 complete educational Chapters, mapped dynamically via `CatalogService`, which handles both unified and split-soloist instrument definitions (e.g. `1a` and `1b` variations).
- **Repository:** [GitHub - Elongacion_Musical](https://github.com/randazzofederico-coder/Elongacion_Musical.git)
- **Status:** Connected and synced.

## 2. APP ARCHITECTURE & DIRECTORY STRUCTURE
The app uses a strict separation between UI components, state Providers, and Native C++ Audio integration to avoid monolithic files (following a < 200 lines per file standard where possible).

```
lib/
├── models/
│   ├── catalog_model.dart     # Definitions: Chapter, Exercise, TrackData
│   └── track_model.dart       # Volatile track state (Volume, Pan, Mute)
├── services/
│   ├── audio_manager.dart     # High-level audio playback and FFI coordinator
│   ├── mixer_stream_source.dart # just_audio custom source bridging
│   └── settings_service.dart  # Persists UI & Audio preferences locally
├── providers/
│   ├── mixer_provider.dart          # Main facade and State coordinator
│   ├── playback_provider.dart       # Play, Seek, Loop states
│   ├── track_list_provider.dart     # Track volumes, mute, solo states
│   ├── mixer_settings_provider.dart # Engine settings & UI toggles
│   └── theme_provider.dart          # Global Light/Dark mode state management
├── screens/
│   └── mixer_screen.dart      # Main mixing console layout
└── widgets/
    ├── mixer/                 # Granular UI components for the Mixer
    │   ├── channel_strip_container.dart # Shared base layout for strips
    │   ├── track_strip.dart      # Individual track styling
    │   ├── master_strip.dart     # Master fader styling
    │   └── transport_section.dart # Playback controls
    └── waveform/              # Audio visualization components
        ├── waveform_painter.dart
        └── waveform_interaction_controller.dart # Multi-touch & Zoom management
```

## 3. UI / UX ("Warm Premium Studio")
The design mimics classic analog hardware using dynamic responsive layouts.
- **Responsiveness Layout:** `MixerScreen` uses an `Expanded` `Row` to distribute tracks horizontally. It automatically hides waveforms on screens < 600px width to prioritize control access. To support narrow mobile screens (e.g., 320px), fixed-width constraints are strictly avoided in favor of `Expanded`, `Flexible`, and `FittedBox`, completely preventing horizontal `RenderFlex` overflow errors.
- **Orientation Strategy:** To ensure a predictable and robust mixing console experience on varying mobile form factors, the application globally enforces Portrait orientation (`portraitUp`, `portraitDown`) at startup via `SystemChrome`.
- **Pixel-Perfect Margins:** The application strictly enforces consistent lateral margins (`16px`) across unrelated screen components (`StudioHeader`, `TrackListSection`, `WaveformSeekBar`, `TransportSection`). This often requires mathematically neutralizing internal paddings of child widgets (e.g., dynamically offsetting a parent container's padding to cleanly account for a child's native margin).
- **Canvas Clipping:** Custom drawn elements (like `LoopRuler` using `CustomPaint`) are explicitly wrapped in `ClipRect` to prevent their rendering instructions from exceeding their designated layout boundaries during interactions like zoom or pan.
- **Mixer Strip Symmetry:** Strip layouts (Tracks vs Master) are strictly synchronized by confining their bottom control sections (knobs/buttons) to mathematically identical fixed-height containers (e.g., `110px`), allowing the `Expanded` faders above them to fluidly fill the remaining screen space in perfect symmetry without `RenderFlex` overflows.
- **Native Layout Bounds:** Avoids using `Transform.scale` for resizing layout-critical widgets (like `KnobControl`). Widgets must provide a native `size` property to ensure Flutter calculates their layout footprint accurately instead of drawing invisible padding bounds.
- **Dynamic Theming & Context-Aware Colors:** UI components utilize `AppColors.methodName(context)` instead of static colors. The application responds globally to Light/Dark Mode toggles routed through the `ThemeProvider` at the root of the app, ensuring seamless and state-driven aesthetic consistency.
- **Waveform Interaction:** `WaveformInteractionController` provides 1x-50x multi-touch pinch-to-zoom and two-finger pan on the master waveform.
- **Settings Persistence:** `SettingsService` automatically saves global variables (dark mode, layout) and exercise-specific variables (volumes, loop ranges, pans, mutes) individually keyed by Exercise ID via `SharedPreferences`.

## 4. AUDIO ENGINE (Native C++ Mixer)
Driven by a custom cross-platform C++ engine (`live_mixer.cpp`) connected to Dart via FFI, achieving "Zero-Copy" playback.
- **Data Flow:** M4A/AAC -> PCM RAM Buffer -> C++ LiveMixer -> DAC via Miniaudio.
  - `miniaudio` handles the raw audio device output and format conversion globally natively.
  - For proprietary compressed files like M4A on Windows, the engine intercepts the read command and taps into the native `mfplat`/`mfreadwrite` APIs to decode to RAM seamlessly.
  - **Web Playback:** Uses Emscripten to compile the C-API to WebAssembly (`live_mixer.wasm`). Overcomes Miniaudio format restrictions by offloading AAC/M4A/MP3 decoding to the browser's native `AudioContext.decodeAudioData`, passing the raw float PCM data into the Wasm Heap. Employs a modern HTML5 `AudioWorklet` inner-loop to pull processed frames directly from Wasm and drive the Web Output device on a dedicated background audio thread, achieving zero-latency playback immune to Flutter UI thread blockages. Uses `dart:js_interop` for seamless communication between the Flutter isolate and the AudioWorklet.
- **Mixing Pipeline:** `Tracks` -> `Master Fader (Layer 1)` -> `Stem Routing Layer (Metronome & Master)` -> `Time Stretch (SoundTouch)` -> `Miniaudio Output`.
- **Latency & Sync:** The Native engine drives an atomic frame counter. Dart polls this counter at 60fps via `Ticker` for sample-accurate UI synchronization. The native audio device is initialized as an "always-on" (hot) continuous stream at application startup, which provides zero-latency instant playback when the user toggles play/pause by outputting silence when paused, avoiding OS-level hardware initialization delays.
- **Time Stretching:** Standardized on `SoundTouch` (C++) compiled with maximum DSP optimizations (`-O3 -ffast-math`). Settings (Sequence, SeekWindow, Overlap) are configured real-time via `SettingsService`.
- **Dynamic Analytical Metronome:** C++ Math-driven software oscillator. No pre-rendered `.wav` files required. Dart passes complex 2D arrays (N-Pulses x M-Subdivisions) flattened via FFI pointers dynamically. Each instance tracks its own custom sequencer grids (e.g., 5/4 alongside 4/4). It features a robust text-input parsing system with a tailored Virtual Keyboard allowing users to define asymmetric structures (e.g., `3+2`) and fractional subdivisions (e.g., `1/3+2`) instantly.
- **Micro & Macro Visualization:** Uses a "Split-Cell" UI for subdivisions, maintaining a linear timeline by intelligently dividing pulse containers. The `MetronomeProvider` calculates the Least Common Multiple (LCM) of all asynchronous metronome tracks to establish a unified "Macro Cycle". A minimalist UI `Ticker` polls the C++ atomic engine frame-counter at 60fps to accurately trace playback progress across a miniaturized, anatomically correct global cycle bar.
- **Pop Prevention:** Every dynamic volume change (Mute/Solo/Play/Pause/Seek) uses an interpolated 20ms fade envelope to avoid hardware zero-crossing clicks.

## 5. REFACTORING GOALS & ROADMAP
- **Web Port & Unified Engine Synchronization (Completed):** The C++ `live_mixer` was successfully ported to WebAssembly (`live_mixer.wasm`) using `dart:js_interop` and `AudioWorklet`. The engine's API was updated to use IEEE-754 `double` standard types across all methods (e.g., `getAtomicPosition`, `seek`) to ensure flawless memory alignment between JavaScript/Wasm and Native Dart FFI.
- **Android/iOS FFI Stabilization (Completed):** Fixed critical architecture issues where Native Dart FFI incorrectly expected 64-bit integers (`Int64`) from the unified C++ engine instead of `Double`. This previously caused catastrophic IEEE-754 binary misinterpretations, making the playback engine jump to astronomical values and instantly stop tracks on mobile devices. FFI Signatures are now strictly bound to `Double`.
- **Decoupling Audio Engine from Flutter (Web):** Separate the audio engine execution from the main Flutter thread. Move audio processing entirely to Web Workers and AudioWorklets to ensure that heavy Flutter UI renders or Dart garbage collection do not block or interfere with the audio processing chain (preventing audio dropouts or glitches).
- **C++ Engine Refactor:** `packages/native_audio_engine/src/live_mixer.cpp` is a powerful but monolithic file (~800 lines). Future steps involve separating this into smaller classes (`TrackManager`, `MetronomeGenerator`, `StretcherContext`).
- **Dart Refactor:** `AudioManager.dart` (~485 lines) and `MixerStreamSource.dart` (>300 lines) combine stream logic with heavy playback and metronome configuration. These need logical division to follow the strict project standards.
- **Platform Focus:** Continued optimization testing on Android for low-latency touch interactions and responsiveness down to ~40ms.

## 6. WEB PERFORMANCE OPTIMIZATIONS

The web build (CanvasKit renderer) exhibits inherent overhead vs native builds due to WebAssembly rendering, DOM virtual layer, and slower GC. The following optimizations bring the mixer UI to near-native responsiveness.

### Phase 1: Global Widget Optimization

| Fix | File(s) | Description |
|-----|---------|-------------|
| `shouldRepaint` | `vertical_waveform.dart`, `waveform_painter.dart` | Was always returning `true`. Now compares `progress`, `data`, `gain`, `color`. |
| Ticker → ValueNotifier | `metronome_screen.dart`, `waveform_seek_bar.dart` | Replaced `setState()` at 60fps with `ValueNotifier` + `ValueListenableBuilder`, scoping rebuilds to only the playhead widget. |
| Selector | `transport_section.dart`, `mixer_screen.dart` | Replaced `context.watch<MixerProvider>()` with granular `Selector` (e.g., `isPlaying`, `isLooping`). |
| AnimatedContainer → Container | `transport_section.dart`, `track_controls.dart` | Removed implicit animation tickers (200ms blur interpolation) on web. |
| BoxShadow kIsWeb | `channel_strip_container.dart`, `transport_section.dart`, `waveform_seek_bar.dart` | Conditionally disabled `BoxShadow` blur on web. Native retains full visual fidelity. |

### Phase 2: Mixer Rebuild Cascade Elimination

| Fix | File(s) | Description |
|-----|---------|-------------|
| Granular Selector for WaveformSeekBar | `mixer_screen.dart` | Added `isPlaying` to Selector to ensure playhead Ticker starts on Play. |
| MasterSection Selector | `master_section.dart` | Replaced `ListenableBuilder(Listenable.merge(tracks))` with `Selector` on master-specific fields only, preventing cascade rebuilds from track fader drags. |
| RepaintBoundary isolation | `track_strip.dart` | Wrapped `VerticalWaveform` and `TrackControls` in `RepaintBoundary` to isolate repaint regions. |
| FaderPainter GPU optimization | `fader_control.dart` | Web: flat color instead of `LinearGradient.createShader()`, no `MaskFilter.blur()`, no `drawShadow`. Native retains premium look. |
| Text Shadow guard | `track_controls.dart` | Guarded text `Shadow` with `kIsWeb` to avoid blur computations. |

### Phase 3: Local Drag State Pattern

The critical architectural change for snappy fader interaction:

| Fix | File(s) | Description |
|-----|---------|-------------|
| Local drag state (FaderControl) | `fader_control.dart` | During drag, uses `_dragVolume` with local `setState()` for instant visual feedback, completely decoupled from `TrackModel.notifyListeners()` cascade. |
| Local drag state (KnobControl) | `knob_control.dart` | Same pattern with `_dragValue` for pan knob. |
| Direct-to-native methods | `audio_manager.dart`, `track_list_provider.dart`, `mixer_provider.dart` | `setTrackVolumeDirect()`, `setTrackPanDirect()`, `setMasterVolumeDirect()` send to C++ engine only, bypassing `TrackModel.volume` setter (which fires `notifyListeners`). Full model sync happens on drag end. |
| ClipRRect optimization | `channel_strip_container.dart` | Uses `Clip.hardEdge` instead of default `Clip.antiAlias` for cheaper GPU clipping. |

**Before:** `Fader drag → track.volume = vol → notifyListeners → ListenableBuilder → rebuild ChannelStripContainer + VerticalWaveform + TrackControls (every pixel)`
**After:** `Fader drag → local setState (instant) + setVolumeDirect (audio only) → ZERO widget rebuilds`

### Phase 4: Real-Time Waveform Visualization

Waveform rendering during fader interaction uses cached paths and GPU-level transforms:

| Component | Technique | Cost |
|-----------|-----------|------|
| **Track waveforms** | Base `Path` cached at `gain=1.0` (built once on load). Gain applied via `canvas.scale(gain, 1.0)` — a single GPU transform. | O(1) per frame |
| **Master waveform** | Weighted sum of all tracks' peak data, recomputed on commit. Same cached Path + `canvas.scale` for master gain. | O(tracks × points) on commit only |
| **Live gain bridge** | `ValueNotifier<double>` owned by `TrackStrip`/`MasterStrip`. FaderControl writes, VerticalWaveform reads via `CustomPainter(repaint: notifier)`. | Zero widget rebuilds |
| **Downsampling** | If waveform data has more points than available pixels, reduces using peak-per-bucket bucketing (e.g., 2000 → 400 vertices). | One-time on cache build |

**Architecture:** `VerticalWaveform` is a `StatefulWidget` that caches `_ChannelPathInfo` (Path + centerX). The `_ScaledWaveformPainter` reads `gainNotifier?.value` live in `paint()` via a getter — when the notifier fires, only `paint()` re-executes with the new gain value, no widget rebuild occurs.