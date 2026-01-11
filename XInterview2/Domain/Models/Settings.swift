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
    
    init(
        apiKey: String = "",
        selectedLanguage: Language = .english,
        selectedVoice: String = APIConstants.Voice.alloy
    ) {
        self.apiKey = apiKey
        self.selectedLanguage = selectedLanguage
        self.selectedVoice = selectedVoice
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
}
