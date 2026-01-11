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
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    
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
        
        // Use AVAudioRecorder for compatibility with Whisper API
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).wav"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        currentRecordingURL = audioURL
        
        print("📁 Recording to: \(audioURL.path)")
        
        // WAV format settings (Linear PCM) for Whisper API compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), // WAV format
            AVSampleRateKey: 16000, // Whisper recommended sample rate
            AVNumberOfChannelsKey: 1, // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        print("📝 Audio settings: \(settings)")
        
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.record()
        isRecording = true
        
        print("✅ Recording started successfully")
    }
    
    func stopRecording() throws {
        guard isRecording else {
            print("⚠️ No recording in progress")
            return
        }
        
        print("⏹️ Stopping recording...")
        
        audioRecorder?.stop()
        isRecording = false
        
        // Read the audio file data
        guard let url = currentRecordingURL else {
            print("❌ No recording URL available")
            throw AudioEngineError.noRecordingInProgress
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                print("📊 Audio file size: \(fileSize.intValue) bytes")
                
                if fileSize.intValue == 0 {
                    print("⚠️ Audio file is empty")
                    throw AudioEngineError.noRecordingInProgress
                }
            }
        } catch {
            print("❌ Error getting file attributes: \(error.localizedDescription)")
            throw error
        }
        
        audioData = try Data(contentsOf: url)
        print("📊 Audio data loaded: \(audioData?.count ?? 0) bytes")
        
        // Clean up the recording file after reading
        try? FileManager.default.removeItem(at: url)
        currentRecordingURL = nil
        
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
        audioPlayer?.rate = 0.8 // Slower speed for clarity
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
            return "No recording is in progress or file is empty"
        }
    }
}
