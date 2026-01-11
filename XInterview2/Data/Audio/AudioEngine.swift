//
//  AudioEngine.swift
//  XInterview2
//
//  Audio recording and playback using AVFoundation
//

import AVFoundation
import Combine

protocol AudioEngineProtocol: AnyObject {
    var audioData: Data? { get }
    var audioLevel: Float { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    
    func startRecording() throws
    func stopRecording() throws
    func playAudio(_ data: Data) throws
    func stopPlayback()
}

class AudioEngine: NSObject, AudioEngineProtocol, ObservableObject {
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioFileURL: URL?
    
    var audioData: Data?
    private(set) var isRecording: Bool = false
    private(set) var isPlaying: Bool = false
    
    // Audio level monitoring
    @Published private(set) var audioLevel: Float = 0.0
    
    private var audioLevelTimer: Timer?
    private var silenceTimer: Timer?
    private var lastAudioLevel: Float = 0.0
    
    // VAD (Voice Activity Detection) configuration
    private let silenceThreshold: Float = 0.05
    private let silenceDuration: TimeInterval = 2.0 // Stop recording after 2 seconds of silence
    private let maxRecordingDuration: TimeInterval = 30.0 // Max 30 seconds per turn
    
    private var recordingStartTime: Date?
    private var isVoiceActive: Bool = false
    
    // Callback for automatic stop
    var onRecordingStopped: (() -> Void)?
    
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
        audioFileURL = audioURL
        
        print("📁 Recording to: \(audioURL.path)")
        
        // WAV format settings (Linear PCM) for Whisper API compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), // WAV format
            AVSampleRateKey: 16000, // Whisper recommended sample rate
            AVNumberOfChannelsKey: 1, // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        print("📝 Audio settings: \(settings)")
        
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        isRecording = true
        recordingStartTime = Date()
        isVoiceActive = false
        
        // Start audio level monitoring
        startAudioLevelMonitoring()
        
        // Start silence timer
        resetSilenceTimer()
        
        print("✅ Recording started successfully")
    }
    
    func stopRecording() throws {
        guard isRecording else {
            print("⚠️ No recording in progress")
            return
        }
        
        print("⏹️ Stopping recording...")
        
        stopAudioLevelMonitoring()
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        
        // Read the audio file data
        guard let url = audioFileURL else {
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
        audioFileURL = nil
        
        // Reset audio level
        audioLevel = 0.0
        
        print("✅ Recording stopped")
        
        // Notify callback
        onRecordingStopped?()
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0.0
            return
        }
        
        // Get average power from channel 0
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert decibels to 0-1 scale
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        audioLevel = level
        lastAudioLevel = level
        
        // Voice Activity Detection
        checkVoiceActivity(level: level)
    }
    
    private func checkVoiceActivity(level: Float) {
        let nowVoiceActive = level > silenceThreshold
        
        if nowVoiceActive && !isVoiceActive {
            // Voice started
            isVoiceActive = true
            print("🗣️ Voice detected (level: \(String(format: "%.2f", level))")
            resetSilenceTimer()
        } else if !nowVoiceActive && isVoiceActive {
            // Voice stopped - check if it's actual silence or just a pause
            silenceTimer?.invalidate()
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: silenceDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                
                // Check if still silent after delay
                if self.audioLevel < self.silenceThreshold {
                    print("🤫 Silence detected, stopping recording")
                    try? self.stopRecording()
                }
            }
        } else {
            // Continuously silent or talking - reset silence timer
            resetSilenceTimer()
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: silenceDuration,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Check max duration
            if let startTime = self.recordingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                if duration >= self.maxRecordingDuration {
                    print("⏰ Max recording duration reached")
                    try? self.stopRecording()
                    return
                }
            }
            
            // Stop if still silent
            if self.audioLevel < self.silenceThreshold {
                print("🤫 Silence detected, stopping recording")
                try? self.stopRecording()
            }
        }
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
        
        // Notify that AI finished speaking - can start auto-recording
        onRecordingStopped?()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            print("❌ Playback error: \(error.localizedDescription)")
        }
        onRecordingStopped?()
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
