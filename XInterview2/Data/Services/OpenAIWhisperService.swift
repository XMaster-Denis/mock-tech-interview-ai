//
//  OpenAIWhisperService.swift
//  XInterview2
//
//  OpenAI Whisper speech-to-text service
//

import Foundation

struct WhisperResponse: Codable {
    let text: String
}

protocol OpenAIWhisperServiceProtocol {
    func transcribe(audioData: Data, apiKey: String) async throws -> String
}

class OpenAIWhisperService: OpenAIWhisperServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    func transcribe(audioData: Data, apiKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append(APIConstants.Model.whisper.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "multipart/form-data; boundary=\(boundary)"
        ]
        
        let response: WhisperResponse = try await httpClient.request(
            endpoint: APIConstants.transcriptionEndpoint,
            method: .post,
            body: body,
            headers: headers,
            responseType: WhisperResponse.self
        )
        
        return response.text
    }
}
