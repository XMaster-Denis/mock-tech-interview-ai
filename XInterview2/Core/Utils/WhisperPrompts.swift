//
//  WhisperPrompts.swift
//  XInterview2
//
//  Technical prompts for Whisper API to preserve English terminology
//

import Foundation

enum WhisperPrompts {
    /// Prompt for English language (basic)
    static let english = "Technical interview context. Professional language."
    
    /// Prompt for Russian language with instructions to keep English terms
    static let russian = """
        Техническое интервью на русском языке с английской терминологией. 
        Сохраняй английские технические термины без перевода: 
        API, SDK, framework, algorithm, backend, frontend, database, 
        React, Swift, Kotlin, code, commit, repository, deployment, 
        server, client, endpoint, authentication, authorization, 
        token, session, cache, queue, thread, process, async, sync,
        JSON, XML, HTTP, HTTPS, REST, GraphQL, WebSocket, Docker,
        Kubernetes, CI/CD, Git, GitHub, GitLab, AWS, Azure, etc.
        """
    
    /// Prompt for German language with instructions to keep English terms
    static let german = """
        Technisches Interview auf Deutsch mit englischer Fachbegriffen.
        Behalte englische technische Begriffe ohne Übersetzung:
        API, SDK, framework, algorithm, backend, frontend, database,
        React, Swift, Kotlin, code, commit, repository, deployment,
        server, client, endpoint, authentication, authorization,
        token, session, cache, queue, thread, process, async, sync,
        JSON, XML, HTTP, HTTPS, REST, GraphQL, WebSocket, Docker,
        Kubernetes, CI/CD, Git, GitHub, GitLab, AWS, Azure, etc.
        """
    
    /// Get prompt for a specific language
    static func prompt(for language: Language) -> String {
        switch language {
        case .english:
            return english
        case .german:
            return german
        case .russian:
            return russian
        }
    }
}
