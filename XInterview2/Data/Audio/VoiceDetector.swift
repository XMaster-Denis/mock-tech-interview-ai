//
//  VoiceDetector.swift
//  XInterview2
//
//  Voice Activity Detection for continuous speech recognition
//

import AVFoundation
import Combine
import Foundation

// MARK: - Voice Events

enum VoiceEvent {
    case speechStarted
    case speechEnded(Data) // Audio data to transcribe
    case silenceDetected
    case error(Error)
}

// MARK: - VoiceDetector

@MainActor
class VoiceDetector: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var speechDetected: Bool = false
    @Published var isSilenceTimerActive: Bool = false  // New: shows when waiting for silence
    @Published var silenceTimerProgress: Double = 0.0  // New: 0.0 to 1.0 progress
    @Published var silenceTimerElapsed: Double = 0.0  // New: elapsed seconds in silence
    
    // MARK: - Configuration
    
    private let silenceThreshold: Float = 0.05
    private var speechStartThreshold: Float // Configurable via settings
    private var silenceTimeout: TimeInterval // Configurable via settings
    private let minSpeechDuration: TimeInterval = 0.2  // Lowered from 0.5 for faster testing
    private let maxRecordingDuration: TimeInterval = 30.0
    private let calibrationDelay: TimeInterval = 1.0 // Ignore first 1s for mic calibration
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingFileURL: URL?
    private var recordingStartTime: Date?
    private var speechStartTime: Date?
    private var silenceStartTime: Date?  // New: tracks when silence started
    private var audioBuffer: Data?
    private var levelMonitorTimer: Timer?
    private var silenceTimer: Timer?
    private var silenceProgressTimer: Timer?  // New: animates progress
    private var lastLevelLogTime: Date?  // Track when we last logged level
    private var lastDuplicateLogTime: Date?  // Track when duplicate log was shown
    
    private var isRecording: Bool = false
    private var isSpeechActive: Bool = false
    private var isPaused: Bool = false
    private var isCalibrated: Bool = false // True after calibration delay
    private var silenceTimerRunning: Bool = false // Prevent duplicate timers
    private var fallbackTimer: Timer? // Force handleSpeechEnd() if main timer fails
    
    // MARK: - Callbacks
    
    var onVoiceEvent: ((VoiceEvent) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        self.speechStartThreshold = 0.15 // Lower default threshold for better sensitivity
        self.silenceTimeout = 1.5  // Default silence timeout
        super.init()
        setupAudioSession()
    }
    
    init(speechThreshold: Float, silenceTimeout: Double = 1.5) {
        self.speechStartThreshold = speechThreshold
        self.silenceTimeout = silenceTimeout
        super.init()
        setupAudioSession()
    }
    
    deinit {
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)
        #endif
    }
    
    // MARK: - Public Methods
    
    func updateThreshold(_ threshold: Float) {
        Logger.voice("Updating speech threshold to: \(threshold)")
        speechStartThreshold = threshold
    }
    
    func updateSilenceTimeout(_ timeout: Double) {
        Logger.voice("Updating silence timeout to: \(timeout)s")
        self.silenceTimeout = timeout
    }
    
    func startListening() {
        guard !isListening else { return }
        
        Logger.voice("Starting to listen... threshold: \(speechStartThreshold)")
        isListening = true
        isPaused = false
        
        startRecording()
        startLevelMonitoring()
    }
    
    func stopListening() {
        Logger.voice("Stopping...")
        isListening = false
        isPaused = true
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        if let ft = fallbackTimer {
            ft.invalidate()
            fallbackTimer = nil
        }
        silenceTimerRunning = false
        
        stopRecording()
        stopLevelMonitoring()
    }
    
    func pauseListening() {
        Logger.voice("Pausing...")
        isPaused = true
        stopLevelMonitoring()
    }
    
    func resumeListening() {
        Logger.voice("Resuming...")
        isPaused = false
        startLevelMonitoring()
    }
    
    // MARK: - Recording
    
    private func startRecording() {
        Logger.voice("startRecording() - resetting calibration state")
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "speech_\(UUID().uuidString).wav"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        recordingFileURL = audioURL
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            audioBuffer = Data()
            
            // Reset calibration - wait before detecting speech
            isCalibrated = false
            isSpeechActive = false
            speechDetected = false
            
            // Start calibration timer
            Timer.scheduledTimer(withTimeInterval: calibrationDelay, repeats: false) { [weak self] _ in
                self?.isCalibrated = true
                Logger.voice("✅ Calibration complete, speech detection enabled (threshold: \(self?.speechStartThreshold ?? 0.15))")
            }
            
            Logger.success("Recording started (calibrating for \(calibrationDelay)s)")
        } catch {
            Logger.error("Failed to start recording", error: error)
            onVoiceEvent?(.error(error))
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        Logger.voice("🛑 Stopping recording...")
        audioRecorder?.stop()
        isRecording = false
        
        // Store audio data without sending event
        if let url = recordingFileURL {
            do {
                let data = try Data(contentsOf: url)
                if !data.isEmpty {
                    audioBuffer = data
                    Logger.voice("Audio data stored: \(data.count) bytes")
                } else {
                    Logger.warning("Recording is empty, ignoring")
                    audioBuffer = nil
                }
                try? FileManager.default.removeItem(at: url)
            } catch {
                Logger.error("Failed to store audio data", error: error)
                audioBuffer = nil
            }
        }
        
        recordingFileURL = nil
        isSpeechActive = false
        speechDetected = false
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceTimerRunning = false // Reset flag when stopping recording
    }
    
    // MARK: - Level Monitoring
    
    private func startLevelMonitoring() {
        stopLevelMonitoring()
        
        levelMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkAudioLevel()
        }
        Logger.voice("Level monitoring started")
    }
    
    private func stopLevelMonitoring() {
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
        Logger.voice("Level monitoring stopped")
    }
    
    private func checkAudioLevel() {
        guard isListening, !isPaused else {
            // Log why we're not processing
            if !isListening {
                Logger.voice("⏸️ Not listening, skipping audio level check")
            } else if isPaused {
                Logger.voice("⏸️ Paused, skipping audio level check")
            }
            return
        }
        
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        audioLevel = level
        
        let isAboveThreshold = level > speechStartThreshold
        
        // Skip speech detection during calibration
        if !isCalibrated {
            return
        }
        
        // Speech started
        if isAboveThreshold && !isSpeechActive {
            isSpeechActive = true
            speechStartTime = Date()
            speechDetected = true
            silenceTimer?.invalidate()
            silenceStartTime = nil
            
            Logger.voice("🎤 SPEECH STARTED! Level: \(String(format: "%.2f", level)) > Threshold: \(speechStartThreshold)")
            onVoiceEvent?(.speechStarted)
        }
        // Speech in progress (cancel silence timer if still speaking)
        else if isAboveThreshold && isSpeechActive {
            if let silenceTimer = silenceTimer, silenceTimer.isValid {
                Logger.voice("🗣️ Speech continues - silence timer cancelled")
            }
            silenceTimer?.invalidate()
            silenceTimer = nil
            silenceTimerRunning = false  // Reset flag to allow new silence timer creation
            fallbackTimer?.invalidate()  // Cancel fallback timer
            fallbackTimer = nil
            silenceStartTime = nil
            isSilenceTimerActive = false
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
        }
        // Speech possibly ended
        else if !isAboveThreshold && isSpeechActive {
            // Prevent creating duplicate silence timers
            guard !silenceTimerRunning else {
                // Only log if not shown in last 0.5s to reduce log spam
                if lastDuplicateLogTime == nil || Date().timeIntervalSince(lastDuplicateLogTime!) >= 0.5 {
                    Logger.voice("⏸️ Silence timer already running, skipping duplicate creation")
                    lastDuplicateLogTime = Date()
                }
                return
            }
            
            // Start silence timer to confirm speech ended
            silenceTimer?.invalidate()
            silenceTimer = nil
            silenceTimerRunning = true // Mark timer as running
            
            silenceStartTime = Date()
            isSilenceTimerActive = true
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
            
            Logger.voice("🔇 SILENCE DETECTED! Level: \(String(format: "%.2f", level)) < Threshold: \(speechStartThreshold)")
            Logger.voice("⏳ Waiting \(String(format: "%.1f", silenceTimeout))s to confirm speech ended...")
            
            // Start progress animation timer
            silenceProgressTimer?.invalidate()
            silenceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.silenceStartTime else { return }
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1.0, elapsed / self.silenceTimeout)
                self.silenceTimerProgress = progress
                self.silenceTimerElapsed = elapsed
                
                // Publish to UI every update
                NotificationCenter.default.post(
                    name: .silenceTimerUpdated,
                    object: self,
                    userInfo: [
                        "progress": progress,
                        "elapsed": elapsed,
                        "timeout": self.silenceTimeout
                    ]
                )
                
                // Log progress every 1.0 seconds
                if Int(elapsed) % 1 == 0 && Int(elapsed * 10) % 10 == 0 {
                    Logger.voice("⏳ Silence: \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", self.silenceTimeout))s")
                }
            }
            
            // Main silence timer
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: silenceTimeout,
                repeats: false
            ) { [weak self] _ in
                self?.silenceTimerRunning = false // Reset flag when timer fires
                self?.fallbackTimer?.invalidate() // Cancel fallback timer
                self?.fallbackTimer = nil
                self?.handleSpeechEnd()
            }
            
            // Fallback timer to ensure handleSpeechEnd() is called
            fallbackTimer = Timer.scheduledTimer(
                withTimeInterval: self.silenceTimeout + 0.1,
                repeats: false
            ) { [weak self] _ in
                if self?.silenceTimerRunning ?? false {
                    Logger.warning("⚠️ Fallback timer triggered - main silence timer didn't fire")
                    self?.silenceTimerRunning = false
                    self?.handleSpeechEnd()
                }
            }
        }
        
        // Check max duration
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration >= maxRecordingDuration {
                Logger.warning("⚠️ MAX DURATION REACHED (\(String(format: "%.1f", duration))s) - No speech detected!")
                Logger.warning("💡 Try lowering the Voice Threshold in settings or speak louder/closer to microphone")
                stopRecording()
                // Restart immediately for continuous listening
                startRecording()
                startLevelMonitoring()
            }
        }
    }
    
    private func trimWAVData(_ data: Data, 
                            startOffset: TimeInterval, 
                            duration: TimeInterval) -> Data? {
        let sampleRate = 16000.0
        let bytesPerSample = 2  // 16-bit PCM
        let channels = 1
        let bytesPerSecond = sampleRate * Double(bytesPerSample * channels)
        
        // Calculate byte offsets
        let startByteOffset = Int(startOffset * bytesPerSecond)
        let audioDataSize = Int(duration * bytesPerSecond)
        
        // Original file duration
        let originalDuration = Double(data.count - 44) / bytesPerSecond
        
        // WAV header is 44 bytes
        let headerSize = 44
        let totalDataSize = headerSize + audioDataSize
        
        guard startByteOffset >= 0, audioDataSize > 0 else {
            Logger.error("Invalid trim parameters: start=\(startOffset)s, duration=\(duration)s")
            return nil
        }
        
        // Extract original header
        let header = data.prefix(headerSize)
        
        // Calculate offset in audio data portion (skip header)
        let audioDataStartOffset = headerSize + startByteOffset
        
        guard audioDataStartOffset + audioDataSize <= data.count else {
            Logger.error("Trim exceeds file size")
            return nil
        }
        
        // Extract audio data segment
        let trimmedAudioData = data.subdata(in: audioDataStartOffset..<(audioDataStartOffset + audioDataSize))
        
        // Build new WAV file with updated header
        var newData = Data(capacity: totalDataSize)
        newData.append(header)
        newData.append(trimmedAudioData)
        
        // Update WAV header fields
        newData.withUnsafeMutableBytes { ptr in
            // Offset 4: File size (excluding first 8 bytes of RIFF header)
            let fileSize = UInt32(totalDataSize - 8)
            ptr.baseAddress?.advanced(by: 4).assumingMemoryBound(to: UInt32.self).pointee = fileSize.littleEndian
            
            // Offset 40: Data chunk size
            let dataSize = UInt32(audioDataSize)
            ptr.baseAddress?.advanced(by: 40).assumingMemoryBound(to: UInt32.self).pointee = dataSize.littleEndian
        }
        
        // Detailed logging
        let originalSizeKB = Double(data.count) / 1024
        let trimmedSizeKB = Double(newData.count) / 1024
        let savedKB = originalSizeKB - trimmedSizeKB
        let savedPercent = (savedKB / originalSizeKB) * 100
        
        let endTrimDuration = originalDuration - (startOffset + duration)
        
        Logger.voice("📊 AUDIO TRIMMING REPORT:")
        Logger.voice("   Original: \(String(format: "%.2f", originalDuration))s (\(Int(originalSizeKB)) KB)")
        Logger.voice("   Trimmed start: \(String(format: "%.2f", startOffset))s (\(Int(startOffset * bytesPerSecond / 1024)) KB)")
        Logger.voice("   Kept speech: \(String(format: "%.2f", duration))s (\(Int(audioDataSize / 1024)) KB)")
        Logger.voice("   Trimmed end: \(String(format: "%.2f", endTrimDuration))s (\(Int(endTrimDuration * bytesPerSecond / 1024)) KB)")
        Logger.voice("   Final: \(String(format: "%.2f", duration))s (\(Int(trimmedSizeKB)) KB)")
        Logger.voice("   💾 Saved: \(String(format: "%.1f", savedKB)) KB (\(String(format: "%.1f", savedPercent))%)")
        
        return newData
    }
    
    private func handleSpeechEnd() {
        guard isSpeechActive, 
              let startTime = speechStartTime,
              let recordingStart = recordingStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Stop silence indicators
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        
        // Post notification to reset UI indicator
        NotificationCenter.default.post(name: .silenceTimerReset, object: self)
        
        // Only process if speech lasted long enough
        guard duration >= minSpeechDuration else {
            Logger.warning("⚠️ Speech too short (\(String(format: "%.2f", duration))s < \(minSpeechDuration)s), ignoring as noise")
            Logger.voice("💡 Tip: Lower minSpeechDuration to accept shorter speech, or speak longer")
            isSpeechActive = false
            speechStartTime = nil
            return
        }
        
        Logger.voice("✅ Speech ended - duration: \(String(format: "%.2f", duration))s")
        
        // Calculate trim offsets
        let startOffset = startTime.timeIntervalSince(recordingStart)
        let speechDuration = duration
        
        // Stop recording to get audio data
        stopRecording()
        
        // Apply trimming
        if let originalData = audioBuffer {
            Logger.voice("📁 Original audio: \(originalData.count) bytes")
            
            if let trimmedData = trimWAVData(originalData, 
                                          startOffset: startOffset, 
                                          duration: speechDuration) {
                Logger.voice("📤 Sending trimmed audio to Whisper API")
                onVoiceEvent?(.speechEnded(trimmedData))
            } else {
                // Fallback to original data if trim fails
                Logger.warning("⚠️ Trim failed, using original audio")
                let originalSizeKB = Double(originalData.count) / 1024
                Logger.voice("📤 Sending original audio: \(String(format: "%.1f", originalSizeKB)) KB")
                onVoiceEvent?(.speechEnded(originalData))
            }
        }
        
        // Restart recording for continuous listening
        if isListening {
            startRecording()
            startLevelMonitoring()
        }
    }
}
