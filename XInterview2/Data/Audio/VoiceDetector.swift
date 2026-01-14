//
//  VoiceDetector.swift
//  XInterview2
//
//  Voice Activity Detection for continuous speech recognition
//  Now with adaptive noise analysis and microphone calibration
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
    private var speechStartThreshold: Float // Configurable via settings (fallback when adaptive mode is off)
    private var silenceTimeout: TimeInterval // Configurable via settings
    private let minSpeechDuration: TimeInterval = 0.2  // Lowered from 0.5 for faster testing
    private let minSpeechLevel: Float = 0.04  // Minimum average audio level to consider as valid speech (not noise)
    private let maxRecordingDuration: TimeInterval = 30.0
    private let calibrationDelay: TimeInterval = 1.0 // Ignore first 1s for mic calibration (legacy)
    
    // MARK: - Adaptive Noise Analysis
    
    private let noiseAnalyzer: NoiseAnalyzer
    private var useAdaptiveMode: Bool = true  // Enable adaptive noise analysis
    private var adaptiveThreshold: Float = 0.0  // Current adaptive threshold
    private var noiseLevel: Float = 0.0  // Current noise level
    
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
    private var cancellables = Set<AnyCancellable>() // For Combine subscriptions
    
    // MARK: - Callbacks
    
    var onVoiceEvent: ((VoiceEvent) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        self.speechStartThreshold = 0.15 // Lower default threshold for better sensitivity
        self.silenceTimeout = 1.5  // Default silence timeout
        self.noiseAnalyzer = NoiseAnalyzer(configuration: .default)
        super.init()
        setupAudioSession()
        observeNoiseAnalyzer()
    }
    
    init(speechThreshold: Float, silenceTimeout: Double = 1.5, adaptiveMode: Bool = true) {
        self.speechStartThreshold = speechThreshold
        self.silenceTimeout = silenceTimeout
        self.useAdaptiveMode = adaptiveMode
        self.noiseAnalyzer = NoiseAnalyzer(configuration: .default)
        super.init()
        setupAudioSession()
        observeNoiseAnalyzer()
    }
    
    init(speechThreshold: Float, silenceTimeout: Double = 1.5, noiseConfig: NoiseAnalyzerConfiguration) {
        self.speechStartThreshold = speechThreshold
        self.silenceTimeout = silenceTimeout
        self.useAdaptiveMode = true
        self.noiseAnalyzer = NoiseAnalyzer(configuration: noiseConfig)
        super.init()
        setupAudioSession()
        observeNoiseAnalyzer()
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
    
    /// Enable or disable adaptive noise analysis mode
    func setAdaptiveMode(_ enabled: Bool) {
        Logger.voice("Setting adaptive mode to: \(enabled)")
        useAdaptiveMode = enabled
        if enabled {
            Logger.voice("🎤 Adaptive mode enabled - using noise analyzer")
        } else {
            Logger.voice("📊 Using fixed threshold: \(speechStartThreshold)")
        }
    }
    
    /// Get current adaptive threshold (if adaptive mode is enabled)
    func getCurrentAdaptiveThreshold() -> Float {
        return useAdaptiveMode ? adaptiveThreshold : speechStartThreshold
    }
    
    /// Get current noise level
    func getCurrentNoiseLevel() -> Float {
        return noiseLevel
    }
    
    /// Check if environment is too noisy
    func isEnvironmentTooNoisy() -> Bool {
        return useAdaptiveMode && noiseAnalyzer.isEnvironmentTooNoisy()
    }
    
    /// Get calibration status
    func getCalibrationStatus() -> CalibrationStatus {
        return noiseAnalyzer.calibrationStatus
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
            
            // Start noise analyzer calibration if adaptive mode is enabled
            if useAdaptiveMode {
                Logger.voice("🎤 Starting adaptive noise calibration...")
                noiseAnalyzer.startCalibration()
                
                // Wait for calibration to complete before enabling speech detection
                Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.isCalibrated = true
                        self?.adaptiveThreshold = self?.noiseAnalyzer.getCurrentThreshold() ?? 0.15
                        self?.noiseLevel = self?.noiseAnalyzer.getCurrentNoiseLevel() ?? 0.0
                        Logger.voice("✅ Adaptive calibration complete, speech detection enabled")
                        Logger.voice("   Noise level: \(String(format: "%.3f", self?.noiseLevel ?? 0))")
                        Logger.voice("   Adaptive threshold: \(String(format: "%.3f", self?.adaptiveThreshold ?? 0))")
                    }
                }
            } else {
                // Legacy calibration - just wait fixed delay
                Timer.scheduledTimer(withTimeInterval: calibrationDelay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.isCalibrated = true
                        Logger.voice("✅ Legacy calibration complete, speech detection enabled (threshold: \(self?.speechStartThreshold ?? 0.15))")
                    }
                }
            }
            
            Logger.success("Recording started (calibrating...)")
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
            MainActor.assumeIsolated {
                self?.checkAudioLevel()
            }
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
        
        // Use adaptive noise analyzer if enabled
        var effectiveThreshold: Float
        var isAboveThreshold: Bool
        
        if useAdaptiveMode {
            // Analyze with noise analyzer
            let analysis = noiseAnalyzer.analyze(audioLevel: level)
            adaptiveThreshold = analysis.adaptiveThreshold
            noiseLevel = analysis.noiseLevel
            effectiveThreshold = analysis.adaptiveThreshold
            isAboveThreshold = analysis.isVoiceDetected
            
            // Log calibration progress
            if case .inProgress(let progress) = analysis.calibrationStatus {
                Logger.voice("🎤 Calibrating... \(Int(progress * 100))%")
            }
        } else {
            // Use fixed threshold
            effectiveThreshold = speechStartThreshold
            isAboveThreshold = level > speechStartThreshold
        }
        
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
            
            let thresholdName = useAdaptiveMode ? "Adaptive" : "Fixed"
            Logger.voice("🎤 SPEECH STARTED! Level: \(String(format: "%.2f", level)) > Threshold: \(String(format: "%.2f", effectiveThreshold)) (\(thresholdName))")
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
            
            let thresholdName = useAdaptiveMode ? "Adaptive" : "Fixed"
            Logger.voice("🔇 SILENCE DETECTED! Level: \(String(format: "%.2f", level)) < Threshold: \(String(format: "%.2f", effectiveThreshold)) (\(thresholdName))")
            Logger.voice("⏳ Waiting \(String(format: "%.1f", silenceTimeout))s to confirm speech ended...")
            
            // Start progress animation timer - capture values to avoid main actor warnings
            let timeoutValue = self.silenceTimeout
            let silenceStartValue = self.silenceStartTime  // Capture before closure
            silenceProgressTimer?.invalidate()
            silenceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let start = silenceStartValue else { return }
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1.0, elapsed / timeoutValue)
                
                MainActor.assumeIsolated {
                    self.silenceTimerProgress = progress
                    self.silenceTimerElapsed = elapsed
                }
                
                // Publish to UI every update
                NotificationCenter.default.post(
                    name: .silenceTimerUpdated,
                    object: self,
                    userInfo: [
                        "progress": progress,
                        "elapsed": elapsed,
                        "timeout": timeoutValue
                    ]
                )
                
                // Log progress every 1.0 seconds
                if Int(elapsed) % 1 == 0 && Int(elapsed * 10) % 10 == 0 {
                    Logger.voice("⏳ Silence: \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", timeoutValue))s")
                }
            }
            
            // Main silence timer - capture timeout to avoid main actor warning
            let mainTimeout = self.silenceTimeout
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: mainTimeout,
                repeats: false
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.silenceTimerRunning = false // Reset flag when timer fires
                    self?.fallbackTimer?.invalidate() // Cancel fallback timer
                    self?.fallbackTimer = nil
                    self?.handleSpeechEnd()
                }
            }
            
            // Fallback timer to ensure handleSpeechEnd() is called
            let fallbackTimeout = self.silenceTimeout + 0.1
            fallbackTimer = Timer.scheduledTimer(
                withTimeInterval: fallbackTimeout,
                repeats: false
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.silenceTimerRunning ?? false {
                        Logger.warning("⚠️ Fallback timer triggered - main silence timer didn't fire")
                        self?.silenceTimerRunning = false
                        self?.handleSpeechEnd()
                    }
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
                            duration: TimeInterval) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let inputFileURL = tempDir.appendingPathComponent("input_\(UUID().uuidString).wav")
        let outputFileURL = tempDir.appendingPathComponent("output_\(UUID().uuidString).wav")
        
        defer {
            // Clean up temp files
            try? FileManager.default.removeItem(at: inputFileURL)
            try? FileManager.default.removeItem(at: outputFileURL)
        }
        
        // Write original data to temp file
        try data.write(to: inputFileURL)
        
        // Create asset and export session
        let asset = AVAsset(url: inputFileURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough  // Use passthrough to avoid re-encoding
        ) else {
            throw NSError(domain: "AudioTrim", code: -1, 
                       userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputFileURL
        exportSession.outputFileType = .wav
        
        // Set time range for trimming
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startOffset, preferredTimescale: 16000),
            duration: CMTime(seconds: duration, preferredTimescale: 16000)
        )
        
        // Export
        await exportSession.export()
        
        if let error = exportSession.error {
            Logger.error("Export failed", error: error)
            throw error
        }
        
        // Read trimmed data
        let trimmedData = try Data(contentsOf: outputFileURL)
        
        // Logging
        let originalSizeKB = Double(data.count) / 1024
        let trimmedSizeKB = Double(trimmedData.count) / 1024
        let savedKB = originalSizeKB - trimmedSizeKB
        let savedPercent = (savedKB / originalSizeKB) * 100
        
        let bytesPerSecond = 32000.0  // 16kHz * 2 bytes * 1 channel
        let originalDuration = Double(data.count - 44) / bytesPerSecond
        let endTrimDuration = originalDuration - (startOffset + duration)
        
        Logger.voice("📊 AUDIO TRIMMING REPORT:")
        Logger.voice("   Original: \(String(format: "%.2f", originalDuration))s (\(Int(originalSizeKB)) KB)")
        Logger.voice("   Trimmed start: \(String(format: "%.2f", startOffset))s (\(Int(startOffset * bytesPerSecond / 1024)) KB)")
        Logger.voice("   Kept speech: \(String(format: "%.2f", duration))s (\(Int(duration * bytesPerSecond / 1024)) KB)")
        Logger.voice("   Trimmed end: \(String(format: "%.2f", endTrimDuration))s (\(Int(endTrimDuration * bytesPerSecond / 1024)) KB)")
        Logger.voice("   Final: \(String(format: "%.2f", duration))s (\(Int(trimmedSizeKB)) KB)")
        Logger.voice("   💾 Saved: \(String(format: "%.1f", savedKB)) KB (\(String(format: "%.1f", savedPercent))%)")
        
        return trimmedData
    }
    
    private func calculateAverageLevel(from data: Data) -> Float {

        guard data.count > 44 else { return 0.0 }
        
        let samplesData = data.dropFirst(44)
        let sampleCount = samplesData.count / 2
        guard sampleCount > 0 else { return 0.0 }
        
        var sum: Float = 0
        samplesData.withUnsafeBytes { rawBuffer in
            guard let buffer = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<sampleCount {
                let sample = abs(Float(buffer[i]))
                sum += sample
            }
        }
        
        let average = sum / Float(sampleCount)
        // Normalize to 0.0-1.0 range (Int16 max is 32768)
        return min(1.0, average / 32768.0)
    }
    
    private func handleSpeechEnd() {
        guard isSpeechActive, 
              let startTime = speechStartTime,
              let recordingStart = recordingStartTime else { return }
        
        // Use silenceStartTime for accurate speech duration (excludes silence timeout)
        let silenceStart = silenceStartTime ?? Date()
        let duration = silenceStart.timeIntervalSince(startTime)
        
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
            
            // Handle async trimming in a Task
            Task {
                do {
                    let trimmedData = try await trimWAVData(originalData, 
                                                      startOffset: startOffset, 
                                                      duration: speechDuration)
                    
                    // Check average audio level to filter out quiet noise
                    let avgLevel = calculateAverageLevel(from: trimmedData)
                    if avgLevel < minSpeechLevel {
                        Logger.warning("⚠️ Audio too quiet (avg level: \(String(format: "%.3f", avgLevel)) < minSpeechLevel: \(minSpeechLevel)), ignoring as noise")
                        Logger.voice("💡 The audio signal is too weak - likely background noise")
                        // Don't send event, just restart listening
                        return
                    }
                    
                    Logger.voice("📊 Average audio level: \(String(format: "%.3f", avgLevel)) ✓")
                    Logger.voice("📤 Sending trimmed audio to Whisper API")
                    onVoiceEvent?(.speechEnded(trimmedData))
                } catch {
                    // Fallback to original data if trim fails
                    Logger.error("Trim failed, using original audio", error: error)
                    let originalSizeKB = Double(originalData.count) / 1024
                    Logger.voice("📤 Sending original audio: \(String(format: "%.1f", originalSizeKB)) KB")
                    onVoiceEvent?(.speechEnded(originalData))
                }
            }
        }
        
        // Restart recording for continuous listening
        if isListening {
            startRecording()
            startLevelMonitoring()
        }
    }
    
    // MARK: - Private Methods - Noise Analyzer
    
    private func observeNoiseAnalyzer() {
        // Observe noise analyzer published properties
        noiseAnalyzer.$currentNoiseLevel
            .sink { [weak self] level in
                self?.noiseLevel = level
            }
            .store(in: &cancellables)
        
        noiseAnalyzer.$adaptiveThreshold
            .sink { [weak self] threshold in
                self?.adaptiveThreshold = threshold
            }
            .store(in: &cancellables)
    }
}
