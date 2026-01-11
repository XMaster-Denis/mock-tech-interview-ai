//
//  HTTPClient.swift
//  XInterview2
//
//  Centralized HTTP client per REFERENCE_PATTERNS.md
//

import Foundation

enum HTTPError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .statusCode(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - Please check your API key"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

protocol HTTPClient {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        headers: [String: String],
        responseType: T.Type
    ) async throws -> T
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
