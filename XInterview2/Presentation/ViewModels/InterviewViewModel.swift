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
            print("🎙️ InterviewViewModel: Recording state changed to .recording")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("❌ InterviewViewModel: Start recording failed - \(error.localizedDescription)")
        }
    }
    
    private func stopRecordingAndProcess() async {
        do {
            try audioEngine.stopRecording()
            state = .transcribing
            print("📝 InterviewViewModel: Recording stopped, transcribing...")
            
            guard let audioData = audioEngine.audioData else {
                errorMessage = "No audio data recorded"
                state = .idle
                print("❌ InterviewViewModel: No audio data available")
                return
            }
            
            print("📊 InterviewViewModel: Audio data size: \(audioData.count) bytes")
            
            // Transcribe audio
            let settings = settingsRepository.loadSettings()
            print("📡 InterviewViewModel: Sending audio to Whisper API...")
            let userText = try await whisperService.transcribe(audioData: audioData, apiKey: settings.apiKey)
            
            print("📝 InterviewViewModel: Transcribed text: \"\(userText)\"")
            
            guard !userText.isEmpty else {
                errorMessage = "No speech detected"
                state = .idle
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
            print("❌ InterviewViewModel: Processing failed - \(error.localizedDescription)")
        }
    }
    
    private func generateAIResponse(isInitial: Bool) async {
        guard session.isActive else {
            state = .idle
            print("⚠️ InterviewViewModel: Session not active")
            return
        }
        
        state = .generatingResponse
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
}
