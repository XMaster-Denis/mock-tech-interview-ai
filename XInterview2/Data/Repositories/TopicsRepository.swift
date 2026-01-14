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
    private let defaultTopicsFile = "default_topics.json"
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        return folderURL.appendingPathComponent(fileName)
    }
    
    private var defaultTopicsURL: URL {
        Bundle.main.url(forResource: "default_topics", withExtension: "json") ?? fileURL
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
                Logger.info("Created XInterview data directory at: \(folderURL.path)")
            } catch {
                Logger.error("Failed to create XInterview data directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensureDefaultTopicsExist() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            loadDefaultTopicsFromBundle()
        }
    }
    
    private func loadDefaultTopicsFromBundle() {
        guard let bundleURL = Bundle.main.url(forResource: "default_topics", withExtension: "json") else {
            Logger.warning("Default topics file not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: bundleURL)
            let topics = try JSONDecoder().decode([InterviewTopic].self, from: data)
            saveTopics(topics)
            Logger.info("Loaded \(topics.count) default topics from bundle")
        } catch {
            Logger.error("Failed to load default topics from bundle: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func loadTopics() -> Result<[InterviewTopic], TopicsRepositoryError> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Try loading from bundle as fallback
            loadDefaultTopicsFromBundle()
            return loadTopics()
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let topics = try JSONDecoder().decode([InterviewTopic].self, from: data)
            Logger.info("Loaded \(topics.count) topics from storage")
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
            Logger.info("Saved \(topics.count) topics to storage")
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
