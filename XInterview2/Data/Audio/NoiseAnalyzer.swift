//
//  NoiseAnalyzer.swift
//  XInterview2
//
//  Adaptive noise analyzer with microphone calibration
//  Automatically adjusts thresholds based on background noise level
//

import AVFoundation
import Combine
import Foundation

// MARK: - Noise Analysis Result

struct NoiseAnalysisResult {
    let audioLevel: Float           // Current audio level (0.0-1.0)
    let noiseLevel: Float           // Estimated background noise level (0.0-1.0)
    let signalToNoiseRatio: Float   // SNR in dB
    let isVoiceDetected: Bool       // Whether voice is present
    let confidence: Float           // Detection confidence (0.0-1.0)
    let adaptiveThreshold: Float    // Current adaptive threshold
    let calibrationStatus: CalibrationStatus
    
    var description: String {
        String(format: "Level: %.3f, Noise: %.3f, SNR: %.1f dB, Voice: %@, Confidence: %.2f, Threshold: %.3f",
               audioLevel, noiseLevel, signalToNoiseRatio,
               isVoiceDetected ? "YES" : "NO", confidence, adaptiveThreshold)
    }
}

// MARK: - Calibration Status

enum CalibrationStatus {
    case notStarted
    case inProgress(progress: Float)  // 0.0 to 1.0
    case completed(noiseLevel: Float)
    case failed(Error)
}

// MARK: - Noise Analyzer Configuration

struct NoiseAnalyzerConfiguration {
    /// Duration of initial calibration in seconds
    let calibrationDuration: TimeInterval
    
    /// Minimum samples required for reliable calibration
    let minCalibrationSamples: Int
    
    /// SNR threshold for voice detection (in dB)
    let snrThreshold: Float
    
    /// Minimum audio level above noise to consider as voice (0.0-1.0)
    let minSignalAboveNoise: Float
    
    /// Smoothing factor for noise level estimation (0.0-1.0, higher = more responsive)
    let noiseSmoothingFactor: Float
    
    /// Window size for statistical analysis (number of samples)
    let statisticalWindowSize: Int
    
    /// Maximum noise level before considering environment too noisy (0.0-1.0)
    let maxAcceptableNoiseLevel: Float
    
    /// Minimum audio level to consider as potential voice (0.0-1.0)
    let minAbsoluteAudioLevel: Float
    
    static let `default` = NoiseAnalyzerConfiguration(
        calibrationDuration: 2.0,          // 2 seconds calibration
        minCalibrationSamples: 20,          // At least 20 samples
        snrThreshold: 6.0,                 // 6 dB SNR threshold
        minSignalAboveNoise: 0.05,         // Signal must be 5% above noise
        noiseSmoothingFactor: 0.1,         // 10% smoothing
        statisticalWindowSize: 10,          // 10 samples window
        maxAcceptableNoiseLevel: 0.3,      // Max 30% noise level
        minAbsoluteAudioLevel: 0.02        // Min 2% absolute level
    )
    
    static let sensitive = NoiseAnalyzerConfiguration(
        calibrationDuration: 2.0,
        minCalibrationSamples: 20,
        snrThreshold: 3.0,                 // More sensitive (3 dB)
        minSignalAboveNoise: 0.03,
        noiseSmoothingFactor: 0.15,
        statisticalWindowSize: 10,
        maxAcceptableNoiseLevel: 0.4,
        minAbsoluteAudioLevel: 0.015
    )
    
    static let strict = NoiseAnalyzerConfiguration(
        calibrationDuration: 3.0,          // Longer calibration
        minCalibrationSamples: 30,
        snrThreshold: 10.0,                // Stricter (10 dB)
        minSignalAboveNoise: 0.08,
        noiseSmoothingFactor: 0.05,        // Less smoothing
        statisticalWindowSize: 15,
        maxAcceptableNoiseLevel: 0.2,
        minAbsoluteAudioLevel: 0.03
    )
}

// MARK: - Noise Analyzer

@MainActor
class NoiseAnalyzer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var calibrationStatus: CalibrationStatus = .notStarted
    @Published var currentNoiseLevel: Float = 0.0
    @Published var adaptiveThreshold: Float = 0.0
    @Published var isCalibrated: Bool = false
    
    // MARK: - Configuration
    
    private let config: NoiseAnalyzerConfiguration
    
    // MARK: - State
    
    private var calibrationSamples: [Float] = []
    private var noiseLevelHistory: [Float] = []
    private var audioLevelHistory: [Float] = []
    private var calibrationStartTime: Date?
    private var calibrationTimer: Timer?
    private var estimatedNoiseLevel: Float = 0.0
    private var lastUpdateTime: Date?
    
    // MARK: - Statistics
    
    private var meanLevel: Float = 0.0
    private var stdDevLevel: Float = 0.0
    private var peakLevel: Float = 0.0
    
    // MARK: - Initialization
    
    init(configuration: NoiseAnalyzerConfiguration = .default) {
        self.config = configuration
        Logger.noise("NoiseAnalyzer initialized with configuration: \(config.calibrationDuration)s calibration")
    }
    
    deinit {
        calibrationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Start calibration to measure background noise
    func startCalibration() {
        Logger.noise("Starting calibration...")
        calibrationSamples.removeAll()
        noiseLevelHistory.removeAll()
        audioLevelHistory.removeAll()
        estimatedNoiseLevel = 0.0
        calibrationStartTime = Date()
        
        calibrationStatus = .inProgress(progress: 0.0)
        isCalibrated = false
        
        // Start calibration timer
        calibrationTimer?.invalidate()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkCalibrationProgress()
            }
        }
        
        Logger.noise("Calibration started - will collect samples for \(config.calibrationDuration)s")
    }
    
    /// Stop calibration
    func stopCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        Logger.noise("Calibration stopped")
    }
    
    /// Reset analyzer state
    func reset() {
        Logger.noise("Resetting analyzer state")
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
    
    /// Analyze audio level and determine if voice is present
    func analyze(audioLevel: Float) -> NoiseAnalysisResult {
        let now = Date()
        lastUpdateTime = now
        
        // Update history
        audioLevelHistory.append(audioLevel)
        if audioLevelHistory.count > config.statisticalWindowSize * 2 {
            audioLevelHistory.removeFirst()
        }
        
        // If calibrating, collect samples
        if case .inProgress = calibrationStatus {
            collectCalibrationSample(audioLevel)
        }
        
        // Update noise level estimation
        updateNoiseLevelEstimation(audioLevel)
        
        // Calculate statistics
        calculateStatistics()
        
        // Calculate adaptive threshold
        let threshold = calculateAdaptiveThreshold()
        adaptiveThreshold = threshold
        currentNoiseLevel = estimatedNoiseLevel
        
        // Detect voice
        let (isVoice, confidence) = detectVoice(audioLevel: audioLevel)
        
        // Calculate SNR
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
        
        // Log significant events
        if isVoice && confidence > 0.7 {
            Logger.noise("✅ Voice detected: \(result.description)")
        } else if case .completed = calibrationStatus {
            Logger.noise("🔊 Analysis: \(result.description)")
        }
        
        return result
    }
    
    /// Get current adaptive threshold
    func getCurrentThreshold() -> Float {
        return adaptiveThreshold
    }
    
    /// Get current noise level
    func getCurrentNoiseLevel() -> Float {
        return estimatedNoiseLevel
    }
    
    /// Check if environment is too noisy
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
        
        Logger.noise("✅ Calibration complete!")
        Logger.noise("   Samples collected: \(calibrationSamples.count)")
        Logger.noise("   Median level: \(String(format: "%.3f", medianNoise))")
        Logger.noise("   90th percentile: \(String(format: "%.3f", noiseFloor))")
        Logger.noise("   Estimated noise: \(String(format: "%.3f", estimatedNoiseLevel))")
        Logger.noise("   Mean: \(String(format: "%.3f", meanLevel))")
        Logger.noise("   Std Dev: \(String(format: "%.3f", stdDevLevel))")
        Logger.noise("   Adaptive threshold: \(String(format: "%.3f", adaptiveThreshold))")
        
        // Check if environment is too noisy
        if isEnvironmentTooNoisy() {
            Logger.warning("⚠️ Environment is noisy (noise level: \(String(format: "%.2f", estimatedNoiseLevel)))")
            Logger.warning("💡 Consider moving to a quieter location or using a better microphone")
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
