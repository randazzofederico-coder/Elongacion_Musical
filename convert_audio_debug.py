import os
import sys
from pathlib import Path

# En Python de 64 bits a veces soundfile crashea al guardar OGG si la DLL subyacente falla.
import soundfile as sf
import traceback

INPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1"
OUTPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1 OGG"

def convert_wav_to_ogg():
    input_path = Path(INPUT_DIR)
    output_path = Path(OUTPUT_DIR)
    output_path.mkdir(parents=True, exist_ok=True)

    wav_files = list(input_path.rglob("*.wav"))
    
    if not wav_files:
        print("No se encontraron archivos .wav.")
        return

    print(f"🎵 Se encontraron {len(wav_files)} archivos .wav.")
    print("Iniciando conversión a OGG (Vorbis)...")
    print("--------------------------------------------------")

    for wav_file in wav_files:
        # Haremos solo el primero para ver el error exacto
        rel_path = wav_file.relative_to(input_path)
        ogg_file = output_path / rel_path.with_suffix('.ogg')
        ogg_file.parent.mkdir(parents=True, exist_ok=True)
        
        print(f"Convirtiendo: {wav_file.name} ... ", end="", flush=True)
        
        try:
            data, samplerate = sf.read(str(wav_file))
            print(f"Leído OK (SR: {samplerate}, Datos: {data.shape}) ... ", end="", flush=True)
            # Intentar escribir con un formato genérico primero para ver si es problema de Vorbis
            # sf.write(str(ogg_file), data, samplerate, format='OGG', subtype='VORBIS')
            
            # Vamos a usar la libreria pydub en vez de soundfile que es mas robusta,
            # pero antes veremos si falla la escritura cruda
            sf.write(str(ogg_file), data, samplerate, format='OGG', subtype='VORBIS')
            print("¡Listo!")
        except Exception as e:
            print(f"\n❌ Error atrapado de Python: {e}")
            traceback.print_exc()
        
        # Paramos despues del primero
        break

if __name__ == "__main__":
    convert_wav_to_ogg()
