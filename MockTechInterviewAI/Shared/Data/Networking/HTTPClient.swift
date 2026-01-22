//
//  HTTPClient.swift
//  XInterview2
//
//  Centralized HTTP client per REFERENCE_PATTERNS.md
//

import Foundation

enum HTTPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(String)
    case requestCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .statusCode(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - Please check your API key in Settings"
        case .serverError(let message):
            return "Server error: \(message)"
        case .requestCancelled:
            return "Request was cancelled"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidURL:
            return "The URL is malformed"
        case .invalidResponse:
            return "Server response is invalid"
        case .statusCode(let code):
            switch code {
            case 400:
                return "Bad request - Invalid parameters"
            case 401:
                return "Authentication failed - Check your API key"
            case 429:
                return "Rate limit exceeded - Too many requests"
            case 500...599:
                return "Server error - Try again later"
            default:
                return "HTTP request failed with code \(code)"
            }
        case .decodingError:
            return "Response format is invalid"
        case .networkError(let error):
            return error.localizedDescription
        case .unauthorized:
            return "API key is invalid or expired"
        case .serverError(let message):
            return message
        case .requestCancelled:
            return "Request was cancelled by user"
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
