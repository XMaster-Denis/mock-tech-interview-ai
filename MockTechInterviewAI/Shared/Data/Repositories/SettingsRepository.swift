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
        let interfaceLanguageRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedInterfaceLanguage) ?? Language.english.rawValue
        let voice = userDefaults.string(forKey: UserDefaultsKeys.selectedVoice) ?? APIConstants.Voice.alloy
        let chatModelRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedChatModel) ?? APIConstants.Model.gpt4o
        let whisperModelRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedWhisperModel) ?? APIConstants.Model.whisperMini
        let ttsModelRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedTTSModel) ?? APIConstants.Model.tts
        let voiceThreshold = userDefaults.float(forKey: UserDefaultsKeys.voiceThreshold)
        let silenceTimeout = userDefaults.double(forKey: UserDefaultsKeys.silenceTimeout)
        let minSpeechLevel = userDefaults.float(forKey: UserDefaultsKeys.minSpeechLevel)
        let allowInterruption = userDefaults.object(forKey: UserDefaultsKeys.allowTTSInterruption) as? Bool ?? true
        
        let language = Language(rawValue: languageRaw) ?? .english
        let interfaceLanguage = Language(rawValue: interfaceLanguageRaw) ?? .english
        let resolvedVoice = APIConstants.Voice.all.contains(voice) ? voice : APIConstants.Voice.alloy
        let chatModel = APIConstants.Model.chatModels.contains(chatModelRaw) ? chatModelRaw : APIConstants.Model.gpt4o
        let whisperModel = APIConstants.Model.whisperModels.contains(whisperModelRaw) ? whisperModelRaw : APIConstants.Model.whisperMini
        let ttsModel = APIConstants.Model.ttsModels.contains(ttsModelRaw) ? ttsModelRaw : APIConstants.Model.tts
        
        // Use saved threshold if valid, otherwise use default (0.2)
        let threshold = voiceThreshold > 0 ? voiceThreshold : 0.2
        
        // Use saved silence timeout if valid, otherwise use default (1.5)
        let timeout = silenceTimeout > 0 ? silenceTimeout : 1.5
        
        // Use saved min speech level if valid, otherwise use default (0.04)
        let speechLevel = minSpeechLevel > 0 ? minSpeechLevel : 0.04
        
        return Settings(
            apiKey: apiKey,
            selectedLanguage: language,
            selectedInterfaceLanguage: interfaceLanguage,
            selectedVoice: resolvedVoice,
            selectedChatModel: chatModel,
            selectedWhisperModel: whisperModel,
            selectedTTSModel: ttsModel,
            voiceThreshold: threshold,
            silenceTimeout: timeout,
            minSpeechLevel: speechLevel,
            allowTTSInterruption: allowInterruption
        )
    }
    
    func saveSettings(_ settings: Settings) {
        let resolvedVoice = APIConstants.Voice.all.contains(settings.selectedVoice) ? settings.selectedVoice : APIConstants.Voice.alloy
        let chatModel = APIConstants.Model.chatModels.contains(settings.selectedChatModel) ? settings.selectedChatModel : APIConstants.Model.gpt4o
        let whisperModel = APIConstants.Model.whisperModels.contains(settings.selectedWhisperModel) ? settings.selectedWhisperModel : APIConstants.Model.whisperMini
        let ttsModel = APIConstants.Model.ttsModels.contains(settings.selectedTTSModel) ? settings.selectedTTSModel : APIConstants.Model.tts
        userDefaults.set(settings.apiKey, forKey: UserDefaultsKeys.apiKey)
        userDefaults.set(settings.selectedLanguage.rawValue, forKey: UserDefaultsKeys.selectedLanguage)
        userDefaults.set(settings.selectedInterfaceLanguage.rawValue, forKey: UserDefaultsKeys.selectedInterfaceLanguage)
        userDefaults.set(resolvedVoice, forKey: UserDefaultsKeys.selectedVoice)
        userDefaults.set(chatModel, forKey: UserDefaultsKeys.selectedChatModel)
        userDefaults.set(whisperModel, forKey: UserDefaultsKeys.selectedWhisperModel)
        userDefaults.set(ttsModel, forKey: UserDefaultsKeys.selectedTTSModel)
        userDefaults.set(settings.voiceThreshold, forKey: UserDefaultsKeys.voiceThreshold)
        userDefaults.set(settings.silenceTimeout, forKey: UserDefaultsKeys.silenceTimeout)
        userDefaults.set(settings.minSpeechLevel, forKey: UserDefaultsKeys.minSpeechLevel)
        userDefaults.set(settings.allowTTSInterruption, forKey: UserDefaultsKeys.allowTTSInterruption)
    }
}
