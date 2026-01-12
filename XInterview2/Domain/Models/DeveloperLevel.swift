//
//  DeveloperLevel.swift
//  XInterview2
//
//  Defines the skill level for interview topics
//

import Foundation

/// Defines the experience/skill level for interview topics
enum DeveloperLevel: String, Codable, CaseIterable, Identifiable {
    case junior
    case middle
    case senior
    case teamLead
    
    /// Unique identifier for Identifiable protocol
    var id: String { rawValue }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .junior:
            return "Junior"
        case .middle:
            return "Middle"
        case .senior:
            return "Senior"
        case .teamLead:
            return "Team Lead"
        }
    }
    
    /// Description of typical topics for this level
    var description: String {
        switch self {
        case .junior:
            return "Basic concepts, fundamental knowledge"
        case .middle:
            return "Advanced concepts, optimization patterns"
        case .senior:
            return "Architecture, system design, best practices"
        case .teamLead:
            return "System design, trade-offs, team decisions"
        }
    }
}
