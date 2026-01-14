//
//  InterviewSession.swift
//  XInterview2
//
//  Represents current interview session state
//

import Foundation

struct InterviewSession: Identifiable, Codable {
    let id: UUID
    var topic: InterviewTopic
    var isActive: Bool
    var transcript: [TranscriptMessage]
    var startTime: Date?
    var endTime: Date?
    var context: InterviewContext?
    
    init(
        id: UUID = UUID(),
        topic: InterviewTopic,
        isActive: Bool = false,
        transcript: [TranscriptMessage] = [],
        startTime: Date? = nil,
        endTime: Date? = nil,
        context: InterviewContext? = nil
    ) {
        self.id = id
        self.topic = topic
        self.isActive = isActive
        self.transcript = transcript
        self.startTime = startTime
        self.endTime = endTime
        self.context = context
    }
    
    /// Creates a default empty session
    static let empty = InterviewSession(
        topic: InterviewTopic(
            id: UUID(),
            title: "",
            prompt: "",
            level: .junior,
            codeLanguage: .swift,
            interviewMode: .questionsOnly
        )
    )
}
