import 'dart:typed_data';

/// Helper to build a standard WAV header.
Uint8List buildWavHeader(int samples, int sampleRate, int numChannels) {
   int bytesPerSample = 2;
   final buffer = Uint8List(44);
   final view = ByteData.view(buffer.buffer);
   int dataSize = samples * numChannels * bytesPerSample;
   // Max file size for streaming (large number)
   int fileSize = 36 + dataSize;
   view.setUint32(0, 0x52494646, Endian.big); 
   view.setUint32(4, fileSize, Endian.little);
   view.setUint32(8, 0x57415645, Endian.big); 
   view.setUint32(12, 0x666d7420, Endian.big); 
   view.setUint32(16, 16, Endian.little); 
   view.setUint16(20, 1, Endian.little); 
   view.setUint16(22, numChannels, Endian.little);
   view.setUint32(24, sampleRate, Endian.little);
   view.setUint32(28, sampleRate * numChannels * bytesPerSample, Endian.little); 
   view.setUint16(32, numChannels * bytesPerSample, Endian.little); 
   view.setUint16(34, 16, Endian.little); 
   view.setUint32(36, 0x64617461, Endian.big); 
   view.setUint32(40, dataSize, Endian.little);
   return buffer;
}

/// Converts a list of floats [-1.0, 1.0] to a 16-bit PCM byte array for WAV.
Uint8List floatToBytes(List<double> samples) {
    final buffer = Uint8List(samples.length * 2);
    final view = ByteData.view(buffer.buffer);
    for (int i = 0; i < samples.length; i++) {
        double val = samples[i];
        if (val > 1.0) val = 1.0;
        else if (val < -1.0) val = -1.0;
        view.setInt16(i * 2, (val * 32767).toInt(), Endian.little);
    }
    return buffer;
}
