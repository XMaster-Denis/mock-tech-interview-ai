//
//  SyntaxHighlighterProtocol.swift
//  XInterview2
//
//  Protocol for language-agnostic syntax highlighting
//

import Foundation
import AppKit

/// Protocol for syntax highlighting different programming languages
protocol SyntaxHighlighterProtocol {
    /// The language this highlighter supports
    var language: CodeLanguage { get }
    
    /// Apply syntax highlighting to the given text
    /// - Parameters:
    ///   - text: The source code to highlight
    ///   - font: The base font to use
    ///   - theme: The color theme to apply
    /// - Returns: An attributed string with syntax highlighting applied
    func highlight(_ text: String, font: NSFont, theme: SyntaxTheme) -> NSAttributedString
    
    /// Extract syntax tokens from the given text
    /// - Parameter text: The source code to tokenize
    /// - Returns: Array of syntax tokens with their ranges and types
    func tokenize(_ text: String) -> [SyntaxToken]
}
