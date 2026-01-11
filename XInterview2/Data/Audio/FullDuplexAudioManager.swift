//
//  FullDuplexAudioManager.swift
//  XInterview2
//
//  Manages full duplex audio: continuous listening + interruptible playback
//

import AVFoundation
import Combine

// MARK: - Audio State

enum AudioState {
    case idle
    case listening
    case processing
    case speaking
    case interrupted
}

// MARK: - FullDuplexAudioManager

@MainActor
class FullDuplexAudioManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var audioState: AudioState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    
    // MARK: - Components
    
    private let voiceDetector = VoiceDetector()
    private var ttsPlayer: AVAudioPlayer?
    
    // MARK: - Properties
    
    private var isTTSPrepared: Bool = false
    private var ttsTask: Task<Void, Never>?
    
    // MARK: - Callbacks
    
    var onUserSpeechStarted: (() -> Void)?
    var onUserSpeechEnded: ((Data) -> Void)?
    var onTTSCancelled: (() -> Void)?
    var onTTSCompleted: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupVoiceDetector()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func updateVoiceThreshold(_ threshold: Float) {
        Logger.audio("Updating voice threshold to: \(threshold)")
        voiceDetector.updateThreshold(threshold)
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        Logger.audio("Audio session setup complete (playAndRecord)")
        #elseif os(macOS)
        // On macOS, AVAudioSession is limited - audio output is handled differently
        Logger.audio("macOS audio setup complete")
        #endif
    }
    
    private func configureAudioSessionForPlayback() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            Logger.audio("Audio session configured for playback (playback + duckOthers)")
        } catch {
            Logger.error("Failed to configure playback session", error: error)
        }
        #elseif os(macOS)
        // On macOS, AVAudioPlayer handles output automatically
        Logger.audio("macOS playback ready")
        #endif
    }
    
    private func configureAudioSessionForRecording() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            Logger.audio("Audio session configured for recording (playAndRecord)")
        } catch {
            Logger.error("Failed to configure recording session", error: error)
        }
        #elseif os(macOS)
        // On macOS, recording is handled by AVAudioRecorder
        Logger.audio("macOS recording ready")
        #endif
    }
    
    private func setupVoiceDetector() {
        voiceDetector.onVoiceEvent = { [weak self] event in
            self?.handleVoiceEvent(event)
        }
        
        // Observe audio level
        voiceDetector.$audioLevel
            .assign(to: &$audioLevel)
    }
    
    // MARK: - Public Methods
    
    func startListening() {
        guard audioState == .idle || audioState == .listening else {
            Logger.warning("Cannot start listening, current state: \(audioState)")
            return
        }
        
        Logger.audio("Starting continuous listening")
        configureAudioSessionForRecording()
        audioState = .listening
        isListening = true
        voiceDetector.startListening()
    }
    
    func stopListening() {
        Logger.audio("Stopping listening")
        audioState = .idle
        isListening = false
        voiceDetector.stopListening()
        stopTTSPreparation()
    }
    
    func pauseListening() {
        Logger.audio("Pausing listening during AI speech")
        voiceDetector.pauseListening()
    }
    
    func resumeListening() {
        Logger.audio("Resuming listening")
        voiceDetector.resumeListening()
    }
    
    // MARK: - TTS Playback
    
    func speak(_ audioData: Data, canBeInterrupted: Bool = true, skipSpeechCheck: Bool = false) async throws {
        Logger.audio("speak() called - data size: \(audioData.count) bytes, canBeInterrupted: \(canBeInterrupted), skipSpeechCheck: \(skipSpeechCheck)")
        
        // If skipSpeechCheck is true, force non-interruptible mode
        let actualCanBeInterrupted = skipSpeechCheck ? false : canBeInterrupted
        Logger.audio("Actual canBeInterrupted: \(actualCanBeInterrupted)")
        
        // Validate audio data
        guard !audioData.isEmpty else {
            Logger.error("TTS audio data is empty")
            throw NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty audio data"])
        }
        
        // Stop any current playback
        stopPlayback()
        
        // If user is speaking and we're not skipping speech check, cancel TTS
        if !skipSpeechCheck && voiceDetector.speechDetected {
            Logger.warning("User is speaking, cancelling TTS")
            audioState = .listening
            return
        }
        
        // Configure audio session for playback (important for macOS)
        configureAudioSessionForPlayback()
        
        Logger.audio("Starting TTS playback (\(audioData.count) bytes)")
        audioState = .speaking
        isSpeaking = true
        isTTSPrepared = true
        
        // If TTS can be interrupted, continue listening in background
        if actualCanBeInterrupted {
            Logger.audio("TTS is interruptible, monitoring for user speech")
        } else {
            Logger.audio("TTS is non-interruptible, pausing listening")
            pauseListening()
        }
        
        // Play the audio
        try await playAudioData(audioData, canBeInterrupted: actualCanBeInterrupted)
    }
    
    private func playAudioData(_ data: Data, canBeInterrupted: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                ttsPlayer = try AVAudioPlayer(data: data)
                ttsPlayer?.delegate = self
                ttsPlayer?.rate = 0.5 // Slower for clarity (like working example)
                ttsPlayer?.volume = 1.0 // Ensure full volume
                ttsPlayer?.prepareToPlay()
                
                if let duration = ttsPlayer?.duration {
                    Logger.audio("TTS player prepared - rate=0.5, volume=1.0, duration=\(String(format: "%.2f", duration))s")
                } else {
                    Logger.audio("TTS player prepared - rate=0.5, volume=1.0")
                }
                
                ttsTask = Task { @MainActor in
                    Logger.audio("Calling ttsPlayer.play()")
                    ttsPlayer?.play()
                    
                    // Wait for playback to complete or be interrupted
                    while ttsPlayer?.isPlaying == true {
                        // Check for interruption
                        if canBeInterrupted && voiceDetector.speechDetected {
                            Logger.audio("User interrupted TTS!")
                            stopPlayback()
                            onTTSCancelled?()
                            audioState = .listening
                            continuation.resume()
                            return
                        }
                        
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                    
                    // Playback completed normally
                    isSpeaking = false
                    isTTSPrepared = false
                    onTTSCompleted?()
                    
                    // Resume listening if needed
                    if audioState == .speaking {
                        resumeListening()
                        audioState = .listening
                    }
                    
                    continuation.resume()
                }
            } catch {
                print("❌ FullDuplexAudioManager: Failed to play audio - \(error)")
                audioState = .listening
                isSpeaking = false
                continuation.resume(throwing: error)
            }
        }
    }
    
    func stopPlayback() {
        Logger.audio("stopPlayback() called")
        ttsTask?.cancel()
        ttsTask = nil
        
        ttsPlayer?.stop()
        ttsPlayer = nil
        
        isSpeaking = false
        isTTSPrepared = false
    }
    
    private func stopTTSPreparation() {
        stopPlayback()
    }
    
    // MARK: - Voice Event Handling
    
    private func handleVoiceEvent(_ event: VoiceEvent) {
        switch event {
        case .speechStarted:
            Logger.audio("User started speaking")
            
            // Interrupt TTS if speaking
            if isSpeaking {
                Logger.audio("Interrupting TTS due to user speech")
                stopPlayback()
                onTTSCancelled?()
                audioState = .listening
            }
            
            onUserSpeechStarted?()
            
        case .speechEnded(let data):
            Logger.audio("User finished speaking, audio data: \(data.count) bytes")
            audioState = .processing
            onUserSpeechEnded?(data)
            
        case .silenceDetected:
            break
            
        case .error(let error):
            print("❌ FullDuplexAudioManager: Voice error - \(error)")
            audioState = .listening
        }
    }
    
    // MARK: - Properties
    
    var speechDetected: Bool {
        voiceDetector.speechDetected
    }
    
    deinit {
        // Clean up TTS resources
        ttsTask?.cancel()
        ttsPlayer?.stop()
    }
}

// MARK: - AVAudioPlayerDelegate

extension FullDuplexAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Logger.audio("TTS playback finished - success: \(flag)")
        isSpeaking = false
        isTTSPrepared = false
        
        onTTSCompleted?()
        
        // Resume listening
        if audioState == .speaking {
            resumeListening()
            audioState = .listening
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Logger.error("TTS playback error", error: error)
        isSpeaking = false
        isTTSPrepared = false
        
        // Resume listening on error
        resumeListening()
        audioState = .listening
        
        onTTSCompleted?()
    }
}
