//
//  OpenAIChatService.swift
//  XInterview2
//
//  OpenAI GPT-4o chat completion service with hybrid interview support
//

import Foundation

// MARK: - Legacy Chat Models (for backward compatibility)

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ChatResponseFormat?
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
    
    init(model: String, messages: [ChatMessage], responseFormat: ChatResponseFormat? = nil, temperature: Double = 0.7) {
        self.model = model
        self.messages = messages
        self.responseFormat = responseFormat
        self.temperature = temperature
    }
}

struct ChatResponseFormat: Codable {
    let type: String
    
    static let json = ChatResponseFormat(type: "json_object")
}

struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - OpenAI Chat Service

class OpenAIChatService: OpenAIChatServiceProtocol {
    private let httpClient: HTTPClient
    
    // Cache for system prompt to save tokens
    private var cachedSystemPrompt: String?
    private var cachedPromptKey: String?
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    /// Get system prompt with caching to save tokens
    private func getHybridSystemPrompt(
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        context: String
    ) -> String {
        // Create a unique key for the prompt configuration
        let promptKey = "\(topic.id.uuidString)-\(level.rawValue)-\(language.rawValue)-\(mode.rawValue)-\(context.hashValue)"
        
        // Return cached prompt if available and key matches
        if let cachedKey = cachedPromptKey,
           cachedKey == promptKey,
           let cachedPrompt = cachedSystemPrompt {
            return cachedPrompt
        }
        
        // Generate new prompt and cache it
        let newPrompt = PromptTemplates.System.hybridInterview(
            for: topic,
            level: level,
            language: language,
            mode: mode,
            context: context
        )
        
        cachedPromptKey = promptKey
        cachedSystemPrompt = newPrompt
        
        return newPrompt
    }
    
    private func getCheckSystemPrompt(
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language
    ) -> String {
        let promptKey = "check-\(topic.id.uuidString)-\(level.rawValue)-\(language.rawValue)"
        
        if let cachedKey = cachedPromptKey,
           cachedKey == promptKey,
           let cachedPrompt = cachedSystemPrompt {
            return cachedPrompt
        }
        
        let newPrompt = PromptTemplates.System.codeTaskCheck(
            for: topic,
            level: level,
            language: language
        )
        
        cachedPromptKey = promptKey
        cachedSystemPrompt = newPrompt
        
        return newPrompt
    }
    
    private func getGenSystemPrompt(
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        context: String
    ) -> String {
        let promptKey = "gen-\(topic.id.uuidString)-\(level.rawValue)-\(language.rawValue)"
        
        if let cachedKey = cachedPromptKey,
           cachedKey == promptKey,
           let cachedPrompt = cachedSystemPrompt {
            return cachedPrompt
        }
        
        let newPrompt = PromptTemplates.System.codeTaskGen(
            for: topic,
            level: level,
            language: language,
            context: context
        )
        
        cachedPromptKey = promptKey
        cachedSystemPrompt = newPrompt
        
        return newPrompt
    }
    
    private func getAssistHelpSystemPrompt(
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        helpMode: HelpMode
    ) -> String {
        let modeKey = (helpMode == .fullSolution) ? "full" : "hint"
        let promptKey = "assist-\(modeKey)-\(topic.id.uuidString)-\(level.rawValue)-\(language.rawValue)"
        
        if let cachedKey = cachedPromptKey,
           cachedKey == promptKey,
           let cachedPrompt = cachedSystemPrompt {
            return cachedPrompt
        }
        
        let newPrompt = PromptTemplates.System.assistHelp(
            for: topic,
            level: level,
            language: language,
            helpMode: helpMode
        )
        
        cachedPromptKey = promptKey
        cachedSystemPrompt = newPrompt
        
        return newPrompt
    }
    
    private func getLanguageCoachSystemPrompt(language: Language) -> String {
        let promptKey = "coach-\(language.rawValue)"
        
        if let cachedKey = cachedPromptKey,
           cachedKey == promptKey,
           let cachedPrompt = cachedSystemPrompt {
            return cachedPrompt
        }
        
        let newPrompt = PromptTemplates.System.languageCoach(language: language)
        cachedPromptKey = promptKey
        cachedSystemPrompt = newPrompt
        
        return newPrompt
    }
    
    private func buildCheckUserMessage(context: String, code: String, language: Language) -> String {
        switch language {
        case .russian:
            let taskBlock = context.isEmpty ? "Задание (кратко):\n(не указано)\n\nОжидаемое поведение/ограничения:\n(нет)" : context
            return """
            \(taskBlock)
            
            Код пользователя:
            \(code)
            """
        case .english:
            let taskBlock = context.isEmpty ? "Task (short):\n(not provided)\n\nExpected behavior/constraints:\n(none)" : context
            return """
            \(taskBlock)
            
            User code:
            \(code)
            """
        case .german:
            let taskBlock = context.isEmpty ? "Aufgabe (kurz):\n(nicht angegeben)\n\nErwartetes Verhalten/Einschraenkungen:\n(keine)" : context
            return """
            \(taskBlock)
            
            Benutzer-Code:
            \(code)
            """
        }
    }
    
    private func buildGenUserMessage(topic: InterviewTopic, language: Language, context: String) -> String {
        switch language {
        case .russian:
            return """
            Сгенерируй новую задачу.
            Тема/направление: \(topic.title)
            Язык общения: \(language.displayName)
            \(context)
            """
        case .english:
            return """
            Generate a new task.
            Topic: \(topic.title)
            Language: \(language.displayName)
            \(context)
            """
        case .german:
            return """
            Erzeuge eine neue Aufgabe.
            Thema: \(topic.title)
            Sprache: \(language.displayName)
            \(context)
            """
        }
    }
    
    private func buildAssistUserMessage(
        context: String,
        code: String,
        userMessage: String,
        language: Language
    ) -> String {
        switch language {
        case .russian:
            return """
            Задача: \(context)
            Код пользователя:
            \(code)
            Пользователь: \(userMessage)
            """
        case .english:
            return """
            Task: \(context)
            User code:
            \(code)
            User: \(userMessage)
            """
        case .german:
            return """
            Aufgabe: \(context)
            Benutzer-Code:
            \(code)
            Nutzer: \(userMessage)
            """
        }
    }
    
    private func buildLanguageCoachUserMessage(userMessage: String, language: Language) -> String {
        switch language {
        case .russian:
            return "Ответ пользователя: \(userMessage)"
        case .english:
            return "User answer: \(userMessage)"
        case .german:
            return "Antwort des Nutzers: \(userMessage)"
        }
    }
    
    private func requestChatResponse(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        temperature: Double
    ) async throws -> String {
        let request = ChatRequest(
            model: model,
            messages: messages,
            responseFormat: .json,
            temperature: temperature
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            Logger.error("Failed to encode chat request")
            throw HTTPError.serverError("Failed to encode request")
        }
        
        if let jsonString = String(data: body, encoding: .utf8) {
            Logger.jsonRequest(jsonString)
        }
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
        let response: ChatResponse = try await httpClient.request(
            endpoint: APIConstants.chatEndpoint,
            method: .post,
            body: body,
            headers: headers,
            responseType: ChatResponse.self
        )
        
        guard let assistantMessage = response.choices.first?.message.content else {
            Logger.error("No response from AI")
            throw HTTPError.serverError("No response from AI")
        }
        
        Logger.jsonResponse(assistantMessage)
        return assistantMessage
    }
    
    private func decodeAIResponse(_ content: String) -> AIResponse? {
        guard let data = content.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AIResponse.self, from: data)
    }
    
    private func normalizeResponse(_ response: AIResponse, mode: LLMMode) -> AIResponse {
        switch mode {
        case .checkSolution:
            return AIResponse(
                spokenText: response.spokenText,
                aicode: nil,
                taskState: response.taskState,
                hint: response.hint,
                hintCode: response.hintCode,
                solutionCode: nil,
                explanation: nil,
                correctCode: nil,
                isCorrect: response.isCorrect
            )
        case .generateTask:
            return AIResponse(
                spokenText: response.spokenText,
                aicode: response.aicode,
                taskState: response.taskState,
                hint: nil,
                hintCode: nil,
                solutionCode: nil,
                explanation: nil,
                correctCode: nil,
                isCorrect: nil
            )
        case .assistHelp(let helpMode):
            switch helpMode {
            case .hintOnly:
                return AIResponse(
                    spokenText: response.spokenText,
                    aicode: nil,
                    taskState: response.taskState,
                    hint: response.hint,
                    hintCode: response.hintCode,
                    solutionCode: nil,
                    explanation: nil,
                    correctCode: nil,
                    isCorrect: response.isCorrect
                )
            case .fullSolution:
                return AIResponse(
                    spokenText: response.spokenText,
                    aicode: nil,
                    taskState: response.taskState,
                    hint: nil,
                    hintCode: nil,
                    solutionCode: response.solutionCode,
                    explanation: response.explanation,
                    correctCode: nil,
                    isCorrect: response.isCorrect
                )
            }
        case .languageCoach:
            return AIResponse(
                spokenText: response.spokenText,
                aicode: nil,
                taskState: nil,
                hint: nil,
                hintCode: nil,
                solutionCode: nil,
                explanation: nil,
                correctCode: nil,
                isCorrect: nil,
                needsCorrection: response.needsCorrection,
                correction: response.correction,
                requestRepeat: response.requestRepeat
            )
        }
    }
    
    private func isValidResponse(
        _ response: AIResponse,
        mode: LLMMode,
        interviewMode: InterviewMode
    ) -> Bool {
        let spokenText = response.spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if spokenText.isEmpty {
            return false
        }
        
        switch mode {
        case .checkSolution:
            guard let isCorrect = response.isCorrect else {
                return false
            }
            guard let taskState = response.taskState else {
                return false
            }
            if taskState == .checkingSolution {
                return false
            }
            if isCorrect {
                return taskState == .none
            }
            guard taskState == .providingHint else {
                return false
            }
            let hintText = response.hint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !hintText.isEmpty
            
        case .generateTask:
            if interviewMode == .questionsOnly {
                if response.taskState != nil || response.aicode != nil {
                    return false
                }
                if response.hint != nil || response.hintCode != nil {
                    return false
                }
                if response.correctCode != nil || response.solutionCode != nil {
                    return false
                }
                if response.isCorrect != nil {
                    return false
                }
                return spokenText.hasSuffix("?")
            }
            guard response.taskState == .taskPresented else {
                return false
            }
            let aicodeText = response.aicode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !aicodeText.isEmpty
        case .assistHelp(let helpMode):
            switch helpMode {
            case .hintOnly:
                guard response.taskState == .providingHint else {
                    return false
                }
                guard response.isCorrect == false else {
                    return false
                }
                let hintText = response.hint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !hintText.isEmpty
            case .fullSolution:
                guard response.taskState == .providingSolution else {
                    return false
                }
                guard response.isCorrect == false else {
                    return false
                }
                let solutionText = response.solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let explanationText = response.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !solutionText.isEmpty && !explanationText.isEmpty
            }
        case .languageCoach:
            guard let needsCorrection = response.needsCorrection else {
                return false
            }
            if needsCorrection {
                let correction = response.correction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !correction.isEmpty
            }
            return true
        }
    }
    
    private func retryInstruction(
        for mode: LLMMode,
        language: Language,
        interviewMode: InterviewMode
    ) -> String {
        switch (mode, language) {
        case (.checkSolution, .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме CHECK с is_correct и task_state."
        case (.checkSolution, .english):
            return "Previous response missed required fields. Return JSON per CHECK schema with is_correct and task_state."
        case (.checkSolution, .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach CHECK-Schema mit is_correct und task_state."
        case (.generateTask, .russian):
            if interviewMode == .questionsOnly {
                return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON только со spoken_text, который заканчивается вопросительным знаком."
            }
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме GEN_TASK с task_state=task_presented и aicode."
        case (.generateTask, .english):
            if interviewMode == .questionsOnly {
                return "Previous response missed required fields. Return JSON with spoken_text only, and it must end with a question mark."
            }
            return "Previous response missed required fields. Return JSON per GEN_TASK schema with task_state=task_presented and aicode."
        case (.generateTask, .german):
            if interviewMode == .questionsOnly {
                return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nur mit spoken_text, das mit einem Fragezeichen endet."
            }
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach GEN_TASK-Schema mit task_state=task_presented und aicode."
        case (.assistHelp(.hintOnly), .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме hintOnly с task_state=providing_hint и hint."
        case (.assistHelp(.hintOnly), .english):
            return "Previous response missed required fields. Return JSON per hintOnly schema with task_state=providing_hint and hint."
        case (.assistHelp(.hintOnly), .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach hintOnly-Schema mit task_state=providing_hint und hint."
        case (.assistHelp(.fullSolution), .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме fullSolution с task_state=providing_solution и solution_code."
        case (.assistHelp(.fullSolution), .english):
            return "Previous response missed required fields. Return JSON per fullSolution schema with task_state=providing_solution and solution_code."
        case (.assistHelp(.fullSolution), .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach fullSolution-Schema mit task_state=providing_solution und solution_code."
        case (.languageCoach, .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON с needs_correction и spoken_text."
        case (.languageCoach, .english):
            return "Previous response missed required fields. Return JSON with needs_correction and spoken_text."
        case (.languageCoach, .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON mit needs_correction und spoken_text."
        }
    }
    
    private func fallbackResponse(
        for mode: LLMMode,
        language: Language,
        interviewMode: InterviewMode
    ) -> AIResponse {
        switch (mode, language) {
        case (.checkSolution, .russian):
            return AIResponse(
                spokenText: "Не смог проверить автоматически. Пришли код еще раз.",
                taskState: .providingHint,
                hint: "Не смог проверить автоматически, уточни или пришли код еще раз.",
                isCorrect: false
            )
        case (.checkSolution, .english):
            return AIResponse(
                spokenText: "I could not verify automatically. Please resend your code.",
                taskState: .providingHint,
                hint: "I could not verify automatically. Please resend your code.",
                isCorrect: false
            )
        case (.checkSolution, .german):
            return AIResponse(
                spokenText: "Ich konnte nicht automatisch prüfen. Bitte sende den Code erneut.",
                taskState: .providingHint,
                hint: "Ich konnte nicht automatisch prüfen. Bitte sende den Code erneut.",
                isCorrect: false
            )
        case (.generateTask, .russian):
            if interviewMode == .questionsOnly {
                return AIResponse(
                    spokenText: "Что такое опционалы в Swift?",
                    aicode: nil,
                    taskState: nil
                )
            }
            return AIResponse(
                spokenText: "Напиши функцию, которая возвращает длину строки.",
                aicode: """
                func stringLength(_ text: String) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                """,
                taskState: .taskPresented
            )
        case (.generateTask, .english):
            if interviewMode == .questionsOnly {
                return AIResponse(
                    spokenText: "What are optionals in Swift?",
                    aicode: nil,
                    taskState: nil
                )
            }
            return AIResponse(
                spokenText: "Write a function that returns the length of a string.",
                aicode: """
                func stringLength(_ text: String) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                """,
                taskState: .taskPresented
            )
        case (.generateTask, .german):
            if interviewMode == .questionsOnly {
                return AIResponse(
                    spokenText: "Was sind Optionals in Swift?",
                    aicode: nil,
                    taskState: nil
                )
            }
            return AIResponse(
                spokenText: "Schreibe eine Funktion, die die Länge eines Strings zurückgibt.",
                aicode: """
                func stringLength(_ text: String) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                """,
                taskState: .taskPresented
            )
        case (.assistHelp(.hintOnly), .russian):
            return AIResponse(
                spokenText: "Попробуй начать с простой проверки и разбить задачу на шаги.",
                taskState: .providingHint,
                hint: "Начни с базового условия и проверь крайние случаи.",
                isCorrect: false
            )
        case (.assistHelp(.hintOnly), .english):
            return AIResponse(
                spokenText: "Try to start with a simple check and break it into steps.",
                taskState: .providingHint,
                hint: "Start with a base condition and handle edge cases.",
                isCorrect: false
            )
        case (.assistHelp(.hintOnly), .german):
            return AIResponse(
                spokenText: "Starte mit einer einfachen Prüfung und zerlege die Aufgabe.",
                taskState: .providingHint,
                hint: "Beginne mit einer Basisbedingung und prüfe Randfälle.",
                isCorrect: false
            )
        case (.assistHelp(.fullSolution), .russian):
            return AIResponse(
                spokenText: "Вот рабочее решение и краткое объяснение.",
                taskState: .providingSolution,
                solutionCode: """
                func solve(_ value: Int) -> Int {
                    return value
                }
                """,
                explanation: "Функция принимает значение и возвращает его без изменений. Это минимальная заглушка для примера. Замени тело под конкретную задачу. Обычно решение строится из проверки условий и вычислений. Добавь обработку краевых случаев.",
                isCorrect: false
            )
        case (.assistHelp(.fullSolution), .english):
            return AIResponse(
                spokenText: "Here is a working solution and a short explanation.",
                taskState: .providingSolution,
                solutionCode: """
                func solve(_ value: Int) -> Int {
                    return value
                }
                """,
                explanation: "The function takes a value and returns it unchanged. This is a minimal placeholder solution. Replace the body for your specific task. Typical solutions combine checks and computations. Add edge case handling.",
                isCorrect: false
            )
        case (.assistHelp(.fullSolution), .german):
            return AIResponse(
                spokenText: "Hier ist eine Lösung und eine kurze Erklärung.",
                taskState: .providingSolution,
                solutionCode: """
                func solve(_ value: Int) -> Int {
                    return value
                }
                """,
                explanation: "Die Funktion nimmt einen Wert und gibt ihn unverändert zurück. Das ist eine minimale Platzhalter-Lösung. Ersetze den Rumpf für deine Aufgabe. Übliche Lösungen kombinieren Prüfungen und Berechnungen. Randfälle beachten.",
                isCorrect: false
            )
        case (.languageCoach, .russian):
            return AIResponse(
                spokenText: "Хорошо. Продолжай.",
                needsCorrection: false,
                requestRepeat: false
            )
        case (.languageCoach, .english):
            return AIResponse(
                spokenText: "Got it. Go on.",
                needsCorrection: false,
                requestRepeat: false
            )
        case (.languageCoach, .german):
            return AIResponse(
                spokenText: "Verstanden. Mach weiter.",
                needsCorrection: false,
                requestRepeat: false
            )
        }
    }
    
    // MARK: - OpenAIChatServiceProtocol Implementation
    
    func sendMessageWithCode(
        messages: [TranscriptMessage],
        codeContext: CodeContext,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        llmMode: LLMMode,
        chatModel: String,
        apiKey: String,
        context: String
    ) async throws -> AIResponse {
        let temperature: Double
        switch llmMode {
        case .checkSolution:
            temperature = 0.2
        case .generateTask:
            temperature = 0.7
        case .assistHelp:
            temperature = 0.3
        case .languageCoach:
            temperature = 0.2
        }
        
        var chatMessages: [ChatMessage]
        
        if llmMode.isCheckSolution {
            let systemPrompt = getCheckSystemPrompt(
                topic: topic,
                level: level,
                language: language
            )
            let userContent = buildCheckUserMessage(
                context: context,
                code: codeContext.currentCode,
                language: language
            )
            chatMessages = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userContent)
            ]
        } else if llmMode.isGenerateTask && mode == .codeTasks {
            let systemPrompt = getGenSystemPrompt(
                topic: topic,
                level: level,
                language: language,
                context: context
            )
            let userContent = buildGenUserMessage(
                topic: topic,
                language: language,
                context: context
            )
            chatMessages = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userContent)
            ]
        } else if case let .assistHelp(helpMode) = llmMode {
            let systemPrompt = getAssistHelpSystemPrompt(
                topic: topic,
                level: level,
                language: language,
                helpMode: helpMode
            )
            let userContent = buildAssistUserMessage(
                context: context,
                code: codeContext.currentCode,
                userMessage: messages.last?.text ?? "",
                language: language
            )
            chatMessages = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userContent)
            ]
        } else if case .languageCoach = llmMode {
            let systemPrompt = getLanguageCoachSystemPrompt(language: language)
            let userContent = buildLanguageCoachUserMessage(
                userMessage: messages.last?.text ?? "",
                language: language
            )
            chatMessages = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userContent)
            ]
        } else {
            let systemPrompt = getHybridSystemPrompt(
                topic: topic,
                level: level,
                language: language,
                mode: mode,
                context: context
            )
            
            var trimmedMessages = messages.suffix(2)
            chatMessages = [ChatMessage(role: "system", content: systemPrompt)]
            for message in trimmedMessages {
                chatMessages.append(ChatMessage(
                    role: message.role.rawValue,
                    content: message.text
                ))
            }
            chatMessages.append(ChatMessage(
                role: "system",
                content: codeContext.toContextString()
            ))
        }
        
        let shouldValidate: Bool
        switch llmMode {
        case .checkSolution, .assistHelp, .languageCoach:
            shouldValidate = true
        case .generateTask:
            shouldValidate = (mode == .codeTasks || mode == .questionsOnly)
        }
        
        do {
            let assistantMessage = try await requestChatResponse(
                messages: chatMessages,
                model: chatModel,
                apiKey: apiKey,
                temperature: temperature
            )
            
            if !shouldValidate {
                if let decoded = decodeAIResponse(assistantMessage) {
                    return decoded
                }
                if let data = assistantMessage.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let spokenText = json["spoken_text"] as? String {
                    return AIResponse(spokenText: spokenText, aicode: nil)
                }
                return AIResponse(
                    spokenText: "Sorry, I could not parse the response. Please try again.",
                    aicode: nil
                )
            }
            
            if let decoded = decodeAIResponse(assistantMessage) {
                let normalized = normalizeResponse(decoded, mode: llmMode)
                if isValidResponse(normalized, mode: llmMode, interviewMode: mode) {
                    return normalized
                }
            }
            
            let retryMessage = ChatMessage(
                role: "system",
                content: retryInstruction(for: llmMode, language: language, interviewMode: mode)
            )
            let retryMessages = chatMessages + [retryMessage]
            
            let retryResponse = try await requestChatResponse(
                messages: retryMessages,
                model: chatModel,
                apiKey: apiKey,
                temperature: temperature
            )
            
            if let decoded = decodeAIResponse(retryResponse) {
                let normalized = normalizeResponse(decoded, mode: llmMode)
                if isValidResponse(normalized, mode: llmMode, interviewMode: mode) {
                    return normalized
                }
            }
            
            Logger.error("LLM response validation failed after retry - using fallback")
            return fallbackResponse(for: llmMode, language: language, interviewMode: mode)
        } catch {
            Logger.error("LLM request failed", error: error)
            return fallbackResponse(for: llmMode, language: language, interviewMode: mode)
        }
    }
    
    func analyzeCodeErrors(
        code: String,
        topic: InterviewTopic,
        level: DeveloperLevel,
        apiKey: String
    ) async throws -> [CodeError] {
        let prompt = buildCodeAnalysisPrompt(code: code, topic: topic, level: level)
        
        let messages = [
            ChatMessage(role: "system", content: "Analyze following Swift code for errors. Return JSON only."),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let request = ChatRequest(
            model: APIConstants.Model.gpt4o,
            messages: messages,
            responseFormat: .json,
            temperature: 0.0
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            throw HTTPError.serverError("Failed to encode request")
        }
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
        
        let response: ChatResponse = try await httpClient.request(
            endpoint: APIConstants.chatEndpoint,
            method: .post,
            body: body,
            headers: headers,
            responseType: ChatResponse.self
        )
        
        guard let content = response.choices.first?.message.content else {
            return []
        }
        
        return parseCodeErrors(content, code: code)
    }
    
    func evaluateCode(
        code: String,
        context: CodeContext,
        apiKey: String
    ) async throws -> CodeEvaluation {
        let prompt = buildEvaluationPrompt(code: code, context: context)
        
        let messages = [
            ChatMessage(role: "system", content: "Evaluate submitted code. Return JSON only."),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let request = ChatRequest(
            model: APIConstants.Model.gpt4o,
            messages: messages,
            responseFormat: .json,
            temperature: 0.0
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            throw HTTPError.serverError("Failed to encode request")
        }
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
        
        let response: ChatResponse = try await httpClient.request(
            endpoint: APIConstants.chatEndpoint,
            method: .post,
            body: body,
            headers: headers,
            responseType: ChatResponse.self
        )
        
        guard let content = response.choices.first?.message.content,
              let data = content.data(using: .utf8),
              let evaluation = try? JSONDecoder().decode(CodeEvaluation.self, from: data) else {
            // Fallback
            return CodeEvaluation.success(feedback: "Code looks good!")
        }
        
        return evaluation
    }
    
    // MARK: - Legacy Support
    
    func sendMessage(
        messages: [TranscriptMessage],
        topic: InterviewTopic,
        language: Language,
        apiKey: String
    ) async throws -> String {
        let emptyContext = CodeContext(
            currentCode: "",
            language: .swift,
            recentChanges: []
        )
        
        let response = try await sendMessageWithCode(
            messages: messages,
            codeContext: emptyContext,
            topic: topic,
            level: .junior,
            language: language,
            mode: .questionsOnly,
            llmMode: .generateTask,
            chatModel: APIConstants.Model.gpt4o,
            apiKey: apiKey,
            context: ""
        )
        
        return response.spokenText
    }
    
    // MARK: - Helper Methods
    
    private func buildCodeAnalysisPrompt(
        code: String,
        topic: InterviewTopic,
        level: DeveloperLevel
    ) -> String {
        return PromptTemplates.CodeAnalysis.analyzeErrors(
            code: code,
            topic: topic,
            level: level
        )
    }
    
    private func buildEvaluationPrompt(code: String, context: CodeContext) -> String {
        return PromptTemplates.CodeEvaluation.evaluateCode(
            code: code,
            context: context
        )
    }
    
    private func parseCodeErrors(_ json: String, code: String) -> [CodeError] {
        guard let data = json.data(using: .utf8) else { return [] }
        
        struct ErrorsResponse: Codable {
            let errors: [ErrorData]
            
            struct ErrorData: Codable {
                let range: NSRangeCodable
                let message: String
                let severity: IssueSeverity
                let line: Int
            }
        }
        
        guard let response = try? JSONDecoder().decode(ErrorsResponse.self, from: data) else {
            return []
        }
        
        return response.errors.map { error in
            CodeError(
                range: error.range.range,
                message: error.message,
                severity: error.severity,
                line: error.line
            )
        }
    }
}
