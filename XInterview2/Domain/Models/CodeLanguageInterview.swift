//
//  CodeLanguageInterview.swift
//  XInterview2
//
//  Created by XMaster on 13.01.26.
//

import CodeEditLanguages


enum CodeLanguageInterview: String, Codable {
    case swift = "Swift"
    case python = "Python"
    
    var codeLanguageOfCodeEditSourceEditor: CodeLanguage {
        switch self {
        case .swift: return .swift
        case .python: return .python
            
        }
    }
    
    var displayName: String {
        self.rawValue
    }
}
