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
    
    var uiDisplayName: String {
        switch self {
        case .junior:
            return L10n.text("developer_level.junior")
        case .middle:
            return L10n.text("developer_level.middle")
        case .senior:
            return L10n.text("developer_level.senior")
        case .teamLead:
            return L10n.text("developer_level.team_lead")
        }
    }
    
    var uiDescription: String {
        switch self {
        case .junior:
            return L10n.text("developer_level.junior_desc")
        case .middle:
            return L10n.text("developer_level.middle_desc")
        case .senior:
            return L10n.text("developer_level.senior_desc")
        case .teamLead:
            return L10n.text("developer_level.team_lead_desc")
        }
    }
}
