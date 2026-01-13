//
//  CodeLanguage.swift
//  XInterview2
//
//  Supported programming languages for code editor
//

import Foundation
import CodeEditLanguages

/// Supported programming languages for syntax highlighting
enum CodeLanguage: String, Codable, CaseIterable, Identifiable {
    case swift
    case python
    case javascript
    case kotlin
    case rust
    case go
    case typescript
    case java
    
    /// Unique identifier
    var id: String { rawValue }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .swift:
            return "Swift"
        case .python:
            return "Python"
        case .javascript:
            return "JavaScript"
        case .kotlin:
            return "Kotlin"
        case .rust:
            return "Rust"
        case .go:
            return "Go"
        case .typescript:
            return "TypeScript"
        case .java:
            return "Java"
        }
    }
    
    /// File extension for this language
    var fileExtension: String {
        switch self {
        case .swift:
            return "swift"
        case .python:
            return "py"
        case .javascript:
            return "js"
        case .kotlin:
            return "kt"
        case .rust:
            return "rs"
        case .go:
            return "go"
        case .typescript:
            return "ts"
        case .java:
            return "java"
        }
    }
    
    /// Comment line prefix
    var commentPrefix: String {
        switch self {
        case .swift, .javascript, .kotlin, .rust, .go, .typescript, .java:
            return "//"
        case .python:
            return "#"
        }
    }
    
    /// Convert to CodeEditSourceEditor language
    var sourceCodeLanguage: CodeLanguage.CodeEditLanguage {
        switch self {
        case .swift:
            return .swift
        case .python:
            return .python
        case .javascript:
            return .javascript
        case .kotlin:
            return .kotlin
        case .rust:
            return .rust
        case .go:
            return .go
        case .typescript:
            return .typescript
        case .java:
            return .java
        }
    }
}

// MARK: - Type Alias for CodeEdit Language

extension CodeLanguage {
    /// CodeEditSourceEditor language type
    typealias CodeEditLanguage = CodeEditLanguages.CodeLanguage
}
