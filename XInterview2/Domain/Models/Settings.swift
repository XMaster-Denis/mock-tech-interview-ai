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
    var silenceTimeout: Double  // Seconds of silence to detect end of speech (0.5 - 5.0)
    
    init(
        apiKey: String = "",
        selectedLanguage: Language = .english,
        selectedVoice: String = APIConstants.Voice.alloy,
        voiceThreshold: Float = 0.2,
        silenceTimeout: Double = 1.5
    ) {
        self.apiKey = apiKey
        self.selectedLanguage = selectedLanguage
        self.selectedVoice = selectedVoice
        self.voiceThreshold = voiceThreshold
        self.silenceTimeout = silenceTimeout
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
}
