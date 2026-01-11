//
//  InterviewSession.swift
//  XInterview2
//
//  Represents the current interview session state
//

import Foundation

struct InterviewSession: Identifiable, Codable {
    let id: UUID
    var topic: InterviewTopic
    var language: Language
    var isActive: Bool
    var messages: [TranscriptMessage]
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        topic: InterviewTopic,
        language: Language = .english,
        isActive: Bool = false,
        messages: [TranscriptMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.topic = topic
        self.language = language
        self.isActive = isActive
        self.messages = messages
        self.createdAt = createdAt
    }
}
