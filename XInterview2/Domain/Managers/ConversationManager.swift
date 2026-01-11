//
//  ConversationManager.swift
//  XInterview2
//
//  Manages the full duplex conversation flow
//

import Foundation
import Combine

// MARK: - Conversation State

enum ConversationState {
    case idle
    case listening
    case processing
    case speaking
}

// MARK: - Conversation Manager

@MainActor
class ConversationManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversationState: ConversationState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var isProcessing: Bool = false
    
    // MARK: - Components
    
    private let audioManager = FullDuplexAudioManager()
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    // MARK: - Properties
    
    private var currentTopic: InterviewTopic?
    private var conversationHistory: [TranscriptMessage] = []
    private var processingTask: Task<Void, Never>?
    private var isStopping: Bool = false
    
    // MARK: - Callbacks
    
    var onUserMessage: ((String) -> Void)?
    var onAIMessage: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init(
        whisperService: OpenAIWhisperServiceProtocol,
        chatService: OpenAIChatServiceProtocol,
        ttsService: OpenAITTSServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.whisperService = whisperService
        self.chatService = chatService
        self.ttsService = ttsService
        self.settingsRepository = settingsRepository
        
        setupAudioManager()
    }
    
    private func setupAudioManager() {
        // Observe audio level
        audioManager.$audioLevel
            .assign(to: &$audioLevel)
        
        // Voice event handlers
        audioManager.onUserSpeechStarted = { [weak self] in
            self?.handleUserSpeechStarted()
        }
        
        audioManager.onUserSpeechEnded = { [weak self] audioData in
            self?.handleUserSpeechEnded(audioData: audioData)
        }
        
        audioManager.onTTSCancelled = { [weak self] in
            self?.handleTTSCancelled()
        }
        
        audioManager.onTTSCompleted = { [weak self] in
            self?.handleTTSCompleted()
        }
    }
    
    // MARK: - Public Methods
    
    func startConversation(topic: InterviewTopic, language: Language) {
        guard conversationState == .idle else { return }
        
        print("🎬 ConversationManager: Starting conversation")
        conversationState = .listening
        currentTopic = topic
        
        // Start continuous listening
        audioManager.startListening()
        
        // Generate opening message
        Task {
            await sendOpeningMessage(topic: topic, language: language)
        }
    }
    
    func stopConversation() {
        print("🛑 ConversationManager: Stopping conversation")
        isStopping = true
        conversationState = .idle
        currentTopic = nil
        
        audioManager.stopListening()
        audioManager.stopPlayback()
        
        processingTask?.cancel()
        processingTask = nil
        
        // Reset stopping flag after a delay to allow pending operations to complete
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            isStopping = false
        }
    }
    
    // MARK: - Voice Event Handlers
    
    private func handleUserSpeechStarted() {
        print("🗣️ ConversationManager: User started speaking")
        
        // Cancel any ongoing processing
        processingTask?.cancel()
        processingTask = nil
    }
    
    private func handleUserSpeechEnded(audioData: Data) {
        print("🤫 ConversationManager: User finished speaking")
        
        guard conversationState != .speaking else { return }
        
        conversationState = .processing
        isProcessing = true
        
        processingTask = Task { [weak self] in
            await self?.processUserSpeech(audioData: audioData)
        }
    }
    
    private func handleTTSCancelled() {
        print("🛑 ConversationManager: TTS was cancelled by user")
        conversationState = .listening
    }
    
    private func handleTTSCompleted() {
        print("✅ ConversationManager: TTS completed")
        conversationState = .listening
        isProcessing = false
    }
    
    // MARK: - Message Processing
    
    private func sendOpeningMessage(topic: InterviewTopic, language: Language) async {
        // Check if stopping
        guard !isStopping else { return }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            onError?("API key is not configured")
            return
        }
        
        do {
            // Generate opening prompt
            let openingPrompt = generateOpeningPrompt(topic: topic, language: language)
            
            // Get AI response (empty messages for opening)
            let response = try await chatService.sendMessage(
                messages: [],
                topic: topic,
                language: language,
                apiKey: apiKey
            )
            
            // Check if stopping before proceeding
            guard !isStopping else { return }
            
            // Add to conversation history
            addMessage(role: TranscriptMessage.MessageRole.assistant, content: response)
            
            // Notify UI
            onAIMessage?(response)
            
            // Convert to speech
            await speakResponse(response, language: language, apiKey: apiKey)
            
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                print("⚠️ ConversationManager: Opening message cancelled due to stop")
                return
            }
            
            print("❌ ConversationManager: Failed to send opening message - \(error)")
            onError?(error.localizedDescription)
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func processUserSpeech(audioData: Data) async {
        // Check if stopping before processing
        guard !isStopping else {
            print("⚠️ ConversationManager: Ignoring speech - conversation is stopping")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            onError?("API key is not configured")
            guard !isStopping else { return }
            conversationState = .listening
            isProcessing = false
            return
        }
        
        do {
            // Transcribe audio
            print("📝 ConversationManager: Transcribing audio...")
            let userText = try await whisperService.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: settings.selectedLanguage.rawValue
            )
            
            // Check if stopping after transcription
            guard !isStopping else {
                print("⚠️ ConversationManager: Transcription cancelled due to stop")
                return
            }
            
            guard !userText.isEmpty else {
                print("⚠️ ConversationManager: Empty transcription, ignoring")
                guard !isStopping else { return }
                conversationState = .listening
                isProcessing = false
                return
            }
            
            print("👤 User: \(userText)")
            onUserMessage?(userText)
            
            // Get AI response
            print("🤖 ConversationManager: Getting AI response...")
            guard let topic = currentTopic else { return }
            let response = try await chatService.sendMessage(
                messages: conversationHistory,
                topic: topic,
                language: settings.selectedLanguage,
                apiKey: apiKey
            )
            
            // Check if stopping after getting AI response
            guard !isStopping else {
                print("⚠️ ConversationManager: AI response cancelled due to stop")
                return
            }
            
            // Add user message to history
            addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
            
            print("🤖 AI: \(response)")
            onAIMessage?(response)
            
            // Convert to speech
            await speakResponse(response, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            // Only handle error if not stopping (cancelled errors are expected on stop)
            guard !isStopping else {
                print("⚠️ ConversationManager: Processing cancelled due to stop")
                return
            }
            
            print("❌ ConversationManager: Processing failed - \(error)")
            onError?(error.localizedDescription)
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func speakResponse(_ text: String, language: Language, apiKey: String) async {
        // Check if stopping before TTS
        guard !isStopping else {
            print("⚠️ ConversationManager: TTS cancelled - conversation is stopping")
            return
        }
        
        do {
            // Generate speech
            let settings = settingsRepository.loadSettings()
            let audioData = try await ttsService.generateSpeech(
                text: text,
                voice: settings.selectedVoice,
                apiKey: apiKey
            )
            
            // Check if stopping after generating speech
            guard !isStopping else {
                print("⚠️ ConversationManager: TTS generation cancelled due to stop")
                return
            }
            
            // Play (interruptible)
            conversationState = .speaking
            try await audioManager.speak(audioData, canBeInterrupted: true)
            
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                print("⚠️ ConversationManager: TTS cancelled due to stop")
                return
            }
            
            print("❌ ConversationManager: TTS failed - \(error)")
            conversationState = .listening
            isProcessing = false
        }
    }
    
    // MARK: - Helpers
    
    private func addMessage(role: TranscriptMessage.MessageRole, content: String) {
        let message = TranscriptMessage(
            role: role,
            text: content,
            timestamp: Date()
        )
        conversationHistory.append(message)
    }
    
    private func generateOpeningPrompt(topic: InterviewTopic, language: Language) -> String {
        let topicTitle = topic.title
        let instructions = topic.prompt
        
        switch language {
        case .english:
            return """
            You are an interview tutor helping a candidate prepare for a \(topicTitle) interview.
            
            Instructions: \(instructions)
            
            Start with a brief, friendly introduction and begin with your first question.
            Keep your responses short (1-2 sentences).
            """
        case .german:
            return """
            Du bist ein Interview-Tutor, der einem Kandidaten bei der Vorbereitung auf ein \(topicTitle)-Interview hilfst.
            
            Anweisungen: \(instructions)
            
            Beginne mit einer kurzen, freundlichen Vorstellung und stelle deine erste Frage.
            Halte deine Antworten kurz (1-2 Sätze).
            """
        case .russian:
            return """
            Вы — наставник по собеседованиям, помогающий кандидату подготовиться к интервью на позицию \(topicTitle).
            
            Инструкции: \(instructions)
            
            Начните с краткого дружелюбного приветствия и задайте первый вопрос.
            Ваши ответы должны быть короткими (1-2 предложения).
            """
        }
    }
    
    // MARK: - Properties
    
    var isListening: Bool {
        audioManager.isListening
    }
    
    var isSpeaking: Bool {
        audioManager.isSpeaking
    }
}
