//
//  AudioCalibrationManager.swift
//  XInterview2
//
//  Audio calibration manager for noise level detection
//  Automatically calibrates microphone threshold based on background noise
//
//  Менеджер аудио калибровки для определения уровня шума
//  Автоматически калибрует порог микрофона на основе фонового шума
//

import AVFoundation
import Combine
import Foundation

// MARK: - Calibration Result

/// Результат калибровки уровня шума
struct CalibrationResult {
    let noiseLevel: Float           // Уровень фонового шума (0.0-1.0)
    let recommendedThreshold: Float  // Рекомендуемый порог для обнаружения речи
    let samplesCollected: Int        // Количество собранных сэмплов
    let duration: TimeInterval      // Длительность калибровки в секундах
    
    var description: String {
        String(format: "Noise: %.3f, Threshold: %.3f, Samples: %d, Duration: %.1fs",
               noiseLevel, recommendedThreshold, samplesCollected, duration)
    }
}

// MARK: - Audio Calibration Manager

/// Менеджер для калибровки уровня шума микрофона
/// Выполняет калибровку в течение указанного времени и возвращает оптимальный порог
@MainActor
class AudioCalibrationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Флаг indicates, что калибровка в процессе
    @Published var isCalibrating: Bool = false
    
    /// Прогресс калибровки (0.0 - 1.0)
    @Published var calibrationProgress: Double = 0.0
    
    /// Текущий уровень шума во время калибровки
    @Published var currentNoiseLevel: Float = 0.0
    
    /// Результат последней калибровки
    @Published var lastCalibrationResult: CalibrationResult?
    
    // MARK: - Configuration
    
    /// Длительность калибровки по умолчанию (в секундах)
    private let defaultCalibrationDuration: TimeInterval = 3.0
    
    /// Интервал сбора сэмплов (в секундах)
    private let sampleInterval: TimeInterval = 0.05
    
    /// Минимальное количество сэмплов для надежной калибровки
    private let minSamples: Int = 20
    
    /// Запас над уровнем шума для порога обнаружения речи (0.0-1.0)
    private let thresholdMargin: Float = 0.05
    
    /// Минимальный абсолютный порог (0.0-1.0)
    private let minAbsoluteThreshold: Float = 0.05
    
    /// Максимальный допустимый порог (0.0-1.0)
    private let maxAbsoluteThreshold: Float = 0.5
    
    // MARK: - Properties
    
    /// Рекордер аудио для записи с микрофона
    private var audioRecorder: AVAudioRecorder?
    
    /// URL временного файла записи
    private var recordingFileURL: URL?
    
    /// Сэмплы уровня аудио для калибровки
    private var calibrationSamples: [Float] = []
    
    /// Время начала калибровки
    private var calibrationStartTime: Date?
    
    /// Таймер для сбора сэмплов
    private var sampleTimer: Timer?
    
    /// Таймер для обновления прогресса
    private var progressTimer: Timer?
    
    /// Callback для завершения калибровки
    var onCalibrationComplete: ((CalibrationResult) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
    }
    
    deinit {
        Task { @MainActor in
            stopCalibration()
        }
    }
    
    
    // MARK: - Public Methods
    
    /// Выполнить калибровку уровня шума
    /// - Parameter duration: Длительность калибровки в секундах (по умолчанию 3.0)
    /// - Returns: Результат калибровки с рекомендуемым порогом
    func calibrateNoiseLevel(duration: TimeInterval = 3.0) async -> CalibrationResult {
        Logger.audio("Starting noise calibration for \(duration)s")
        
        await MainActor.run {
            isCalibrating = true
            calibrationProgress = 0.0
            currentNoiseLevel = 0.0
            calibrationSamples.removeAll()
            calibrationStartTime = Date()
        }
        
        // Начать запись
        startRecording()
        
        // Запустить таймер сбора сэмплов
        startSampleCollection(duration: duration)
        
        // Запустить таймер обновления прогресса
        startProgressTimer(duration: duration)
        
        // Ожидать завершения калибровки
        await waitForCalibrationComplete(duration: duration)
        
        // Вычислить результат
        let result = computeCalibrationResult()
        
        // Остановить запись
        stopRecording()
        
        await MainActor.run {
            // Сбросить состояние
            isCalibrating = false
            calibrationProgress = 1.0
            
            // Сохранить результат
            lastCalibrationResult = result
            
            // Логировать результат
            Logger.audio("Calibration complete: \(result.description)")
            
            // Вызвать callback
            onCalibrationComplete?(result)
        }
        
        return result
    }
    
    /// Остановить калибровку
    func stopCalibration() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        stopRecording()
        isCalibrating = false
    }
    
    // MARK: - Private Methods - Recording
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)
        #endif
    }
    
    private func startRecording() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "calibration_\(UUID().uuidString).wav"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        recordingFileURL = audioURL
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
        } catch {
            Logger.error("Failed to start recording for calibration", error: error)
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        if let url = recordingFileURL {
            try? FileManager.default.removeItem(at: url)
            recordingFileURL = nil
        }
    }
    
    // MARK: - Private Methods - Sample Collection
    
    private func startSampleCollection(duration: TimeInterval) {
        sampleTimer?.invalidate()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectSample()
            }
        }
    }
    
    private func collectSample() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        
        calibrationSamples.append(level)
        currentNoiseLevel = level
    }
    
    private func startProgressTimer(duration: TimeInterval) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.calibrationStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                self.calibrationProgress = min(1.0, elapsed / duration)
            }
        }
    }
    
    private func waitForCalibrationComplete(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        sampleTimer?.invalidate()
        sampleTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Private Methods - Computation
    
    private func computeCalibrationResult() -> CalibrationResult {
        let duration = calibrationStartTime.map { Date().timeIntervalSince($0) } ?? 0.0
        let samplesCollected = calibrationSamples.count
        
        guard samplesCollected >= minSamples else {
            Logger.warning("Insufficient samples collected: \(samplesCollected) < \(minSamples)")
            // Вернуть значения по умолчанию
            return CalibrationResult(
                noiseLevel: 0.0,
                recommendedThreshold: 0.15,
                samplesCollected: samplesCollected,
                duration: duration
            )
        }
        
        // Вычислить медианный уровень шума
        let sortedSamples = calibrationSamples.sorted()
        let medianIndex = sortedSamples.count / 2
        _ = sortedSamples[medianIndex]  // medianNoise - не используется
        
        // Использовать 90-й перцентиль для более надежной оценки
        let percentile90Index = Int(Double(sortedSamples.count) * 0.9)
        let noiseLevel = sortedSamples[min(percentile90Index, sortedSamples.count - 1)]
        
        // Вычислить рекомендуемый порог
        let baseThreshold = noiseLevel + thresholdMargin
        let recommendedThreshold = max(minAbsoluteThreshold, min(maxAbsoluteThreshold, baseThreshold))
        
        return CalibrationResult(
            noiseLevel: noiseLevel,
            recommendedThreshold: recommendedThreshold,
            samplesCollected: samplesCollected,
            duration: duration
        )
    }
}
