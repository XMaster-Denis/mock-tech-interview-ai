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
    
    private let audioManager: FullDuplexAudioManager
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
        
        let audioManager = FullDuplexAudioManager()
        self.audioManager = audioManager
        
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
        guard conversationState == .idle else {
            Logger.warning("Cannot start conversation, current state: \(conversationState)")
            return
        }
        
        Logger.state("Starting conversation - topic: \(topic.title), language: \(language)")
        conversationState = .listening
        currentTopic = topic
        
        // Load settings and update voice threshold
        let settings = settingsRepository.loadSettings()
        audioManager.updateVoiceThreshold(settings.voiceThreshold)
        Logger.state("Voice threshold set to: \(settings.voiceThreshold)")
        
        // Start continuous listening
        Logger.state("Starting audio listening")
        audioManager.startListening()
        
        // Generate opening message
        Logger.state("Sending opening message task")
        Task {
            await sendOpeningMessage(topic: topic, language: language)
        }
    }
    
    func stopConversation() {
        Logger.state("Stopping conversation")
        isStopping = true
        conversationState = .idle
        currentTopic = nil
        
        Logger.state("Stopping audio manager")
        audioManager.stopListening()
        audioManager.stopPlayback()
        
        Logger.state("Cancelling processing task")
        processingTask?.cancel()
        processingTask = nil
        
        // Reset stopping flag after a delay to allow pending operations to complete
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            Logger.state("Resetting isStopping flag")
            isStopping = false
        }
    }
    
    // MARK: - Voice Event Handlers
    
    private func handleUserSpeechStarted() {
        Logger.state("User started speaking")
        
        // Cancel any ongoing processing
        if processingTask != nil {
            Logger.state("Cancelling processing task due to user speech")
            processingTask?.cancel()
            processingTask = nil
        }
    }
    
    private func handleUserSpeechEnded(audioData: Data) {
        Logger.state("User finished speaking - audio data: \(audioData.count) bytes")
        
        guard conversationState != .speaking else {
            Logger.warning("Ignoring speech end - currently speaking")
            return
        }
        
        conversationState = .processing
        isProcessing = true
        
        Logger.state("Creating processing task for user speech")
        processingTask = Task { [weak self] in
            await self?.processUserSpeech(audioData: audioData)
        }
    }
    
    private func handleTTSCancelled() {
        Logger.state("TTS was cancelled by user")
        conversationState = .listening
    }
    
    private func handleTTSCompleted() {
        Logger.state("TTS completed")
        conversationState = .listening
        isProcessing = false
    }
    
    // MARK: - Message Processing
    
    private func sendOpeningMessage(topic: InterviewTopic, language: Language) async {
        Logger.state("sendOpeningMessage() START - topic: \(topic.title), language: \(language)")
        
        // Check if stopping
        guard !isStopping else {
            Logger.warning("sendOpeningMessage() cancelled - isStopping=true")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            Logger.error("API key is not configured")
            onError?("API key is not configured")
            return
        }
        
        do {
            // Generate opening prompt
            Logger.state("Generating opening prompt")
            let openingPrompt = generateOpeningPrompt(topic: topic, language: language)
            
            // Get AI response (empty messages for opening)
            Logger.state("Calling chatService.sendMessage() for opening message")
            let response = try await chatService.sendMessage(
                messages: [],
                topic: topic,
                language: language,
                apiKey: apiKey
            )
            
            Logger.state("Received AI opening response: \(String(response.prefix(100)))...")
            
            // Check if stopping before proceeding
            guard !isStopping else {
                Logger.warning("sendOpeningMessage() cancelled after getting response - isStopping=true")
                return
            }
            
            // Add to conversation history
            Logger.state("Adding AI response to conversation history")
            addMessage(role: TranscriptMessage.MessageRole.assistant, content: response)
            
            // Notify UI
            Logger.state("Notifying UI of AI message")
            onAIMessage?(response)
            
            // Convert to speech (opening message - skip speech check to allow playback)
            Logger.state("Converting AI response to speech (skipSpeechCheck=true for non-interruptible)")
            await speakResponse(response, language: language, apiKey: apiKey, skipSpeechCheck: true)
            
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                Logger.warning("sendOpeningMessage() error cancelled due to stop")
                return
            }
            
            Logger.error("Failed to send opening message", error: error)
            onError?(error.localizedDescription)
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func processUserSpeech(audioData: Data) async {
        Logger.state("processUserSpeech() START - audio data: \(audioData.count) bytes")
        
        // Check if stopping before processing
        guard !isStopping else {
            Logger.warning("processUserSpeech() cancelled - isStopping=true")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            Logger.error("API key is not configured")
            onError?("API key is not configured")
            guard !isStopping else { return }
            conversationState = .listening
            isProcessing = false
            return
        }
        
        do {
            // Transcribe audio
            Logger.state("Calling whisperService.transcribe()")
            let userText = try await whisperService.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: settings.selectedLanguage.rawValue
            )
            
            Logger.state("Received transcription: '\(userText)'")
            
            // Check if stopping after transcription
            guard !isStopping else {
                Logger.warning("processUserSpeech() cancelled after transcription - isStopping=true")
                return
            }
            
            guard !userText.isEmpty else {
                Logger.warning("Empty transcription, ignoring")
                guard !isStopping else { return }
                conversationState = .listening
                isProcessing = false
                return
            }
            
            Logger.state("User message: '\(userText)'")
            onUserMessage?(userText)
            
            // Get AI response
            Logger.state("Calling chatService.sendMessage() for user message")
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            let response = try await chatService.sendMessage(
                messages: conversationHistory,
                topic: topic,
                language: settings.selectedLanguage,
                apiKey: apiKey
            )
            
            Logger.state("Received AI response: \(String(response.prefix(100)))...")
            
            // Check if stopping after getting AI response
            guard !isStopping else {
                Logger.warning("processUserSpeech() cancelled after AI response - isStopping=true")
                return
            }
            
            // Add user message to history
            Logger.state("Adding user message to history")
            addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
            
            Logger.state("AI message: '\(response)'")
            onAIMessage?(response)
            
            // Convert to speech
            Logger.state("Converting AI response to speech")
            await speakResponse(response, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch HTTPError.requestCancelled {
            // Request was cancelled due to user speech - this is expected
            Logger.warning("processUserSpeech() - transcribe request cancelled (expected on user speech)")
            // Reset state without showing error
            guard !isStopping else { return }
            conversationState = .listening
            isProcessing = false
        } catch {
            // Only handle error if not stopping (cancelled errors are expected on stop)
            guard !isStopping else {
                Logger.warning("processUserSpeech() error cancelled due to stop")
                return
            }
            
            Logger.error("Processing failed", error: error)
            onError?(error.localizedDescription)
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func speakResponse(_ text: String, language: Language, apiKey: String, skipSpeechCheck: Bool = false) async {
        Logger.state("speakResponse() START - text length: \(text.count)")
        
        // Check if stopping before TTS
        guard !isStopping else {
            Logger.warning("speakResponse() cancelled - isStopping=true")
            return
        }
        
        do {
            // Generate speech
            let settings = settingsRepository.loadSettings()
            Logger.state("Calling ttsService.generateSpeech() - voice: \(settings.selectedVoice)")
            let audioData = try await ttsService.generateSpeech(
                text: text,
                voice: settings.selectedVoice,
                apiKey: apiKey
            )
            
            Logger.state("Received TTS audio data: \(audioData.count) bytes")
            
            // Check if stopping after generating speech
            guard !isStopping else {
                Logger.warning("speakResponse() cancelled after generation - isStopping=true")
                return
            }
            
            // Play (interruptible)
            Logger.state("Calling audioManager.speak()")
            conversationState = .speaking
            try await audioManager.speak(audioData, canBeInterrupted: true, skipSpeechCheck: skipSpeechCheck)
            
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                Logger.warning("speakResponse() error cancelled due to stop")
                return
            }
            
            Logger.error("TTS failed", error: error)
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
