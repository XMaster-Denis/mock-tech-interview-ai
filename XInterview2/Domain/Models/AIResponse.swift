//
//  AIResponse.swift
//  XInterview2
//
//  Structured AI response with editor actions
//

import Foundation
import AppKit

/// Represents a complete response from the AI with potential editor actions
struct AIResponse: Codable {
    /// Text to be spoken by TTS
    let spokenText: String
    
    /// Action to perform on the code editor (optional)
    let editorAction: EditorAction?
    
    /// Code evaluation if applicable (optional)
    let evaluation: CodeEvaluation?
    
    init(
        spokenText: String,
        editorAction: EditorAction? = nil,
        evaluation: CodeEvaluation? = nil
    ) {
        self.spokenText = spokenText
        self.editorAction = editorAction
        self.evaluation = evaluation
    }
}

/// Actions AI can perform on the code editor
enum EditorAction: Codable {
    case insert(text: String, location: Int)
    case replace(range: NSRangeCodable, text: String)
    case clear
    case highlight(ranges: [NSRangeCodable])
    case none
    
    // MARK: - Coding
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case location
        case range
        case ranges
    }
    
    enum ActionType: String, Codable {
        case insert
        case replace
        case clear
        case highlight
        case none
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        
        switch type {
        case .insert:
            let text = try container.decode(String.self, forKey: .text)
            let location = try container.decode(Int.self, forKey: .location)
            self = .insert(text: text, location: location)
        case .replace:
            let text = try container.decode(String.self, forKey: .text)
            let rangeCodable = try container.decode(NSRangeCodable.self, forKey: .range)
            self = .replace(range: rangeCodable, text: text)
        case .clear:
            self = .clear
        case .highlight:
            let rangesCodable = try container.decode([NSRangeCodable].self, forKey: .ranges)
            self = .highlight(ranges: rangesCodable)
        case .none:
            self = .none
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .insert(let text, let location):
            try container.encode(ActionType.insert, forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(location, forKey: .location)
        case .replace(let rangeCodable, let text):
            try container.encode(ActionType.replace, forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encode(rangeCodable, forKey: .range)
        case .clear:
            try container.encode(ActionType.clear, forKey: .type)
        case .highlight(let rangesCodable):
            try container.encode(ActionType.highlight, forKey: .type)
            try container.encode(rangesCodable, forKey: .ranges)
        case .none:
            try container.encode(ActionType.none, forKey: .type)
        }
    }
    
    // MARK: - Helpers
    
    func withNSRanges() -> EditorActionNSRange {
        switch self {
        case .insert(let text, let location):
            return .insert(text: text, location: location)
        case .replace(let rangeCodable, let text):
            return .replace(range: rangeCodable.range, text: text)
        case .clear:
            return .clear
        case .highlight(let rangesCodable):
            return .highlight(ranges: rangesCodable.map { $0.range })
        case .none:
            return .none
        }
    }
}

/// EditorAction using NSRange directly (for internal use)
enum EditorActionNSRange {
    case insert(text: String, location: Int)
    case replace(range: NSRange, text: String)
    case clear
    case highlight(ranges: [NSRange])
    case none
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
