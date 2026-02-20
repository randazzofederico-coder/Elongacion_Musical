#include <iostream>
#include <vector>
#include <fstream>
#include <cmath>
#include <chrono>

// Include the Vocoder and KissFFT directly for a monolithic build
#include "packages/native_audio_engine/src/Vocoder.cpp"
#include "packages/native_audio_engine/src/kiss_fft.c"

using namespace std;

// --- SIMPLE WAV READER / WRITER ---
struct WavHeader {
    char chunkId[4] = {'R', 'I', 'F', 'F'};
    uint32_t chunkSize = 0;
    char format[4] = {'W', 'A', 'V', 'E'};
    char subchunk1Id[4] = {'f', 'm', 't', ' '};
    uint32_t subchunk1Size = 16;
    uint16_t audioFormat = 3; // 3 = IEEE Float
    uint16_t numChannels = 2; // Stereo
    uint32_t sampleRate = 44100;
    uint32_t byteRate = 44100 * 2 * 4;
    uint16_t blockAlign = 2 * 4;
    uint16_t bitsPerSample = 32;
    char subchunk2Id[4] = {'d', 'a', 't', 'a'};
    uint32_t subchunk2Size = 0;
};

bool readWavFloat(const char* filepath, vector<float>& outBuffer, uint32_t& sampleRate, uint16_t& channels) {
    ifstream file(filepath, ios::binary);
    if (!file) {
        cerr << "Error: Could not open " << filepath << endl;
        return false;
    }

    // Skip to format
    file.seekg(22);
    file.read((char*)&channels, 2);
    file.read((char*)&sampleRate, 4);

    // Skip to data length
    file.seekg(40);
    uint32_t dataSize;
    file.read((char*)&dataSize, 4);

    outBuffer.resize(dataSize / sizeof(float));
    file.read((char*)outBuffer.data(), dataSize);
    
    return true;
}

void writeWavFloat(const char* filepath, const vector<float>& buffer, uint32_t sampleRate, uint16_t channels) {
    ofstream file(filepath, ios::binary);
    WavHeader header;
    header.sampleRate = sampleRate;
    header.numChannels = channels;
    header.byteRate = sampleRate * channels * sizeof(float);
    header.blockAlign = channels * sizeof(float);
    header.subchunk2Size = buffer.size() * sizeof(float);
    header.chunkSize = 36 + header.subchunk2Size;
    
    file.write((char*)&header, sizeof(WavHeader));
    file.write((char*)buffer.data(), buffer.size() * sizeof(float));
}

int main(int argc, char** argv) {
    if (argc < 4) {
        cout << "Usage: vocoder_test.exe <input.wav> <output.wav> <speed>" << endl;
        cout << "Example: vocoder_test.exe track.wav stretched.wav 0.8" << endl;
        return 1;
    }

    const char* inPath = argv[1];
    const char* outPath = argv[2];
    float speed = std::stof(argv[3]);

    vector<float> inBuffer;
    uint32_t sampleRate;
    uint16_t channels;

    cout << "Loading " << inPath << "..." << endl;
    if (!readWavFloat(inPath, inBuffer, sampleRate, channels)) {
        return 1;
    }
    
    if (channels != 2) {
        cout << "Warning: Mono audio detected. Vocoder expects Stereo for now." << endl;
    }

    cout << "Sample Rate: " << sampleRate << ", Channels: " << channels << ", Frames: " << inBuffer.size()/channels << endl;
    cout << "Processing at " << speed << "x speed..." << endl;

    Vocoder vocoder(sampleRate, channels);
    vocoder.setTempo(speed);

    vector<float> outBuffer;
    outBuffer.reserve((inBuffer.size() / speed) + 4096);

    const int chunkSize = 1024;
    vector<float> chunk(chunkSize * channels);
    vector<float> outChunk(chunkSize * 4 * channels); // Extra capacity for receipt

    auto start_time = chrono::high_resolution_clock::now();

    for (size_t i = 0; i < inBuffer.size(); i += chunkSize * channels) {
        int copyFrames = min(chunkSize, (int)(inBuffer.size() - i) / channels);
        
        vocoder.putSamples(inBuffer.data() + i, copyFrames);
        
        int gotFrames = vocoder.receiveSamples(outChunk.data(), outChunk.size() / channels);
        while (gotFrames > 0) {
            outBuffer.insert(outBuffer.end(), outChunk.begin(), outChunk.begin() + (gotFrames * channels));
            gotFrames = vocoder.receiveSamples(outChunk.data(), outChunk.size() / channels);
        }
    }

    auto end_time = chrono::high_resolution_clock::now();
    chrono::duration<double> diff = end_time - start_time;
    
    cout << "Processing Time: " << diff.count() << " seconds." << endl;
    cout << "Writing " << outPath << " (" << outBuffer.size()/channels << " frames)..." << endl;

    writeWavFloat(outPath, outBuffer, sampleRate, channels);

    cout << "Done!" << endl;
    return 0;
}
