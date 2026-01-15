//
//  TaskType.swift
//  XInterview2
//
//  Type of interview task
//

import Foundation

/// Type of task the AI is presenting to the user
enum TaskType: String, Codable {
    case question   /// Simple question - user responds verbally
    case codeTask  /// Code challenge - user writes code
    
    var displayName: String {
        switch self {
        case .question:
            return "Question"
        case .codeTask:
            return "Code Task"
        }
    }
}

/// Hint context for when AI provides assistance
struct HintContext: Codable {
    /// Type of hint
    let type: HintType
    
    /// Code to insert (for code_insertion hints)
    let code: String?
    
    /// Explanation of what the code does
    let explanation: String?
    
    /// Range to highlight (for highlighting inserted code)
    let highlightRange: NSRangeCodable?
    
    init(
        type: HintType,
        code: String? = nil,
        explanation: String? = nil,
        highlightRange: NSRangeCodable? = nil
    ) {
        self.type = type
        self.code = code
        self.explanation = explanation
        self.highlightRange = highlightRange
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case type
        case code
        case explanation
        case highlightRange = "highlight_range"
    }
}

/// Type of hint AI can provide
enum HintType: String, Codable {
    case codeInsertion = "code_insertion"   /// Insert actual code into editor
    case textHint = "text_hint"             /// Just give a text hint/explanation
    
    var displayName: String {
        switch self {
        case .codeInsertion:
            return "Code Insertion"
        case .textHint:
            return "Text Hint"
        }
    }
}
