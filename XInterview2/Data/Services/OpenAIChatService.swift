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
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    // MARK: - OpenAIChatServiceProtocol Implementation
    
    func sendMessageWithCode(
        messages: [TranscriptMessage],
        codeContext: CodeContext,
        topic: InterviewTopic,
        level: DeveloperLevel,
        language: Language,
        mode: InterviewMode,
        apiKey: String
    ) async throws -> AIResponse {
        Logger.network("Chat sendMessageWithCode() START - topic: \(topic.title), level: \(level.displayName), mode: \(mode.displayName)")
        Logger.network("Code length: \(codeContext.currentCode.count) chars")
        Logger.network("Conversation history count: \(messages.count)")
        
        let systemPrompt = HybridInterviewPrompt.generate(
            for: topic,
            level: level,
            language: language,
            mode: mode
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
        
        Logger.network("Chat request body size: \(body.count) bytes")
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
        
        Logger.network("Sending chat request to OpenAI API")
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
        
        Logger.success("Chat response received - length: \(assistantMessage.count) chars")
        Logger.info("Raw JSON from OpenAI: \(assistantMessage)")
        
        // Parse JSON response
        guard let data = assistantMessage.data(using: .utf8),
              let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: data) else {
            Logger.error("Failed to parse AI response as JSON - using fallback")
            // Fallback to plain text response with default task type
            return AIResponse(
                taskType: .question,
                spokenText: assistantMessage,
                codeTemplate: nil,
                editorAction: EditorAction.none,
                evaluation: nil,
                hintContext: nil
            )
        }
        
        Logger.success("AI response parsed - action: \(aiResponse.editorAction != nil)")
        return aiResponse
    }
    
    func analyzeCodeErrors(
        code: String,
        topic: InterviewTopic,
        level: DeveloperLevel,
        apiKey: String
    ) async throws -> [CodeError] {
        Logger.network("Analyze code errors START - code length: \(code.count)")
        
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
        Logger.network("Evaluate code START - code length: \(code.count)")
        
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
            apiKey: apiKey
        )
        
        return response.spokenText
    }
    
    // MARK: - Helper Methods
    
    private func buildCodeAnalysisPrompt(
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
    
    private func buildEvaluationPrompt(code: String, context: CodeContext) -> String {
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
