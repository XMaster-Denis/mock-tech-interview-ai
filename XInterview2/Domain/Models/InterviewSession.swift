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
    var isActive: Bool
    var transcript: [TranscriptMessage]
    var startTime: Date?
    var endTime: Date?
    
    init(
        id: UUID = UUID(),
        topic: InterviewTopic = InterviewTopic.defaultTopics[0],
        isActive: Bool = false,
        transcript: [TranscriptMessage] = [],
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = id
        self.topic = topic
        self.isActive = isActive
        self.transcript = transcript
        self.startTime = startTime
        self.endTime = endTime
    }
}
