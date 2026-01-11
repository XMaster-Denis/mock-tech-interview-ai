//
//  VoiceDetector.swift
//  XInterview2
//
//  Voice Activity Detection for continuous speech recognition
//

import AVFoundation
import Combine

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
    
    // MARK: - Configuration
    
    private let silenceThreshold: Float = 0.05
    private let speechStartThreshold: Float = 0.15 // Increased from 0.08 to reduce false positives
    private let silenceTimeout: TimeInterval = 1.5
    private let minSpeechDuration: TimeInterval = 0.5
    private let maxRecordingDuration: TimeInterval = 30.0
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingFileURL: URL?
    private var recordingStartTime: Date?
    private var speechStartTime: Date?
    private var audioBuffer: Data?
    private var levelMonitorTimer: Timer?
    private var silenceTimer: Timer?
    
    private var isRecording: Bool = false
    private var isSpeechActive: Bool = false
    private var isPaused: Bool = false
    
    // MARK: - Callbacks
    
    var onVoiceEvent: ((VoiceEvent) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
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
    
    func startListening() {
        guard !isListening else { return }
        
        Logger.voice("Starting to listen...")
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
            Logger.success("Recording started")
        } catch {
            Logger.error("Failed to start recording", error: error)
            onVoiceEvent?(.error(error))
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        Logger.voice("Stopping recording...")
        audioRecorder?.stop()
        isRecording = false
        
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
        isSpeechActive = false
        speechDetected = false
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
        guard isListening, !isPaused else { return }
        
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0.0
            return
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        audioLevel = level
        
        let isAboveThreshold = level > speechStartThreshold
        
        // Speech started
        if isAboveThreshold && !isSpeechActive {
            isSpeechActive = true
            speechStartTime = Date()
            speechDetected = true
            silenceTimer?.invalidate()
            
            Logger.voice("Speech started (level: \(String(format: "%.2f", level)), threshold: \(speechStartThreshold))")
            onVoiceEvent?(.speechStarted)
        }
        // Speech in progress
        else if isAboveThreshold && isSpeechActive {
            silenceTimer?.invalidate()
        }
        // Speech possibly ended
        else if !isAboveThreshold && isSpeechActive {
            // Start silence timer to confirm speech ended
            silenceTimer?.invalidate()
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
                Logger.warning("Max duration reached (\(String(format: "%.1f", duration))s)")
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
        
        // Only process if speech lasted long enough
        if duration >= minSpeechDuration {
            Logger.voice("Speech ended (duration: \(String(format: "%.2f", duration))s)")
            
            // Save current recording
            stopRecording()
            
            // Start new recording immediately for continuous listening
            if isListening {
                startRecording()
                startLevelMonitoring()
            }
        } else {
            // Too short - treat as noise
            Logger.warning("Speech too short (\(String(format: "%.2f", duration))s), ignoring as noise")
            isSpeechActive = false
            speechStartTime = nil
            silenceTimer?.invalidate()
        }
    }
}
