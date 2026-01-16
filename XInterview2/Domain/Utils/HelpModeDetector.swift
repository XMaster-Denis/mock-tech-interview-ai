//
//  HelpModeDetector.swift
//  XInterview2
//
//  Simple keyword-based help mode detection
//

import Foundation

enum HelpModeDetector {
    static func detectHelpMode(_ text: String, language: Language) -> HelpMode? {
        let lowercasedText = text.lowercased()
        
        switch language {
        case .english:
            let fullSolutionPhrases = [
                "i can't do it",
                "i dont know how",
                "i don't know how",
                "give me the full solution",
                "write it for me",
                "i give up",
                "do it for me",
                "give me the code"
            ]
            let hintPhrases = [
                "hint",
                "help",
                "how do i do this",
                "i don't know"
            ]
            if fullSolutionPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .fullSolution
            }
            if hintPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .hintOnly
            }
        case .russian:
            let fullSolutionPhrases = [
                "я не умею",
                "не получается",
                "сделай пожалуйста",
                "дай готовый код",
                "можешь написать полностью",
                "я сдаюсь",
                "сделай за меня",
                "напиши полностью"
            ]
            let hintPhrases = [
                "подскажи",
                "помоги",
                "не знаю",
                "как сделать",
                "подсказка"
            ]
            if fullSolutionPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .fullSolution
            }
            if hintPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .hintOnly
            }
        case .german:
            let fullSolutionPhrases = [
                "ich kann das nicht",
                "ich weiss nicht wie",
                "ich weiß nicht wie",
                "gib mir die volle loesung",
                "schreib es fuer mich",
                "ich gebe auf",
                "mach es fuer mich"
            ]
            let hintPhrases = [
                "hilfe",
                "hinweis",
                "wie mache ich das",
                "ich weiss nicht",
                "ich weiß nicht"
            ]
            if fullSolutionPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .fullSolution
            }
            if hintPhrases.contains(where: { lowercasedText.contains($0) }) {
                return .hintOnly
            }
        }
        
        return nil
    }
}
