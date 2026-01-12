//
//  SyntaxHighlighterFactory.swift
//  XInterview2
//
//  Factory for creating syntax highlighters
//

import Foundation
import AppKit

/// Factory for creating appropriate syntax highlighters for each language
struct SyntaxHighlighterFactory {
    
    /// Creates a syntax highlighter for the specified language
    /// - Parameter language: The programming language
    /// - Returns: A syntax highlighter instance
    static func highlighter(for language: CodeLanguage) -> SyntaxHighlighterProtocol {
        switch language {
        case .swift:
            return SwiftSyntaxHighlighter()
        case .python:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .python)
        case .javascript:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .javascript)
        case .kotlin:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .kotlin)
        case .rust:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .rust)
        case .go:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .go)
        case .typescript:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .typescript)
        case .java:
            // Placeholder for future implementation
            return PlaceholderSyntaxHighlighter(language: .java)
        }
    }
}

// MARK: - Placeholder Syntax Highlighter

/// Placeholder syntax highlighter for languages not yet implemented
struct PlaceholderSyntaxHighlighter: SyntaxHighlighterProtocol {
    let language: CodeLanguage
    
    func highlight(_ text: String, font: NSFont, theme: SyntaxTheme) -> NSAttributedString {
        // Return plain text with default color
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        attributedString.addAttributes(
            theme.attributes(for: .none, font: font),
            range: fullRange
        )
        return attributedString
    }
    
    func tokenize(_ text: String) -> [SyntaxToken] {
        return []
    }
}
