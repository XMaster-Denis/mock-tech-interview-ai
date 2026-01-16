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

// MARK: - Interview Task State

enum InterviewTaskState {
    case noTask
    case taskPresented(expectedSolution: String?)
    case waitingForUserConfirmation
}

// MARK: - Conversation Manager

@MainActor
class ConversationManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversationState: ConversationState = .idle
    @Published var audioLevel: Float = 0.0
    @Published var isProcessing: Bool = false
    @Published var taskState: InterviewTaskState = .noTask
    
    // MARK: - Components
    
    private let audioManager: FullDuplexAudioManager
    private let whisperService: OpenAIWhisperServiceProtocol
    private let chatService: OpenAIChatServiceProtocol
    private let ttsService: OpenAITTSServiceProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    // Code Editor Integration
    private var currentCodeContext: CodeContext = CodeContext(currentCode: "", language: .swift, recentChanges: [])
    private var currentLevel: DeveloperLevel = .junior
    
    // Task State Management
    private var currentTaskState: InterviewTaskState = .noTask
    private var currentTaskCode: String = ""
    
    // MARK: - Properties
    
    private var currentTopic: InterviewTopic?
    private var currentMode: InterviewMode = .questionsOnly
    private var conversationHistory: [TranscriptMessage] = []
    private var currentContext: InterviewContext?
    private var processingTask: Task<Void, Never>?
    private var isStopping: Bool = false
    
    // Flag to track if we're currently processing a Chat API request
    // This prevents cancelling requests mid-flight when user starts speaking
    private var isProcessingChatRequest: Bool = false
    
    // Flag to track if we need to request the next question after TTS completes
    private var shouldRequestNextQuestion: Bool = false
    
    // Flag to track if we're currently requesting the next question
    // This prevents infinite loop when AI returns is_correct: true for next question request
    private var isRequestingNextQuestion: Bool = false
    
    // MARK: - Callbacks
    
    var onUserMessage: ((String) -> Void)?
    var onAIMessage: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onCodeUpdate: ((String) -> Void)?
    var onTaskStateChanged: ((InterviewTaskState) -> Void)?
    
    // MARK: - Initialization
    
    init(
        whisperService: OpenAIWhisperServiceProtocol,
        chatService: OpenAIChatServiceProtocol,
        ttsService: OpenAITTSServiceProtocol,
        settingsRepository: SettingsRepositoryProtocol,
        developerLevel: DeveloperLevel = .junior
    ) {
        self.whisperService = whisperService
        self.chatService = chatService
        self.ttsService = ttsService
        self.settingsRepository = settingsRepository
        self.currentLevel = developerLevel
        
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
    
    func startConversation(topic: InterviewTopic, language: Language, context: InterviewContext? = nil) {
        guard conversationState == .idle else {
            return
        }
        
        conversationState = .listening
        currentTopic = topic
        currentContext = context
        
        // Load settings and update voice threshold, silence timeout, and min speech level
        let settings = settingsRepository.loadSettings()
        audioManager.updateVoiceThreshold(settings.voiceThreshold)
        audioManager.updateSilenceTimeout(settings.silenceTimeout)
        audioManager.updateMinSpeechLevel(settings.minSpeechLevel)
        
        // Start continuous listening
        audioManager.startListening()
        
        // Generate opening message
        Task {
            await sendOpeningMessage(topic: topic, language: language)
        }
    }
    
    func stopConversation() {
        isStopping = true
        conversationState = .idle
        currentTopic = nil
        currentContext = nil
        
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
        
        // Only cancel if we're NOT processing a Chat API request
        // This prevents "Network error: cancelled" when user speaks during API call
        if processingTask != nil && !isProcessingChatRequest {
            processingTask?.cancel()
            processingTask = nil
        }
    }
    
    private func handleUserSpeechEnded(audioData: Data) {
        guard conversationState != .speaking else {
            return
        }
        
        conversationState = .processing
        isProcessing = true
        
        processingTask = Task { [weak self] in
            await self?.processUserSpeech(audioData: audioData)
        }
    }
    
    private func handleTTSCancelled() {
        conversationState = .listening
        shouldRequestNextQuestion = false
    }
    
    private func handleTTSCompleted() {
        conversationState = .listening
        isProcessing = false

        // Check if we need to request the next question
        Logger.debug("🔔 handleTTSCompleted: shouldRequestNextQuestion=\(shouldRequestNextQuestion)")
        if shouldRequestNextQuestion {
            shouldRequestNextQuestion = false
            Logger.debug("🚀 Calling requestNextQuestion()")
            Task {
                await requestNextQuestion()
            }
        } else {
            Logger.debug("⏭️ Not requesting next question (shouldRequestNextQuestion=false)")
        }
    }
    
    // MARK: - Message Processing
    
    private func sendOpeningMessage(topic: InterviewTopic, language: Language) async {
        // Check if stopping
        guard !isStopping else {
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
            // Get AI response (empty messages for opening)
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
            // Set flag to prevent cancellation during Chat API request
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: [],
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: language,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            // Check if stopping before proceeding
            guard !isStopping else {
                return
            }
            
            // Add to conversation history
            addMessage(role: TranscriptMessage.MessageRole.assistant, content: aiResponse.spokenText)
            
            // Handle AI response with task state logic
            await handleAIResponse(aiResponse, language: language, apiKey: apiKey)
            
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                return
            }
            
            Logger.error("Failed to send opening message", error: error)
            
            // Reset flag on error
            isProcessingChatRequest = false
            
            // Use error description if available, otherwise localized description
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
            
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func processUserSpeech(audioData: Data) async {
        // Check if stopping before processing
        guard !isStopping else {
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
            // Transcribe audio with technical prompt and temperature
            let prompt = PromptTemplates.Whisper.prompt(for: settings.selectedLanguage)
            let userText = try await whisperService.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: settings.selectedLanguage.rawValue,
                prompt: prompt,
                temperature: 0.1
            )
            
            // Check if stopping after transcription
            guard !isStopping else {
                return
            }
            
            guard !userText.isEmpty else {
                guard !isStopping else { return }
                conversationState = .listening
                isProcessing = false
                return
            }
            
            
            // Check task state before processing
            switch currentTaskState {
            case .taskPresented:
                // User is responding to a task
                let language = settings.selectedLanguage
                
                if isCompletionPhrase(userText, language: language) {
                    // User says they completed task
                    addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
                    onUserMessage?(userText)
                    await checkUserSolution()
                    return
                }
                
                if isHelpRequest(userText, language: language) {
                    // User asks for help
                    addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
                    onUserMessage?(userText)
                    await requestHelp()
                    return
                }
                
                // Any other text is treated as an attempt at solution
                // Add user message to history
                addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
                onUserMessage?(userText)
                
                // Check the solution
                await checkUserSolution()
                return
                
            case .waitingForUserConfirmation:
                // User is confirming understanding
                let language = settings.selectedLanguage
                
                if isUnderstandingConfirmation(userText, language: language) {
                    // User confirms understanding - move to next question
                    addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
                    onUserMessage?(userText)
                    updateTaskState(.noTask)
                    
                    // Continue with next question
                    // Fall through to normal processing
                } else {
                    // User didn't confirm understanding - ask again
                    addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
                    onUserMessage?(userText)
                    return
                }
                
            case .noTask:
                // Normal conversation - no active task
                break
            }
            
            // Add user message to history BEFORE calling API
            // This ensures AI has context of what user just said
            addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
            
            onUserMessage?(userText)
            
            // Get AI response
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            
            // Include context if available for follow-up questions
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
            // Set flag to prevent cancellation during Chat API request
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch HTTPError.requestCancelled {
            // Request was cancelled due to user speech - this is expected
            // Reset state without showing error
            guard !isStopping else { return }
            isProcessingChatRequest = false
            conversationState = .listening
            isProcessing = false
        } catch {
            // Only handle error if not stopping (cancelled errors are expected on stop)
            guard !isStopping else {
                return
            }
            
            Logger.error("Processing failed", error: error)
            
            // Reset flag on error
            isProcessingChatRequest = false
            
            // Use error description if available, otherwise localized description
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
            
            conversationState = .listening
            isProcessing = false
        }
    }
    
    private func speakResponse(_ text: String, language: Language, apiKey: String, skipSpeechCheck: Bool = false) async {
        // Check if stopping before TTS
        guard !isStopping else {
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
                return
            }
            
            // Play (interruptible)
            conversationState = .speaking
            try await audioManager.speak(audioData, canBeInterrupted: true, skipSpeechCheck: skipSpeechCheck)
            
        } catch let error as NSError where error.code == NSURLErrorCancelled || (error.domain == "AudioManager" && error.code == -1) {
            // TTS was cancelled due to user speech - this is expected
            // Reset state without showing error
            guard !isStopping else { return }
            conversationState = .listening
            isProcessing = false
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                return
            }
            
            Logger.error("TTS failed", error: error)
            
            // Use error description if available, otherwise localized description
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
            
            conversationState = .listening
            isProcessing = false
        }
    }
    
    // MARK: - Code Editor Integration
    
    func updateCodeContext(code: String, language: CodeLanguageInterview) {
        currentCodeContext = CodeContext(
            currentCode: code,
            language: language,
            recentChanges: []
        )
    }
    
    func updateInterviewMode(_ mode: InterviewMode) {
        self.currentMode = mode
    }
    
    func updateDeveloperLevel(_ level: DeveloperLevel) {
        self.currentLevel = level
    }
    
 
    
 
    
    // MARK: - Text Message Handling
    
    /// Отправляет текстовое сообщение пользователя минуя транскрибацию аудио
    /// - Parameter text: Текст сообщения пользователя
    func sendTextMessage(_ text: String) async {
        // Проверка флага isStopping
        guard !isStopping else {
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
            // Добавляем сообщение пользователя в историю
            addMessage(role: TranscriptMessage.MessageRole.user, content: text)
            onUserMessage?(text)
            
            // Получаем ответ от AI
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
            // Set flag to prevent cancellation during Chat API request
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            // Проверка флага isStopping
            guard !isStopping else {
                return
            }
            
            // Handle AI response with task state logic
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            guard !isStopping else {
                return
            }
            
            Logger.error("Failed to send text message", error: error)
            
            // Reset flag on error
            isProcessingChatRequest = false
            
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
        }
    }
    
    // MARK: - Task State Management
    
    private func updateTaskState(_ newState: InterviewTaskState) {
        currentTaskState = newState
        taskState = newState
        onTaskStateChanged?(newState)
    }
    
    /// Confirm task completion from UI button
    func confirmTaskCompletion() async {
        await checkUserSolution()
    }
    
    /// Request help from UI button
    func requestHelpFromUI() async {
        await requestHelp()
    }
    
    /// Confirm understanding from UI button
    func confirmUnderstanding() async {
        updateTaskState(.noTask)
        
        // Trigger next question
        guard let topic = currentTopic else {
            Logger.error("No current topic available")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        let contextSummary = currentContext?.getContextSummary() ?? ""
        
        do {
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to get next question", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    /// Check if text contains completion phrases
    private func isCompletionPhrase(_ text: String, language: Language) -> Bool {
        let lowercasedText = text.lowercased()
        
        switch language {
        case .english:
            let completionPhrases = ["done", "finished", "ready", "completed", "that's it", "that is it", "all done"]
            return completionPhrases.contains { lowercasedText.contains($0) }
            
        case .russian:
            let completionPhrases = ["готов", "сделал", "всё", "закончил", "готово"]
            return completionPhrases.contains { lowercasedText.contains($0) }
            
        case .german:
            let completionPhrases = ["fertig", "erledigt", "bereit", "geschafft", "das ist es", "alles fertig"]
            return completionPhrases.contains { lowercasedText.contains($0) }
        }
    }
    
    /// Check if text contains help request phrases
    private func isHelpRequest(_ text: String, language: Language) -> Bool {
        let lowercasedText = text.lowercased()
        
        switch language {
        case .english:
            let helpPhrases = ["i don't know", "help me", "can't do it", "how do i do this", "hint", "don't know", "help"]
            return helpPhrases.contains { lowercasedText.contains($0) }
            
        case .russian:
            let helpPhrases = ["не знаю", "помоги", "не могу", "как сделать", "подскажи", "помощь"]
            return helpPhrases.contains { lowercasedText.contains($0) }
            
        case .german:
            let helpPhrases = ["ich weiß nicht", "hilf mir", "kann ich nicht", "wie mache ich das", "hinweis", "hilfe"]
            return helpPhrases.contains { lowercasedText.contains($0) }
        }
    }
    
    /// Check if text contains understanding confirmation phrases
    private func isUnderstandingConfirmation(_ text: String, language: Language) -> Bool {
        let lowercasedText = text.lowercased()
        
        switch language {
        case .english:
            let confirmationPhrases = ["i understand", "got it", "ready", "understood", "i got it"]
            return confirmationPhrases.contains { lowercasedText.contains($0) }
            
        case .russian:
            let confirmationPhrases = ["понял", "всё понятно", "готов", "понятно"]
            return confirmationPhrases.contains { lowercasedText.contains($0) }
            
        case .german:
            let confirmationPhrases = ["ich verstehe", "alles klar", "bereit", "verstanden"]
            return confirmationPhrases.contains { lowercasedText.contains($0) }
        }
    }
    
    /// Check user's solution
    private func checkUserSolution() async {
        guard let topic = currentTopic else {
            Logger.error("No current topic available")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            onError?("API key is not configured")
            return
        }
        
        do {
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
            // Add a system message indicating user is ready for solution check
            let checkMessage = TranscriptMessage(
                role: .user,
                text: "I'm done with the task. Please check my solution.",
                timestamp: Date()
            )
            conversationHistory.append(checkMessage)
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to check solution", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    /// Request next question after correct solution
    private func requestNextQuestion() async {
        guard let topic = currentTopic else {
            Logger.error("No current topic available")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        let contextSummary = currentContext?.getContextSummary() ?? ""
        
        do {
            // Set flag to indicate we're requesting next question
            isRequestingNextQuestion = true
            isProcessingChatRequest = true
            defer {
                isProcessingChatRequest = false
                isRequestingNextQuestion = false
            }
            
            // Add a message to indicate we want the next question
            let nextQuestionMessage = TranscriptMessage(
                role: .user,
                text: "The previous task was completed correctly. Please provide a NEW coding task with a problem statement and starter code.",
                timestamp: Date()
            )
            conversationHistory.append(nextQuestionMessage)
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to get next question", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    /// Request help from AI
    private func requestHelp() async {
        guard let topic = currentTopic else {
            Logger.error("No current topic available")
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        
        guard !apiKey.isEmpty else {
            onError?("API key is not configured")
            return
        }
        
        do {
            isProcessingChatRequest = true
            defer { isProcessingChatRequest = false }
            
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
            // Add a system message indicating user needs help
            let helpMessage = TranscriptMessage(
                role: .user,
                text: "I need help with this task.",
                timestamp: Date()
            )
            conversationHistory.append(helpMessage)
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: conversationHistory,
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to request help", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    /// Handle AI response with task state logic
    private func handleAIResponse(_ aiResponse: AIResponse, language: Language, apiKey: String) async {
        // Check if this is a correct solution confirmation (we need to request next question after TTS)
        // Only rely on is_correct flag, ignore task_state completely
        // But prevent infinite loop when we're already requesting next question
        Logger.debug("🔍 handleAIResponse: isCorrect=\(String(describing: aiResponse.isCorrect)), taskState=\(String(describing: aiResponse.taskState)), isRequestingNextQuestion=\(isRequestingNextQuestion)")
        if aiResponse.isCorrect == true && !isRequestingNextQuestion {
            shouldRequestNextQuestion = true
            Logger.debug("✅ Set shouldRequestNextQuestion=true because isCorrect=true")
        }
        
        // Update task state based on AI response
        if let taskState = aiResponse.taskState {
            switch taskState {
            case .taskPresented:
                updateTaskState(.taskPresented(expectedSolution: aiResponse.aicode))
                currentTaskCode = aiResponse.aicode ?? ""
                
            case .checkingSolution:
                // AI is checking user's solution
                if let isCorrect = aiResponse.isCorrect {
                    if isCorrect {
                        updateTaskState(.noTask)
                    } else {
                        updateTaskState(.taskPresented(expectedSolution: nil))
                    }
                }
                
            case .providingHint:
                // AI is giving a hint - stay in task presented state
                updateTaskState(.taskPresented(expectedSolution: nil))
                
            case .showingSolution:
                // AI is showing solution - wait for user confirmation
                updateTaskState(.waitingForUserConfirmation)
                
            case .waitingForUnderstanding:
                updateTaskState(.waitingForUserConfirmation)
                
            case .none:
                updateTaskState(.noTask)
            }
        }
        
        // Apply code in editor based on state
        if let aicode = aiResponse.aicode {
            // If this is a hint (hintCode), don't overwrite entire code
            if aiResponse.taskState == .providingHint {
                // For hints, we might add logic to partially update code
                // For now, we'll show the hint in spoken_text and keep current code
            } else {
                onCodeUpdate?(aicode)
            }
        }
        
        // Notify UI of AI message
        onAIMessage?(aiResponse.spokenText)
        
        // Speak the response
        await speakResponse(aiResponse.spokenText, language: language, apiKey: apiKey)
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
    
    // MARK: - Properties
    
    var isListening: Bool {
        audioManager.isListening
    }
    
    var isSpeaking: Bool {
        audioManager.isSpeaking
    }
}
