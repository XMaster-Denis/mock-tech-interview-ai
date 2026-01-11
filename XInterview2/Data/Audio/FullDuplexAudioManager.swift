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
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        #elseif os(macOS)
        // On macOS, AVAudioSession is limited - audio output is handled differently
        print("✅ FullDuplexAudioManager: macOS audio setup complete")
        #endif
    }
    
    private func configureAudioSessionForPlayback() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            print("✅ FullDuplexAudioManager: Audio session configured for playback")
        } catch {
            print("❌ FullDuplexAudioManager: Failed to configure playback session - \(error)")
        }
        #elseif os(macOS)
        // On macOS, AVAudioPlayer handles output automatically
        print("✅ FullDuplexAudioManager: macOS playback ready")
        #endif
    }
    
    private func configureAudioSessionForRecording() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("✅ FullDuplexAudioManager: Audio session configured for recording")
        } catch {
            print("❌ FullDuplexAudioManager: Failed to configure recording session - \(error)")
        }
        #elseif os(macOS)
        // On macOS, recording is handled by AVAudioRecorder
        print("✅ FullDuplexAudioManager: macOS recording ready")
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
        guard audioState == .idle || audioState == .listening else { return }
        
        print("🎤 FullDuplexAudioManager: Starting continuous listening")
        configureAudioSessionForRecording()
        audioState = .listening
        isListening = true
        voiceDetector.startListening()
    }
    
    func stopListening() {
        print("🔇 FullDuplexAudioManager: Stopping listening")
        audioState = .idle
        isListening = false
        voiceDetector.stopListening()
        stopTTSPreparation()
    }
    
    func pauseListening() {
        print("⏸️ FullDuplexAudioManager: Pausing listening during AI speech")
        voiceDetector.pauseListening()
    }
    
    func resumeListening() {
        print("▶️ FullDuplexAudioManager: Resuming listening")
        voiceDetector.resumeListening()
    }
    
    // MARK: - TTS Playback
    
    func speak(_ audioData: Data, canBeInterrupted: Bool = true) async throws {
        // Stop any current playback
        stopPlayback()
        
        // If user is speaking, cancel TTS
        if voiceDetector.speechDetected {
            print("⚠️ FullDuplexAudioManager: User is speaking, cancelling TTS")
            audioState = .listening
            return
        }
        
        // Configure audio session for playback (important for macOS)
        configureAudioSessionForPlayback()
        
        print("🔊 FullDuplexAudioManager: Starting TTS playback (\(audioData.count) bytes)")
        audioState = .speaking
        isSpeaking = true
        isTTSPrepared = true
        
        // If TTS can be interrupted, continue listening in background
        if canBeInterrupted {
            print("👂 FullDuplexAudioManager: TTS is interruptible, monitoring for user speech")
        } else {
            pauseListening()
        }
        
        // Play the audio
        try await playAudioData(audioData, canBeInterrupted: canBeInterrupted)
    }
    
    private func playAudioData(_ data: Data, canBeInterrupted: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                ttsPlayer = try AVAudioPlayer(data: data)
                ttsPlayer?.delegate = self
                ttsPlayer?.rate = 0.5 // Slower for clarity (like working example)
                ttsPlayer?.volume = 1.0 // Ensure full volume
                ttsPlayer?.prepareToPlay()
                print("🎵 FullDuplexAudioManager: TTS player prepared, rate=0.5, volume=1.0")
                
                ttsTask = Task { @MainActor in
                    ttsPlayer?.play()
                    
                    // Wait for playback to complete or be interrupted
                    while ttsPlayer?.isPlaying == true {
                        // Check for interruption
                        if canBeInterrupted && voiceDetector.speechDetected {
                            print("🛑 FullDuplexAudioManager: User interrupted TTS!")
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
        ttsTask?.cancel()
        ttsTask = nil
        
        ttsPlayer?.stop()
        ttsPlayer = nil
        
        isSpeaking = false
        isTTSPrepared = false
        
        print("🛑 FullDuplexAudioManager: Playback stopped")
    }
    
    private func stopTTSPreparation() {
        stopPlayback()
    }
    
    // MARK: - Voice Event Handling
    
    private func handleVoiceEvent(_ event: VoiceEvent) {
        switch event {
        case .speechStarted:
            print("🗣️ FullDuplexAudioManager: User started speaking")
            
            // Interrupt TTS if speaking
            if isSpeaking {
                print("🛑 FullDuplexAudioManager: Interrupting TTS due to user speech")
                stopPlayback()
                onTTSCancelled?()
                audioState = .listening
            }
            
            onUserSpeechStarted?()
            
        case .speechEnded(let data):
            print("🤫 FullDuplexAudioManager: User finished speaking")
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
        print("✅ FullDuplexAudioManager: TTS playback finished (success: \(flag))")
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
        print("❌ FullDuplexAudioManager: TTS playback error - \(error?.localizedDescription ?? "unknown")")
        isSpeaking = false
        isTTSPrepared = false
        
        // Resume listening on error
        resumeListening()
        audioState = .listening
        
        onTTSCompleted?()
    }
}
