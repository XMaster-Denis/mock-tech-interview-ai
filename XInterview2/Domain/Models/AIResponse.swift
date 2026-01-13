//
//  AIResponse.swift
//  XInterview2
//
//  Structured AI response with editor actions
//

import Foundation
import AppKit

/// Represents a complete response from AI with potential editor actions
struct AIResponse: Codable {
    /// Type of task
    let taskType: TaskType
    
    /// Text to be spoken by TTS
    let spokenText: String
    
    /// Code template for user to complete (optional, for code tasks)
    let codeTemplate: String?
    
    /// Action to perform on code editor (optional)
    let editorAction: EditorAction?
    
    /// Code evaluation if applicable (optional)
    let evaluation: CodeEvaluation?
    
    /// Hint context when AI provides assistance (optional)
    let hintContext: HintContext?
    
    init(
        taskType: TaskType,
        spokenText: String,
        codeTemplate: String? = nil,
        editorAction: EditorAction? = nil,
        evaluation: CodeEvaluation? = nil,
        hintContext: HintContext? = nil
    ) {
        self.taskType = taskType
        self.spokenText = spokenText
        self.codeTemplate = codeTemplate
        self.editorAction = editorAction
        self.evaluation = evaluation
        self.hintContext = hintContext
    }
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case taskType = "task_type"
        case spokenText = "spoken_text"
        case codeTemplate = "code_template"
        case editorAction = "editor_action"
        case evaluation
        case hintContext = "hint_context"
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
enum EditorActionNSRange: Equatable {
    case insert(text: String, location: Int)
    case replace(range: NSRange, text: String)
    case clear
    case highlight(ranges: [NSRange])
    case none
}
