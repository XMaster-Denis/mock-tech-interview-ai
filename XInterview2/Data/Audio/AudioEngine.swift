//
//  AudioEngine.swift
//  XInterview2
//
//  Audio recording and playback using AVFoundation
//

import AVFoundation

protocol AudioEngineProtocol: AnyObject {
    var audioData: Data? { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    
    func startRecording() throws
    func stopRecording() throws
    func playAudio(_ data: Data) throws
    func stopPlayback()
}

class AudioEngine: NSObject, AudioEngineProtocol {
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var audioFile: AVAudioFile?
    
    var audioData: Data?
    private(set) var isRecording: Bool = false
    private(set) var isPlaying: Bool = false
    
    private var currentRecordingURL: URL?
    
    // MARK: - Recording
    
    func startRecording() throws {
        guard !isRecording else {
            print("⚠️ Recording already in progress")
            return
        }
        
        print("🎙️ Starting recording...")
        
        // Note: AVAudioSession is iOS-only, macOS handles audio differently
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        
        // Configure format for recording - use standard format compatible with most microphones
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        guard let validFormat = format else {
            print("❌ Failed to create audio format")
            throw AudioEngineError.formatCreationFailed
        }
        
        print("📝 Audio format: \(validFormat)")
        
        // Create unique file to avoid conflicts
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        currentRecordingURL = audioURL
        
        print("📁 Recording to: \(audioURL.path)")
        
        audioFile = try AVAudioFile(forWriting: audioURL, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        
        // Install tap on input node
        var bufferCount = 0
        var totalFrames: AVAudioFrameCount = 0
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: validFormat) { [weak self] buffer, _ in
            guard let self = self, let file = self.audioFile else {
                print("❌ Tap callback: Self or audioFile is nil")
                return
            }
            
            do {
                try file.write(from: buffer)
                bufferCount += 1
                totalFrames += buffer.frameLength
                
                if bufferCount % 10 == 0 { // Log every 10 buffers
                    print("🎵 Written \(totalFrames) frames (\(bufferCount) buffers)")
                }
            } catch {
                print("❌ Error writing buffer: \(error.localizedDescription)")
            }
        }
        
        try audioEngine?.start()
        isRecording = true
        
        print("✅ Recording started successfully")
    }
    
    func stopRecording() throws {
        guard isRecording else {
            print("⚠️ No recording in progress")
            return
        }
        
        print("⏹️ Stopping recording...")
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Read the audio file data
        if let file = audioFile {
            do {
                let fileLength = file.length
                print("📊 Audio file length: \(fileLength) frames")
                audioData = try Data(contentsOf: file.url)
                print("📊 Audio data size: \(audioData?.count ?? 0) bytes")
            } catch {
                print("❌ Error reading audio file: \(error.localizedDescription)")
                throw error
            }
        }
        
        isRecording = false
        audioEngine = nil
        
        // Clean up the recording file after reading
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
            currentRecordingURL = nil
        }
        
        print("✅ Recording stopped")
    }
    
    // MARK: - Playback
    
    func playAudio(_ data: Data) throws {
        guard !isPlaying else {
            print("⚠️ Audio already playing")
            return
        }
        
        print("🔊 Playing audio (\(data.count) bytes)")
        
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        print("🔇 Playback stopped")
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        print("✅ Playback finished (success: \(flag))")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            print("❌ Playback error: \(error.localizedDescription)")
        }
    }
}

// MARK: - AudioEngineError

enum AudioEngineError: LocalizedError {
    case formatCreationFailed
    case recordingInProgress
    case noRecordingInProgress
    
    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .recordingInProgress:
            return "Recording is already in progress"
        case .noRecordingInProgress:
            return "No recording is in progress"
        }
    }
}
