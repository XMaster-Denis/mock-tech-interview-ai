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
    
    @Published var session = InterviewSession.empty
    @Published var conversationState: ConversationState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var voiceThreshold: Float = 0.15  // From settings for UI display
    @Published var errorMessage: String?
    @Published var code: String = ""
    @Published var codeLanguage: CodeLanguageInterview = .swift
    @Published var topics: [InterviewTopic] = []
    @Published var isEditingTopic = false
    @Published var topicToEdit: InterviewTopic?
    @Published var textInput: String = ""
    @Published var isSendingTextMessage: Bool = false
    
    // MARK: - Components
    
    private let conversationManager: ConversationManager
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let topicsRepository: TopicsRepository
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    convenience init() {
        self.init(
            whisperService: OpenAIWhisperService(),
            chatService: OpenAIChatService(),
            ttsService: OpenAITTSService(),
            settingsRepository: SettingsRepository(),
            topicsRepository: TopicsRepository(),
            developerLevel: .junior
        )
    }
    
    init(
        whisperService: OpenAIWhisperServiceProtocol,
        chatService: OpenAIChatServiceProtocol,
        ttsService: OpenAITTSServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        topicsRepository: TopicsRepository,
        developerLevel: DeveloperLevel = .junior
    ) {
        self.whisperService = whisperService
        self.chatService = chatService
        self.ttsService = ttsService
        self.settingsRepository = settingsRepository
        self.topicsRepository = topicsRepository
        
        // Initialize ConversationManager on MainActor
        self.conversationManager = ConversationManager(
            whisperService: whisperService,
            chatService: chatService,
            ttsService: ttsService,
            settingsRepository: settingsRepository,
            developerLevel: developerLevel
        )
        
        setupBindings()
        loadTopics()
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
        
        // Setup code update callback
        conversationManager.onCodeUpdate = { [weak self] newCode in
            self?.code = newCode
        }
        
        // Sync code changes to ConversationManager
        $code
            .dropFirst() // Skip initial value
            .sink { [weak self] newCode in
                self?.conversationManager.updateCodeContext(code: newCode, language: self?.codeLanguage ?? .swift)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadTopics() {
        switch topicsRepository.loadTopics() {
        case .success(let loadedTopics):
            self.topics = loadedTopics
            // Set default topic if session has no topic
            if session.topic.title.isEmpty, let firstTopic = loadedTopics.first {
                session.topic = firstTopic
            }
        case .failure(let error):
            errorMessage = "Failed to load topics: \(error.localizedDescription)"
            Logger.error("Failed to load topics: \(error.localizedDescription)")
        }
    }
    
    func addTopic(_ topic: InterviewTopic) {
        switch topicsRepository.addTopic(topic) {
        case .success:
            loadTopics()
        case .failure(let error):
            errorMessage = "Failed to add topic: \(error.localizedDescription)"
            Logger.error("Failed to add topic: \(error.localizedDescription)")
        }
    }
    
    func updateTopic(_ topic: InterviewTopic) {
        switch topicsRepository.updateTopic(topic) {
        case .success:
            loadTopics()
            // Update session topic if the updated topic is the selected one
            if session.topic.id == topic.id {
                session.topic = topic
            }
        case .failure(let error):
            errorMessage = "Failed to update topic: \(error.localizedDescription)"
            Logger.error("Failed to update topic: \(error.localizedDescription)")
        }
    }
    
    func deleteTopic(id: UUID) {
        switch topicsRepository.deleteTopic(id: id) {
        case .success:
            loadTopics()
            // Select a different topic if we deleted the selected one
            if session.topic.id == id, let firstTopic = topics.first {
                session.topic = firstTopic
            }
        case .failure(let error):
            errorMessage = "Failed to delete topic: \(error.localizedDescription)"
            Logger.error("Failed to delete topic: \(error.localizedDescription)")
        }
    }
    
    func startEditingTopic(_ topic: InterviewTopic) {
        topicToEdit = topic
        isEditingTopic = true
    }
    
    func cancelEditing() {
        topicToEdit = nil
        isEditingTopic = false
    }
    
    func startInterview() {
        guard !session.isActive else { return }
        
        // Check API key
        let settings = settingsRepository.loadSettings()
        guard !settings.apiKey.isEmpty else {
            errorMessage = "Please configure your OpenAI API key in Settings first"
            return
        }
        
        // Update mode in conversation manager before starting
        conversationManager.updateInterviewMode(session.topic.interviewMode)
        
        // Initialize context if not present
        if session.context == nil {
            session.context = InterviewContext(sessionId: session.id)
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
    
    // MARK: - Code Editor Methods
    
    /// Set code in the editor (called by ConversationManager)
    func setCode(_ newCode: String) {
        code = newCode
        // Sync to ConversationManager
        conversationManager.updateCodeContext(code: newCode, language: codeLanguage)
    }
    
    /// Update code language
    func updateCodeLanguage(_ language: CodeLanguageInterview) {
        codeLanguage = language
        // Sync to ConversationManager
        conversationManager.updateCodeContext(code: code, language: language)
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
    
    // MARK: - Text Message Handling
    
    /// Отправляет текстовое сообщение пользователя
    func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            Logger.warning("Cannot send empty text message")
            return
        }
        
        guard session.isActive else {
            errorMessage = "Please start the interview first"
            Logger.warning("Cannot send message - interview is not active")
            return
        }
        
        isSendingTextMessage = true
        
        Task {
            await conversationManager.sendTextMessage(text)
            await MainActor.run {
                textInput = ""
                isSendingTextMessage = false
            }
        }
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
