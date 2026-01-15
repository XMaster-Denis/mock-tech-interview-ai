//
//  TaskType.swift
//  XInterview2
//
//  Type of interview task
//

import Foundation

/// Type of task AI is presenting to user
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
