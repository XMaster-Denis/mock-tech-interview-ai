//
//  RealTimeCodeAnalyzer.swift
//  XInterview2
//
//  Real-time code analysis with debouncing
//

import Foundation
import Combine

/// Analyzes code in real-time as user types
@MainActor
class RealTimeCodeAnalyzer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var detectedErrors: [CodeError] = []
    @Published var isAnalyzing: Bool = false
    @Published var lastAnalysisTime: Date?
    
    // MARK: - Components
    
    private let chatService: OpenAIChatServiceProtocol
    private let topic: InterviewTopic
    private let level: DeveloperLevel
    private let apiKey: String
    
    // MARK: - Properties
    
    private var debounceTask: Task<Void, Never>?
    private var previousCode: String = ""
    private let debounceDelay: TimeInterval = 2.0 // 2 seconds
    
    // MARK: - Initialization
    
    init(
        chatService: OpenAIChatServiceProtocol,
        topic: InterviewTopic,
        level: DeveloperLevel,
        apiKey: String
    ) {
        self.chatService = chatService
        self.topic = topic
        self.level = level
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Trigger code analysis (debounced)
    func analyze(code: String) {
        // Skip if code is empty or unchanged
        guard !code.isEmpty && code != previousCode else { return }
        
        previousCode = code
        
        // Cancel previous task
        debounceTask?.cancel()
        
        // Schedule new analysis
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            await performAnalysis(code: code)
        }
    }
    
    /// Cancel pending analysis
    func cancelPendingAnalysis() {
        debounceTask?.cancel()
        isAnalyzing = false
    }
    
    /// Clear detected errors
    func clearErrors() {
        detectedErrors = []
    }
    
    // MARK: - Private Methods
    
    private func performAnalysis(code: String) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let errors = try await chatService.analyzeCodeErrors(
                code: code,
                topic: topic,
                level: level,
                apiKey: apiKey
            )
            
            detectedErrors = errors
            lastAnalysisTime = Date()
            
            // Notify via callback if set
            onErrorsDetected?(errors)
            
        } catch {
            Logger.error("Real-time code analysis failed", error: error)
        }
    }
    
    // MARK: - Callbacks
    
    var onErrorsDetected: (([CodeError]) -> Void)?
}

// MARK: - Code Change Tracker

/// Tracks code changes for context
class CodeChangeTracker {
    private var changes: [CodeChange] = []
    private let maxChanges: Int = 10
    
    func addChange(_ change: CodeChange) {
        changes.append(change)
        if changes.count > maxChanges {
            changes.removeFirst()
        }
    }
    
    func getRecentChanges(limit: Int = 3) -> [CodeChange] {
        return Array(changes.suffix(limit))
    }
    
    func clear() {
        changes = []
    }
    
    func createChange(oldText: String, newText: String, range: NSRange) -> CodeChange {
        return CodeChange(
            range: range,
            oldText: oldText,
            newText: newText
        )
    }
}
