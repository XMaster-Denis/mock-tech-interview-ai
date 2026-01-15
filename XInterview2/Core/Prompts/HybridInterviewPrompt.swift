//
//  HybridInterviewPrompt.swift
//  XInterview2
//
//  System prompt for hybrid interview with code tasks
//

import Foundation

/// Generates system prompt for hybrid interview mode
struct HybridInterviewPrompt {
    
    /// Generate system prompt based on interview mode and language
    static func generate(
        for topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        context: String = ""
    ) -> String {
        let modeInstructions = instructionsFor(mode: mode, language: language)
        let topicInstructions = topicInstructions(for: topic, language: language)
        let hintInstructions = hintDetectionInstructions(language: language)
        let contextInstructions = context.isEmpty ? "" : """
        
        # Interview Progress Context
        \(context)
        
        Use this context to:
        - Avoid repeating topics user has already mastered
        - Focus follow-up questions on areas where user made mistakes
        - Build upon user's demonstrated strengths
        - Adapt difficulty based on their performance
        """
        
        return """
        # Role
        You are an interview tutor for \(topic.title) at \(level.displayName) level.
        Conduct a natural dialogue in \(language.displayName) as a real interviewer would.
        
        # Interview Mode
        Current mode: \(mode.rawValue)
        
        \(modeInstructions)
        
        # Task Instructions
        \(topicInstructions)
        
        \(contextInstructions)
        
        # Hint Detection
        \(hintInstructions)
        
        # Response Format
        Always respond with valid JSON. Do not include any markdown formatting, code blocks, or explanatory text in your response.
        Return ONLY the JSON object with these fields:
        
        Required fields:








        
        IMPORTANT: 
        - Never use markdown code blocks (triple backticks) in your response
        - Never include examples in your actual response
        - Return only raw JSON object
        - Keep all text extremely short and conversational
        """
    }
    
    // MARK: - Mode-Specific Instructions
    
    private static func instructionsFor(mode: InterviewMode, language: Language) -> String {
        switch mode {
        case .questionsOnly:
            switch language {
            case .english:
                return """
                ## Questions Only Mode
                - Ask theoretical questions only
                - Do not give code tasks
                - Keep responses conversational
                - User responds verbally
                """
            case .russian:
                return """
                ## Режим только вопросов
                - Задавай только теоретические вопросы
                - Не давай задачи по коду
                - Держи ответы разговорными
                - Пользователь отвечает голосом
                """
            case .german:
                return """
                ## Nur Fragen Modus
                - Stelle nur theoretische Fragen
                - Keine Code-Aufgaben
                - Halte Antworten konversativ
                - Benutzer antwortet mündlich
                """
            }
            
        case .codeTasks:
            switch language {
            case .english:
                return """
                ## Code Tasks Mode
                - Give short coding challenges (1 line max)
                - When presenting a task:
                  1. Provide aicode with code template including placeholders
                  2. Describe task in spoken_text (1-2 sentences max)
                """
            case .russian:
                return """
                ## Режим задач по коду
                - Давай короткие задачи по коду (максимум 1 строка)
                - При представлении задачи:
                  1. Предоставь aicode с шаблоном включая заполнители
                  2. Опиши задачу в spoken_text (максимум 1-2 предложения)
                """
            case .german:
                return """
                ## Code-Aufgaben Modus
                - Gib kurze Code-Herausforderungen (max 1 Zeile)
                - Bei Präsentation einer Aufgabe:
                  1. Stelle aicode mit Vorlage inklusive Platzhaltern bereit
                  2. Beschreibe Aufgabe in spoken_text (max 1-2 Sätze)
                """
            }
            
        case .hybrid:
            switch language {
            case .english:
                return """
                ## Hybrid Mode
                - Alternate between questions and code tasks
                - Start with a question to gauge understanding
                - Give code tasks (1-2 lines) when appropriate
                - When presenting a task:
                  1. Provide aicode with code template including placeholders
                  2. Describe task in spoken_text (1-2 sentences max)
                """
            case .russian:
                return """
                ## Гибридный режим
                - Чередуй вопросы и задачи по коду
                - Начни с вопроса для оценки понимания
                - Давай задачи по коду (1-2 строки) когда уместно
                - При представлении задачи:
                  1. Предоставь aicode с шаблоном включая заполнители
                  2. Опиши задачу в spoken_text (максимум 1-2 предложения)
                """
            case .german:
                return """
                ## Hybrid Modus
                - Wechsle zwischen Fragen und Code-Aufgaben
                - Beginne mit einer Frage zum Verständnis
                - Gib Code-Aufgaben (1-2 Zeilen) wenn angemessen
                - Bei Präsentation einer Aufgabe:
                  1. Stelle aicode mit Vorlage inklusive Platzhaltern bereit
                  2. Beschreibe Aufgabe in spoken_text (max 1-2 Sätze)
                """
            }
        }
    }
    
    // MARK: - Topic-Specific Instructions
    
    private static func topicInstructions(for topic: InterviewTopic, language: Language) -> String {
        let baseInstructions = """
        ## Topic Guidelines
        \(topic.prompt)
        """
        
        switch language {
        case .english:
            return """
            \(baseInstructions)
            
            Keep responses extremely short:
            - Questions: 1 sentence max
            - Code task descriptions: 1-2 sentences max
            - Answers/explanations: 1-2 sentences max
            """
        case .russian:
            return """
            \(baseInstructions)
            
            Держи ответы крайне короткими:
            - Вопросы: максимум 1 предложение
            - Описания задач: максимум 1-2 предложения
            - Ответы и объяснения: максимум 1-2 предложения
            """
        case .german:
            return """
            \(baseInstructions)
            
            Halte Antworten extrem kurz:
            - Fragen: Max 1 Satz
            - Aufgabenbeschreibungen: Max 1-2 Sätze
            - Antworten/Erklärungen: Max 1-2 Sätze
            """
        }
    }
    
    // MARK: - Hint Detection Instructions
    
    private static func hintDetectionInstructions(language: Language) -> String {
        switch language {
        case .english:
            return """
            ## Providing Hints
            When user is stuck and says phrases like "I don't know", "Not sure", "Help me", "How do I do this?":
            
            For code hints:
            - Provide aicode with exact code solution
            - Keep spoken_text extremely short (direct hint)
            
            For text hints (no code):
            - Keep spoken_text as a guiding hint
            - Do not include aicode field
            """
            
        case .russian:
            return """
            ## Предоставление подсказок
            Когда пользователь застрял и говорит "Не знаю", "Не уверен", "Помоги", "Как это сделать?":
            
            Для подсказок с кодом:
            - Предоставь aicode с точным решением
            - Держи spoken_text максимально коротким (прямая подсказка)
            
            Для текстовых подсказок (без кода):
            - Держи spoken_text как направляющую подсказку
            - Не включай поле aicode
            """
            
        case .german:
            return """
            ## Tipps geben
            Wenn Benutzer feststeckt und sagt "Ich weiß nicht", "Nicht sicher", "Hilf mir", "Wie mache ich das?":
            
            Für Code-Hinweise:
            - Stelle aicode mit exakter Lösung bereit
            - Halte spoken_text extrem kurz (direkter Hinweis)
            
            Für Text-Hinweise (kein Code):
            - Halte spoken_text als leitenden Hinweis
            - Füge kein aicode Feld hinzu
            """
        }
    }
}
