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
    
    // Code Editor Integration
    private(set) var codeEditorViewModel: CodeEditorViewModel?
    private var currentCodeContext: CodeContext = CodeContext(currentCode: "", language: .swift, recentChanges: [])
    private var currentLevel: DeveloperLevel = .junior
    
    // MARK: - Properties
    
    private var currentTopic: InterviewTopic?
    private var currentMode: InterviewMode = .questionsOnly
    private var conversationHistory: [TranscriptMessage] = []
    private var currentContext: InterviewContext?
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
        settingsRepository: SettingsRepositoryProtocol,
        codeEditorViewModel: CodeEditorViewModel? = nil,
        developerLevel: DeveloperLevel = .junior
    ) {
        self.whisperService = whisperService
        self.chatService = chatService
        self.ttsService = ttsService
        self.settingsRepository = settingsRepository
        self.codeEditorViewModel = codeEditorViewModel
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
            Logger.warning("Cannot start conversation, current state: \(conversationState)")
            return
        }
        
        Logger.state("Starting conversation - topic: \(topic.title), language: \(language)")
        conversationState = .listening
        currentTopic = topic
        currentContext = context
        
        // Load settings and update voice threshold, silence timeout, and min speech level
        let settings = settingsRepository.loadSettings()
        audioManager.updateVoiceThreshold(settings.voiceThreshold)
        audioManager.updateSilenceTimeout(settings.silenceTimeout)
        audioManager.updateMinSpeechLevel(settings.minSpeechLevel)
        Logger.info("Voice threshold: \(settings.voiceThreshold), Silence timeout: \(settings.silenceTimeout)s, Min speech level: \(settings.minSpeechLevel)")
        
        // Start continuous listening
        Logger.state("Starting audio listening")
        audioManager.startListening()
        
        // Initialize code context if editor is available
        if let editor = codeEditorViewModel {
            updateCodeContext(from: editor)
        }
        
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
        currentContext = nil
        
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
            // Get AI response (empty messages for opening)
            Logger.state("Calling chatService.sendMessageWithCode() for opening message")
            let contextSummary = currentContext?.getContextSummary() ?? ""
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
            
            Logger.info("AIResponse received - spokenText: \(aiResponse.spokenText.prefix(50))...")
            Logger.info("AIResponse - hasEditorAction: \(aiResponse.editorAction != nil)")
            Logger.info("AIResponse - hasEvaluation: \(aiResponse.evaluation != nil)")
            
            let response = aiResponse.spokenText
            
            // Apply editor action if present
            if let action = aiResponse.editorAction {
                applyEditorAction(action)
            }
            
            // Apply code template if present
            if let codeTemplate = aiResponse.codeTemplate {
                codeEditorViewModel?.setCode(codeTemplate)
            }
            
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
            
            // Use error description if available, otherwise localized description
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
            
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
            // Transcribe audio with technical prompt and temperature
            let prompt = WhisperPrompts.prompt(for: settings.selectedLanguage)
            Logger.state("Calling whisperService.transcribe() with prompt and temperature")
            let userText = try await whisperService.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: settings.selectedLanguage.rawValue,
                prompt: prompt,
                temperature: 0.1
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
            
            // Add user message to history BEFORE calling API
            // This ensures AI has context of what user just said
            Logger.state("Adding user message to history")
            addMessage(role: TranscriptMessage.MessageRole.user, content: userText)
            
            onUserMessage?(userText)
            
            // Get AI response
            guard let topic = currentTopic else {
                Logger.error("No current topic available")
                return
            }
            
            // Update code context before sending
            updateCodeContextFromEditor()
            
            // Include context if available for follow-up questions
            let contextSummary = currentContext?.getContextSummary() ?? ""
            
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
            
            let response = aiResponse.spokenText
            
            // Apply editor action if present
            if let action = aiResponse.editorAction {
                applyEditorAction(action)
            }
            
            // Apply code template if present
            if let codeTemplate = aiResponse.codeTemplate {
                codeEditorViewModel?.setCode(codeTemplate)
            }
            
            // Handle hint context if present (AI providing assistance)
            if let hint = aiResponse.hintContext {
                applyHint(hint)
            }
            
            // Handle evaluation if present
            if let evaluation = aiResponse.evaluation {
                handleEvaluation(evaluation)
            }
            
            // Check if stopping after getting AI response
            guard !isStopping else {
                Logger.warning("processUserSpeech() cancelled after AI response - isStopping=true")
                return
            }
            
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
            
            // Use error description if available, otherwise localized description
            let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError?(errorMessage)
            
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
            
        } catch let error as NSError where error.code == NSURLErrorCancelled || (error.domain == "AudioManager" && error.code == -1) {
            // TTS was cancelled due to user speech - this is expected
            Logger.warning("speakResponse() - TTS cancelled (expected on user speech interruption)")
            // Reset state without showing error
            conversationState = .listening
            isProcessing = false
        } catch {
            // Only handle error if not stopping
            guard !isStopping else {
                Logger.warning("speakResponse() error cancelled due to stop")
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
    
    private func updateCodeContext(from viewModel: CodeEditorViewModel) {
        currentCodeContext = CodeContext(
            currentCode: viewModel.code,
            language: viewModel.language,
            recentChanges: []
        )
    }
    
    private func updateCodeContextFromEditor() {
        guard let editor = codeEditorViewModel else { return }
        updateCodeContext(from: editor)
    }
    
    func setCodeEditorViewModel(_ viewModel: CodeEditorViewModel, level: DeveloperLevel = .junior) {
        self.codeEditorViewModel = viewModel
        self.currentLevel = level
        updateCodeContext(from: viewModel)
        Logger.info("Code editor attached - level: \(level.displayName)")
    }
    
    func updateInterviewMode(_ mode: InterviewMode) {
        self.currentMode = mode
        Logger.info("Interview mode updated: \(mode.displayName)")
    }
    
    func updateDeveloperLevel(_ level: DeveloperLevel) {
        self.currentLevel = level
        Logger.info("Developer level updated: \(level.displayName)")
    }
    
    private func applyEditorAction(_ action: EditorAction) {
        guard let editor = codeEditorViewModel else {
            Logger.warning("Cannot apply editor action - no editor attached")
            return
        }
        
        Logger.info("Applying editor action")
        
        switch action {
        case .insert(let text, let location):
            // Insert at specific location
            editor.insertCodeAtCursor(text)
            // Optionally move cursor to location
        case .replace(let rangeCodable, let text):
            editor.replaceCodeInRange(rangeCodable.range, with: text)
        case .clear:
            editor.replaceAllCode("")
        case .highlight(let rangesCodable):
            let ranges = rangesCodable.map { $0.range }
            editor.highlightHints(ranges)
        case .none:
            break
        }
        
        // Update code context after applying action
        updateCodeContext(from: editor)
    }
    
    private func handleEvaluation(_ evaluation: CodeEvaluation) {
        Logger.info("Code evaluation - isCorrect: \(evaluation.isCorrect)")
        
        guard let editor = codeEditorViewModel else { return }
        
        if evaluation.isCorrect {
            // Show success feedback - can add UI notification later
            Logger.success("Code is correct: \(evaluation.feedback)")
        } else {
            // Highlight error lines
            let errorRanges = evaluation.issueLines.compactMap { editor.rangeForLine($0) }
            let errors = errorRanges.enumerated().map { index, range in
                CodeError(
                    range: range,
                    message: evaluation.feedback,
                    severity: evaluation.severity ?? .error,
                    line: evaluation.issueLines[index]
                )
            }
            editor.highlightErrors(errors)
        }
    }
    
    private func applyHint(_ hint: HintContext) {
        Logger.info("Applying hint - type: \(hint.type)")
        
        guard let editor = codeEditorViewModel else {
            Logger.warning("Cannot apply hint - no editor attached")
            return
        }
        
        switch hint.type {
        case .codeInsertion:
            // Insert code and highlight it
            if let code = hint.code {
                editor.insertCodeAtCursor(code)
                if let range = hint.highlightRange {
                    editor.highlightHints([range.range])
                }
                Logger.success("Inserted hint code: \(code.prefix(50))...")
            }
        case .textHint:
            // Just explanation, no code insertion
            if let explanation = hint.explanation {
                Logger.info("Text hint: \(explanation)")
            }
        }
        
        // Update code context after hint
        updateCodeContext(from: editor)
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
