//
//  OpenAIChatService.swift
//  XInterview2
//
//  OpenAI GPT-4o chat completion service
//

import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
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

protocol OpenAIChatServiceProtocol {
    func sendMessage(messages: [TranscriptMessage], topic: InterviewTopic, language: Language, apiKey: String) async throws -> String
}

class OpenAIChatService: OpenAIChatServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    func sendMessage(
        messages: [TranscriptMessage],
        topic: InterviewTopic,
        language: Language,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = buildSystemPrompt(topic: topic, language: language)
        
        let chatMessages = [ChatMessage(role: "system", content: systemPrompt)] +
        messages.map { ChatMessage(role: $0.role.rawValue, content: $0.text) }
        
        let request = ChatRequest(
            model: APIConstants.Model.gpt4o,
            messages: chatMessages
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
        
        guard let assistantMessage = response.choices.first?.message.content else {
            throw HTTPError.serverError("No response from AI")
        }
        
        return assistantMessage
    }
    
    private func buildSystemPrompt(topic: InterviewTopic, language: Language) -> String {
        let languageInstruction: String
        switch language {
        case .english:
            languageInstruction = "Respond in English."
        case .russian:
            languageInstruction = "Отвечайте на русском языке."
        case .german:
            languageInstruction = "Antworten Sie auf Deutsch."
        }
        
        return """
        You are a friendly technical interviewer conducting a job interview. 

        Interview Topic: \(topic.title)
        Topic Guidance: \(topic.prompt)

        \(languageInstruction)

        Follow these guidelines:
        - Keep questions short and conversational (1-2 sentences)
        - Ask one question at a time
        - Wait for the user's response before asking follow-up questions
        - Provide gentle, constructive corrections when appropriate
        - Maintain a natural interview tone - be encouraging but professional
        - Start with a brief introduction and ask your first question
        - Avoid overwhelming the user with multiple topics at once

        Remember: This is a conversation, not a test. Help the user feel comfortable.
        """
    }
}
