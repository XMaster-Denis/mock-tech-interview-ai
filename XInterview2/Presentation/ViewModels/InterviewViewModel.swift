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
    
    private let settingsRepository: SettingsRepositoryProtocol
    private let audioEngine: AudioEngineProtocol
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    
    // MARK: - Initialization
    
    init() {
        let initialTopic = InterviewTopic.defaultTopics[0]
        self.settingsRepository = SettingsRepository()
        self.audioEngine = AudioEngine()
        self.whisperService = OpenAIWhisperService()
        self.chatService = OpenAIChatService()
        self.ttsService = OpenAITTSService()
        
        self.selectedTopic = initialTopic
        self.session = InterviewSession(topic: initialTopic)
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
        
        // Generate initial greeting
        Task {
            await generateAIResponse(isInitial: true)
        }
    }
    
    func stopInterview() {
        session.isActive = false
        state = .idle
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
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func stopRecordingAndProcess() async {
        do {
            try audioEngine.stopRecording()
            state = .transcribing
            
            guard let audioData = audioEngine.audioData else {
                errorMessage = "No audio data recorded"
                state = .idle
                return
            }
            
            // Transcribe audio
            let settings = settingsRepository.loadSettings()
            let userText = try await whisperService.transcribe(audioData: audioData, apiKey: settings.apiKey)
            
            guard !userText.isEmpty else {
                state = .idle
                return
            }
            
            // Add user message to session
            let userMessage = TranscriptMessage(role: .user, text: userText)
            session.messages.append(userMessage)
            
            // Generate AI response
            await generateAIResponse(isInitial: false)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            state = .idle
        }
    }
    
    private func generateAIResponse(isInitial: Bool) async {
        guard session.isActive else {
            state = .idle
            return
        }
        
        state = .generatingResponse
        
        do {
            let settings = settingsRepository.loadSettings()
            
            let responseText = try await chatService.sendMessage(
                messages: session.messages,
                topic: session.topic,
                language: session.language,
                apiKey: settings.apiKey
            )
            
            // Add AI message to session
            let aiMessage = TranscriptMessage(role: .assistant, text: responseText)
            session.messages.append(aiMessage)
            
            // Generate and play speech
            state = .playingResponse
            let audioData = try await ttsService.generateSpeech(
                text: responseText,
                voice: settings.selectedVoice,
                apiKey: settings.apiKey
            )
            
            try audioEngine.playAudio(audioData)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            state = .idle
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
}
