//
//  Settings.swift
//  XInterview2
//
//  User settings and preferences
//

import Foundation

struct Settings: Codable {
    var apiKey: String
    var selectedLanguage: Language
    var selectedVoice: String
    var voiceThreshold: Float  // Sensitivity for voice detection (0.05 - 0.5)
    
    init(
        apiKey: String = "",
        selectedLanguage: Language = .english,
        selectedVoice: String = APIConstants.Voice.alloy,
        voiceThreshold: Float = 0.25
    ) {
        self.apiKey = apiKey
        self.selectedLanguage = selectedLanguage
        self.selectedVoice = selectedVoice
        self.voiceThreshold = voiceThreshold
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
}
