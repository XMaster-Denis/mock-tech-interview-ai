//
//  InterviewViewModel.swift
//  XInterview2
//
//  ViewModel for interview session management
//

import Foundation
import Combine

@MainActor
class InterviewViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var session: InterviewSession
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedTopic: InterviewTopic
    @Published var conversationState: ConversationState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var audioLogs: [String] = []
    
    enum ConversationState {
        case idle
        case listening
        case processing
        case speaking
    }
    
    // MARK: - State
    
    enum InterviewState {
        case idle
        case recording
        case transcribing
        case generatingResponse
        case playingResponse
    }
    
    @Published private(set) var state: InterviewState = .idle
    
    // MARK: - Dependencies
    
    private let audioEngine: AudioEngineProtocol
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        let initialTopic = InterviewTopic.defaultTopics[0]
        self.audioEngine = AudioEngine()
        self.whisperService = OpenAIWhisperService()
        self.chatService = OpenAIChatService()
        self.ttsService = OpenAITTSService()
        self.settingsRepository = SettingsRepository()
        
        self.selectedTopic = initialTopic
        self.session = InterviewSession(topic: initialTopic)
        
        // Setup automatic recording callback
        setupAutoRecording()
        setupAudioLevelObservation()
    }
    
    // MARK: - Auto Recording Setup
    
    private func setupAutoRecording() {
        guard let audioEngineWithCallback = audioEngine as? AudioEngine else { return }
        
        // Start auto-recording when AI finishes speaking
        audioEngineWithCallback.onRecordingStopped = { [weak self] in
            guard let self = self else { return }
            
            // Only auto-start if session is active
            if self.session.isActive && self.conversationState != .processing {
                print("🎤 Auto-starting recording after AI response")
                Task {
                    await self.startRecording()
                }
            }
        }
    }
    
    private func setupAudioLevelObservation() {
        guard let audioEngineWithCallback = audioEngine as? AudioEngine else { return }
        
        // Observe audio level changes
        audioEngineWithCallback.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Observe audio logs
        audioEngineWithCallback.$audioLogs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logs in
                self?.audioLogs = logs
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startInterview() {
        guard session.isActive == false else { return }
        
        let settings = settingsRepository.loadSettings()
        guard settings.hasValidAPIKey else {
            errorMessage = "Please configure your OpenAI API key in Settings"
            return
        }
        
        // Create new session with selected topic and language
        session = InterviewSession(
            topic: selectedTopic,
            language: settings.selectedLanguage,
            isActive: true,
            messages: []
        )
        
        conversationState = .processing
        
        // Generate initial greeting
        Task {
            await generateAIResponse(isInitial: true)
        }
    }
    
    func stopInterview() {
        session.isActive = false
        state = .idle
        conversationState = .idle
        errorMessage = nil
    }
    
    func toggleRecording() {
        switch state {
        case .idle, .playingResponse:
            Task {
                await startRecording()
            }
        case .recording:
            Task {
                await stopRecordingAndProcess()
            }
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func startRecording() async {
        do {
            try audioEngine.startRecording()
            state = .recording
            conversationState = .listening
            errorMessage = nil
            print("🎙️ InterviewViewModel: Recording state changed to .recording")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            state = .idle
            conversationState = .idle
            print("❌ InterviewViewModel: Start recording failed - \(error.localizedDescription)")
        }
    }
    
    private func stopRecordingAndProcess() async {
        do {
            try audioEngine.stopRecording()
            state = .transcribing
            conversationState = .processing
            print("📝 InterviewViewModel: Recording stopped, transcribing...")
            
            guard let audioData = audioEngine.audioData else {
                errorMessage = "No audio data recorded"
                state = .idle
                conversationState = .idle
                print("❌ InterviewViewModel: No audio data available")
                return
            }
            
            print("📊 InterviewViewModel: Audio data size: \(audioData.count) bytes")
            
            // Transcribe audio
            let settings = settingsRepository.loadSettings()
            print("📡 InterviewViewModel: Sending audio to Whisper API...")
            let userText = try await whisperService.transcribe(
                audioData: audioData, 
                apiKey: settings.apiKey,
                language: settings.selectedLanguage.rawValue
            )
            
            print("📝 InterviewViewModel: Transcribed text: \"\(userText)\"")
            
            guard !userText.isEmpty else {
                errorMessage = "No speech detected"
                state = .idle
                conversationState = .listening
                print("⚠️ InterviewViewModel: Empty transcription")
                return
            }
            
            // Add user message to session
            let userMessage = TranscriptMessage(role: .user, text: userText)
            session.messages.append(userMessage)
            print("✅ InterviewViewModel: User message added")
            
            // Generate AI response
            await generateAIResponse(isInitial: false)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            state = .idle
            conversationState = .listening
            print("❌ InterviewViewModel: Processing failed - \(error.localizedDescription)")
            
            // Auto-restart recording on error
            if session.isActive {
                print("🔄 InterviewViewModel: Auto-restarting recording after error")
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                    await startRecording()
                }
            }
        }
    }
    
    private func generateAIResponse(isInitial: Bool) async {
        guard session.isActive else {
            state = .idle
            conversationState = .idle
            print("⚠️ InterviewViewModel: Session not active")
            return
        }
        
        state = .generatingResponse
        conversationState = .processing
        print("🤖 InterviewViewModel: Generating AI response...")
        
        do {
            let settings = settingsRepository.loadSettings()
            
            let responseText = try await chatService.sendMessage(
                messages: session.messages,
                topic: session.topic,
                language: session.language,
                apiKey: settings.apiKey
            )
            
            print("🤖 InterviewViewModel: AI response: \"\(responseText)\"")
            
            // Add AI message to session
            let aiMessage = TranscriptMessage(role: .assistant, text: responseText)
            session.messages.append(aiMessage)
            print("✅ InterviewViewModel: AI message added")
            
            // Generate and play speech
            state = .playingResponse
            conversationState = .speaking
            print("🔊 InterviewViewModel: Generating TTS audio...")
            let audioData = try await ttsService.generateSpeech(
                text: responseText,
                voice: settings.selectedVoice,
                apiKey: settings.apiKey
            )
            
            print("🔊 InterviewViewModel: Playing TTS audio (\(audioData.count) bytes)")
            try audioEngine.playAudio(audioData)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            state = .idle
            conversationState = .listening
            print("❌ InterviewViewModel: AI response failed - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Computed Properties
    
    var canRecord: Bool {
        session.isActive && (state == .idle || state == .playingResponse)
    }
    
    var isRecording: Bool {
        state == .recording
    }
    
    var recordingButtonText: String {
        switch state {
        case .idle, .playingResponse:
            return "Start Recording"
        case .recording:
            return "Stop Recording"
        case .transcribing:
            return "Transcribing..."
        case .generatingResponse:
            return "Thinking..."
        }
    }
    
    var statusText: String {
        switch conversationState {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .speaking:
            return "AI Speaking..."
        }
    }
    
    // MARK: - Audio Testing
    
    func startAudioTest() async throws -> AsyncStream<String> {
        guard let audioEngineWithCallback = audioEngine as? AudioEngine else {
            throw AudioEngineError.recordingInProgress
        }
        return try audioEngineWithCallback.startTestRecording(duration: 5.0)
    }
    
    func stopAudioTest() throws {
        guard let audioEngineWithCallback = audioEngine as? AudioEngine else {
            return
        }
        try audioEngineWithCallback.stopTestRecording()
    }
    
    func clearAudioLogs() {
        guard let audioEngineWithCallback = audioEngine as? AudioEngine else {
            return
        }
        audioEngineWithCallback.clearLogs()
        audioLogs.removeAll()
    }
}
