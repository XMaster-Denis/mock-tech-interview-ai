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
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum TaskTypeCodingKeys: String, CodingKey {
        case question = "question"
        case codeTask = "code_task"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TaskTypeCodingKeys.self)
        let commonContainer = try decoder.container(keyedBy: TaskTypeCommonCodingKeys.self)
        let rawValue = try commonContainer.decode(String.self, forKey: .type)
        
        switch rawValue {
        case TaskTypeCodingKeys.question.rawValue:
            self = .question
        case TaskTypeCodingKeys.codeTask.rawValue:
            self = .codeTask
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid task type: \(rawValue)")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        let rawValue: String
        
        switch self {
        case .question:
            rawValue = TaskTypeCodingKeys.question.rawValue
        case .codeTask:
            rawValue = TaskTypeCodingKeys.codeTask.rawValue
        }
        
        var container = encoder.container(keyedBy: TaskTypeCommonCodingKeys.self)
        try container.encode(rawValue, forKey: .type)
    }
    
    enum TaskTypeCommonCodingKeys: String, CodingKey {
        case type
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
    case codeInsertion   /// Insert actual code into editor
    case textHint       /// Just give a text hint/explanation
    
    var displayName: String {
        switch self {
        case .codeInsertion:
            return "Code Insertion"
        case .textHint:
            return "Text Hint"
        }
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum HintTypeCodingKeys: String, CodingKey {
        case codeInsertion = "code_insertion"
        case textHint = "text_hint"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: HintTypeCodingKeys.self)
        let commonContainer = try decoder.container(keyedBy: HintTypeCommonCodingKeys.self)
        let rawValue = try commonContainer.decode(String.self, forKey: .type)
        
        switch rawValue {
        case HintTypeCodingKeys.codeInsertion.rawValue:
            self = .codeInsertion
        case HintTypeCodingKeys.textHint.rawValue:
            self = .textHint
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid hint type: \(rawValue)")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        let rawValue: String
        
        switch self {
        case .codeInsertion:
            rawValue = HintTypeCodingKeys.codeInsertion.rawValue
        case .textHint:
            rawValue = HintTypeCodingKeys.textHint.rawValue
        }
        
        var container = encoder.container(keyedBy: HintTypeCommonCodingKeys.self)
        try container.encode(rawValue, forKey: .type)
    }
    
    enum HintTypeCommonCodingKeys: String, CodingKey {
        case type
    }
}
