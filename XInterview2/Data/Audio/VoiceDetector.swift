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
    private let minSpeechDuration: TimeInterval = 0.5
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
    
    private var isRecording: Bool = false
    private var isSpeechActive: Bool = false
    private var isPaused: Bool = false
    private var isCalibrated: Bool = false // True after calibration delay
    
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
        // Clean up without calling main actor methods
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
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
        // Don't reset lastLevelLogTime to maintain periodic logging across recording restarts
        
        if let url = recordingFileURL {
            do {
                let data = try Data(contentsOf: url)
                if !data.isEmpty {
                    Logger.info("Recorded \(data.count) bytes")
                    onVoiceEvent?(.speechEnded(data))
                } else {
                    Logger.warning("Recording is empty, ignoring")
                }
                try? FileManager.default.removeItem(at: url)
            } catch {
                Logger.error("Failed to read recording", error: error)
            }
        }
        
        recordingFileURL = nil
        audioBuffer = nil
        recordingStartTime = nil
        speechStartTime = nil
        silenceStartTime = nil
        isSpeechActive = false
        speechDetected = false
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
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
        
        // Log level every 1 second regardless of state
        let now = Date()
        if lastLevelLogTime == nil || now.timeIntervalSince(lastLevelLogTime!) >= 1.0 {
            if isCalibrated {
                if isAboveThreshold {
                    Logger.voice("🎤 Level: \(String(format: "%.2f", level)) / Threshold: \(speechStartThreshold) - SPEECH DETECTED")
                } else {
                    Logger.voice("🔇 Level: \(String(format: "%.2f", level)) / Threshold: \(speechStartThreshold) - below")
                }
            }
            lastLevelLogTime = now
        }
        
        // Skip speech detection during calibration
        if !isCalibrated {
            if isAboveThreshold {
                Logger.voice("⏳ Calibration in progress (level: \(String(format: "%.2f", level)) > threshold: \(speechStartThreshold)) - ignoring")
            }
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
            silenceStartTime = nil
            isSilenceTimerActive = false
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
        }
        // Speech possibly ended
        else if !isAboveThreshold && isSpeechActive {
            // Start silence timer to confirm speech ended
            silenceTimer?.invalidate()
            silenceTimer = nil
            
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
                
                // Log progress every 0.5 seconds
                if Int(elapsed * 10) % 5 == 0 {
                    Logger.voice("⏳ Silence: \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", self.silenceTimeout))s")
                }
            }
            
            // Main silence timer
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: silenceTimeout,
                repeats: false
            ) { [weak self] _ in
                self?.handleSpeechEnd()
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
    
    private func handleSpeechEnd() {
        guard isSpeechActive, let startTime = speechStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Stop silence indicators
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Post notification to reset UI indicator
        NotificationCenter.default.post(name: .silenceTimerReset, object: self)
        
        // Only process if speech lasted long enough
        if duration >= minSpeechDuration {
            Logger.voice("✅ Speech ended (duration: \(String(format: "%.2f", duration))s) - sending to transcription")
            
            // Save current recording
            stopRecording()
            
            // Start new recording immediately for continuous listening
            if isListening {
                startRecording()
                startLevelMonitoring()
            }
        } else {
            // Too short - treat as noise
            Logger.warning("⚠️ Speech too short (\(String(format: "%.2f", duration))s < \(minSpeechDuration)s), ignoring as noise")
            isSpeechActive = false
            speechStartTime = nil
        }
    }
}
