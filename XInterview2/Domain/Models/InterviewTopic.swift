//
//  InterviewTopic.swift
//  XInterview2
//
//  Interview topic with prompt guidance
//

import Foundation

struct InterviewTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var prompt: String
    var level: DeveloperLevel
    var codeLanguage: CodeLanguageInterview
    var interviewMode: InterviewMode
    
    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        level: DeveloperLevel = .junior,
        codeLanguage: CodeLanguageInterview = .swift,
        interviewMode: InterviewMode = .hybrid
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.level = level
        self.codeLanguage = codeLanguage
        self.interviewMode = interviewMode
    }
}
