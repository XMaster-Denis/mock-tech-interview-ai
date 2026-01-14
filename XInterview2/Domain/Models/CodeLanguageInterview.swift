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
    
    static var allCases: [CodeLanguageInterview] {
        return [.swift, .python]
    }
    
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
