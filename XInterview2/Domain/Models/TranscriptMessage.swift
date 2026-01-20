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
    let audioFileName: String?
    let translationText: String?
    let translationNotes: String?
    
    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        timestamp: Date = Date(),
        audioFileName: String? = nil,
        translationText: String? = nil,
        translationNotes: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.audioFileName = audioFileName
        self.translationText = translationText
        self.translationNotes = translationNotes
    }
}
