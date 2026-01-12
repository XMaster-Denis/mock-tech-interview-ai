//
//  SwiftSyntaxHighlighter.swift
//  XInterview2
//
//  Swift-specific syntax highlighting implementation
//

import Foundation
import AppKit

/// Syntax highlighter for Swift programming language
struct SwiftSyntaxHighlighter: SyntaxHighlighterProtocol {
    let language: CodeLanguage = .swift
    
    // MARK: - Swift Keywords
    
    private static let keywords: Set<String> = [
        // Declarations
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "precedencegroup", "private", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var",
        
        // Statements
        "break", "case", "catch", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch",
        "throw", "where", "while",
        
        // Expressions & Types
        "Any", "as", "false", "is", "nil", "self", "Self", "super",
        "true", "try", "catch", "throws",
        
        // Availability & Attributes
        "#available", "#colorLiteral", "#column", "#dsohandle", "#else", "#elseif",
        "#endif", "#error", "#file", "#fileID", "#fileLiteral", "#filePath",
        "#function", "#if", "#imageLiteral", "#keyPath", "#line", "#selector",
        "#sourceLocation", "#warning",
        
        // Common types
        "Int", "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary",
        "Set", "Optional", "Void", "Never", "AnyObject", "AnyClass",
        
        // SwiftUI types (common)
        "View", "State", "Binding", "ObservedObject", "StateObject", "EnvironmentObject",
        "Published", "Environment", "FetchRequest", "ScenePhase", "Namespace"
    ]
    
    // MARK: - Syntax Rules
    
    private let rules: [SyntaxRule] = {
        var rules: [SyntaxRule] = []
        
        do {
            // String literals
            try rules.append(SyntaxRule(type: .string, pattern: #""(?:[^"\\]|\\.)*""#))
            try rules.append(SyntaxRule(type: .string, pattern: #"'(?:[^'\\]|\\.)*'"#))
            
            // Single-line comments
            try rules.append(SyntaxRule(type: .comment, pattern: #"//.*$"#))
            
            // Multi-line comments
            try rules.append(SyntaxRule(type: .comment, pattern: #"/\*[\s\S]*?\*/"#))
            
            // Numbers (integer, float, hex)
            try rules.append(SyntaxRule(type: .number, pattern: #"\b\d+(\.\d+)?([eE][+-]?\d+)?\b"#))
            try rules.append(SyntaxRule(type: .number, pattern: #"\b0x[0-9a-fA-F]+\b"#))
            
            // Attributes (e.g., @objc, @escaping)
            try rules.append(SyntaxRule(type: .attribute, pattern: #"@\w+"#))
            
            // Keywords - basic Swift keywords (compiler directives handled separately)
            let keywordPattern = #"\b(associatedtype|as|break|case|catch|class|continue|default|defer|deinit|do|else|enum|extension|false|for|func|guard|if|in|inout|internal|is|let|nil|open|precedencegroup|private|protocol|public|rethrows|repeat|return|self|Self|static|struct|subscript|super|switch|throw|throws|true|try|typealias|var|where|while)\b"#
            try rules.append(SyntaxRule(type: .keyword, pattern: keywordPattern))
            
            // Types (capitalized words after : or as)
            try rules.append(SyntaxRule(type: .type, pattern: #":\s*([A-Z][a-zA-Z0-9_]*)"#))
            try rules.append(SyntaxRule(type: .type, pattern: #"as\s+([A-Z][a-zA-Z0-9_]*)"#))
            try rules.append(SyntaxRule(type: .type, pattern: #"->\s*([A-Z][a-zA-Z0-9_]*)"#))
            
            // Functions
            try rules.append(SyntaxRule(type: .function, pattern: #"\b[a-z_][a-zA-Z0-9_]*\s*\("#))
            
            // Variables
            try rules.append(SyntaxRule(type: .variable, pattern: #"(var|let)\s+([a-z_][a-zA-Z0-9_]*)"#))
            
        } catch {
            Logger.error("Failed to create syntax rules", error: error)
        }
        
        return rules
    }()
    
    // MARK: - SyntaxHighlighterProtocol
    
    func highlight(_ text: String, font: NSFont, theme: SyntaxTheme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Apply default color to entire text
        attributedString.addAttributes(
            theme.attributes(for: .none, font: font),
            range: fullRange
        )
        
        // Apply syntax highlighting
        let tokens = tokenize(text)
        
        for token in tokens {
            let intersectionRange = NSIntersectionRange(fullRange, token.range)
            if intersectionRange.length > 0 {
                attributedString.addAttributes(
                    theme.attributes(for: token.type, font: font),
                    range: intersectionRange
                )
            }
        }
        
        return attributedString
    }
    
    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let textLength = text.utf16.count
        
        for rule in rules {
            let matches = rule.pattern.matches(in: text, range: NSRange(location: 0, length: textLength))
            
            for match in matches {
                let token = SyntaxToken(range: match.range, type: rule.type)
                tokens.append(token)
            }
        }
        
        // Sort tokens by location and remove overlapping ones
        tokens.sort { $0.range.location < $1.range.location }
        tokens = removeOverlappingTokens(tokens)
        
        return tokens
    }
    
    // MARK: - Helper Methods
    
    private func removeOverlappingTokens(_ tokens: [SyntaxToken]) -> [SyntaxToken] {
        var filtered: [SyntaxToken] = []
        var lastEnd = 0
        
        for token in tokens {
            if token.range.location >= lastEnd {
                filtered.append(token)
                lastEnd = token.range.location + token.range.length
            } else if token.range.location + token.range.length > lastEnd {
                // Partial overlap - trim the token
                let overlapStart = lastEnd - token.range.location
                let trimmedRange = NSRange(
                    location: lastEnd,
                    length: token.range.length - overlapStart
                )
                if trimmedRange.length > 0 {
                    filtered.append(SyntaxToken(range: trimmedRange, type: token.type))
                    lastEnd = trimmedRange.location + trimmedRange.length
                }
            }
        }
        
        return filtered
    }
}
