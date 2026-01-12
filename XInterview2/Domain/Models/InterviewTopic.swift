//
//  InterviewTopic.swift
//  XInterview2
//
//  Interview topic with prompt guidance
//

import Foundation

struct InterviewTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var prompt: String
    var level: DeveloperLevel
    
    init(id: UUID = UUID(), title: String, prompt: String, level: DeveloperLevel = .junior) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.level = level
    }
    
    static let defaultTopics: [InterviewTopic] = [
        InterviewTopic(
            title: "Swift Basics",
            prompt: "Interview the user about Swift fundamentals including optionals, closures, and basic data structures.",
            level: .junior
        ),
        InterviewTopic(
            title: "UI Development",
            prompt: "Focus interview on SwiftUI and UIKit concepts, views, state management, and layout systems.",
            level: .middle
        ),
        InterviewTopic(
            title: "Concurrency",
            prompt: "Discuss async/await, actors, GCD, and thread safety in Swift applications.",
            level: .middle
        ),
        InterviewTopic(
            title: "Architecture Patterns",
            prompt: "Cover MVVM, MVC, VIPER, and other architectural patterns used in iOS development.",
            level: .senior
        ),
        InterviewTopic(
            title: "Data Persistence",
            prompt: "Explore Core Data, UserDefaults, file I/O, and iCloud synchronization.",
            level: .middle
        ),
        InterviewTopic(
            title: "Networking",
            prompt: "Discuss URLSession, Codable, API design, error handling, and caching strategies.",
            level: .middle
        )
    ]
}
