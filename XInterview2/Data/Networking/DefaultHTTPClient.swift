//
//  DefaultHTTPClient.swift
//  XInterview2
//
//  URLSession-based HTTP client implementation
//

import Foundation

class DefaultHTTPClient: HTTPClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        headers: [String: String],
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: APIConstants.baseURL + endpoint) else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(T.self, from: data)
            case 401:
                throw HTTPError.unauthorized
            case 400...499:
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw HTTPError.serverError(errorResponse.error.message ?? "Unknown error")
                }
                throw HTTPError.statusCode(httpResponse.statusCode)
            case 500...599:
                throw HTTPError.serverError("Server error")
            default:
                throw HTTPError.statusCode(httpResponse.statusCode)
            }
        } catch let error as HTTPError {
            throw error
        } catch {
            // Check if error is CancellationError (code -999 in Swift)
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                throw HTTPError.requestCancelled
            }
            throw HTTPError.networkError(error)
        }
    }
}

// MARK: - Error Response Models

struct ErrorResponse: Decodable {
    let error: ErrorDetail
    
    struct ErrorDetail: Decodable {
        let message: String?
        let type: String?
    }
}
