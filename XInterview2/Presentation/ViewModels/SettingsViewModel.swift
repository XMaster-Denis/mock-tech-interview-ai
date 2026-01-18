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
    @Published var minSpeechLevel: Float = 0.04
    @Published var calibratedNoiseLevel: Float? = nil
    @Published var allowTTSInterruption: Bool = true
    @Published var isCalibrating: Bool = false
    @Published var calibrationProgress: Double = 0.0
    
    // MARK: - Dependencies
    
    private let settingsRepository: SettingsRepositoryProtocol
    private let calibrationManager = AudioCalibrationManager()
    
    // MARK: - Initialization
    
    convenience init() {
        self.init(settingsRepository: SettingsRepository())
    }
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
        // Initialize on MainActor
        loadSettings()
        setupCalibrationManager()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        let settings = settingsRepository.loadSettings()
        apiKey = settings.apiKey
        selectedLanguage = settings.selectedLanguage
        selectedVoice = settings.selectedVoice
        voiceThreshold = settings.voiceThreshold
        silenceTimeout = settings.silenceTimeout
        minSpeechLevel = settings.minSpeechLevel
        calibratedNoiseLevel = settings.calibratedNoiseThreshold
        allowTTSInterruption = settings.allowTTSInterruption
    }
    
    func saveSettings() {
        let settings = Settings(
            apiKey: apiKey,
            selectedLanguage: selectedLanguage,
            selectedVoice: selectedVoice,
            voiceThreshold: voiceThreshold,
            silenceTimeout: silenceTimeout,
            minSpeechLevel: minSpeechLevel,
            calibratedNoiseThreshold: calibratedNoiseLevel,
            allowTTSInterruption: allowTTSInterruption
        )
        settingsRepository.saveSettings(settings)
    }
    
    func calibrateNoiseLevel() async {
        isCalibrating = true
        calibratedNoiseLevel = nil
        calibrationProgress = 0.0
        
        // Подписаться на прогресс калибровки
        calibrationManager.$calibrationProgress
            .sink { [weak self] progress in
                self?.calibrationProgress = progress
            }
            .store(in: &cancellables)
        
        // Выполнить калибровку
        let result = await calibrationManager.calibrateNoiseLevel(duration: 3.0)
        
        // Обновить порог
        voiceThreshold = result.recommendedThreshold
        calibratedNoiseLevel = result.recommendedThreshold
        isCalibrating = false
        calibrationProgress = 1.0
        
        // Автоматически сохранить настройки
        saveSettings()
    }
    
    private func setupCalibrationManager() {
        // Подписаться на обновления калибровки
        calibrationManager.$isCalibrating
            .assign(to: &$isCalibrating)
    }
    
    var hasValidAPIKey: Bool {
        !apiKey.isEmpty && apiKey.count > 20
    }
    
    var cancellables = Set<AnyCancellable>()
    
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
