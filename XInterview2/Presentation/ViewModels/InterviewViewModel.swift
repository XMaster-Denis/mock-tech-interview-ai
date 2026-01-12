//
//  InterviewViewModel.swift
//  XInterview2
//
//  Manages interview session with full duplex audio
//

import SwiftUI
import Combine

@MainActor
class InterviewViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var session = InterviewSession()
    @Published var conversationState: ConversationState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var voiceThreshold: Float = 0.15  // From settings for UI display
    @Published var errorMessage: String?
    @Published var codeEditorViewModel = CodeEditorViewModel()
    
    // MARK: - Components
    
    private let conversationManager: ConversationManager
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    convenience init() {
        self.init(
            whisperService: OpenAIWhisperService(),
            chatService: OpenAIChatService(),
            ttsService: OpenAITTSService(),
            settingsRepository: SettingsRepository(),
            codeEditorViewModel: CodeEditorViewModel(),
            developerLevel: .junior
        )
    }
    
    init(
        whisperService: OpenAIWhisperServiceProtocol,
        chatService: OpenAIChatServiceProtocol,
        ttsService: OpenAITTSServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        codeEditorViewModel: CodeEditorViewModel,
        developerLevel: DeveloperLevel = .junior
    ) {
        self.whisperService = whisperService
        self.chatService = chatService
        self.ttsService = ttsService
        self.settingsRepository = settingsRepository
        self.codeEditorViewModel = codeEditorViewModel
        
        // Initialize ConversationManager on MainActor with code editor
        self.conversationManager = ConversationManager(
            whisperService: whisperService,
            chatService: chatService,
            ttsService: ttsService,
            settingsRepository: settingsRepository,
            codeEditorViewModel: codeEditorViewModel,
            developerLevel: developerLevel
        )
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind conversation state
        conversationManager.$conversationState
            .assign(to: &$conversationState)
        
        // Bind audio level
        conversationManager.$audioLevel
            .assign(to: &$audioLevel)
        
        // Bind voice threshold from settings
        voiceThreshold = settingsRepository.loadSettings().voiceThreshold
        
        // Setup message callbacks
        conversationManager.onUserMessage = { [weak self] text in
            self?.addUserMessage(text)
        }
        
        conversationManager.onAIMessage = { [weak self] text in
            self?.addAIMessage(text)
        }
        
        conversationManager.onError = { [weak self] error in
            self?.errorMessage = error
        }
    }
    
    // MARK: - Public Methods
    
    func startInterview() {
        guard !session.isActive else { return }
        
        // Check API key
        let settings = settingsRepository.loadSettings()
        guard !settings.apiKey.isEmpty else {
            errorMessage = "Please configure your OpenAI API key in Settings first"
            return
        }
        
        session.isActive = true
        session.startTime = Date()
        conversationManager.startConversation(topic: session.topic, language: settings.selectedLanguage)
    }
    
    func stopInterview() {
        guard session.isActive else { return }
        
        session.isActive = false
        session.endTime = Date()
        conversationManager.stopConversation()
    }
    
    func toggleRecording() {
        // Recording is now automatic - toggle controls interview instead
        if session.isActive {
            stopInterview()
        } else {
            startInterview()
        }
    }
    
    func selectTopic(_ topic: InterviewTopic) {
        guard !session.isActive else { return }
        session.topic = topic
    }
    
    var selectedTopic: InterviewTopic {
        session.topic
    }
    
    // MARK: - Message Handling
    
    private func addUserMessage(_ text: String) {
        let message = TranscriptMessage(
            role: .user,
            text: text,
            timestamp: Date()
        )
        session.transcript.append(message)
    }
    
    private func addAIMessage(_ text: String) {
        let message = TranscriptMessage(
            role: .assistant,
            text: text,
            timestamp: Date()
        )
        session.transcript.append(message)
    }
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        conversationState == .listening
    }
    
    var canRecord: Bool {
        session.isActive
    }
    
    var recordingButtonText: String {
        isRecording ? "Recording..." : "Speak"
    }
    
    var statusText: String {
        switch conversationState {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .speaking:
            return "Speaking..."
        }
    }
}
