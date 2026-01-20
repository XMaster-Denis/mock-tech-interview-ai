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
    var selectedChatModel: String
    var selectedWhisperModel: String
    var selectedTTSModel: String
    var voiceThreshold: Float  // Sensitivity for voice detection (0.05 - 0.5)
    var silenceTimeout: Double  // Seconds of silence to detect end of speech (0.5 - 5.0)
    var minSpeechLevel: Float  // Minimum audio level to validate speech (0.01 - 0.1)
    var calibratedNoiseThreshold: Float?  // Last calibrated noise threshold (optional)
    var allowTTSInterruption: Bool  // Allow microphone noise to interrupt TTS playback
    
    init(
        apiKey: String = "",
        selectedLanguage: Language = .english,
        selectedVoice: String = APIConstants.Voice.alloy,
        selectedChatModel: String = APIConstants.Model.gpt4o,
        selectedWhisperModel: String = APIConstants.Model.whisperMini,
        selectedTTSModel: String = APIConstants.Model.tts,
        voiceThreshold: Float = 0.2,
        silenceTimeout: Double = 1.5,
        minSpeechLevel: Float = 0.04,
        calibratedNoiseThreshold: Float? = nil,
        allowTTSInterruption: Bool = true
    ) {
        self.apiKey = apiKey
        self.selectedLanguage = selectedLanguage
        self.selectedVoice = selectedVoice
        self.selectedChatModel = selectedChatModel
        self.selectedWhisperModel = selectedWhisperModel
        self.selectedTTSModel = selectedTTSModel
        self.voiceThreshold = voiceThreshold
        self.silenceTimeout = silenceTimeout
        self.minSpeechLevel = minSpeechLevel
        self.calibratedNoiseThreshold = calibratedNoiseThreshold
        self.allowTTSInterruption = allowTTSInterruption
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
}
