//
//  VoiceDetector.swift
//  XInterview2
//
//  Voice Activity Detection for continuous speech recognition
//  Uses fixed threshold from settings for reliable speech detection
//
//  Детектор голосовой активности для непрерывного распознавания речи
//  Использует фиксированный порог из настроек для надежного обнаружения речи
//

import AVFoundation
import Combine
import Foundation

// MARK: - Voice Events
// MARK: - События голоса

/// События голосовой активности
/// Определяет различные состояния голосовой активности для обработки
enum VoiceEvent {
    case speechStarted                    // Речь началась
    case speechEnded(Data)                // Речь закончилась (аудиоданные для транскрибации)
    case silenceDetected                  // Обнаружена тишина
    case error(Error)                     // Произошла ошибка
}

// MARK: - VoiceDetector
// MARK: - Детектор голоса

/// Детектор голосовой активности
/// Обнаруживает начало и конец речи пользователя для транскрибации
/// Использует фиксированный порог из настроек для надежного обнаружения речи
@MainActor
class VoiceDetector: NSObject, ObservableObject {
    // MARK: - Published Properties
    // MARK: - Опубликованные свойства (для SwiftUI)
    
    /// Флаг indicates, что детектор активен и слушает микрофон
    @Published var isListening: Bool = false
    
    /// Текущий уровень аудио (0.0 - 1.0) для отображения в UI
    @Published var audioLevel: Float = 0.0
    
    /// Флаг indicates, что речь была обнаружена
    @Published var speechDetected: Bool = false
    
    /// Флаг indicates, что таймер тишины активен (ожидание подтверждения окончания речи)
    @Published var isSilenceTimerActive: Bool = false
    
    /// Прогресс таймера тишины (0.0 - 1.0)
    @Published var silenceTimerProgress: Double = 0.0
    
    /// Прошедшее время в тишине в секундах
    @Published var silenceTimerElapsed: Double = 0.0
    
    // MARK: - Configuration
    // MARK: - Конфигурация
    
    /// Порог тишины для определения конца речи
    private let silenceThreshold: Float = 0.05
    
    /// Порог начала речи (настраивается через настройки)
    private var speechStartThreshold: Float
    
    /// Тайм-аут тишины в секундах (настраивается через настройки)
    private var silenceTimeout: TimeInterval
    
    /// Минимальная длительность речи для валидации (фильтрация коротких шумов)
    private let minSpeechDuration: TimeInterval = 0.2
    
    /// Минимальный средний уровень аудио для валидации речи (фильтрация тихих шумов)
    private var minSpeechLevel: Float = 0.04
    
    /// Максимальная длительность записи (защита от бесконечной записи)
    private let maxRecordingDuration: TimeInterval = 30.0
    
    // MARK: - Properties
    // MARK: - Свойства
    
    /// Рекордер аудио для записи с микрофона
    private var audioRecorder: AVAudioRecorder?
    
    /// URL временного файла записи
    private var recordingFileURL: URL?
    
    /// Время начала записи
    private var recordingStartTime: Date?
    
    /// Время начала речи (для вычисления длительности)
    private var speechStartTime: Date?
    
    /// Время начала тишины (для вычисления длительности тишины)
    private var silenceStartTime: Date?
    
    /// Буфер аудиоданных для отправки на транскрибацию
    private var audioBuffer: Data?
    
    /// Таймер для мониторинга уровня аудио (каждые 0.05 сек)
    private var levelMonitorTimer: Timer?
    
    /// Таймер ожидания тишины (подтверждение окончания речи)
    private var silenceTimer: Timer?
    
    /// Таймер для анимации прогресса тишины
    private var silenceProgressTimer: Timer?
    
    // MARK: - State Flags
    // MARK: - Флаги состояния
    
    /// Флаг indicates, что запись активна
    private var isRecording: Bool = false
    
    /// Флаг indicates, что речь в данный момент активна
    private var isSpeechActive: Bool = false
    
    /// Флаг indicates, что детектор на паузе
    private var isPaused: Bool = false
    
    // MARK: - Callbacks
    // MARK: - Обратные вызовы
    
    /// Callback для событий голосовой активности
    var onVoiceEvent: ((VoiceEvent) -> Void)?
    
    // MARK: - Initialization
    // MARK: - Инициализация
    
    /// Инициализатор по умолчанию
    override init() {
        self.speechStartThreshold = 0.15
        self.silenceTimeout = 1.5
        super.init()
        setupAudioSession()
    }
    
    /// Инициализатор с настраиваемыми параметрами
    init(speechThreshold: Float, silenceTimeout: Double = 1.5, minSpeechLevel: Float = 0.04) {
        self.speechStartThreshold = speechThreshold
        self.silenceTimeout = silenceTimeout
        self.minSpeechLevel = minSpeechLevel
        super.init()
        setupAudioSession()
    }
    
    /// Деинициализация - очистка ресурсов
    deinit {
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    /// Настройка аудио сессии для записи
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)
        #endif
    }
    
    // MARK: - Public Methods
    // MARK: - Публичные методы
    
    /// Обновить порог начала речи
    func updateThreshold(_ threshold: Float) {
        speechStartThreshold = threshold
    }
    
    /// Обновить тайм-аут тишины
    func updateSilenceTimeout(_ timeout: Double) {
        self.silenceTimeout = timeout
    }
    
    /// Обновить минимальный уровень речи для валидации
    func updateMinSpeechLevel(_ level: Float) {
        self.minSpeechLevel = level
        Logger.voice("VoiceDetector.minSpeechLevel updated to: \(level)")
    }
    
    /// Начать прослушивание микрофона
    func startListening() {
        guard !isListening else { return }
        
        Logger.voice("VoiceDetector.startListening()")
        isListening = true
        isPaused = false
        
        startRecording()
        startLevelMonitoring()
    }
    
    /// Остановить прослушивание микрофона
    func stopListening() {
        Logger.voice("VoiceDetector.stopListening()")
        isListening = false
        isPaused = true
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        
        stopRecording()
        stopLevelMonitoring()
    }
    
    /// Приостановить прослушивание (без остановки записи)
    func pauseListening() {
        Logger.voice("VoiceDetector.pauseListening()")
        isPaused = true
        stopLevelMonitoring()
    }
    
    /// Возобновить прослушивание
    func resumeListening() {
        Logger.voice("VoiceDetector.resumeListening()")
        isPaused = false
        startLevelMonitoring()
    }
    
    // MARK: - Recording
    // MARK: - Запись аудио
    
    /// Начать запись аудио с микрофона
    private func startRecording() {
        // Создать временный файл для записи
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "speech_\(UUID().uuidString).wav"
        let audioURL = documentsDirectory.appendingPathComponent(fileName)
        recordingFileURL = audioURL
        
        // Настройки формата аудио: PCM 16-bit, 16kHz, моно
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            // Создать и запустить рекордер
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            audioBuffer = Data()
            
            // Сбросить состояние
            isSpeechActive = false
            speechDetected = false
        } catch {
            Logger.error("Failed to start recording", error: error)
            onVoiceEvent?(.error(error))
        }
    }
    
    /// Остановить запись и сохранить аудиоданные
    private func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        // Сохранить аудиоданные без отправки события
        if let url = recordingFileURL {
            do {
                let data = try Data(contentsOf: url)
                if !data.isEmpty {
                    audioBuffer = data
                } else {
                    audioBuffer = nil
                }
                // Удалить временный файл
                try? FileManager.default.removeItem(at: url)
            } catch {
                Logger.error("Failed to store audio data", error: error)
                audioBuffer = nil
            }
        }
        
        // Сбросить состояние
        recordingFileURL = nil
        isSpeechActive = false
        speechDetected = false
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    // MARK: - Level Monitoring
    // MARK: - Мониторинг уровня аудио
    
    /// Запустить мониторинг уровня аудио (каждые 0.05 сек)
    private func startLevelMonitoring() {
        stopLevelMonitoring()
        
        levelMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkAudioLevel()
            }
        }
    }
    
    /// Остановить мониторинг уровня аудио
    private func stopLevelMonitoring() {
        levelMonitorTimer?.invalidate()
        levelMonitorTimer = nil
    }
    
    /// Проверить уровень аудио и определить состояние речи
    /// Основная логика обнаружения голосовой активности
    private func checkAudioLevel() {
        guard isListening, !isPaused else {
            return
        }
        
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0.0
            return
        }
        
        // Получить средний уровень мощности аудио
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        // Нормализовать в диапазон 0.0-1.0 (от -60dB до 0dB)
        let level = max(0.0, min(1.0, (averagePower + 60) / 60))
        audioLevel = level
        
        // Использовать фиксированный порог из настроек
        let effectiveThreshold = speechStartThreshold
        let isAboveThreshold = level > speechStartThreshold
        
        // Речь началась
        if isAboveThreshold && !isSpeechActive {
            isSpeechActive = true
            speechStartTime = Date()
            speechDetected = true
            silenceTimer?.invalidate()
            silenceTimer = nil
            silenceStartTime = nil
            
            Logger.voice("VoiceDetector.speechStarted() - Level: \(String(format: "%.2f", level)) > Threshold: \(String(format: "%.2f", effectiveThreshold))")
            onVoiceEvent?(.speechStarted)
        }
        // Речь продолжается (отменить таймер тишины если пользователь все еще говорит)
        else if isAboveThreshold && isSpeechActive {
            if let timer = silenceTimer, timer.isValid {
                timer.invalidate()
                silenceTimer = nil
                silenceProgressTimer?.invalidate()
                silenceProgressTimer = nil
            }
            silenceStartTime = nil
            isSilenceTimerActive = false
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
        }
        // Речь возможно закончилась
        else if !isAboveThreshold && isSpeechActive {
            // Предотвратить создание дубликатов таймеров тишины
            guard silenceTimer == nil || !silenceTimer!.isValid else {
                return
            }
            
            // Запустить таймер тишины для подтверждения окончания речи
            silenceTimer?.invalidate()
            silenceTimer = nil
            
            silenceStartTime = Date()
            isSilenceTimerActive = true
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
            
            Logger.voice("VoiceDetector.silenceDetected() - Level: \(String(format: "%.2f", level)) < Threshold: \(String(format: "%.2f", effectiveThreshold))")
            
            // Запустить таймер анимации прогресса
            let timeoutValue = self.silenceTimeout
            let silenceStartValue = self.silenceStartTime
            silenceProgressTimer?.invalidate()
            silenceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let start = silenceStartValue else { return }
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1.0, elapsed / timeoutValue)
                
                MainActor.assumeIsolated {
                    self.silenceTimerProgress = progress
                    self.silenceTimerElapsed = elapsed
                }
                
                // Публиковать в UI при каждом обновлении
                NotificationCenter.default.post(
                    name: .silenceTimerUpdated,
                    object: self,
                    userInfo: [
                        "progress": progress,
                        "elapsed": elapsed,
                        "timeout": timeoutValue
                    ]
                )
            }
            
            // Основной таймер тишины
            silenceTimer = Timer.scheduledTimer(
                withTimeInterval: timeoutValue,
                repeats: false
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleSpeechEnd()
                }
            }
        }
        
        // Проверить максимальную длительность записи
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration >= maxRecordingDuration {
                Logger.warning("VoiceDetector.maxDurationReached() - Duration: \(String(format: "%.1f", duration))s")
                stopRecording()
                // Перезапустить немедленно для непрерывного прослушивания
                startRecording()
                startLevelMonitoring()
            }
        }
    }
    
    /// Обрезать WAV данные до указанного диапазона времени
    /// Использует AVAssetExportSession для точного обрезания без перекодирования
    private func trimWAVData(_ data: Data, 
                            startOffset: TimeInterval, 
                            duration: TimeInterval) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let inputFileURL = tempDir.appendingPathComponent("input_\(UUID().uuidString).wav")
        let outputFileURL = tempDir.appendingPathComponent("output_\(UUID().uuidString).wav")
        
        defer {
            // Очистить временные файлы
            try? FileManager.default.removeItem(at: inputFileURL)
            try? FileManager.default.removeItem(at: outputFileURL)
        }
        
        // Записать оригинальные данные во временный файл
        try data.write(to: inputFileURL)
        
        // Создать актив и сессию экспорта
        let asset = AVAsset(url: inputFileURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough  // Использовать passthrough для избежания перекодирования
        ) else {
            throw NSError(domain: "AudioTrim", code: -1, 
                       userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputFileURL
        exportSession.outputFileType = .wav
        
        // Установить временной диапазон для обрезания
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startOffset, preferredTimescale: 16000),
            duration: CMTime(seconds: duration, preferredTimescale: 16000)
        )
        
        // Экспортировать
        await exportSession.export()
        
        if let error = exportSession.error {
            Logger.error("Export failed", error: error)
            throw error
        }
        
        // Прочитать обрезанные данные
        let trimmedData = try Data(contentsOf: outputFileURL)
        
        let originalSizeKB = Double(data.count) / 1024
        let trimmedSizeKB = Double(trimmedData.count) / 1024
        let savedKB = originalSizeKB - trimmedSizeKB
        let savedPercent = (savedKB / originalSizeKB) * 100
        
        let bytesPerSecond = 32000.0  // 16kHz * 2 bytes * 1 channel
        let originalDuration = Double(data.count - 44) / bytesPerSecond
        
        return trimmedData
    }
    
    /// Вычислить средний уровень аудио из данных WAV
    /// Используется для фильтрации тихих шумов
    private func calculateAverageLevel(from data: Data) -> Float {
 
        guard data.count > 44 else { return 0.0 }
        
        // Пропустить WAV заголовок (44 байта)
        let samplesData = data.dropFirst(44)
        let sampleCount = samplesData.count / 2
        guard sampleCount > 0 else { return 0.0 }
        
        var sum: Float = 0
        samplesData.withUnsafeBytes { rawBuffer in
            guard let buffer = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<sampleCount {
                let sample = abs(Float(buffer[i]))
                sum += sample
            }
        }
        
        let average = sum / Float(sampleCount)
        // Нормализовать в диапазон 0.0-1.0 (максимум Int16 = 32768)
        return min(1.0, average / 32768.0)
    }
    
    /// Обработать окончание речи
    /// Основная логика завершения записи и отправки аудиоданных
    private func handleSpeechEnd() {
        guard isSpeechActive,
              let startTime = speechStartTime,
              let recordingStart = recordingStartTime else { return }
        
        // Использовать silenceStartTime для точной длительности речи (исключает тайм-аут тишины)
        let silenceStart = silenceStartTime ?? Date()
        let duration = silenceStart.timeIntervalSince(startTime)
        
        // Остановить индикаторы тишины
        isSilenceTimerActive = false
        silenceTimerProgress = 0.0
        silenceTimerElapsed = 0.0
        silenceProgressTimer?.invalidate()
        silenceProgressTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Отправить уведомление для сброса индикатора UI
        NotificationCenter.default.post(name: .silenceTimerReset, object: self)
        
        // Обработать только если речь длилась достаточно долго
        guard duration >= minSpeechDuration else {

            isSpeechActive = false
            speechStartTime = nil
            return
        }
        
        // Вычислить смещения для обрезания
        let startOffset = startTime.timeIntervalSince(recordingStart)
        let speechDuration = duration
        
        // Остановить запись для получения аудиоданных
        stopRecording()
        
        // Применить обрезание
        if let originalData = audioBuffer {
            
            // Обработать асинхронное обрезание в Task
            Task {
                do {
                    let trimmedData = try await trimWAVData(originalData, 
                                                      startOffset: startOffset, 
                                                      duration: speechDuration)
                    
                    // Проверить средний уровень аудио для фильтрации тихих шумов
                    let avgLevel = calculateAverageLevel(from: trimmedData)
                    if avgLevel < minSpeechLevel {
                        Logger.warning("VoiceDetector.audioTooQuiet() - Avg level: \(String(format: "%.3f", avgLevel)) < \(minSpeechLevel)")
                        // Не отправлять событие, просто перезапустить прослушивание
                        return
                    }
                    
                    onVoiceEvent?(.speechEnded(trimmedData))
                } catch {
                    // Использовать оригинальные данные если обрезание не удалось
                    Logger.error("VoiceDetector.trimFailed() - Using original audio", error: error)
                    let originalSizeKB = Double(originalData.count) / 1024
                    Logger.voice("VoiceDetector.sendingAudio() - Original size: \(String(format: "%.1f", originalSizeKB)) KB")
                    onVoiceEvent?(.speechEnded(originalData))
                }
            }
        }
        
        // Перезапустить запись для непрерывного прослушивания
        if isListening {
            startRecording()
            startLevelMonitoring()
        }
    }
}
