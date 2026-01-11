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
    
    init(id: UUID = UUID(), title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
    
    static let defaultTopics: [InterviewTopic] = [
        InterviewTopic(
            title: "Swift Basics",
            prompt: "Interview the user about Swift fundamentals including optionals, closures, and basic data structures."
        ),
        InterviewTopic(
            title: "UI Development",
            prompt: "Focus interview on SwiftUI and UIKit concepts, views, state management, and layout systems."
        ),
        InterviewTopic(
            title: "Concurrency",
            prompt: "Discuss async/await, actors, GCD, and thread safety in Swift applications."
        ),
        InterviewTopic(
            title: "Architecture Patterns",
            prompt: "Cover MVVM, MVC, VIPER, and other architectural patterns used in iOS development."
        ),
        InterviewTopic(
            title: "Data Persistence",
            prompt: "Explore Core Data, UserDefaults, file I/O, and iCloud synchronization."
        ),
        InterviewTopic(
            title: "Networking",
            prompt: "Discuss URLSession, Codable, API design, error handling, and caching strategies."
        )
    ]
}
