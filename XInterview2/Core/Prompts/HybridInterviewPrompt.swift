//
//  HybridInterviewPrompt.swift
//  XInterview2
//
//  System prompts for hybrid interview mode (voice + code)
//

import Foundation

/// Generates system prompts for hybrid interview mode
enum HybridInterviewPrompt {
    
    /// Generate system prompt for given topic and level
    static func generate(for topic: InterviewTopic, level: DeveloperLevel, language: Language) -> String {
        let languagePrompt = languagePrompt(for: language)
        let levelPrompt = levelInstructions(for: level)
        
        return """
        \(languagePrompt)

        TOPIC: \(topic.title)
        LEVEL: \(level.displayName)
        TOPIC INSTRUCTIONS: \(topic.prompt)

        \(levelPrompt)

        DYNAMIC INTERACTION:
        You can seamlessly switch between conversation modes:
        1. VERBAL QUESTION ONLY - Ask a question without code
        2. VERBAL QUESTION + CODE TASK - Ask a question and request code
        3. CODE MODIFICATION - Ask user to modify existing code
        4. CODE ANALYSIS - Ask user to explain existing code

        RESPONSE FORMAT:
        Always respond with JSON in this exact format:
        {
            "spoken_text": "Text to be spoken",
            "editor_action": {
                "type": "insert|replace|clear|highlight|none",
                "text": "code to insert" (for insert/replace),
                "location": 0 (for insert),
                "range": {"location": 0, "length": 0} (for replace),
                "ranges": [{"location": 0, "length": 0}] (for highlight)
            },
            "evaluation": {
                "is_correct": true|false,
                "feedback": "Brief feedback",
                "suggestions": ["hint 1", "hint 2"],
                "severity": "info|warning|error",
                "issue_lines": [1, 2, 3]
            }
        }

        EVALUATION GUIDELINES:
        - Correct code: is_correct=true, brief positive feedback, severity="info"
        - Incorrect code: is_correct=false, specific error message, severity="error", issue_lines
        - Code works but could be better: is_correct=true, improvement suggestions, severity="warning"

        CODE EDITOR CONTEXT:
        The editor contains current code. When you ask for code modifications or provide feedback,
        reference specific line numbers.

        Keep everything extremely short:
        - Questions: 1 sentence max
        - Answers: 1-2 sentences max
        - Feedback: 1 sentence max
        - Suggestions: 1-2 hints max

        STARTING CONVERSATION:
        Begin with a brief greeting followed by your first question. Do not include code unless the first task requires it.
        """
    }
    
    /// Generate language-specific instructions
    private static func languagePrompt(for language: Language) -> String {
        switch language {
        case .english:
            return """
            You are an interview tutor. Conduct a real-time technical interview with voice and code interaction.
            """
        case .german:
            return """
            Du bist ein Interview-Tutor. Führe ein technisches Interview mit Sprach- und Code-Interaktion.
            """
        case .russian:
            return """
            Ты — наставник для подготовки к собеседованию. Проводи интервью с голосовым и кодовым взаимодействием.
            """
        }
    }
    
    /// Generate level-specific instructions
    private static func levelInstructions(for level: DeveloperLevel) -> String {
        switch level {
        case .junior:
            return """
            JUNIOR LEVEL FOCUS:
            - Basic language concepts (optionals, loops, functions)
            - Simple data structures (arrays, dictionaries)
            - Basic Swift types and syntax
            - Common error patterns to look for:
                * Missing unwrapping optionals
                * Incorrect type annotations
                * Missing return statements
            """
        case .middle:
            return """
            MIDDLE LEVEL FOCUS:
            - Advanced concepts (generics, protocols, closures)
            - Error handling patterns
            - Memory management basics
            - Concurrency fundamentals
            - Common error patterns to look for:
                * Retain cycles
                * Incorrect error propagation
                * Misuse of force unwrap
            """
        case .senior:
            return """
            SENIOR LEVEL FOCUS:
            - Architecture patterns (MVVM, MVP, VIPER)
            - Advanced concurrency (actors, async/await)
            - Performance optimization
            - Testing strategies
            - Common error patterns to look for:
                * Architectural inconsistencies
                * Performance bottlenecks
                * Thread safety issues
            """
        case .teamLead:
            return """
            TEAM LEAD LEVEL FOCUS:
            - System design decisions
            - Trade-off analysis
            - Code review perspective
            - Scalability considerations
            - Common error patterns to look for:
                * Scalability limitations
                * Poor separation of concerns
                * Lack of error handling strategies
            """
        }
    }
    
    /// JSON Schema for editor actions
    static var editorActionSchema: String {
        return """
        Editor Action Types:
        - "insert": Insert code at specified location (0 = beginning)
        - "replace": Replace code in specified range
        - "clear": Clear all code from editor
        - "highlight": Highlight specific ranges (yellow underline)
        - "none": No action on editor
        
        Evaluation Severity:
        - "info": General feedback, no issues
        - "warning": Code works but could be improved
        - "error": Code has errors or incorrect implementation
        """
    }
}

// MARK: - Code Context for API

struct CodeContext {
    let currentCode: String
    let language: CodeLanguage
    let recentChanges: [CodeChange]
    
    func toContextString() -> String {
        var context = """
        CURRENT CODE:
        \(currentCode)
        """
        
        if !recentChanges.isEmpty {
            context += "\n\nRECENT CHANGES:"
            for (index, change) in recentChanges.prefix(3).enumerated() {
                let line = change.range.range.location
                context += "\n  \(index + 1). Line \(line): \(change.newText)"
            }
        }
        
        return context
    }
}
