import sys
import numpy as np
import wave
import time

def read_wav(filename):
    with wave.open(filename, 'rb') as wf:
        sr = wf.getframerate()
        channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        n_frames = wf.getnframes()
        raw_data = wf.readframes(n_frames)
        
        if sampwidth == 2:
            data = np.frombuffer(raw_data, dtype=np.int16).astype(np.float32) / 32768.0
        elif sampwidth == 3: # 24-bit support
            raw_bytes = np.frombuffer(raw_data, dtype=np.uint8).reshape(-1, 3)
            padded = np.zeros((raw_bytes.shape[0], 4), dtype=np.uint8)
            padded[:, 1:] = raw_bytes 
            data = padded.view(np.int32).astype(np.float32) / 2147483648.0
        elif sampwidth == 4:
            data = np.frombuffer(raw_data, dtype=np.float32)
        else:
            raise ValueError(f"Unsupported bit depth: {sampwidth*8} bits")
            
        if channels == 2:
            data = data.reshape(-1, 2)
        else:
            data = data.reshape(-1, 1)
            
        return data, sr, channels

def write_wav(filename, data, sr):
    data = np.clip(data, -1.0, 1.0)
    data_int16 = (data * 32767.0).astype(np.int16)
    
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(data.shape[1])
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(data_int16.tobytes())

# --- WSOLA TIME-STRETCHING ---
# WSOLA (Waveform Similarity Overlap-Add) preserves transients much better than 
# a simple Phase Vocoder for percussive music. It avoids the "metallic" / "phasiness" sound.
# --- TRANSIENT-PRESERVING PHASE VOCODER ---
# A hybrid approach: Pure Phase Vocoder for tonal parts, but forces phase-alignment
# (phase reset) when a percussive hit (transient) is detected.
def phase_vocoder(audio, stretch_factor, n_fft=2048):
    hop_length_out = n_fft // 4
    hop_length_in = int(hop_length_out * stretch_factor)
    
    window = np.hanning(n_fft)
    
    # Pad audio to avoid boundary clicks
    padded_audio = np.pad(audio, ((n_fft, n_fft), (0, 0)), mode='constant')
    channels = audio.shape[1]
    
    k_bins = np.arange(n_fft)
    expected_phase_advance = 2.0 * np.pi * k_bins * hop_length_in / n_fft
    
    out_length = int(len(audio) / stretch_factor) + n_fft*2
    out_audio = np.zeros((out_length, channels), dtype=np.float32)
    
    for ch in range(channels):
        in_ch_data = padded_audio[:, ch]
        out_ch_data = out_audio[:, ch]
        
        # Pre-calculate framing
        num_frames = (len(in_ch_data) - n_fft) // hop_length_in
        if num_frames <= 0: continue
        
        # 1. Vectorized Analysis
        matrix = np.lib.stride_tricks.as_strided(
            in_ch_data, 
            shape=(num_frames, n_fft), 
            strides=(in_ch_data.strides[0] * hop_length_in, in_ch_data.strides[0])
        )
        
        windowed_matrix = matrix * window
        stft_matrix = np.fft.fft(windowed_matrix, axis=1)
        
        magnitude = np.abs(stft_matrix)
        phase = np.angle(stft_matrix)
        
        # 2. Transient Detection
        # Calculate broadband energy differential
        energy = np.sum(magnitude**2, axis=1)
        energy_diff = np.zeros_like(energy)
        energy_diff[1:] = energy[1:] / (energy[:-1] + 1e-7) # Ratio of energy increase
        
        # Threshold for detecting a transient (e.g., 200% energy increase)
        TRANSIENT_THRESHOLD = 2.5
        is_transient = energy_diff > TRANSIENT_THRESHOLD
        
        # 3. Iterative Phase Processing (Needed because phase depends on transient state)
        syn_stft = np.zeros_like(stft_matrix, dtype=np.complex64)
        sum_phase = np.zeros(n_fft, dtype=np.float32)
        
        last_phase = phase[0]
        sum_phase[:] = phase[0]
        syn_stft[0] = magnitude[0] * np.exp(1j * sum_phase)
        
        transient_cooldown = 0
        
        for i in range(1, num_frames):
            
            # If we hit a transient (and aren't in cooldown)
            if is_transient[i] and transient_cooldown == 0:
                # PHASE RESET: Force synthesis phase to exactly match analysis phase
                # This locks all frequencies together vertically, preserving the punch.
                sum_phase[:] = phase[i]
                transient_cooldown = 3 # Don't re-trigger for a few frames
            else:
                # Standard Phase Vocoder Advance
                phase_diff = phase[i] - last_phase
                
                bin_deviation = phase_diff - expected_phase_advance
                bin_deviation = (bin_deviation + np.pi) % (2.0 * np.pi) - np.pi
                
                true_freq_dev = bin_deviation / hop_length_in
                
                sum_phase += (k_bins * 2.0 * np.pi / n_fft + true_freq_dev) * hop_length_out
                
            if transient_cooldown > 0:
                transient_cooldown -= 1
                
            last_phase = phase[i]
            syn_stft[i] = magnitude[i] * np.exp(1j * sum_phase)
            
        # 4. Synthesis (IFFT)
        syn_frames = np.real(np.fft.ifft(syn_stft, axis=1)) 
        
        # 5. Overlap Add 
        window_squared_sum = np.sum(window**2)
        scale = hop_length_out / window_squared_sum
        syn_frames *= window * scale
        
        # Output buffer injection
        for i in range(num_frames):
            out_pos = i * hop_length_out
            add_len = min(n_fft, len(out_ch_data) - out_pos)
            out_ch_data[out_pos : out_pos + add_len] += syn_frames[i, :add_len]
            
    return out_audio[n_fft : -n_fft]

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Uso: python vocoder.py <input.wav> <output.wav> <velocidad>")
        print("Ejemplo: python vocoder.py prueba.wav estirado.wav 0.8")
        sys.exit(1)
        
    in_file = sys.argv[1]
    out_file = sys.argv[2]
    speed = float(sys.argv[3])
    
    print(f"Cargando {in_file}...")
    try:
        audio, sr, channels = read_wav(in_file)
    except Exception as e:
        print(f"Error cargando archivo: {e}")
        sys.exit(1)
        
    print(f"Canales: {channels}, Sample Rate: {sr}Hz, Duracion: {len(audio)/sr:.2f}s")
    print(f"Estirando a velocidad {speed}x con PV-TSM Vectorizado...")
    
    start_time = time.time()
    out_audio = phase_vocoder(audio, stretch_factor=speed)
    end_time = time.time()
    
    print(f"Procesamiento terminado en {end_time - start_time:.2f} segundos.")
    print(f"Guardando {out_file}...")
    write_wav(out_file, out_audio, sr)
    print("¡Listo!")
