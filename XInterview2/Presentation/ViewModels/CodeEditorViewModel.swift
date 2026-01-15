//
//  CodeEditorViewModel.swift
//  XInterview2
//
//  ViewModel for code editor with syntax highlighting and AI integration
//

import SwiftUI
import AppKit
import Combine

@MainActor
class CodeEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var code: String = ""
    @Published var attributedCode: NSAttributedString = NSAttributedString()
    @Published var language: CodeLanguageInterview = .swift
    @Published var errorRanges: [NSRange] = []
    @Published var hintRanges: [NSRange] = []
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    // AI Control flags
    @Published var isAIEditing: Bool = false
    @Published var isUserEditable: Bool = true
    
    // UI State
    @Published var showLineNumbers: Bool = true
    @Published var cursorPosition: (line: Int, column: Int) = (1, 1)
    
    // MARK: - Components
    

    private let theme: SyntaxTheme = .xcodeDark
    private let font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    
    // MARK: - Properties
    
    private var debounceTask: Task<Void, Never>?
    private var previousCode: String = ""
    
    // MARK: - Initialization
    
    init(language: CodeLanguageInterview = .swift) {
        self.language = language
    }
    
    // MARK: - Code Management
    
    func setCode(_ newCode: String) {
        code = newCode
        previousCode = newCode
    }
    
    func updateLanguage(_ newLanguage: CodeLanguageInterview) {
        language = newLanguage
    }
    
    // MARK: - User Actions
    
    func userDidChange(_ newCode: String) {
        guard isUserEditable && !isAIEditing else { return }
        
        code = newCode
        updateCursorPosition(in: newCode)
        
        // Notify of changes (callback will be set by parent)
        onCodeChanged?()
    }
    
    func handleCodeChange(_ newCode: String) {
        // Debounced code change handler
        guard isUserEditable && !isAIEditing else { return }
        
        if newCode != previousCode {
            code = newCode
            previousCode = newCode
            updateCursorPosition(in: newCode)
            onCodeChanged?()
        }
    }
    
    // MARK: - AI Actions (Full Control)
    
    func replaceAllCode(_ newCode: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        code = newCode
    }
    
    func insertCodeAtCursor(_ text: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        let insertLocation = selectedRange.location
        code.insert(contentsOf: text, at: code.index(code.startIndex, offsetBy: insertLocation))

        
        // Move cursor to end of inserted text
        let newLocation = insertLocation + text.utf16.count
        selectedRange = NSRange(location: newLocation, length: 0)
    }
    
    func insertCodeAtLine(_ line: Int, _ text: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        let lines = code.components(separatedBy: .newlines)
        var insertionIndex = 0
        
        for i in 0..<min(line, lines.count) {
            insertionIndex += lines[i].utf16.count + 1 // +1 for newline
        }
        
        let actualInsertionIndex = min(insertionIndex, code.utf16.count)
        code.insert(contentsOf: text, at: code.index(code.startIndex, offsetBy: actualInsertionIndex))
    }
    
    func replaceCodeInRange(_ range: NSRange, with text: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        guard let stringRange = Range(range, in: code) else { return }
        
        code.removeSubrange(stringRange)
        code.insert(contentsOf: text, at: code.index(code.startIndex, offsetBy: range.location))

    }
    
    func selectRange(_ range: NSRange) {
        selectedRange = range
    }
    
    func scrollToRange(_ range: NSRange) {
        // This will be handled by the view
        onScrollToRange?(range)
    }
    
    // MARK: - Error/Highlight Management
    
    func highlightErrors(_ errors: [CodeError]) {
        errorRanges = errors.map { $0.nsRange }
    }
    
    func highlightHints(_ ranges: [NSRange]) {
        hintRanges = ranges
    }
    
    func clearHighlights() {
        errorRanges = []
        hintRanges = []
    }
    
    // MARK: - Helper Methods

    
    private func updateCursorPosition(in text: String) {
        let lines = text.prefix(code.utf16.count).components(separatedBy: .newlines)
        let currentLine = min(lines.count, code.lines().count)
        let currentColumn = selectedRange.location - text.prefix(selectedRange.location).components(separatedBy: .newlines).dropLast().joined(separator: "\n").utf16.count
        
        cursorPosition = (line: currentLine, column: max(1, currentColumn))
    }
    
    func line(for range: NSRange) -> Int {
        guard let stringRange = Range(range, in: code) else { return 1 }
        let substring = code[..<stringRange.lowerBound]
        return substring.components(separatedBy: .newlines).count
    }
    
    func rangeForLine(_ line: Int) -> NSRange? {
        let lines = code.components(separatedBy: .newlines)
        guard line >= 1 && line <= lines.count else { return nil }
        
        var location = 0
        for i in 0..<(line - 1) {
            location += lines[i].utf16.count + 1 // +1 for newline
        }
        
        let length = lines[line - 1].utf16.count
        return NSRange(location: location, length: length)
    }
    
    // MARK: - Editor Actions
    

    
    // MARK: - Callbacks
    
    var onCodeChanged: (() -> Void)?
    var onScrollToRange: ((NSRange) -> Void)?
}

// MARK: - String Helper

extension String {
    func lines() -> [String] {
        return components(separatedBy: .newlines)
    }
}
