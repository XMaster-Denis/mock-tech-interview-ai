//
//  AIResponse.swift
//  XInterview2
//
//  Simplified AI response
//

import Foundation

/// Represents the state of an interview task
enum TaskState: String, Codable {
    case none = "none"
    case taskPresented = "task_presented"
    case checkingSolution = "checking_solution"
    case providingHint = "providing_hint"
    case providingSolution = "providing_solution"
    case showingSolution = "showing_solution"
    case waitingForUnderstanding = "waiting_for_understanding"
}

/// Represents a simplified response from AI
struct AIResponse: Codable {
    /// Text to be spoken by TTS
    let spokenText: String
    
    /// Code to display in editor (optional)
    let aicode: String?
    
    /// Current state of the task (optional)
    let taskState: TaskState?
    
    /// Text hint to help user (optional)
    let hint: String?
    
    /// Partial code solution as hint (optional)
    let hintCode: String?
    
    /// Full solution code for assistance (optional)
    let solutionCode: String?
    
    /// Explanation for full solution (optional)
    let explanation: String?
    
    /// Complete correct solution (optional)
    let correctCode: String?
    
    /// Whether user's solution is correct (optional)
    let isCorrect: Bool?
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case spokenText = "spoken_text"
        case aicode
        case taskState = "task_state"
        case hint
        case hintCode = "hint_code"
        case solutionCode = "solution_code"
        case explanation
        case correctCode = "correct_code"
        case isCorrect = "is_correct"
    }
    
    init(
        spokenText: String,
        aicode: String? = nil,
        taskState: TaskState? = nil,
        hint: String? = nil,
        hintCode: String? = nil,
        solutionCode: String? = nil,
        explanation: String? = nil,
        correctCode: String? = nil,
        isCorrect: Bool? = nil
    ) {
        self.spokenText = spokenText
        self.aicode = aicode
        self.taskState = taskState
        self.hint = hint
        self.hintCode = hintCode
        self.solutionCode = solutionCode
        self.explanation = explanation
        self.correctCode = correctCode
        self.isCorrect = isCorrect
    }
}
