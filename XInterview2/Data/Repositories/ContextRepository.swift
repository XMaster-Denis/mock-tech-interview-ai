//
//  ContextRepository.swift
//  XInterview2
//
//  Repository for managing interview context with JSON persistence
//

import Foundation

enum ContextRepositoryError: Error {
    case fileNotFound
    case invalidData
    case writeFailed
    case directoryCreationFailed
}

class ContextRepository {
    private let fileName = "interview_contexts.json"
    private let folderName = "XInterview"
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        return folderURL.appendingPathComponent(fileName)
    }
    
    init() {
        createDataDirectoryIfNeeded()
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
    
    // MARK: - CRUD Operations
    
    func loadAllContexts() -> Result<[InterviewContext], ContextRepositoryError> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .success([])
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let contexts = try JSONDecoder().decode([InterviewContext].self, from: data)
            return .success(contexts)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
                return .success([])
            }
            Logger.error("Failed to load contexts: \(error.localizedDescription)")
            return .failure(.invalidData)
        }
    }
    
    func saveContexts(_ contexts: [InterviewContext]) -> Result<Void, ContextRepositoryError> {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(contexts)
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            Logger.error("Failed to save contexts: \(error.localizedDescription)")
            return .failure(.writeFailed)
        }
    }
    
    func getContext(sessionId: UUID) -> InterviewContext? {
        switch loadAllContexts() {
        case .success(let contexts):
            return contexts.first { $0.sessionId == sessionId }
        case .failure:
            return nil
        }
    }
    
    func getLatestContext(topicId: UUID, level: DeveloperLevel, language: Language) -> InterviewContext? {
        switch loadAllContexts() {
        case .success(let contexts):
            return contexts
                .filter { $0.topicId == topicId && $0.levelRaw == level.rawValue && $0.languageRaw == language.rawValue }
                .sorted { $0.lastUpdated > $1.lastUpdated }
                .first
        case .failure:
            return nil
        }
    }
    
    func saveContext(_ context: InterviewContext) -> Result<Void, ContextRepositoryError> {
        switch loadAllContexts() {
        case .success(var contexts):
            if let index = contexts.firstIndex(where: { $0.sessionId == context.sessionId }) {
                contexts[index] = context
            } else {
                contexts.append(context)
            }
            return saveContexts(contexts)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func deleteContext(sessionId: UUID) -> Result<Void, ContextRepositoryError> {
        switch loadAllContexts() {
        case .success(var contexts):
            let initialCount = contexts.count
            contexts.removeAll { $0.sessionId == sessionId }
            
            if contexts.count < initialCount {
                return saveContexts(contexts)
            } else {
                return .failure(.fileNotFound)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func deleteAllContexts() -> Result<Void, ContextRepositoryError> {
        do {
            try FileManager.default.removeItem(at: fileURL)
            return .success(())
        } catch {
            Logger.error("Failed to delete all contexts: \(error.localizedDescription)")
            return .failure(.writeFailed)
        }
    }
}
