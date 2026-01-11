//
//  TranscriptMessage.swift
//  XInterview2
//
//  Represents a single message in the interview transcript
//

import Foundation

struct TranscriptMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    init(id: UUID = UUID(), role: MessageRole, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
