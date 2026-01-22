//
//  NoiseAnalyzer.swift
//  XInterview2
//
//  Adaptive noise analyzer with microphone calibration
//  Automatically adjusts thresholds based on background noise level
//
//  Адаптивный анализатор шума с калибровкой микрофона
//  Автоматически настраивает пороги на основе уровня фонового шума
//

import AVFoundation
import Combine
import Foundation

// MARK: - Noise Analysis Result
// MARK: - Результат анализа шума

/// Результат анализа шума
struct NoiseAnalysisResult {
    let audioLevel: Float           // Текущий уровень аудио (0.0-1.0)
    let noiseLevel: Float           // Оцененный уровень фонового шума (0.0-1.0)
    let signalToNoiseRatio: Float   // Отношение сигнал/шум в дБ
    let isVoiceDetected: Bool       // Присутствует ли голос
    let confidence: Float           // Уверенность обнаружения (0.0-1.0)
    let adaptiveThreshold: Float    // Текущий адаптивный порог
    let calibrationStatus: CalibrationStatus
    
    var description: String {
        String(format: "Level: %.3f, Noise: %.3f, SNR: %.1f dB, Voice: %@, Confidence: %.2f, Threshold: %.3f",
               audioLevel, noiseLevel, signalToNoiseRatio,
               isVoiceDetected ? "YES" : "NO", confidence, adaptiveThreshold)
    }
}

// MARK: - Calibration Status
// MARK: - Статус калибровки

/// Статус калибровки анализатора шума
enum CalibrationStatus {
    case notStarted                                      // Калибровка не началась
    case inProgress(progress: Float)                      // В процессе (0.0 - 1.0)
    case completed(noiseLevel: Float)                     // Завершена
    case failed(Error)                                    // Ошибка
}

// MARK: - Noise Analyzer Configuration
// MARK: - Конфигурация анализатора шума

/// Конфигурация анализатора шума
struct NoiseAnalyzerConfiguration {
    /// Длительность начальной калибровки в секундах
    let calibrationDuration: TimeInterval
    
    /// Минимальное количество сэмплов для надежной калибровки
    let minCalibrationSamples: Int
    
    /// Порог SNR для обнаружения голоса (в дБ)
    let snrThreshold: Float
    
    /// Минимальный уровень аудио выше шума для рассмотрения как голос (0.0-1.0)
    let minSignalAboveNoise: Float
    
    /// Коэффициент сглаживания для оценки уровня шума (0.0-1.0, выше = более отзывчивый)
    let noiseSmoothingFactor: Float
    
    /// Размер окна для статистического анализа (количество сэмплов)
    let statisticalWindowSize: Int
    
    /// Максимальный уровень шума перед тем, как считать окружение слишком шумным (0.0-1.0)
    let maxAcceptableNoiseLevel: Float
    
    /// Минимальный уровень аудио для рассмотрения как потенциальный голос (0.0-1.0)
    let minAbsoluteAudioLevel: Float
    
    /// Конфигурация по умолчанию
    static let `default` = NoiseAnalyzerConfiguration(
        calibrationDuration: 2.0,          // 2 секунды калибровки
        minCalibrationSamples: 20,          // Минимум 20 сэмплов
        snrThreshold: 6.0,                 // Порог SNR 6 дБ
        minSignalAboveNoise: 0.05,         // Сигнал должен быть на 5% выше шума
        noiseSmoothingFactor: 0.1,         // 10% сглаживание
        statisticalWindowSize: 10,          // Окно из 10 сэмплов
        maxAcceptableNoiseLevel: 0.3,      // Максимум 30% шума
        minAbsoluteAudioLevel: 0.02        // Минимум 2% абсолютный уровень
    )
    
    /// Чувствительная конфигурация (более чувствительная к тихой речи)
    static let sensitive = NoiseAnalyzerConfiguration(
        calibrationDuration: 2.0,
        minCalibrationSamples: 20,
        snrThreshold: 3.0,                 // Более чувствительный (3 дБ)
        minSignalAboveNoise: 0.03,
        noiseSmoothingFactor: 0.15,
        statisticalWindowSize: 10,
        maxAcceptableNoiseLevel: 0.4,
        minAbsoluteAudioLevel: 0.015
    )
    
    /// Строгая конфигурация (меньше ложных срабатываний)
    static let strict = NoiseAnalyzerConfiguration(
        calibrationDuration: 3.0,          // Более длинная калибровка
        minCalibrationSamples: 30,
        snrThreshold: 10.0,                // Более строгий (10 дБ)
        minSignalAboveNoise: 0.08,
        noiseSmoothingFactor: 0.05,        // Меньше сглаживания
        statisticalWindowSize: 15,
        maxAcceptableNoiseLevel: 0.2,
        minAbsoluteAudioLevel: 0.03
    )
}

// MARK: - Noise Analyzer
// MARK: - Анализатор шума

/// Адаптивный анализатор шума для автоматической настройки порогов обнаружения речи
/// Выполняет калибровку фонового шума и адаптивно настраивает пороги
@MainActor
class NoiseAnalyzer: ObservableObject {
    
    // MARK: - Published Properties
    // MARK: - Опубликованные свойства
    
    /// Статус калибровки
    @Published var calibrationStatus: CalibrationStatus = .notStarted
    
    /// Текущий уровень шума
    @Published var currentNoiseLevel: Float = 0.0
    
    /// Текущий адаптивный порог
    @Published var adaptiveThreshold: Float = 0.0
    
    /// Флаг indicates, что калибровка завершена
    @Published var isCalibrated: Bool = false
    
    // MARK: - Configuration
    // MARK: - Конфигурация
    
    /// Конфигурация анализатора шума
    private let config: NoiseAnalyzerConfiguration
    
    // MARK: - State
    // MARK: - Состояние
    
    /// Сэмплы для калибровки
    private var calibrationSamples: [Float] = []
    
    /// История уровней шума
    private var noiseLevelHistory: [Float] = []
    
    /// История уровней аудио
    private var audioLevelHistory: [Float] = []
    
    /// Время начала калибровки
    private var calibrationStartTime: Date?
    
    /// Таймер калибровки
    private var calibrationTimer: Timer?
    
    /// Оцененный уровень шума
    private var estimatedNoiseLevel: Float = 0.0
    
    /// Время последнего обновления
    private var lastUpdateTime: Date?
    
    // MARK: - Statistics
    // MARK: - Статистика
    
    /// Средний уровень
    private var meanLevel: Float = 0.0
    
    /// Стандартное отклонение
    private var stdDevLevel: Float = 0.0
    
    /// Пиковый уровень
    private var peakLevel: Float = 0.0
    
    // MARK: - Initialization
    // MARK: - Инициализация
    
    /// Инициализировать анализатор шума с конфигурацией
    init(configuration: NoiseAnalyzerConfiguration = .default) {
        self.config = configuration
    }
    
    /// Деинициализация - очистка таймера
    deinit {
        calibrationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    // MARK: - Публичные методы
    
    /// Начать калибровку для измерения фонового шума
    func startCalibration() {
        calibrationSamples.removeAll()
        noiseLevelHistory.removeAll()
        audioLevelHistory.removeAll()
        estimatedNoiseLevel = 0.0
        calibrationStartTime = Date()
        
        calibrationStatus = .inProgress(progress: 0.0)
        isCalibrated = false
        
        // Запустить таймер калибровки
        calibrationTimer?.invalidate()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkCalibrationProgress()
            }
        }
        
    }
    
    /// Остановить калибровку
    func stopCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
    }
    
    /// Сбросить состояние анализатора
    func reset() {
        stopCalibration()
        calibrationSamples.removeAll()
        noiseLevelHistory.removeAll()
        audioLevelHistory.removeAll()
        estimatedNoiseLevel = 0.0
        meanLevel = 0.0
        stdDevLevel = 0.0
        peakLevel = 0.0
        calibrationStatus = .notStarted
        isCalibrated = false
        currentNoiseLevel = 0.0
        adaptiveThreshold = 0.0
    }
    
    /// Проанализировать уровень аудио и определить присутствует ли голос
    func analyze(audioLevel: Float) -> NoiseAnalysisResult {
        let now = Date()
        lastUpdateTime = now
        
        // Обновить историю
        audioLevelHistory.append(audioLevel)
        if audioLevelHistory.count > config.statisticalWindowSize * 2 {
            audioLevelHistory.removeFirst()
        }
        
        // Если калибруется, собирать сэмплы
        if case .inProgress = calibrationStatus {
            collectCalibrationSample(audioLevel)
        }
        
        // Обновить оценку уровня шума
        updateNoiseLevelEstimation(audioLevel)
        
        // Вычислить статистику
        calculateStatistics()
        
        // Вычислить адаптивный порог
        let threshold = calculateAdaptiveThreshold()
        adaptiveThreshold = threshold
        currentNoiseLevel = estimatedNoiseLevel
        
        // Обнаружить голос
        let (isVoice, confidence) = detectVoice(audioLevel: audioLevel)
        
        // Вычислить SNR
        let snr = calculateSNR(audioLevel: audioLevel)
        
        let result = NoiseAnalysisResult(
            audioLevel: audioLevel,
            noiseLevel: estimatedNoiseLevel,
            signalToNoiseRatio: snr,
            isVoiceDetected: isVoice,
            confidence: confidence,
            adaptiveThreshold: threshold,
            calibrationStatus: calibrationStatus
        )
        
        // Логировать значимые события
        if isVoice && confidence > 0.7 {
            // Voice detected
        }
        
        return result
    }
    
    /// Получить текущий адаптивный порог
    func getCurrentThreshold() -> Float {
        return adaptiveThreshold
    }
    
    /// Получить текущий уровень шума
    func getCurrentNoiseLevel() -> Float {
        return estimatedNoiseLevel
    }
    
    /// Проверить, слишком ли шумное окружение
    func isEnvironmentTooNoisy() -> Bool {
        return estimatedNoiseLevel > config.maxAcceptableNoiseLevel
    }
    
    // MARK: - Private Methods - Calibration
    
    private func collectCalibrationSample(_ level: Float) {
        calibrationSamples.append(level)
        
        // Update progress
        if let startTime = calibrationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = Float(elapsed / config.calibrationDuration)
            calibrationStatus = .inProgress(progress: min(1.0, progress))
        }
    }
    
    private func checkCalibrationProgress() {
        guard let startTime = calibrationStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        if elapsed >= config.calibrationDuration {
            completeCalibration()
        } else if calibrationSamples.count >= config.minCalibrationSamples * 3 {
            // Early completion if we have enough samples
            completeCalibration()
        }
    }
    
    private func completeCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        
        guard calibrationSamples.count >= config.minCalibrationSamples else {
            let error = NSError(
                domain: "NoiseAnalyzer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Insufficient calibration samples: \(calibrationSamples.count)"]
            )
            calibrationStatus = .failed(error)
            Logger.error("Calibration failed: insufficient samples", error: error)
            return
        }
        
        // Calculate noise level from samples
        let sortedSamples = calibrationSamples.sorted()
        let medianIndex = sortedSamples.count / 2
        let medianNoise = sortedSamples[medianIndex]
        
        // Use 90th percentile as noise floor (more robust)
        let percentile90Index = Int(Double(sortedSamples.count) * 0.9)
        let noiseFloor = sortedSamples[min(percentile90Index, sortedSamples.count - 1)]
        
        // Estimated noise level is slightly above the noise floor
        estimatedNoiseLevel = min(noiseFloor * 1.2, config.maxAcceptableNoiseLevel)
        
        // Calculate initial statistics
        calculateStatistics()
        
        calibrationStatus = .completed(noiseLevel: estimatedNoiseLevel)
        isCalibrated = true
        
        // Calibration complete
        
        // Check if environment is too noisy
        if isEnvironmentTooNoisy() {
            // Environment is noisy
        }
    }
    
    // MARK: - Private Methods - Analysis
    
    private func updateNoiseLevelEstimation(_ level: Float) {
        guard isCalibrated else { return }
        
        // Only update noise level when signal is likely noise (not voice)
        // Use statistical approach: if level is close to recent minimum, it's noise
        let recentMin = audioLevelHistory.min() ?? 0.0
        let isLikelyNoise = abs(level - recentMin) < stdDevLevel * 2
        
        if isLikelyNoise || level < estimatedNoiseLevel {
            // Update noise level with smoothing
            estimatedNoiseLevel = config.noiseSmoothingFactor * level +
                                  (1 - config.noiseSmoothingFactor) * estimatedNoiseLevel
        }
        
        // Update noise history
        noiseLevelHistory.append(estimatedNoiseLevel)
        if noiseLevelHistory.count > config.statisticalWindowSize {
            noiseLevelHistory.removeFirst()
        }
    }
    
    private func calculateStatistics() {
        let samples = isCalibrated ? audioLevelHistory : calibrationSamples
        guard samples.count > 0 else { return }
        
        // Calculate mean
        meanLevel = samples.reduce(0, +) / Float(samples.count)
        
        // Calculate standard deviation
        if samples.count > 1 {
            let variance = samples.map { pow($0 - meanLevel, 2) }.reduce(0, +) / Float(samples.count - 1)
            stdDevLevel = sqrt(variance)
        }
        
        // Track peak
        peakLevel = max(peakLevel, samples.max() ?? 0)
    }
    
    private func calculateAdaptiveThreshold() -> Float {
        guard isCalibrated else {
            // Return default threshold during calibration
            return estimatedNoiseLevel + config.minSignalAboveNoise
        }
        
        // Base threshold is noise level + minimum signal
        let baseThreshold = estimatedNoiseLevel + config.minSignalAboveNoise
        
        // Add statistical margin based on standard deviation
        let statisticalMargin = stdDevLevel * 1.5
        
        // Ensure minimum absolute level
        let absoluteThreshold = max(baseThreshold, config.minAbsoluteAudioLevel)
        
        // Final threshold with statistical margin
        let finalThreshold = absoluteThreshold + statisticalMargin
        
        // Clamp to reasonable range
        return min(max(finalThreshold, config.minAbsoluteAudioLevel), 0.8)
    }
    
    private func detectVoice(audioLevel: Float) -> (isVoice: Bool, confidence: Float) {
        guard isCalibrated else {
            return (false, 0.0)
        }
        
        let threshold = adaptiveThreshold
        
        // Check minimum absolute level
        guard audioLevel >= config.minAbsoluteAudioLevel else {
            return (false, 0.0)
        }
        
        // Check if above adaptive threshold
        let isAboveThreshold = audioLevel > threshold
        
        // Calculate SNR
        let snr = calculateSNR(audioLevel: audioLevel)
        let isAboveSNR = snr >= config.snrThreshold
        
        // Combine criteria
        let isVoice = isAboveThreshold && isAboveSNR
        
        // Calculate confidence
        var confidence: Float = 0.0
        
        if isVoice {
            // Confidence based on how far above threshold
            let margin = audioLevel - threshold
            let marginConfidence = min(1.0, margin / (threshold * 0.5))
            
            // Confidence based on SNR
            let snrMargin = snr - config.snrThreshold
            let snrConfidence = min(1.0, snrMargin / 5.0)
            
            // Combined confidence
            confidence = (marginConfidence * 0.6) + (snrConfidence * 0.4)
        } else {
            // Confidence that it's NOT voice (noise)
            if audioLevel < threshold {
                let belowMargin = threshold - audioLevel
                confidence = min(1.0, belowMargin / (threshold * 0.3))
            }
        }
        
        return (isVoice, confidence)
    }
    
    private func calculateSNR(audioLevel: Float) -> Float {
        guard estimatedNoiseLevel > 0.001 else {
            // If noise level is very low, assume high SNR
            return 60.0
        }
        
        guard audioLevel > estimatedNoiseLevel else {
            return 0.0
        }
        
        // SNR in dB: 20 * log10(signal / noise)
        let ratio = audioLevel / estimatedNoiseLevel
        return 20 * log10(ratio)
    }
}

// MARK: - Logger Extension

extension Logger {
    static func noise(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("🎤 [NoiseAnalyzer] \(message)", file: file, function: function, line: line)
    }
}
