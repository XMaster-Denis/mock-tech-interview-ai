//
//  ConversationManager.swift
//  XInterview2
//
//  Manages the full duplex conversation flow
//

import Foundation
import Combine
import AVFoundation

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
    private var currentTaskText: String = ""
    private var recentTopics: [String] = []
    private let maxRecentTopics = 5
    private var recentQuestions: [String] = []
    private let maxRecentQuestions = 10
    private var cachedNextTaskResponse: AIResponse?
    private var isPrefetchingNextTask: Bool = false
    private let ttsAudioCache = TTSAudioCache()
    private let userAudioCache = UserAudioCache()
    
    private var pendingUserAudio: Data?
    private var pendingUserAudioEndTime: Date?
    private var pendingMergeGap: TimeInterval?
    private var pendingMergeTask: Task<Void, Never>?
    private let mergeWindow: TimeInterval = 0.5
    private let maxMergeGap: TimeInterval = 2.0
    
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
    private var lastLLMMode: LLMMode?
    
    // MARK: - Callbacks
    
    var onUserMessage: ((String) -> Void)?
    var onAIMessage: ((String) -> Void)?
    var onAIAudioAvailable: ((String, String) -> Void)?
    var onUserAudioAvailable: ((String, String) -> Void)?
    var onError: ((String) -> Void)?
    var onCodeUpdate: ((String) -> Void)?
    var onTaskStateChanged: ((InterviewTaskState) -> Void)?
    var onHintUpdate: ((String?, String?) -> Void)?
    var onSolutionUpdate: ((String?, String?) -> Void)?
    var onContextUpdated: ((InterviewContext) -> Void)?
    
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
        cachedNextTaskResponse = nil
        isPrefetchingNextTask = false
        recentTopics = context?.recentTopics ?? []
        recentQuestions = context?.recentQuestions ?? []
        if currentContext?.topicId == nil {
            currentContext?.topicId = topic.id
        }
        if currentContext?.levelRaw == nil {
            currentContext?.levelRaw = currentLevel.rawValue
        }
        if currentContext?.languageRaw == nil {
            currentContext?.languageRaw = language.rawValue
        }
        
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
        cachedNextTaskResponse = nil
        isPrefetchingNextTask = false
        
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
        if pendingUserAudio != nil {
            pendingMergeTask?.cancel()
            pendingMergeTask = nil
            if let endTime = pendingUserAudioEndTime {
                let gap = Date().timeIntervalSince(endTime)
                pendingMergeGap = min(max(0.0, gap), maxMergeGap)
            }
        }
    }
    
    private func handleUserSpeechEnded(audioData: Data) {
        guard conversationState != .idle else {
            return
        }
        
        queueUserAudioForProcessing(audioData)
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
                if let cached = cachedNextTaskResponse {
                    cachedNextTaskResponse = nil
                    isRequestingNextQuestion = true
                    let settings = settingsRepository.loadSettings()
                    await Task.yield()
                    await handleAIResponse(cached, language: settings.selectedLanguage, apiKey: settings.apiKey)
                    isRequestingNextQuestion = false
                } else {
                    await requestNextQuestion()
                }
            }
        } else {
            Logger.debug("⏭️ Not requesting next question (shouldRequestNextQuestion=false)")
        }
    }
    
    // MARK: - Message Processing

    private func queueUserAudioForProcessing(_ audioData: Data) {
        if let pending = pendingUserAudio {
            let gap = pendingMergeGap ?? 0.0
            if let merged = mergeWavData(first: pending, second: audioData, gap: gap) {
                pendingUserAudio = merged
            } else {
                pendingUserAudio = audioData
            }
        } else {
            pendingUserAudio = audioData
        }
        
        pendingUserAudioEndTime = Date()
        pendingMergeGap = nil
        
        pendingMergeTask?.cancel()
        pendingMergeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.mergeWindow * 1_000_000_000))
            guard let mergedAudio = self.pendingUserAudio else { return }
            self.pendingUserAudio = nil
            self.pendingUserAudioEndTime = nil
            
            if self.isProcessing {
                return
            }
            
            self.conversationState = .processing
            self.isProcessing = true
            self.processingTask = Task { [weak self] in
                await self?.processUserSpeech(audioData: mergedAudio)
                await MainActor.run {
                    self?.processingTask = nil
                }
            }
        }
    }
    
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
            let contextSummary = buildConversationContext(language: language)
            
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
                llmMode: .generateTask,
                chatModel: settings.selectedChatModel,
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
            let minDuration: TimeInterval = 0.35
            let minLevel = settings.minSpeechLevel
            if !shouldTranscribe(audioData: audioData, minDuration: minDuration, minLevel: minLevel) {
                Logger.warning("Speech ignored: too short or too quiet (minDuration=\(minDuration), minLevel=\(minLevel))")
                conversationState = .listening
                isProcessing = false
                return
            }
            
            // Transcribe audio with technical prompt and temperature
            let prompt = PromptTemplates.Whisper.prompt(for: settings.selectedLanguage)
            let userText = try await whisperService.transcribe(
                audioData: audioData,
                model: settings.selectedWhisperModel,
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
            
            var remainingUserAudioFileName = userAudioCache.saveAudio(audioData)
            var didAddUserMessage = false
            let addUserMessage: (String) -> Void = { [weak self] text in
                self?.addMessage(role: TranscriptMessage.MessageRole.user, content: text)
                self?.onUserMessage?(text)
                if let fileName = remainingUserAudioFileName {
                    self?.onUserAudioAvailable?(text, fileName)
                    remainingUserAudioFileName = nil
                }
            }
            if currentMode != .codeTasks, case .noTask = currentTaskState {
                addUserMessage(userText)
                didAddUserMessage = true
            }
            
            if shouldCoachLanguage(for: settings.selectedLanguage) && currentMode != .codeTasks {
                _ = await runLanguageCoach(
                    userText: userText,
                    language: settings.selectedLanguage,
                    apiKey: apiKey
                )
            }
            
            // Check task state before processing
            switch currentTaskState {
            case .taskPresented:
                if currentMode == .questionsOnly {
                    updateTaskState(.noTask)
                    break
                }
                // User is responding to a task
                let language = settings.selectedLanguage
                
                if isCompletionPhrase(userText, language: language) {
                    // User says they completed task
                    addUserMessage(userText)
                    await checkUserSolution()
                    return
                }
                
                if let helpMode = HelpModeDetector.detectHelpMode(userText, language: language) {
                    // User asks for help
                    addUserMessage(userText)
                    await requestHelp(mode: helpMode, userMessage: userText)
                    return
                }
                
                // Any other text is treated as an attempt at solution
                // Add user message to history
                addUserMessage(userText)
                
                // Check the solution
                await checkUserSolution()
                return
                
            case .waitingForUserConfirmation:
                if currentMode == .questionsOnly {
                    updateTaskState(.noTask)
                    break
                }
                // User is confirming understanding
                let language = settings.selectedLanguage
                
                if isUnderstandingConfirmation(userText, language: language) {
                    // User confirms understanding - move to next question
                    addUserMessage(userText)
                    updateTaskState(.noTask)
                    
                    // Continue with next question
                    // Fall through to normal processing
                } else {
                    // User didn't confirm understanding - ask again
                    addUserMessage(userText)
                    return
                }
                
            case .noTask:
                // Normal conversation - no active task
                break
            }
            
            // Add user message to history BEFORE calling API
            // This ensures AI has context of what user just said
            if !didAddUserMessage {
                addUserMessage(userText)
            }
            
            // Get AI response
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            
            // Include context if available for follow-up questions
            let contextSummary = buildConversationContext(language: settings.selectedLanguage)
            
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
                llmMode: .generateTask,
                chatModel: settings.selectedChatModel,
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
                model: settings.selectedTTSModel,
                voice: settings.selectedVoice,
                apiKey: apiKey
            )
            if let fileName = ttsAudioCache.saveAudio(audioData) {
                onAIAudioAvailable?(text, fileName)
            }
            
            // Check if stopping after generating speech
            guard !isStopping else {
                return
            }
            
            // Play (interruptible)
            conversationState = .speaking
            try await audioManager.speak(
                audioData,
                canBeInterrupted: settings.allowTTSInterruption,
                skipSpeechCheck: skipSpeechCheck
            )
            
            if !audioManager.isSpeaking {
                conversationState = .listening
                isProcessing = false
            }
            
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
            if case .taskPresented = currentTaskState {
                let language = settings.selectedLanguage
                if let helpMode = HelpModeDetector.detectHelpMode(text, language: language) {
                    addMessage(role: TranscriptMessage.MessageRole.user, content: text)
                    onUserMessage?(text)
                    await requestHelp(mode: helpMode, userMessage: text)
                    return
                }
            }
            
            // Добавляем сообщение пользователя в историю
            addMessage(role: TranscriptMessage.MessageRole.user, content: text)
            onUserMessage?(text)
            
            // Получаем ответ от AI
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            
            let contextSummary = buildConversationContext(language: settings.selectedLanguage)
            
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
                llmMode: .generateTask,
                chatModel: settings.selectedChatModel,
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
        let language = settingsRepository.loadSettings().selectedLanguage
        let userMessage: String
        
        switch language {
        case .russian:
            userMessage = "Подскажи"
        case .english:
            userMessage = "Help"
        case .german:
            userMessage = "Hilfe"
        }
        
        await requestHelp(mode: .hintOnly, userMessage: userMessage)
    }
    
    /// Confirm understanding from UI button
    func confirmUnderstanding() async {
        updateTaskState(.noTask)
        await requestNextQuestion()
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
            let checkContext = buildCheckContext(
                language: settings.selectedLanguage,
                isHelpRequest: false
            )
            lastLLMMode = .checkSolution
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: [],
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                llmMode: .checkSolution,
                chatModel: settings.selectedChatModel,
                apiKey: apiKey,
                context: checkContext
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
        
        if let cached = cachedNextTaskResponse {
            cachedNextTaskResponse = nil
            isRequestingNextQuestion = true
            let settings = settingsRepository.loadSettings()
            await handleAIResponse(cached, language: settings.selectedLanguage, apiKey: settings.apiKey)
            isRequestingNextQuestion = false
            return
        }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        let contextSummary = buildGenContext(language: settings.selectedLanguage)
        
        do {
            // Set flag to indicate we're requesting next question
            isRequestingNextQuestion = true
            isProcessingChatRequest = true
            defer {
                isProcessingChatRequest = false
                isRequestingNextQuestion = false
            }
            
            lastLLMMode = .generateTask
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: [],
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                llmMode: .generateTask,
                chatModel: settings.selectedChatModel,
                apiKey: apiKey,
                context: contextSummary
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to get next question", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    private func prefetchNextTask() {
        guard !isPrefetchingNextTask else { return }
        guard cachedNextTaskResponse == nil else { return }
        guard let topic = currentTopic else { return }
        
        let settings = settingsRepository.loadSettings()
        let apiKey = settings.apiKey
        if apiKey.isEmpty { return }
        
        isPrefetchingNextTask = true
        let contextSummary = buildGenContext(language: settings.selectedLanguage)
        
        Task {
            do {
                let response = try await chatService.sendMessageWithCode(
                    messages: [],
                    codeContext: currentCodeContext,
                    topic: topic,
                    level: currentLevel,
                    language: settings.selectedLanguage,
                    mode: currentMode,
                    llmMode: .generateTask,
                    chatModel: settings.selectedChatModel,
                    apiKey: apiKey,
                    context: contextSummary
                )
                cachedNextTaskResponse = response
            } catch {
                Logger.error("Prefetch next task failed", error: error)
            }
            isPrefetchingNextTask = false
        }
    }
    
    /// Request help from AI
    private func requestHelp(mode: HelpMode, userMessage: String) async {
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
            let helpContext = buildHelpContext(language: settings.selectedLanguage)
            lastLLMMode = .assistHelp(mode)
            
            let aiResponse = try await chatService.sendMessageWithCode(
                messages: [
                    TranscriptMessage(role: .user, text: userMessage, timestamp: Date())
                ],
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: settings.selectedLanguage,
                mode: currentMode,
                llmMode: .assistHelp(mode),
                chatModel: settings.selectedChatModel,
                apiKey: apiKey,
                context: helpContext
            )
            
            await handleAIResponse(aiResponse, language: settings.selectedLanguage, apiKey: apiKey)
            
        } catch {
            Logger.error("Failed to request help", error: error)
            onError?(error.localizedDescription)
        }
    }
    
    /// Handle AI response with task state logic
    private func handleAIResponse(_ aiResponse: AIResponse, language: Language, apiKey: String) async {
        Logger.debug("🔍 handleAIResponse: isCorrect=\(String(describing: aiResponse.isCorrect)), taskState=\(String(describing: aiResponse.taskState)), isRequestingNextQuestion=\(isRequestingNextQuestion)")
        if lastLLMMode?.isCheckSolution == true, aiResponse.isCorrect == true, !isRequestingNextQuestion {
            shouldRequestNextQuestion = true
            Logger.debug("✅ Set shouldRequestNextQuestion=true because isCorrect=true")
            prefetchNextTask()
        }
        
        // Update task state based on AI response
        if let taskState = aiResponse.taskState {
            if currentMode == .questionsOnly {
                updateTaskState(.noTask)
            } else {
                switch taskState {
            case .taskPresented:
                updateTaskState(.taskPresented(expectedSolution: aiResponse.aicode))
                currentTaskCode = aiResponse.aicode ?? ""
                currentTaskText = aiResponse.spokenText
                onHintUpdate?(nil, nil)
                onSolutionUpdate?(nil, nil)
                if recentTopics.last != aiResponse.spokenText {
                    recentTopics.append(aiResponse.spokenText)
                }
                if recentTopics.count > maxRecentTopics {
                    recentTopics = Array(recentTopics.suffix(maxRecentTopics))
                }
                currentContext?.updateRecentTask(taskText: aiResponse.spokenText, maxTopics: maxRecentTopics)
                if let context = currentContext {
                    onContextUpdated?(context)
                }
                
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
                onHintUpdate?(aiResponse.hint, aiResponse.hintCode)
                
            case .providingSolution:
                // AI is providing full solution - keep task active
                updateTaskState(.taskPresented(expectedSolution: nil))
                onSolutionUpdate?(aiResponse.solutionCode, aiResponse.explanation)
                
            case .showingSolution:
                // AI is showing solution - wait for user confirmation
                updateTaskState(.waitingForUserConfirmation)
                onSolutionUpdate?(aiResponse.correctCode, nil)
                
            case .waitingForUnderstanding:
                updateTaskState(.waitingForUserConfirmation)
                
            case .none:
                updateTaskState(.noTask)
            }
            }
        }
        
        if lastLLMMode?.isCheckSolution == true, aiResponse.isCorrect == true {
            updateTaskState(.noTask)
        }
        
        let shouldRecordQuestion: Bool
        if currentMode == .questionsOnly {
            shouldRecordQuestion = aiResponse.taskState == nil &&
                aiResponse.aicode == nil &&
                lastLLMMode?.isCheckSolution != true
        } else {
            shouldRecordQuestion = currentMode != .codeTasks &&
                aiResponse.taskState == .some(.none) &&
                aiResponse.aicode == nil &&
                lastLLMMode?.isCheckSolution != true
        }
        
        if shouldRecordQuestion {
            let question = aiResponse.spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !question.isEmpty, recentQuestions.last != question {
                recentQuestions.append(question)
                if recentQuestions.count > maxRecentQuestions {
                    recentQuestions = Array(recentQuestions.suffix(maxRecentQuestions))
                }
                currentContext?.updateRecentQuestion(question, maxQuestions: maxRecentQuestions)
                if let context = currentContext {
                    onContextUpdated?(context)
                }
            }
        }
        
        // Apply code in editor based on state
        if let aicode = aiResponse.aicode, currentMode != .questionsOnly {
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
        if let explanation = aiResponse.explanation, !explanation.isEmpty {
            onAIMessage?(explanation)
        }
        
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
    
    private func shouldCoachLanguage(for language: Language) -> Bool {
        switch language {
        case .english, .german:
            return true
        case .russian:
            return false
        }
    }
    
    private func runLanguageCoach(userText: String, language: Language, apiKey: String) async -> Bool {
        guard let topic = currentTopic else {
            return false
        }
        
        do {
            let chatModel = settingsRepository.loadSettings().selectedChatModel
            let response = try await chatService.sendMessageWithCode(
                messages: [TranscriptMessage(role: .user, text: userText, timestamp: Date())],
                codeContext: currentCodeContext,
                topic: topic,
                level: currentLevel,
                language: language,
                mode: currentMode,
                llmMode: .languageCoach,
                chatModel: chatModel,
                apiKey: apiKey,
                context: ""
            )
            
            if response.needsCorrection == true {
                let correction = response.correction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let correctionMessage = makeCoachCorrectionMessage(correction: correction, language: language)
                let messageToSpeak = correctionMessage.isEmpty ? response.spokenText : correctionMessage
                if !messageToSpeak.isEmpty {
                    onAIMessage?(messageToSpeak)
                    await speakResponse(messageToSpeak, language: language, apiKey: apiKey)
                }
                return response.requestRepeat ?? false
            }
        } catch {
            Logger.error("Language coach failed", error: error)
        }
        
        return false
    }

    private func makeCoachCorrectionMessage(correction: String, language: Language) -> String {
        guard !correction.isEmpty else {
            return ""
        }
        
        switch language {
        case .russian:
            return "Вернее будет сказать: \(correction)"
        case .english:
            return "A better way to say it is: \(correction)"
        case .german:
            return "Besser wäre: \(correction)"
        }
    }

    private func mergeWavData(first: Data, second: Data, gap: TimeInterval) -> Data? {
        guard first.count > 44, second.count > 44 else {
            return nil
        }
        
        let maxGap = max(0.0, min(gap, maxMergeGap))
        let silence = silencePCMData(duration: maxGap)
        let firstPCM = first.dropFirst(44)
        let secondPCM = second.dropFirst(44)
        
        var combinedPCM = Data()
        combinedPCM.append(firstPCM)
        combinedPCM.append(silence)
        combinedPCM.append(secondPCM)
        
        return makeWavData(fromPCM: combinedPCM)
    }
    
    private func silencePCMData(duration: TimeInterval) -> Data {
        guard duration > 0 else { return Data() }
        let sampleRate = 16000.0
        let samples = Int(sampleRate * duration)
        let byteCount = samples * 2
        return Data(count: byteCount)
    }
    
    private func makeWavData(fromPCM pcmData: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let chunkSize = UInt32(36) + dataSize
        
        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian, Array.init))
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt 
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: channels.littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        header.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian, Array.init))
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian, Array.init))
        
        var wav = Data()
        wav.append(header)
        wav.append(pcmData)
        return wav
    }
    
    
    private func shouldTranscribe(audioData: Data, minDuration: TimeInterval, minLevel: Float) -> Bool {
        guard !audioData.isEmpty else {
            return false
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        
        do {
            try audioData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let audioFile = try AVAudioFile(forReading: tempURL)
            let format = audioFile.processingFormat
            let duration = Double(audioFile.length) / format.sampleRate
            if duration < minDuration {
                Logger.warning("Speech too short: \(duration)s < \(minDuration)s")
                return false
            }
            
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return true
            }
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData else {
                return true
            }
            
            let channelCount = Int(format.channelCount)
            let frameLength = Int(buffer.frameLength)
            if frameLength == 0 {
                return false
            }
            
            var sumSquares: Double = 0
            var totalSamples = 0
            for channel in 0..<channelCount {
                let data = channelData[channel]
                for i in 0..<frameLength {
                    let sample = Double(data[i])
                    sumSquares += sample * sample
                }
                totalSamples += frameLength
            }
            
            let rms = sqrt(sumSquares / Double(totalSamples))
            if Float(rms) < minLevel {
                Logger.warning("Speech too quiet: rms=\(rms) < \(minLevel)")
                return false
            }
            
            return true
        } catch {
            Logger.warning("Speech validation failed, letting it pass: \(error.localizedDescription)")
            return true
        }
    }
    
    private func buildCheckContext(language: Language, isHelpRequest: Bool) -> String {
        let taskText = currentTaskText.isEmpty ? "(no task text)" : currentTaskText
        let requirements = "(none)"
        let helpLine = isHelpRequest ? "help" : "verify"
        
        switch language {
        case .russian:
            return """
            Задание (кратко):
            \(taskText)
            
            Ожидаемое поведение/ограничения:
            \(requirements)
            
            Запрос пользователя: \(isHelpRequest ? "нужна подсказка" : "проверка решения")
            """
        case .english:
            return """
            Task (short):
            \(taskText)
            
            Expected behavior/constraints:
            \(requirements)
            
            User request: \(helpLine)
            """
        case .german:
            return """
            Aufgabe (kurz):
            \(taskText)
            
            Erwartetes Verhalten/Einschraenkungen:
            \(requirements)
            
            Nutzeranfrage: \(helpLine)
            """
        }
    }
    
    private func buildHelpContext(language: Language) -> String {
        let taskText = currentTaskText.isEmpty ? "(no task text)" : currentTaskText
        let requirements = "(none)"
        
        switch language {
        case .russian:
            return """
            \(taskText)
            
            Ожидаемое поведение/ограничения:
            \(requirements)
            """
        case .english:
            return """
            \(taskText)
            
            Expected behavior/constraints:
            \(requirements)
            """
        case .german:
            return """
            \(taskText)
            
            Erwartetes Verhalten/Einschraenkungen:
            \(requirements)
            """
        }
    }
    
    private func buildGenContext(language: Language) -> String {
        let recent = recentTopics.suffix(maxRecentTopics)
        let recentLine = recent.isEmpty ? "recent_topics: none" : "recent_topics: \(recent.joined(separator: "; "))"
        let avoidLine = recent.isEmpty ? "avoid: none" : "avoid: \(recent.joined(separator: "; "))"
        
        switch language {
        case .russian:
            return """
            recent_topics: \(recent.isEmpty ? "none" : recent.joined(separator: "; "))
            \(avoidLine)
            """
        case .english:
            return """
            \(recentLine)
            \(avoidLine)
            """
        case .german:
            return """
            \(recentLine)
            \(avoidLine)
            """
        }
    }
    
    private func buildQuestionContext(language: Language) -> String {
        let recent = recentQuestions.suffix(maxRecentQuestions)
        let recentLine = recent.isEmpty ? "recent_questions: none" : "recent_questions: \(recent.joined(separator: "; "))"
        let avoidLine = recent.isEmpty ? "avoid: none" : "avoid: \(recent.joined(separator: "; "))"
        
        switch language {
        case .russian:
            return """
            recent_questions: \(recent.isEmpty ? "none" : recent.joined(separator: "; "))
            \(avoidLine)
            """
        case .english:
            return """
            \(recentLine)
            \(avoidLine)
            """
        case .german:
            return """
            \(recentLine)
            \(avoidLine)
            """
        }
    }
    
    private func buildConversationContext(language: Language) -> String {
        if currentMode == .codeTasks {
            return buildGenContext(language: language)
        }
        return buildQuestionContext(language: language)
    }
    
    // MARK: - Properties
    
    var isListening: Bool {
        audioManager.isListening
    }
    
    var isSpeaking: Bool {
        audioManager.isSpeaking
    }

    func clearAudioCaches() {
        ttsAudioCache.clear()
        userAudioCache.clear()
    }
}
