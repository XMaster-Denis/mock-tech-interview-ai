//
//  SettingsViewModel.swift
//  XInterview2
//
//  ViewModel for Settings view
//

import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var apiKey: String = ""
    @Published var selectedLanguage: Language = .english
    @Published var selectedVoice: String = APIConstants.Voice.alloy
    @Published var voiceThreshold: Float = 0.2
    @Published var silenceTimeout: Double = 1.5
    
    // MARK: - Dependencies
    
    private let settingsRepository: SettingsRepositoryProtocol
    
    // MARK: - Initialization
    
    init(settingsRepository: SettingsRepositoryProtocol = SettingsRepository()) {
        self.settingsRepository = settingsRepository
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        let settings = settingsRepository.loadSettings()
        apiKey = settings.apiKey
        selectedLanguage = settings.selectedLanguage
        selectedVoice = settings.selectedVoice
        voiceThreshold = settings.voiceThreshold
        silenceTimeout = settings.silenceTimeout
    }
    
    func saveSettings() {
        let settings = Settings(
            apiKey: apiKey,
            selectedLanguage: selectedLanguage,
            selectedVoice: selectedVoice,
            voiceThreshold: voiceThreshold,
            silenceTimeout: silenceTimeout
        )
        settingsRepository.saveSettings(settings)
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
    
    var availableVoices: [String] {
        [
            APIConstants.Voice.alloy,
            APIConstants.Voice.echo,
            APIConstants.Voice.fable,
            APIConstants.Voice.onyx,
            APIConstants.Voice.nova,
            APIConstants.Voice.shimmer
        ]
    }
    
    var voiceDisplayName: String {
        switch selectedVoice {
        case APIConstants.Voice.alloy: return "Alloy"
        case APIConstants.Voice.echo: return "Echo"
        case APIConstants.Voice.fable: return "Fable"
        case APIConstants.Voice.onyx: return "Onyx"
        case APIConstants.Voice.nova: return "Nova"
        case APIConstants.Voice.shimmer: return "Shimmer"
        default: return selectedVoice
        }
    }
}
