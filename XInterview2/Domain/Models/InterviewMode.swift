//
//  InterviewMode.swift
//  XInterview2
//
//  Interview mode selection
//

import Foundation

enum InterviewMode: String, CaseIterable, Identifiable {
    case questionsOnly = "Questions"
    case codeTasks = "Code Tasks"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue
    }
    
    var description: String {
        switch self {
        case .questionsOnly:
            return "Standard interview with verbal questions and answers"
        case .codeTasks:
            return "Coding challenges with AI evaluation"
        }
    }
}
