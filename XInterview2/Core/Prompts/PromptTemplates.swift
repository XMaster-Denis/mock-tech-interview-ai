//
//  PromptTemplates.swift
//  XInterview2
//
//  Centralized prompt templates for all AI interactions
//

import Foundation

/// Centralized prompt templates for all AI interactions
enum PromptTemplates {
    
    // MARK: - System Prompts
    
    enum System {
        /// Generate system prompt for hybrid interview mode
        static func hybridInterview(
            for topic: InterviewTopic,
            level: DeveloperLevel,
            language: Language,
            mode: InterviewMode,
            context: String = ""
        ) -> String {
            let modeInstructions = ModeInstructions.forMode(mode, language: language)
            let topicInstructions = topicInstructions(for: topic, language: language)
            let hintInstructions = HintInstructions.forLanguage(language: language)
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
            - spoken_text: Text to be spoken by TTS (string, required)
            - aicode: Code to display in editor (string, optional, only for code tasks)
            
            IMPORTANT: 
            - Never use markdown code blocks (triple backticks) in your response
            - Never include examples in your actual response
            - Return only raw JSON object
            - Keep all text extremely short and conversational
            """
        }
        
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
    }
    
    // MARK: - Whisper Prompts
    
    enum Whisper {
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
    
    // MARK: - Code Templates
    
    enum CodeTemplates {
        /// Get code template for a specific language with placeholders
        static func templateFor(language: CodeLanguageInterview) -> String {
            switch language {
            case .swift:
                return """
                // Swift code template
                // Use // YOUR CODE HERE for placeholders
                
                func exampleFunction() -> ReturnType {
                    // YOUR CODE HERE
                    return defaultValue // Replace this line
                }
                """
            case .python:
                return """
                # Python code template
                # Use # YOUR CODE HERE for placeholders
                
                def example_function():
                    # YOUR CODE HERE
                    return None  # Replace this line
                """
            }
        }
        
        /// Placeholder comment for user to write code
        static let placeholderComment = "// YOUR CODE HERE"
        
        /// Placeholder return value for Swift
        static let swiftPlaceholderReturn = "return 0 // Replace this line"
        
        /// Placeholder return value for Python
        static let pythonPlaceholderReturn = "return None  # Replace this line"
    }
    
    // MARK: - Mode Instructions
    
    enum ModeInstructions {
        /// Get instructions for a specific interview mode and language
        static func forMode(_ mode: InterviewMode, language: Language) -> String {
            switch mode {
            case .questionsOnly:
                return questionsOnly(language: language)
            case .codeTasks:
                return codeTasks(language: language)
            case .hybrid:
                return hybrid(language: language)
            }
        }
        
        private static func questionsOnly(language: Language) -> String {
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
        }
        
        private static func codeTasks(language: Language) -> String {
            switch language {
            case .english:
                return """
                ## Code Tasks Mode
                - Give short coding challenges (1 line max)
                - When presenting a task:
                  1. Provide aicode with code template that includes:
                     - Clear placeholder comments: `// YOUR CODE HERE`
                     - Partial code structure but NOT complete solution
                     - Function/method signature without implementation
                     - Return placeholder value (0, "", nil, etc.) that user should replace
                  2. Describe task in spoken_text (1-2 sentences max)
                
                Example of CORRECT template:
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                ```
                
                Example of INCORRECT template (DO NOT use):
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    return a + b // This is already correct!
                }
                ```
                
                IMPORTANT: Never provide complete solution code. The user must write the implementation themselves.
                """
            case .russian:
                return """
                ## Режим задач по коду
                - Давай короткие задачи по коду (максимум 1 строка)
                - При представлении задачи:
                  1. Предоставь aicode с шаблоном включая:
                     - Ясные комментарии-заполнители: `// YOUR CODE HERE`
                     - Частичную структуру кода, но НЕ полное решение
                     - Сигнатуру функции/метода без реализации
                     - Значение-заполнитель для возврата (0, "", nil и т.д.), которое пользователь должен заменить
                  2. Опиши задачу в spoken_text (максимум 1-2 предложения)
                
                Пример ПРАВИЛЬНОГО шаблона:
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                ```
                
                Пример НЕПРАВИЛЬНОГО шаблона (НЕ используй):
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    return a + b // Это уже правильное решение!
                }
                ```
                
                ВАЖНО: Никогда не предоставляй полное решение кода. Пользователь должен написать реализацию сам.
                """
            case .german:
                return """
                ## Code-Aufgaben Modus
                - Gib kurze Code-Herausforderungen (max 1 Zeile)
                - Bei Präsentation einer Aufgabe:
                  1. Stelle aicode mit Vorlage bereit, die enthält:
                     - Klare Platzhalter-Kommentare: `// YOUR CODE HERE`
                     - Teilweise Code-Struktur aber KEINE vollständige Lösung
                     - Funktions-/Methodensignatur ohne Implementierung
                     - Platzhalter-Rückgabewert (0, "", nil, etc.), den Benutzer ersetzen soll
                  2. Beschreibe Aufgabe in spoken_text (max 1-2 Sätze)
                
                Beispiel von KORREKTER Vorlage:
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                ```
                
                Beispiel von FALSCHER Vorlage (NICHT verwenden):
                ```swift
                func calculateSum(_ a: Int, _ b: Int) -> Int {
                    return a + b // Das ist bereits korrekt!
                }
                ```
                
                WICHTIG: Stelle niemals vollständigen Lösungscode bereit. Der Benutzer muss die Implementierung selbst schreiben.
                """
            }
        }
        
        private static func hybrid(language: Language) -> String {
            switch language {
            case .english:
                return """
                ## Hybrid Mode
                - Alternate between questions and code tasks
                - Start with a question to gauge understanding
                - Give code tasks (1-2 lines) when appropriate
                - When presenting a task:
                  1. Provide aicode with code template that includes:
                     - Clear placeholder comments: `// YOUR CODE HERE`
                     - Partial code structure but NOT complete solution
                     - Function/method signature without implementation
                     - Return placeholder value (0, "", nil, etc.) that user should replace
                  2. Describe task in spoken_text (1-2 sentences max)
                
                Example of CORRECT template:
                ```swift
                func greet(name: String) -> String {
                    // YOUR CODE HERE
                    return "" // Replace this line
                }
                ```
                
                Example of INCORRECT template (DO NOT use):
                ```swift
                func greet(name: String) -> String {
                    return "Hello, \\(name)!" // This is already correct!
                }
                ```
                
                IMPORTANT: Never provide complete solution code. The user must write the implementation themselves.
                """
            case .russian:
                return """
                ## Гибридный режим
                - Чередуй вопросы и задачи по коду
                - Начни с вопроса для оценки понимания
                - Давай задачи по коду (1-2 строки) когда уместно
                - При представлении задачи:
                  1. Предоставь aicode с шаблоном включая:
                     - Ясные комментарии-заполнители: `// YOUR CODE HERE`
                     - Частичную структуру кода, но НЕ полное решение
                     - Сигнатуру функции/метода без реализации
                     - Значение-заполнитель для возврата (0, "", nil и т.д.), которое пользователь должен заменить
                  2. Опиши задачу в spoken_text (максимум 1-2 предложения)
                
                Пример ПРАВИЛЬНОГО шаблона:
                ```swift
                func greet(name: String) -> String {
                    // YOUR CODE HERE
                    return "" // Replace this line
                }
                ```
                
                Пример НЕПРАВИЛЬНОГО шаблона (НЕ используй):
                ```swift
                func greet(name: String) -> String {
                    return "Hello, \\(name)!" // Это уже правильное решение!
                }
                ```
                
                ВАЖНО: Никогда не предоставляй полное решение кода. Пользователь должен написать реализацию сам.
                """
            case .german:
                return """
                ## Hybrid Modus
                - Wechsle zwischen Fragen und Code-Aufgaben
                - Beginne mit einer Frage zum Verständnis
                - Gib Code-Aufgaben (1-2 Zeilen) wenn angemessen
                - Bei Präsentation einer Aufgabe:
                  1. Stelle aicode mit Vorlage bereit, die enthält:
                     - Klare Platzhalter-Kommentare: `// YOUR CODE HERE`
                     - Teilweise Code-Struktur aber KEINE vollständige Lösung
                     - Funktions-/Methodensignatur ohne Implementierung
                     - Platzhalter-Rückgabewert (0, "", nil, etc.), den Benutzer ersetzen soll
                  2. Beschreibe Aufgabe in spoken_text (max 1-2 Sätze)
                
                Beispiel von KORREKTER Vorlage:
                ```swift
                func greet(name: String) -> String {
                    // YOUR CODE HERE
                    return "" // Replace this line
                }
                ```
                
                Beispiel von FALSCHER Vorlage (NICHT verwenden):
                ```swift
                func greet(name: String) -> String {
                    return "Hello, \\(name)!" // Das ist bereits korrekt!
                }
                ```
                
                WICHTIG: Stelle niemals vollständigen Lösungscode bereit. Der Benutzer muss die Implementierung selbst schreiben.
                """
            }
        }
    }
    
    // MARK: - Hint Instructions
    
    enum HintInstructions {
        /// Get hint detection instructions for a specific language
        static func forLanguage(language: Language) -> String {
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
    
    // MARK: - Code Analysis Prompts
    
    enum CodeAnalysis {
        /// Generate prompt for analyzing code errors
        static func analyzeErrors(
            code: String,
            topic: InterviewTopic,
            level: DeveloperLevel
        ) -> String {
            return """
            Analyze this Swift code for errors and issues.
            
            Topic: \(topic.title)
            Level: \(level.displayName)
            
            Code:
            ```
            \(code)
            ```
            
            Return JSON in this format:
            {
                "errors": [
                    {
                        "range": {"location": start_index, "length": length},
                        "message": "error message",
                        "severity": "error|warning",
                        "line": line_number
                    }
                ]
            }
            """
        }
    }
    
    // MARK: - Code Evaluation Prompts
    
    enum CodeEvaluation {
        /// Generate prompt for evaluating code submission
        static func evaluateCode(code: String, context: CodeContext) -> String {
            return """
            Evaluate this code submission.
            
            Current code:
            ```
            \(code)
            ```
            
            Return JSON in this format:
            {
                "is_correct": true|false,
                "feedback": "Brief feedback (1 sentence)",
                "suggestions": ["hint 1", "hint 2"],
                "severity": "info|warning|error",
                "issue_lines": [1, 2, 3]
            }
            """
        }
    }
}
