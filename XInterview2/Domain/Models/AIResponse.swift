//
//  AIResponse.swift
//  XInterview2
//
//  Simplified AI response
//

import Foundation

/// Represents a simplified response from AI
struct AIResponse: Codable {
    /// Text to be spoken by TTS
    let spokenText: String
    
    /// Code to display in editor (optional)
    let aicode: String?
    
    // MARK: - Coding Keys for snake_case JSON
    
    enum CodingKeys: String, CodingKey {
        case spokenText = "spoken_text"
        case aicode
    }
    
    init(spokenText: String, aicode: String? = nil) {
        self.spokenText = spokenText
        self.aicode = aicode
    }
}
