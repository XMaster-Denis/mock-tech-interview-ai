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
    var minSpeechLevel: Float  // Minimum audio level to validate speech (0.01 - 0.1)
    var calibratedNoiseThreshold: Float?  // Last calibrated noise threshold (optional)
    
    init(
        apiKey: String = "",
        selectedLanguage: Language = .english,
        selectedVoice: String = APIConstants.Voice.alloy,
        voiceThreshold: Float = 0.2,
        silenceTimeout: Double = 1.5,
        minSpeechLevel: Float = 0.04,
        calibratedNoiseThreshold: Float? = nil
    ) {
        self.apiKey = apiKey
        self.selectedLanguage = selectedLanguage
        self.selectedVoice = selectedVoice
        self.voiceThreshold = voiceThreshold
        self.silenceTimeout = silenceTimeout
        self.minSpeechLevel = minSpeechLevel
        self.calibratedNoiseThreshold = calibratedNoiseThreshold
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
}
