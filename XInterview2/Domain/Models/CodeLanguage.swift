//
//  CodeLanguage.swift
//  XInterview2
//
//  Supported programming languages for code editor
//

import Foundation

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
}
