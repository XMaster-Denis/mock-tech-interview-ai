//
//  LLMResponseValidationTests.swift
//  XInterview2Tests
//

import XCTest
@testable import XInterview2

final class LLMResponseValidationTests: XCTestCase {
    private final class MockHTTPClient: HTTPClient {
        var responses: [String]
        var requests: [ChatRequest] = []
        
        init(responses: [String]) {
            self.responses = responses
        }
        
        func request<T>(
            endpoint: String,
            method: HTTPMethod,
            body: Data?,
            headers: [String: String],
            responseType: T.Type
        ) async throws -> T where T : Decodable {
            if let body,
               let request = try? JSONDecoder().decode(ChatRequest.self, from: body) {
                requests.append(request)
            }
            
            let content = responses.isEmpty ? "{}" : responses.removeFirst()
            let response = ChatResponse(
                id: "test",
                object: "chat.completion",
                created: 0,
                model: "gpt-4o",
                choices: [
                    ChatResponse.Choice(
                        index: 0,
                        message: ChatMessage(role: "assistant", content: content),
                        finishReason: "stop"
                    )
                ]
            )
            
            guard let typed = response as? T else {
                throw HTTPError.decodingError(NSError(domain: "MockHTTPClient", code: -1))
            }
            return typed
        }
    }
    
    private func makeTopic() -> InterviewTopic {
        InterviewTopic(
            title: "Swift Basics",
            prompt: "Basic Swift tasks",
            level: .junior,
            codeLanguage: .swift,
            interviewMode: .codeTasks
        )
    }
    
    private func makeCodeContext() -> CodeContext {
        CodeContext(currentCode: "func square(_ x: Int) -> Int { return x * x }", language: .swift, recentChanges: [])
    }
    
    func testCheckMissingIsCorrectRetriesThenFallback() async throws {
        let mock = MockHTTPClient(responses: [
            #"{"spoken_text":"Checking.","task_state":"checking_solution"}"#,
            #"{"spoken_text":"Checking.","task_state":"checking_solution"}"#
        ])
        let service = OpenAIChatService(httpClient: mock)
        
        let response = try await service.sendMessageWithCode(
            messages: [],
            codeContext: makeCodeContext(),
            topic: makeTopic(),
            level: .junior,
            language: .english,
            mode: .codeTasks,
            llmMode: .checkSolution,
            apiKey: "test",
            context: "Task (short): check"
        )
        
        XCTAssertEqual(response.isCorrect, false)
        XCTAssertEqual(response.taskState, .providingHint)
        XCTAssertNotNil(response.hint)
    }
    
    func testCheckCheckingSolutionRetriesThenSucceeds() async throws {
        let mock = MockHTTPClient(responses: [
            #"{"spoken_text":"OK.","task_state":"checking_solution","is_correct":true}"#,
            #"{"spoken_text":"OK.","task_state":"none","is_correct":true}"#
        ])
        let service = OpenAIChatService(httpClient: mock)
        
        let response = try await service.sendMessageWithCode(
            messages: [],
            codeContext: makeCodeContext(),
            topic: makeTopic(),
            level: .junior,
            language: .english,
            mode: .codeTasks,
            llmMode: .checkSolution,
            apiKey: "test",
            context: "Task (short): check"
        )
        
        XCTAssertEqual(response.isCorrect, true)
        XCTAssertEqual(response.taskState, .none)
    }
    
    func testGenMissingAicodeRetriesThenFallback() async throws {
        let mock = MockHTTPClient(responses: [
            #"{"spoken_text":"New task","task_state":"task_presented"}"#,
            #"{"spoken_text":"New task","task_state":"task_presented"}"#
        ])
        let service = OpenAIChatService(httpClient: mock)
        
        let response = try await service.sendMessageWithCode(
            messages: [],
            codeContext: makeCodeContext(),
            topic: makeTopic(),
            level: .junior,
            language: .english,
            mode: .codeTasks,
            llmMode: .generateTask,
            apiKey: "test",
            context: "recent_topics: none"
        )
        
        XCTAssertEqual(response.taskState, .taskPresented)
        XCTAssertNotNil(response.aicode)
    }
    
    func testCheckRequestUsesShortMessages() async throws {
        let mock = MockHTTPClient(responses: [
            #"{"spoken_text":"OK.","task_state":"none","is_correct":true}"#
        ])
        let service = OpenAIChatService(httpClient: mock)
        
        _ = try await service.sendMessageWithCode(
            messages: [],
            codeContext: makeCodeContext(),
            topic: makeTopic(),
            level: .junior,
            language: .english,
            mode: .codeTasks,
            llmMode: .checkSolution,
            apiKey: "test",
            context: "Task (short): check"
        )
        
        let messageCount = mock.requests.first?.messages.count ?? 0
        XCTAssertLessThanOrEqual(messageCount, 4)
        XCTAssertEqual(messageCount, 2)
    }
}
