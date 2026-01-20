//
//  LLMMode.swift
//  XInterview2
//
//  Separate LLM modes for code task flows
//

import Foundation

enum LLMMode {
    case checkSolution
    case generateTask
    case assistHelp(HelpMode)
    case languageCoach
    
    var isCheckSolution: Bool {
        switch self {
        case .checkSolution:
            return true
        case .generateTask, .assistHelp, .languageCoach:
            return false
        }
    }
    
    var isGenerateTask: Bool {
        switch self {
        case .generateTask:
            return true
        case .checkSolution, .assistHelp, .languageCoach:
            return false
        }
    }
}
