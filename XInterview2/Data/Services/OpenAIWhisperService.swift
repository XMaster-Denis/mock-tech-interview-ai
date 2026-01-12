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
    func transcribe(audioData: Data, apiKey: String, language: String, prompt: String?, temperature: Float?) async throws -> String
}

class OpenAIWhisperService: OpenAIWhisperServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    func transcribe(audioData: Data, apiKey: String, language: String, prompt: String? = nil, temperature: Float? = nil) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var body = Data()
        
        // Add file (WAV format)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append(APIConstants.Model.whisper.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add language parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append(language.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add prompt parameter (optional)
        if let prompt = prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add temperature parameter (optional)
        if let temperature = temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append(String(temperature).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
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
