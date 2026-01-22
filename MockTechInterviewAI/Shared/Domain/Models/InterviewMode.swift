//
//  InterviewMode.swift
//  XInterview2
//
//  Interview mode selection
//

import Foundation

enum InterviewMode: String, Codable, CaseIterable, Identifiable {
    case questionsOnly = "Questions"
    case codeTasks = "Code Tasks"
    case hybrid = "Hybrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .questionsOnly:
            return "Questions"
        case .codeTasks:
            return "Code Tasks"
        case .hybrid:
            return "Hybrid"
        }
    }
    
    var description: String {
        switch self {
        case .questionsOnly:
            return "Standard interview with verbal questions and answers"
        case .codeTasks:
            return "Coding challenges with AI evaluation"
        case .hybrid:
            return "Mixed mode with both questions and coding tasks"
        }
    }
    
    var uiDisplayName: String {
        switch self {
        case .questionsOnly:
            return L10n.text("interview_mode.questions")
        case .codeTasks:
            return L10n.text("interview_mode.code_tasks")
        case .hybrid:
            return L10n.text("interview_mode.hybrid")
        }
    }
    
    var uiDescription: String {
        switch self {
        case .questionsOnly:
            return L10n.text("interview_mode.questions_desc")
        case .codeTasks:
            return L10n.text("interview_mode.code_tasks_desc")
        case .hybrid:
            return L10n.text("interview_mode.hybrid_desc")
        }
    }
}
