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
    func generateSpeech(text: String, voice: String, apiKey: String) async throws -> Data
}

class OpenAITTSService: OpenAITTSServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = DefaultHTTPClient()) {
        self.httpClient = httpClient
    }
    
    func generateSpeech(text: String, voice: String, apiKey: String) async throws -> Data {
        Logger.network("TTS generateSpeech() START - text length: \(text.count), voice: \(voice)")
        
        let request = TTSRequest(
            model: APIConstants.Model.tts,
            input: text,
            voice: voice
        )
        
        guard let body = try? JSONEncoder().encode(request) else {
            Logger.error("Failed to encode TTS request")
            throw HTTPError.serverError("Failed to encode request")
        }
        
        Logger.network("TTS request body size: \(body.count) bytes")
        
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
        
        Logger.network("Sending TTS request to OpenAI API")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Invalid HTTP response for TTS")
            throw HTTPError.invalidResponse
        }
        
        Logger.network("TTS response status: \(httpResponse.statusCode), received data: \(data.count) bytes")
        
        switch httpResponse.statusCode {
        case 200...299:
            Logger.success("TTS audio received successfully - \(data.count) bytes")
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
