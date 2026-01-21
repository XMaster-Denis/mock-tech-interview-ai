//
//  CodeLanguageInterview.swift
//  XInterview2
//
//  Created by XMaster on 13.01.26.
//

import Foundation
import CodeEditLanguages


enum CodeLanguageInterview: String, Codable, CaseIterable {
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case java = "Java"
    case cpp = "C++"
    case csharp = "C#"
    case go = "Go"
    case php = "PHP"
    case ruby = "Ruby"
    case kotlin = "Kotlin"
    case rust = "Rust"
    
    static var allCases: [CodeLanguageInterview] {
        return [
            .swift,
            .python,
            .javascript,
            .typescript,
            .java,
            .cpp,
            .csharp,
            .go,
            .php,
            .ruby,
            .kotlin,
            .rust
        ]
    }
    
    var codeLanguageOfCodeEditSourceEditor: CodeLanguage {
        switch self {
        case .swift: return .swift
        case .python: return .python
        case .javascript: return .javascript
        case .typescript: return .typescript
        case .java: return .java
        case .cpp: return .cpp
        case .csharp: return .cSharp
        case .go: return .go
        case .php: return .php
        case .ruby: return .ruby
        case .kotlin: return .kotlin
        case .rust: return .rust
            
        }
    }
    
    var displayName: String {
        self.rawValue
    }
}
