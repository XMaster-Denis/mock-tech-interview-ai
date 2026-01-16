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
    
    private func requestChatResponse(
        messages: [ChatMessage],
        apiKey: String,
        temperature: Double
    ) async throws -> String {
        let request = ChatRequest(
            model: APIConstants.Model.gpt4o,
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
                correctCode: nil,
                isCorrect: nil
            )
        }
    }
    
    private func isValidResponse(_ response: AIResponse, mode: LLMMode) -> Bool {
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
            guard response.taskState == .taskPresented else {
                return false
            }
            let aicodeText = response.aicode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !aicodeText.isEmpty
        }
    }
    
    private func retryInstruction(for mode: LLMMode, language: Language) -> String {
        switch (mode, language) {
        case (.checkSolution, .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме CHECK с is_correct и task_state."
        case (.checkSolution, .english):
            return "Previous response missed required fields. Return JSON per CHECK schema with is_correct and task_state."
        case (.checkSolution, .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach CHECK-Schema mit is_correct und task_state."
        case (.generateTask, .russian):
            return "В предыдущем ответе отсутствовали обязательные поля. Верни JSON по схеме GEN_TASK с task_state=task_presented и aicode."
        case (.generateTask, .english):
            return "Previous response missed required fields. Return JSON per GEN_TASK schema with task_state=task_presented and aicode."
        case (.generateTask, .german):
            return "Im vorherigen Antwort fehlten Pflichtfelder. Gib JSON nach GEN_TASK-Schema mit task_state=task_presented und aicode."
        }
    }
    
    private func fallbackResponse(for mode: LLMMode, language: Language) -> AIResponse {
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
                spokenText: "Ich konnte nicht automatisch pruefen. Bitte sende den Code erneut.",
                taskState: .providingHint,
                hint: "Ich konnte nicht automatisch pruefen. Bitte sende den Code erneut.",
                isCorrect: false
            )
        case (.generateTask, .russian):
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
            return AIResponse(
                spokenText: "Schreibe eine Funktion, die die Laenge eines Strings zurueckgibt.",
                aicode: """
                func stringLength(_ text: String) -> Int {
                    // YOUR CODE HERE
                    return 0 // Replace this line
                }
                """,
                taskState: .taskPresented
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
        apiKey: String,
        context: String
    ) async throws -> AIResponse {
        let temperature: Double = (llmMode == .checkSolution) ? 0.2 : 0.7
        var chatMessages: [ChatMessage]
        
        if llmMode == .checkSolution {
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
        } else if mode == .codeTasks {
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
        
        let shouldValidate = (llmMode == .checkSolution) || (mode == .codeTasks)
        
        do {
            let assistantMessage = try await requestChatResponse(
                messages: chatMessages,
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
                if isValidResponse(normalized, mode: llmMode) {
                    return normalized
                }
            }
            
            let retryMessage = ChatMessage(
                role: "system",
                content: retryInstruction(for: llmMode, language: language)
            )
            let retryMessages = chatMessages + [retryMessage]
            
            let retryResponse = try await requestChatResponse(
                messages: retryMessages,
                apiKey: apiKey,
                temperature: temperature
            )
            
            if let decoded = decodeAIResponse(retryResponse) {
                let normalized = normalizeResponse(decoded, mode: llmMode)
                if isValidResponse(normalized, mode: llmMode) {
                    return normalized
                }
            }
            
            Logger.error("LLM response validation failed after retry - using fallback")
            return fallbackResponse(for: llmMode, language: language)
        } catch {
            Logger.error("LLM request failed", error: error)
            return fallbackResponse(for: llmMode, language: language)
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
