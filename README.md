# Elongación Musical

**Elongación Musical** is a specialized practice application designed to help musicians improve their rhythmic and instrumental skills through interactive exercises. It features a custom high-performance audio engine for precise timing and low-latency playback.

## Key Features

### 🎚️ Multi-track Audio Mixer
Take full control of your practice session with a professional-grade mixer interface:
- **Volume & Pan**: Adjust levels and stereo positioning for each track independently.
- **Mute & Solo**: Isolate specific instruments or rhythmic elements to focus on defined parts.
- **Custom Mixes**: Create the perfect balance for your practice needs.

### ⏱️ Advanced Practice Tools
- **Variable Speed Playback**: Slow down challenging passages without altering pitch, allowing for gradual tempo increases as you master the material.
- **Looping**: Select specific sections of an exercise to repeat continuously, perfect for drilling difficult measures.

### 📚 Structured Curriculum
The application is organized into progressive chapters to guide your development:
- **Rhythm Chapters**: Focus on timing, subdivision, and complex polyrhythms.
- **Instrument Chapters**: Apply rhythmic concepts to your instrument with melodic and harmonic exercises.

### 🚀 High-Performance Audio
Built on top of a custom C++ **Native Audio Engine**, Elongación Musical delivers:
- Sample-accurate synchronization.
- Ultra-low latency response.
- Stable playback even under heavy processing loads.

## Getting Started

### Prerequisites
- **Flutter SDK**: Ensure you have the latest stable version of Flutter installed.
- **C++ Build Tools**:
  - **Windows**: Visual Studio with C++ desktop development workload.
  - **Android**: Android NDK and CMake (manageable via Android Studio SDK Manager).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/elongacion_musical.git
   cd elongacion_musical
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # For Windows
   flutter run -d windows

   # For Android
   flutter run -d android
   ```

## Development

This project uses a hybrid architecture with Flutter for the UI and C++ for the audio engine.
- **Dart/Flutter code**: Located in `lib/`
- **Native Audio Engine**: Located in `packages/native_audio_engine/`

## License
[Insert License Here]
