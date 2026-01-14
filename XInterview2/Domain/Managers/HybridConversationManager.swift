//
//  HybridConversationManager.swift
//  XInterview2
//
//  Manager for hybrid interview (voice + code)
//

import Foundation
import Combine

@MainActor
class HybridConversationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProcessing: Bool = false
    @Published var lastResponse: AIResponse?
    @Published var currentCode: String = ""
    
    // MARK: - Components
    
    private let chatService: OpenAIChatServiceProtocol
    private let ttService: OpenAITTSServiceProtocol
    private let codeEditorController: CodeEditorController
    private let codeAnalyzer: RealTimeCodeAnalyzer
    private let codeChangeTracker: CodeChangeTracker
    
    // MARK: - Properties
    
    private var messages: [TranscriptMessage] = []
    private var currentTopic: InterviewTopic
    private var currentLevel: DeveloperLevel
    private var currentLanguage: Language
    private var currentMode: InterviewMode = .questionsOnly
    private var apiKey: String
    
    // MARK: - Initialization
    
    init(
        chatService: OpenAIChatServiceProtocol,
        ttService: OpenAITTSServiceProtocol,
        codeEditorController: CodeEditorController,
        codeAnalyzer: RealTimeCodeAnalyzer,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        apiKey: String
    ) {
        self.chatService = chatService
        self.ttService = ttService
        self.codeEditorController = codeEditorController
        self.codeAnalyzer = codeAnalyzer
        self.codeChangeTracker = CodeChangeTracker()
        self.currentTopic = topic
        self.currentLevel = level
        self.currentLanguage = language
        self.apiKey = apiKey
        
        // Setup code analyzer callback
        codeAnalyzer.onErrorsDetected = { [weak self] errors in
            self?.handleDetectedErrors(errors)
        }
    }
    
    // MARK: - Conversation Management
    
    /// Start interview with initial AI message
    func startInterview() {
        Logger.info("Hybrid interview started - topic: \(currentTopic.title)")
        
        // Clear previous conversation
        messages = []
        
        // Get initial response from AI
        Task {
            await sendToAI(userInput: nil)
        }
    }
    
    /// Send user message to AI
    func sendUserMessage(_ message: String) {
        guard !message.isEmpty else { return }
        
        Logger.info("User message: \(message.prefix(50))...")
        
        // Add user message
        let userMessage = TranscriptMessage(
            role: .user,
            text: message,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Send to AI
        Task {
            await sendToAI(userInput: message)
        }
    }
    
    /// Submit code for evaluation
    func submitCode(code: String) {
        Logger.info("Code submitted - length: \(code.count)")
        
        currentCode = code
        
        let userMessage = TranscriptMessage(
            role: .user,
            text: "Here's my code:",
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Send to AI for evaluation
        Task {
            await sendToAI(userInput: "Here's my code:")
        }
    }
    
    // MARK: - Code Context Management
    
    /// Update code context
    func updateCode(_ code: String, range: NSRange? = nil) {
        let oldCode = currentCode
        currentCode = code
        
        // Track changes
        if let range = range, let oldRange = Range(range, in: oldCode) {
            let oldText = String(oldCode[oldRange])
            let newRange = Range(range, in: code)
            let newText = newRange.map { String(code[$0]) } ?? ""
            
            let change = CodeChange(range: range, oldText: oldText, newText: newText)
            codeChangeTracker.addChange(change)
        }
        
        // Trigger real-time analysis
        codeAnalyzer.analyze(code: code)
    }
    
    /// Get current code context
    private func getCodeContext() -> CodeContext {
        return CodeContext(
            currentCode: currentCode,
            language: .swift,
            recentChanges: codeChangeTracker.getRecentChanges()
        )
    }
    
    // MARK: - Private Methods
    
    private func sendToAI(userInput: String?) async {
        isProcessing = true
        defer { isProcessing = false }
        
        codeEditorController.showAIThinking()
        defer { codeEditorController.hideAIThinking() }
        
        do {
            let codeContext = getCodeContext()
            
            let response: AIResponse
            
            if let input = userInput {
                response = try await chatService.sendMessageWithCode(
                    messages: messages,
                    codeContext: codeContext,
                    topic: currentTopic,
                    level: currentLevel,
                    language: currentLanguage,
                    mode: currentMode,
                    apiKey: apiKey,
                    context: ""
                )
            } else {
                // Initial message
                response = try await chatService.sendMessageWithCode(
                    messages: [],
                    codeContext: codeContext,
                    topic: currentTopic,
                    level: currentLevel,
                    language: currentLanguage,
                    mode: currentMode,
                    apiKey: apiKey,
                    context: ""
                )
            }
            
            // Process response
            await processAIResponse(response)
            
        } catch {
            Logger.error("Failed to get AI response", error: error)
        }
    }
    
    private func processAIResponse(_ response: AIResponse) async {
        Logger.info("AI response received - hasAction: \(response.editorAction != nil)")
        
        lastResponse = response
        
        // Add AI message to history
        let aiMessage = TranscriptMessage(
            role: .assistant,
            text: response.spokenText,
            timestamp: Date()
        )
        messages.append(aiMessage)
        
        // Apply editor action if present
        if let action = response.editorAction {
            codeEditorController.applyAIAction(action.withNSRanges())
        }
        
        // Handle evaluation
        if let evaluation = response.evaluation {
            handleEvaluation(evaluation)
        }
        
        // Speak the response
        do {
            try await ttService.generateSpeech(
                text: response.spokenText,
                voice: "",
                apiKey: apiKey
            )
        } catch {
            Logger.error("Failed to generate speech", error: error)
        }
    }
    
    private func handleEvaluation(_ evaluation: CodeEvaluation) {
        if evaluation.isCorrect {
            // Code is correct
            Logger.info("Code evaluation: CORRECT - \(evaluation.feedback)")
            
            // Show visual feedback
            if evaluation.severity == .info {
                // Success feedback
                // Can show toast or highlight in green
            }
        } else {
            // Code has errors
            Logger.warning("Code evaluation: INCORRECT - \(evaluation.feedback)")
            
            // Highlight error lines
            let errorRanges = evaluation.issueLines.compactMap { codeEditorController.editorViewModel.rangeForLine($0) }
            codeEditorController.highlightErrors(
                errorRanges.enumerated().map { index, range in
                    CodeError(
                        range: range,
                        message: evaluation.feedback,
                        severity: evaluation.severity ?? .error,
                        line: evaluation.issueLines[index]
                    )
                }
            )
        }
    }
    
    private func handleDetectedErrors(_ errors: [CodeError]) {
        Logger.info("Detected \(errors.count) real-time errors")
        
        // Highlight errors in editor
        codeEditorController.highlightErrors(errors)
    }
    
    // MARK: - Topic Management
    
    func updateTopic(_ topic: InterviewTopic) {
        currentTopic = topic
        Logger.info("Topic updated to: \(topic.title)")
    }
    
    func updateLevel(_ level: DeveloperLevel) {
        currentLevel = level
        Logger.info("Level updated to: \(level.displayName)")
    }
    
    func updateLanguage(_ language: Language) {
        currentLanguage = language
        Logger.info("Language updated to: \(language.displayName)")
    }
    
    // MARK: - Conversation State
    
    func getConversationHistory() -> [TranscriptMessage] {
        return messages
    }
    
    func clearConversation() {
        messages = []
        currentCode = ""
        codeChangeTracker.clear()
        codeAnalyzer.clearErrors()
        codeEditorController.clearHighlights()
        Logger.info("Conversation cleared")
    }
}
