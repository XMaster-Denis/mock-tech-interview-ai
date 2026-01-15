//
//  CodeEditorController.swift
//  XInterview2
//
//  Dual control controller for code editor (User + AI)
//

import Foundation
import AppKit
import Combine

@MainActor
class CodeEditorController: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAIThinking: Bool = false
    
    // MARK: - Components
    
    private let viewModel: CodeEditorViewModel
    
    // MARK: - Properties
    
    private var animationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(viewModel: CodeEditorViewModel) {
        self.viewModel = viewModel
        
        // Setup code change callback for real-time analysis
        viewModel.onCodeChanged = { [weak self] in
            self?.onUserCodeChanged()
        }
    }
    
    // MARK: - User Actions
    
    /// Enable user editing
    func enableUserEditing() {
        viewModel.isUserEditable = true
    }
    
    /// Disable user editing (e.g., while AI is editing)
    func disableUserEditing() {
        viewModel.isUserEditable = false
    }
    
    // MARK: - AI Actions (Full Control)
    
    /// Replace all code in the editor
    func replaceAllCode(_ code: String, animated: Bool = true) {
        showAIThinking()
        defer { hideAIThinking() }
        
        if animated {
            animateCodeChange {
                self.viewModel.replaceAllCode(code)
            }
        } else {
            viewModel.replaceAllCode(code)
        }
    }
    
    /// Insert code at cursor position
    func insertCodeAtCursor(_ code: String, animated: Bool = true) {
        showAIThinking()
        defer { hideAIThinking() }
        
        if animated {
            animateCodeChange {
                self.viewModel.insertCodeAtCursor(code)
            }
        } else {
            viewModel.insertCodeAtCursor(code)
        }
    }
    
    /// Insert code at specific line
    func insertCodeAtLine(_ line: Int, _ code: String, animated: Bool = true) {
        showAIThinking()
        defer { hideAIThinking() }
        
        if animated {
            animateCodeChange {
                self.viewModel.insertCodeAtLine(line, code)
            }
        } else {
            viewModel.insertCodeAtLine(line, code)
        }
    }
    
    /// Replace code in a specific range
    func replaceCodeInRange(_ range: NSRange, with text: String, animated: Bool = true) {
        showAIThinking()
        defer { hideAIThinking() }
        
        if animated {
            animateCodeChange {
                self.viewModel.replaceCodeInRange(range, with: text)
            }
        } else {
            viewModel.replaceCodeInRange(range, with: text)
        }
    }
    
    /// Select a specific range in the editor
    func selectRange(_ range: NSRange) {
        viewModel.selectRange(range)
    }
    
    /// Scroll to show a specific range
    func scrollToRange(_ range: NSRange) {
        viewModel.scrollToRange(range)
    }
    
    /// Scroll to show a specific line
    func scrollToLine(_ line: Int) {
        if let range = viewModel.rangeForLine(line) {
            scrollToRange(range)
        }
    }
    
    // MARK: - Feedback Actions
    
    /// Highlight errors in the editor
    func highlightErrors(_ errors: [CodeError]) {
        viewModel.highlightErrors(errors)
    }
    
    /// Highlight hints in the editor
    func highlightHints(_ ranges: [NSRange]) {
        viewModel.highlightHints(ranges)
    }
    
    /// Highlight a single line as a hint
    func highlightLine(_ line: Int) {
        if let range = viewModel.rangeForLine(line) {
            viewModel.highlightHints([range])
        }
    }
    
    /// Clear all highlights
    func clearHighlights() {
        viewModel.clearHighlights()
    }
    
    // MARK: - Visual Feedback
    
    /// Show AI thinking indicator
    func showAIThinking() {
        isAIThinking = true
    }
    
    /// Hide AI thinking indicator
    func hideAIThinking() {
        isAIThinking = false
    }
    
    /// Apply an AI action to the editor

    
    // MARK: - Helper Methods
    
    private func animateCodeChange(_ change: @escaping () -> Void) {
        animationTask?.cancel()
        animationTask = Task {
            // Slight fade out
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            
            // Apply change
            change()
            
            // Fade back in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }
    
    private func onUserCodeChanged() {
        // Clear highlights when user makes changes
        // This prevents stale error highlights
        clearHighlights()
    }
    
    // MARK: - Code Access
    
    var currentCode: String {
        viewModel.code
    }
    
    var selectedRange: NSRange {
        viewModel.selectedRange
    }
    
    var editorViewModel: CodeEditorViewModel {
        viewModel
    }
    
    func line(for range: NSRange) -> Int {
        viewModel.line(for: range)
    }
}

// MARK: - Private Extension for CodeEditorViewModel

private extension CodeEditorViewModel {
    func highlightCode() {
        // Trigger re-highlighting
        // This will update attributedCode
        // The view will pick it up via @Published
    }
}
