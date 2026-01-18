//
//  InterviewContext.swift
//  XInterview2
//
//  Tracks the state and progress of an interview session
//

import Foundation

/// Represents a specific discussion point within an interview
struct DiscussionPoint: Identifiable, Codable {
    let id: UUID
    let topic: String
    let userAnswer: String
    let isCorrect: Bool
    let feedback: String
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        topic: String,
        userAnswer: String,
        isCorrect: Bool,
        feedback: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.topic = topic
        self.userAnswer = userAnswer
        self.isCorrect = isCorrect
        self.feedback = feedback
        self.timestamp = timestamp
    }
}

/// Represents a completed coding task
struct CompletedTask: Identifiable, Codable {
    let id: UUID
    let taskDescription: String
    let code: String
    let isCorrect: Bool
    let feedback: String
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        taskDescription: String,
        code: String,
        isCorrect: Bool,
        feedback: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.taskDescription = taskDescription
        self.code = code
        self.isCorrect = isCorrect
        self.feedback = feedback
        self.timestamp = timestamp
    }
}

/// Represents an area where the user made mistakes
struct Mistake: Identifiable, Codable {
    let id: UUID
    let topic: String
    let mistake: String
    let correction: String
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        topic: String,
        mistake: String,
        correction: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.topic = topic
        self.mistake = mistake
        self.correction = correction
        self.timestamp = timestamp
    }
}

/// Overall context of an interview session for AI continuation
struct InterviewContext: Codable {
    let sessionId: UUID
    var topicId: UUID?
    var levelRaw: String?
    var languageRaw: String?
    var discussionPoints: [DiscussionPoint]
    var completedTasks: [CompletedTask]
    var mistakes: [Mistake]
    var strengths: [String]
    var weaknesses: [String]
    var lastTaskId: UUID?
    var lastTaskText: String
    var recentTopics: [String]
    var lastUpdated: Date
    
    init(
        sessionId: UUID = UUID(),
        topicId: UUID? = nil,
        levelRaw: String? = nil,
        languageRaw: String? = nil,
        discussionPoints: [DiscussionPoint] = [],
        completedTasks: [CompletedTask] = [],
        mistakes: [Mistake] = [],
        strengths: [String] = [],
        weaknesses: [String] = [],
        lastTaskId: UUID? = nil,
        lastTaskText: String = "",
        recentTopics: [String] = [],
        lastUpdated: Date = Date()
    ) {
        self.sessionId = sessionId
        self.topicId = topicId
        self.levelRaw = levelRaw
        self.languageRaw = languageRaw
        self.discussionPoints = discussionPoints
        self.completedTasks = completedTasks
        self.mistakes = mistakes
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.lastTaskId = lastTaskId
        self.lastTaskText = lastTaskText
        self.recentTopics = recentTopics
        self.lastUpdated = lastUpdated
    }
    
    /// Returns a summary of topics already discussed
    func getDiscussedTopics() -> [String] {
        Set(discussionPoints.map { $0.topic })
            .sorted()
    }
    
    /// Returns a summary of completed task types
    func getCompletedTaskTypes() -> [String] {
        Set(completedTasks.map { $0.taskDescription })
            .sorted()
    }
    
    /// Returns a formatted context summary for AI prompts
    func getContextSummary() -> String {
        var summary = "Interview Progress Summary:\n"
        
        if !discussionPoints.isEmpty {
            summary += "\nDiscussed Topics:\n"
            for point in discussionPoints {
                let status = point.isCorrect ? "✓ Correct" : "✗ Incorrect"
                summary += "- \(point.topic): \(status)\n"
                summary += "  Answer: \(point.userAnswer)\n"
                if !point.feedback.isEmpty {
                    summary += "  Feedback: \(point.feedback)\n"
                }
            }
        }
        
        if !completedTasks.isEmpty {
            summary += "\nCompleted Tasks:\n"
            for task in completedTasks {
                let status = task.isCorrect ? "✓ Correct" : "✗ Incorrect"
                summary += "- \(task.taskDescription): \(status)\n"
                if !task.feedback.isEmpty {
                    summary += "  Feedback: \(task.feedback)\n"
                }
            }
        }
        
        if !mistakes.isEmpty {
            summary += "\nMistakes Made:\n"
            for mistake in mistakes {
                summary += "- \(mistake.topic): \(mistake.mistake)\n"
                summary += "  Correction: \(mistake.correction)\n"
            }
        }
        
        if !strengths.isEmpty {
            summary += "\nIdentified Strengths:\n"
            strengths.forEach { summary += "- \($0)\n" }
        }
        
        if !weaknesses.isEmpty {
            summary += "\nIdentified Weaknesses:\n"
            weaknesses.forEach { summary += "- \($0)\n" }
        }
        
        summary += "\nUse this context to tailor follow-up questions, focusing on areas where the user needs improvement while building on their strengths."
        
        return summary
    }
    
    /// Returns a compact context for task generation
    func getCompactTaskContext(maxTopics: Int = 5) -> String {
        let recent = recentTopics.suffix(maxTopics)
        let recentLine = recent.isEmpty ? "recent_topics: none" : "recent_topics: \(recent.joined(separator: "; "))"
        return recentLine
    }
    
    /// Updates the last updated timestamp
    mutating func touch() {
        lastUpdated = Date()
    }
    
    /// Adds a discussion point
    mutating func addDiscussionPoint(_ point: DiscussionPoint) {
        discussionPoints.append(point)
        touch()
    }
    
    /// Adds a completed task
    mutating func addCompletedTask(_ task: CompletedTask) {
        completedTasks.append(task)
        touch()
    }
    
    /// Adds a mistake
    mutating func addMistake(_ mistake: Mistake) {
        mistakes.append(mistake)
        touch()
    }
    
    /// Adds a strength
    mutating func addStrength(_ strength: String) {
        if !strengths.contains(strength) {
            strengths.append(strength)
            touch()
        }
    }
    
    /// Adds a weakness
    mutating func addWeakness(_ weakness: String) {
        if !weaknesses.contains(weakness) {
            weaknesses.append(weakness)
            touch()
        }
    }
    
    /// Tracks the last task and updates the recent topics ring buffer
    mutating func updateRecentTask(taskText: String, maxTopics: Int = 5) {
        let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        lastTaskId = UUID()
        lastTaskText = trimmed
        
        if recentTopics.last != trimmed {
            recentTopics.append(trimmed)
            if recentTopics.count > maxTopics {
                recentTopics = Array(recentTopics.suffix(maxTopics))
            }
        }
        
        touch()
    }
}
