//
//  OpenAIChatServiceProtocol.swift
//  XInterview2
//
//  Protocol for OpenAI Chat API service with hybrid interview support
//

import Foundation

/// Protocol for OpenAI Chat completion service
protocol OpenAIChatServiceProtocol {
    /// Send chat message with code context for hybrid interview
    /// - Parameters:
    ///   - messages: Conversation history
    ///   - codeContext: Current code and recent changes
    ///   - topic: Interview topic
    ///   - level: Developer skill level
    ///   - language: Programming language
    ///   - apiKey: OpenAI API key
    /// - Returns: Structured AI response with potential editor actions
    func sendMessageWithCode(
        messages: [TranscriptMessage],
        codeContext: CodeContext,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        apiKey: String
    ) async throws -> AIResponse
    
    /// Analyze code errors in real-time (debounced)
    /// - Parameters:
    ///   - code: Current code
    ///   - topic: Interview topic
    ///   - level: Developer skill level
    ///   - apiKey: OpenAI API key
    /// - Returns: Detected code errors
    func analyzeCodeErrors(
        code: String,
        topic: InterviewTopic,
        level: DeveloperLevel,
        apiKey: String
    ) async throws -> [CodeError]
    
    /// Evaluate code submission
    /// - Parameters:
    ///   - code: Submitted code
    ///   - context: Code context with requirements
    ///   - apiKey: OpenAI API key
    /// - Returns: Code evaluation result
    func evaluateCode(
        code: String,
        context: CodeContext,
        apiKey: String
    ) async throws -> CodeEvaluation
}

// MARK: - Legacy Support (for backward compatibility)

extension OpenAIChatServiceProtocol {
    /// Legacy method for backward compatibility
    func sendMessage(
        messages: [TranscriptMessage],
        topic: InterviewTopic,
        language: Language,
        apiKey: String
    ) async throws -> String {
        let emptyContext = CodeContext(
            currentCode: "",
            language: .swift,
            recentChanges: []
        )
        
        let response = try await sendMessageWithCode(
            messages: messages,
            codeContext: emptyContext,
            topic: topic,
            level: .junior,
            language: language,
            apiKey: apiKey
        )
        
        return response.spokenText
    }
}
