//
//  TopicsRepository.swift
//  XInterview2
//
//  Repository for managing interview topics with JSON persistence
//

import Foundation

enum TopicsRepositoryError: Error {
    case fileNotFound
    case invalidData
    case writeFailed
    case directoryCreationFailed
}

class TopicsRepository {
    private let fileName = "topics.json"
    private let folderName = "XInterview"
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        return folderURL.appendingPathComponent(fileName)
    }
    
    init() {
        createDataDirectoryIfNeeded()
        ensureDefaultTopicsExist()
    }
    
    // MARK: - Directory Management
    
    private func createDataDirectoryIfNeeded() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                Logger.error("Failed to create XInterview data directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensureDefaultTopicsExist() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let defaultTopics = createDefaultTopics()
            switch saveTopics(defaultTopics) {
            case .success:
                break
            case .failure(let error):
                Logger.error("Failed to create default topics: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Default Topics
    
    private func createDefaultTopics() -> [InterviewTopic] {
        return [
            InterviewTopic(
                title: "Swift Basics",
                prompt: "Ask the candidate about basic Swift concepts like optionals, closures, and value types vs reference types.",
                level: .junior,
                codeLanguage: .swift,
                interviewMode: .questionsOnly
            ),
            InterviewTopic(
                title: "iOS Architecture",
                prompt: "Discuss iOS architecture patterns like MVC, MVVM, and SwiftUI. Ask about state management and data flow.",
                level: .middle,
                codeLanguage: .swift,
                interviewMode: .questionsOnly
            ),
            InterviewTopic(
                title: "SwiftUI Layout",
                prompt: "Test the candidate's knowledge of SwiftUI layout system. Ask to implement a simple UI with proper constraints.",
                level: .junior,
                codeLanguage: .swift,
                interviewMode: .codeTasks
            ),
            InterviewTopic(
                title: "Async Programming",
                prompt: "Mix of questions and coding tasks about Swift's async/await and Combine framework.",
                level: .middle,
                codeLanguage: .swift,
                interviewMode: .hybrid
            ),
            InterviewTopic(
                title: "Python Algorithms",
                prompt: "Ask the candidate to solve a basic algorithmic task in Python and explain time/space complexity.",
                level: .junior,
                codeLanguage: .python,
                interviewMode: .codeTasks
            ),
            InterviewTopic(
                title: "JavaScript Fundamentals",
                prompt: "Discuss JS core concepts like closures, event loop, and async patterns with a short coding task.",
                level: .junior,
                codeLanguage: .javascript,
                interviewMode: .hybrid
            ),
            InterviewTopic(
                title: "Java OOP Basics",
                prompt: "Questions about OOP principles and a small Java class design task.",
                level: .middle,
                codeLanguage: .java,
                interviewMode: .questionsOnly
            ),
            InterviewTopic(
                title: "Go Concurrency",
                prompt: "Cover goroutines, channels, and a small concurrency coding exercise in Go.",
                level: .middle,
                codeLanguage: .go,
                interviewMode: .codeTasks
            )
        ]
    }
    
    // MARK: - CRUD Operations
    
    func loadTopics() -> Result<[InterviewTopic], TopicsRepositoryError> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Create default topics if file doesn't exist
            ensureDefaultTopicsExist()
            return loadTopics()
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let topics = try JSONDecoder().decode([InterviewTopic].self, from: data)
            return .success(topics)
        } catch {
            Logger.error("Failed to load topics: \(error.localizedDescription)")
            return .failure(.invalidData)
        }
    }
    
    func saveTopics(_ topics: [InterviewTopic]) -> Result<Void, TopicsRepositoryError> {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(topics)
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            Logger.error("Failed to save topics: \(error.localizedDescription)")
            return .failure(.writeFailed)
        }
    }
    
    func getTopic(id: UUID) -> InterviewTopic? {
        switch loadTopics() {
        case .success(let topics):
            return topics.first { $0.id == id }
        case .failure:
            return nil
        }
    }
    
    func addTopic(_ topic: InterviewTopic) -> Result<Void, TopicsRepositoryError> {
        switch loadTopics() {
        case .success(var topics):
            topics.append(topic)
            return saveTopics(topics)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func updateTopic(_ topic: InterviewTopic) -> Result<Void, TopicsRepositoryError> {
        switch loadTopics() {
        case .success(var topics):
            if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                topics[index] = topic
                return saveTopics(topics)
            } else {
                return .failure(.fileNotFound)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func deleteTopic(id: UUID) -> Result<Void, TopicsRepositoryError> {
        switch loadTopics() {
        case .success(var topics):
            let initialCount = topics.count
            topics.removeAll { $0.id == id }
            
            if topics.count < initialCount {
                return saveTopics(topics)
            } else {
                return .failure(.fileNotFound)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}
