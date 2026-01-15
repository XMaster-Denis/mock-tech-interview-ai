//
//  SettingsRepository.swift
//  XInterview2
//
//  Settings persistence using UserDefaults
//

import Foundation

protocol SettingsRepositoryProtocol {
    func loadSettings() -> Settings
    func saveSettings(_ settings: Settings)
}

final class SettingsRepository: SettingsRepositoryProtocol {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func loadSettings() -> Settings {
        let apiKey = userDefaults.string(forKey: UserDefaultsKeys.apiKey) ?? ""
        let languageRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedLanguage) ?? Language.english.rawValue
        let voice = userDefaults.string(forKey: UserDefaultsKeys.selectedVoice) ?? APIConstants.Voice.alloy
        let voiceThreshold = userDefaults.float(forKey: UserDefaultsKeys.voiceThreshold)
        let silenceTimeout = userDefaults.double(forKey: UserDefaultsKeys.silenceTimeout)
        let minSpeechLevel = userDefaults.float(forKey: UserDefaultsKeys.minSpeechLevel)
        
        let language = Language(rawValue: languageRaw) ?? .english
        
        // Use saved threshold if valid, otherwise use default (0.2)
        let threshold = voiceThreshold > 0 ? voiceThreshold : 0.2
        
        // Use saved silence timeout if valid, otherwise use default (1.5)
        let timeout = silenceTimeout > 0 ? silenceTimeout : 1.5
        
        // Use saved min speech level if valid, otherwise use default (0.04)
        let speechLevel = minSpeechLevel > 0 ? minSpeechLevel : 0.04
        
        return Settings(
            apiKey: apiKey,
            selectedLanguage: language,
            selectedVoice: voice,
            voiceThreshold: threshold,
            silenceTimeout: timeout,
            minSpeechLevel: speechLevel
        )
    }
    
    func saveSettings(_ settings: Settings) {
        userDefaults.set(settings.apiKey, forKey: UserDefaultsKeys.apiKey)
        userDefaults.set(settings.selectedLanguage.rawValue, forKey: UserDefaultsKeys.selectedLanguage)
        userDefaults.set(settings.selectedVoice, forKey: UserDefaultsKeys.selectedVoice)
        userDefaults.set(settings.voiceThreshold, forKey: UserDefaultsKeys.voiceThreshold)
        userDefaults.set(settings.silenceTimeout, forKey: UserDefaultsKeys.silenceTimeout)
        userDefaults.set(settings.minSpeechLevel, forKey: UserDefaultsKeys.minSpeechLevel)
    }
}
