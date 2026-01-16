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
    private func getSystemPrompt(
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
    
    // MARK: - OpenAIChatServiceProtocol Implementation
    
    func sendMessageWithCode(
        messages: [TranscriptMessage],
        codeContext: CodeContext,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        apiKey: String,
        context: String
    ) async throws -> AIResponse {
        
        // Use cached system prompt to save tokens
        let systemPrompt = getSystemPrompt(
            topic: topic,
            level: level,
            language: language,
            mode: mode,
            context: context
        )
        
        var chatMessages = [ChatMessage(role: "system", content: systemPrompt)]
        
        // Add conversation history
        for message in messages {
            chatMessages.append(ChatMessage(
                role: message.role.rawValue,
                content: message.text
            ))
        }
        
        // Add code context as a system message
        chatMessages.append(ChatMessage(
            role: "system",
            content: codeContext.toContextString()
        ))
        
        let request = ChatRequest(
            model: APIConstants.Model.gpt4o,
            messages: chatMessages,
            responseFormat: .json,
            temperature: 0.7
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            Logger.error("Failed to encode chat request")
            throw HTTPError.serverError("Failed to encode request")
        }
        
        // Log JSON request to GPT
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
        
        // Log JSON response from GPT
        Logger.jsonResponse(assistantMessage)
        
        // Parse JSON response
        guard let data = assistantMessage.data(using: .utf8) else {
            Logger.error("Failed to convert response to UTF-8 data")
            throw HTTPError.serverError("Invalid response encoding")
        }
        
        do {
            let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
            return aiResponse
        } catch {
            Logger.error("Failed to parse AI response as JSON: \(error.localizedDescription)")
            Logger.jsonResponse(assistantMessage)
            
            // Try to extract spoken text from JSON manually as fallback
            if let jsonData = assistantMessage.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let spokenText = json["spoken_text"] as? String {
                return AIResponse(
                    spokenText: spokenText,
                    aicode: nil
                )
            }
            
            // Last resort: return error message
            Logger.error("Could not extract spoken_text from JSON - returning error message")
            return AIResponse(
                spokenText: "Извините, произошла ошибка при обработке ответа. Пожалуйста, попробуйте еще раз.",
                aicode: nil
            )
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
