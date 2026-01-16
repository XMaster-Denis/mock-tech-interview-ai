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
    
    var isCheckSolution: Bool {
        switch self {
        case .checkSolution:
            return true
        case .generateTask, .assistHelp:
            return false
        }
    }
    
    var isGenerateTask: Bool {
        switch self {
        case .generateTask:
            return true
        case .checkSolution, .assistHelp:
            return false
        }
    }
}
