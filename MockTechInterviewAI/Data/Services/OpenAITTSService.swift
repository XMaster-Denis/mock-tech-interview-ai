//
//  OpenAITTSService.swift
//  XInterview2
//
//  OpenAI text-to-speech service
//

import Foundation

struct TTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
}

protocol OpenAITTSServiceProtocol {
    func generateSpeech(text: String, model: String, voice: String, apiKey: String) async throws -> Data
}

class OpenAITTSService: OpenAITTSServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    func generateSpeech(text: String, model: String, voice: String, apiKey: String) async throws -> Data {
        let request = TTSRequest(
            model: model,
            input: text,
            voice: voice
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            Logger.error("Failed to encode TTS request")
            throw HTTPError.serverError("Failed to encode request")
        }
        
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
        
        // Note: TTS endpoint returns audio data, not JSON
        guard let url = URL(string: APIConstants.baseURL + APIConstants.ttsEndpoint) else {
            throw HTTPError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response for TTS")
            throw HTTPError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            Logger.error("TTS unauthorized - invalid API key")
            throw HTTPError.unauthorized
        default:
            Logger.error("TTS request failed with status: \(httpResponse.statusCode)")
            throw HTTPError.statusCode(httpResponse.statusCode)
        }
    }
}
