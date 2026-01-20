//
//  OpenAIChatServiceProtocol.swift
//  XInterview2
//
//  Protocol for OpenAI Chat API service with hybrid interview support
//

import Foundation
import AppKit

/// Protocol for OpenAI Chat completion service
protocol OpenAIChatServiceProtocol {
    /// Send chat message with code context for hybrid interview
    /// - Parameters:
    ///   - messages: Conversation history
    ///   - codeContext: Current code and recent changes
    ///   - topic: Interview topic
    ///   - level: Developer skill level
    ///   - language: Programming language
    ///   - mode: Interview mode
    ///   - llmMode: LLM mode for check vs generation
    ///   - apiKey: OpenAI API key
    ///   - context: Interview context with progress summary
    /// - Returns: Structured AI response with potential editor actions
    func sendMessageWithCode(
        messages: [TranscriptMessage],
        codeContext: CodeContext,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        llmMode: LLMMode,
        chatModel: String,
        apiKey: String,
        context: String
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

    /// Translate assistant message to interface language with brief notes
    /// - Parameters:
    ///   - text: Assistant message text
    ///   - sourceLanguage: Interview language
    ///   - targetLanguage: Interface language
    ///   - chatModel: Model to use for translation
    ///   - apiKey: OpenAI API key
    /// - Returns: Translation result with optional notes
    func translateAssistantMessage(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        chatModel: String,
        apiKey: String
    ) async throws -> TranslationResult
}

// MARK: - Code Context

struct CodeContext: Codable {
    let currentCode: String
    let language: CodeLanguageInterview
    let recentChanges: [CodeChange]
    
    init(currentCode: String, language: CodeLanguageInterview, recentChanges: [CodeChange]) {
        self.currentCode = currentCode
        self.language = language
        self.recentChanges = recentChanges
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case currentCode = "current_code"
        case language
        case recentChanges = "recent_changes"
    }
    
    func toContextString() -> String {
        return """
        Current Code (\(language.displayName)):
        ```
        \(currentCode)
        ```
        
        Recent Changes: \(recentChanges.count)
        """
    }
}



/// Represents a change made to code
struct CodeChange: Codable {
    let range: NSRangeCodable
    let oldText: String
    let newText: String
    let timestamp: Date
    
    init(range: NSRange, oldText: String, newText: String) {
        self.range = NSRangeCodable(range)
        self.oldText = oldText
        self.newText = newText
        self.timestamp = Date()
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case range
        case oldText = "old_text"
        case newText = "new_text"
        case timestamp
    }
}

/// Codable wrapper for NSRange
struct NSRangeCodable: Codable {
    let range: NSRange
    
    init(_ range: NSRange) {
        self.range = range
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let location = try container.decode(Int.self, forKey: .location)
        let length = try container.decode(Int.self, forKey: .length)
        self.range = NSRange(location: location, length: length)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range.location, forKey: .location)
        try container.encode(range.length, forKey: .length)
    }
    
    enum CodingKeys: String, CodingKey {
        case location
        case length
    }
}

/// Severity of code issues
enum IssueSeverity: String, Codable {
    case info
    case warning
    case error
    
    var displayName: String {
        switch self {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
    
    var color: NSColor {
        switch self {
        case .info:
            return NSColor(hex: "#4CA6FF")
        case .warning:
            return NSColor(hex: "#FFD93D")
        case .error:
            return NSColor(hex: "#FF6B6B")
        }
    }
}

/// Error detected in code by real-time analysis
struct CodeError: Codable {
    let range: NSRangeCodable
    let message: String
    let severity: IssueSeverity
    let line: Int
    
    init(range: NSRange, message: String, severity: IssueSeverity, line: Int) {
        self.range = NSRangeCodable(range)
        self.message = message
        self.severity = severity
        self.line = line
    }
    
    var nsRange: NSRange {
        return range.range
    }
}

/// Evaluation of user's code submission
struct CodeEvaluation: Codable {
    /// Whether code is correct
    let isCorrect: Bool
    
    /// Feedback message
    let feedback: String
    
    /// Suggestions for improvement
    let suggestions: [String]
    
    /// Severity of issues (if any)
    let severity: IssueSeverity?
    
    /// Line numbers with issues
    let issueLines: [Int]
    
    init(
        isCorrect: Bool,
        feedback: String,
        suggestions: [String] = [],
        severity: IssueSeverity? = nil,
        issueLines: [Int] = []
    ) {
        self.isCorrect = isCorrect
        self.feedback = feedback
        self.suggestions = suggestions
        self.severity = severity
        self.issueLines = issueLines
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case feedback
        case suggestions
        case severity
        case issueLines = "issue_lines"
    }
    
    /// Create a success evaluation
    static func success(feedback: String) -> CodeEvaluation {
        return CodeEvaluation(
            isCorrect: true,
            feedback: feedback,
            severity: .info,
            issueLines: []
        )
    }
    
    /// Create an error evaluation
    static func error(
        feedback: String,
        suggestions: [String] = [],
        issueLines: [Int] = []
    ) -> CodeEvaluation {
        return CodeEvaluation(
            isCorrect: false,
            feedback: feedback,
            suggestions: suggestions,
            severity: .error,
            issueLines: issueLines
        )
    }
    
    /// Create a warning evaluation
    static func warning(
        feedback: String,
        suggestions: [String] = [],
        issueLines: [Int] = []
    ) -> CodeEvaluation {
        return CodeEvaluation(
            isCorrect: true,
            feedback: feedback,
            suggestions: suggestions,
            severity: .warning,
            issueLines: issueLines
        )
    }
}
