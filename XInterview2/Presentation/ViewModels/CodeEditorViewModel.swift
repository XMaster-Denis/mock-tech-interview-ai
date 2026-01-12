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
    @Published var language: CodeLanguage = .swift
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
    
    private var syntaxHighlighter: SyntaxHighlighterProtocol
    private let theme: SyntaxTheme = .xcodeDark
    private let font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    
    // MARK: - Properties
    
    private var debounceTask: Task<Void, Never>?
    private var previousCode: String = ""
    
    // MARK: - Initialization
    
    init(language: CodeLanguage = .swift) {
        self.language = language
        self.syntaxHighlighter = SyntaxHighlighterFactory.highlighter(for: language)
    }
    
    // MARK: - Code Management
    
    func setCode(_ newCode: String) {
        code = newCode
        highlightCode()
        previousCode = newCode
    }
    
    func updateLanguage(_ newLanguage: CodeLanguage) {
        language = newLanguage
        syntaxHighlighter = SyntaxHighlighterFactory.highlighter(for: newLanguage)
        highlightCode()
    }
    
    // MARK: - User Actions
    
    func userDidChange(_ newCode: String) {
        guard isUserEditable && !isAIEditing else { return }
        
        code = newCode
        scheduleHighlight()
        updateCursorPosition(in: newCode)
        
        // Notify of changes (callback will be set by parent)
        onCodeChanged?()
    }
    
    // MARK: - AI Actions (Full Control)
    
    func replaceAllCode(_ newCode: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        code = newCode
        highlightCode()
    }
    
    func insertCodeAtCursor(_ text: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        let insertLocation = selectedRange.location
        code.insert(contentsOf: text, at: code.index(code.startIndex, offsetBy: insertLocation))
        highlightCode()
        
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
        highlightCode()
    }
    
    func replaceCodeInRange(_ range: NSRange, with text: String) {
        isAIEditing = true
        defer { isAIEditing = false }
        
        guard let stringRange = Range(range, in: code) else { return }
        
        code.removeSubrange(stringRange)
        code.insert(contentsOf: text, at: code.index(code.startIndex, offsetBy: range.location))
        highlightCode()
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
    
    private func scheduleHighlight() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            if !Task.isCancelled {
                highlightCode()
            }
        }
    }
    
    private func highlightCode() {
        let highlighted = syntaxHighlighter.highlight(code, font: font, theme: theme)
        attributedCode = highlighted
    }
    
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
