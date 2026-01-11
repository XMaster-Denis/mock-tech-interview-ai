//
//  AudioEngine.swift
//  XInterview2
//
//  Audio recording and playback using AVFoundation
//

import AVFoundation
import Combine
import CoreAudio

protocol AudioEngineProtocol: AnyObject {
    var audioData: Data? { get }
    var audioLevel: Float { get }
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
    var audioLogs: [String] { get }
    
    func startRecording() throws
    func stopRecording() throws
    func playAudio(_ data: Data) throws
    func stopPlayback()
    func startTestRecording(duration: TimeInterval) throws -> AsyncStream<String>
    func stopTestRecording() throws
    func clearLogs()
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
    @Published private(set) var audioLogs: [String] = []
    
    private var audioLevelTimer: Timer?
    private var silenceTimer: Timer?
    private var testRecordingTimer: Timer?
    private var testLogsContinuation: AsyncStream<String>.Continuation?
    
    private var lastAudioLevel: Float = 0.0
    
    // VAD (Voice Activity Detection) configuration
    private let silenceThreshold: Float = 0.05
    private let silenceDuration: TimeInterval = 2.0
    private let maxRecordingDuration: TimeInterval = 30.0
    
    private var recordingStartTime: Date?
    private var isVoiceActive: Bool = false
    private var isTestMode: Bool = false
    
    // Callback for automatic stop
    var onRecordingStopped: (() -> Void)?
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.audioLogs.append(logMessage)
            if self.audioLogs.count > 100 {
                self.audioLogs.removeFirst()
            }
        }
        
        print(logMessage)
    }
    
    func clearLogs() {
        audioLogs.removeAll()
    }
    
    // MARK: - Recording
    
    func startRecording() throws {
        guard !isRecording else {
            log("⚠️ Recording already in progress")
            return
        }
        
        log("🎙️ Starting recording...")
        
        // Configure audio session (iOS only)
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        log("📱 Audio session configured: Category=\(session.category.rawValue), Mode=\(session.mode.rawValue)")
        #else
        log("💻 macOS audio session - no configuration needed")
        #endif
        
        // Use AVAudioRecorder for compatibility with Whisper API
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).wav"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        audioFileURL = audioURL
        
        log("📁 Recording to: \(audioURL.path)")
        
        // Log available audio devices on macOS
        #if os(macOS)
        logAvailableAudioInputs()
        #endif
        
        // WAV format settings (Linear PCM) for Whisper API compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        log("📝 Audio settings: \(settings)")
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        } catch {
            log("❌ Failed to create AVAudioRecorder: \(error.localizedDescription)")
            throw error
        }
        
        guard let recorder = audioRecorder else {
            log("❌ Audio recorder is nil after initialization")
            throw AudioEngineError.formatCreationFailed
        }
        
        recorder.isMeteringEnabled = true
        log("🎚️ Metering enabled: \(recorder.isMeteringEnabled)")
        
        let started = recorder.record()
        log("🎙️ Recorder.record() returned: \(started)")
        
        if started {
            isRecording = true
            recordingStartTime = Date()
            isVoiceActive = false
            
            // Start audio level monitoring
            startAudioLevelMonitoring()
            
            // Start silence timer
            resetSilenceTimer()
            
            log("✅ Recording started successfully, URL: \(recorder.url.path)")
            log("📊 Recorder settings: format=\(recorder.settings)")
        } else {
            log("❌ Recording failed to start")
            throw AudioEngineError.formatCreationFailed
        }
    }
    
    func stopRecording() throws {
        guard isRecording else {
            log("⚠️ No recording in progress")
            return
        }
        
        log("⏹️ Stopping recording...")
        
        stopAudioLevelMonitoring()
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        
        // Read the audio file data
        guard let url = audioFileURL else {
            log("❌ No recording URL available")
            throw AudioEngineError.noRecordingInProgress
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                log("📊 Audio file size: \(fileSize.intValue) bytes")
                
                if fileSize.intValue == 0 {
                    log("⚠️ Audio file is empty")
                    throw AudioEngineError.noRecordingInProgress
                }
            }
        } catch {
            log("❌ Error getting file attributes: \(error.localizedDescription)")
            throw error
        }
        
        audioData = try Data(contentsOf: url)
        log("📊 Audio data loaded: \(audioData?.count ?? 0) bytes")
        
        // Log file header for WAV format verification
        if let data = audioData, data.count >= 44 {
            let header = data.prefix(44).map { String(format: "%02x", $0) }.joined(separator: " ")
            log("📦 WAV file header: \(header)")
            
            // Check for RIFF header
            let riff = String(data: data[0..<4], encoding: .ascii) ?? ""
            let wave = String(data: data[8..<12], encoding: .ascii) ?? ""
            log("📦 File signature: RIFF=\(riff), WAVE=\(wave)")
        }
        
        // Clean up the recording file after reading
        try? FileManager.default.removeItem(at: url)
        audioFileURL = nil
        
        // Reset audio level
        audioLevel = 0.0
        
        log("✅ Recording stopped")
        
        // Notify callback
        onRecordingStopped?()
    }
    
    // MARK: - Test Recording
    
    func startTestRecording(duration: TimeInterval) throws -> AsyncStream<String> {
        log("🧪 Starting test recording for \(duration) seconds")
        
        isTestMode = true
        
        return AsyncStream { continuation in
            self.testLogsContinuation = continuation
            
            Task { @MainActor in
                do {
                    try self.startRecording()
                    
                    self.testRecordingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                        Task { @MainActor in
                            do {
                                try self.stopRecording()
                                self.testLogsContinuation?.finish()
                                self.isTestMode = false
                            } catch {
                                self.log("❌ Test recording error: \(error.localizedDescription)")
                                self.testLogsContinuation?.finish()
                                self.isTestMode = false
                            }
                        }
                    }
                } catch {
                    self.log("❌ Failed to start test recording: \(error.localizedDescription)")
                    self.testLogsContinuation?.finish()
                    self.isTestMode = false
                }
            }
        }
    }
    
    func stopTestRecording() throws {
        testRecordingTimer?.invalidate()
        testRecordingTimer = nil
        
        if isRecording {
            try stopRecording()
        }
        
        isTestMode = false
        testLogsContinuation?.finish()
        testLogsContinuation = nil
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        log("🔊 Starting audio level monitoring...")
        
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopAudioLevelMonitoring() {
        log("🔇 Stopping audio level monitoring")
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0.0
            return
        }
        
        // CRITICAL: Call updateMeters() before reading meter values
        recorder.updateMeters()
        
        // Get average power from channel 0 (in decibels, range -160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Get peak power from channel 0
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Log level periodically
        if isTestMode && arc4random_uniform(20) == 0 { // Log ~5% of the time during test
            log("🎚️ Audio level - Avg: \(String(format: "%.1f", averagePower)) dB, Peak: \(String(format: "%.1f", peakPower)) dB")
        }
        
        // Convert decibels to 0-1 scale
        // -60 dB is considered silence, 0 dB is maximum
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        audioLevel = level
        
        // Send level to stream during test
        if isTestMode {
            testLogsContinuation?.yield("Level: \(String(format: "%.2f", level))")
        }
        
        lastAudioLevel = level
        
        // Voice Activity Detection
        checkVoiceActivity(level: level)
    }
    
    private func checkVoiceActivity(level: Float) {
        let nowVoiceActive = level > silenceThreshold
        
        if nowVoiceActive && !isVoiceActive {
            // Voice started
            isVoiceActive = true
            log("🗣️ Voice detected (level: \(String(format: "%.2f", level)))")
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
                    log("🤫 Silence detected, stopping recording")
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
                    log("⏰ Max recording duration reached")
                    try? self.stopRecording()
                    return
                }
            }
            
            // Stop if still silent
            if self.audioLevel < self.silenceThreshold {
                log("🤫 Silence detected, stopping recording")
                try? self.stopRecording()
            }
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ data: Data) throws {
        guard !isPlaying else {
            log("⚠️ Audio already playing")
            return
        }
        
        log("🔊 Playing audio (\(data.count) bytes)")
        
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.rate = 0.8
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        isPlaying = true
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        log("🔇 Playback stopped")
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioEngine: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        log("✅ Playback finished (success: \(flag))")
        
        // Notify that AI finished speaking - can start auto-recording
        onRecordingStopped?()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            log("❌ Playback error: \(error.localizedDescription)")
        }
        onRecordingStopped?()
    }
}

// MARK: - macOS Audio Input Logging

extension AudioEngine {
    private func logAvailableAudioInputs() {
        #if os(macOS)
        log("🎤 macOS Audio System:")
        
        // Get default input device
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        if status == noErr {
            var deviceName: String = ""
            var nameSize: UInt32 = 0
            
            // Get name size
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyDataSize(deviceID, &nameAddress, 0, nil, &nameSize)
            
            // Get name
            var nameBuffer = [Int8](repeating: 0, count: Int(nameSize))
            let getRawNameStatus = AudioObjectGetPropertyData(
                deviceID,
                &nameAddress,
                0,
                nil,
                &nameSize,
                &nameBuffer
            )
            
            if getRawNameStatus == noErr {
                deviceName = String(cString: nameBuffer)
                log("  Default Input Device: \(deviceName)")
            } else {
                log("  ❌ Failed to get device name")
            }
            log("  Device ID: \(deviceID)")
        } else {
            log("  ❌ Failed to get default input device")
        }
        
        // Log that we're using AVAudioRecorder
        log("  Using AVAudioRecorder for recording")
        log("  Format: WAV (Linear PCM), 16kHz, Mono, 16-bit")
        #endif
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
