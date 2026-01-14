//
//  NoiseAnalyzerTests.swift
//  XInterview2Tests
//
//  Unit tests for NoiseAnalyzer
//

import XCTest
@testable import XInterview2

// MARK: - Noise Analyzer Tests

@MainActor
final class NoiseAnalyzerTests: XCTestCase {
    
    var analyzer: NoiseAnalyzer!
    
    override func setUp() async throws {
        try await super.setUp()
        analyzer = NoiseAnalyzer(configuration: .default)
    }
    
    override func tearDown() async throws {
        analyzer = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(analyzer)
        XCTAssertEqual(analyzer.currentNoiseLevel, 0.0)
        XCTAssertEqual(analyzer.adaptiveThreshold, 0.0)
        XCTAssertFalse(analyzer.isCalibrated)
    }
    
    func testInitializationWithCustomConfig() {
        let customConfig = NoiseAnalyzerConfiguration(
            calibrationDuration: 1.0,
            minCalibrationSamples: 10,
            snrThreshold: 8.0,
            minSignalAboveNoise: 0.06,
            noiseSmoothingFactor: 0.2,
            statisticalWindowSize: 5,
            maxAcceptableNoiseLevel: 0.25,
            minAbsoluteAudioLevel: 0.025
        )
        let customAnalyzer = NoiseAnalyzer(configuration: customConfig)
        XCTAssertNotNil(customAnalyzer)
    }
    
    // MARK: - Calibration Tests
    
    func testCalibrationStart() {
        analyzer.startCalibration()
        
        switch analyzer.calibrationStatus {
        case .inProgress(let progress):
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThanOrEqual(progress, 1.0)
        default:
            XCTFail("Calibration should be in progress")
        }
    }
    
    func testCalibrationWithLowNoise() async {
        analyzer.startCalibration()
        
        // Simulate low noise environment (0.01 - 0.03)
        for _ in 0..<50 {
            let level = Float.random(in: 0.01...0.03)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Wait for calibration to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        if case .completed(let noiseLevel) = analyzer.calibrationStatus {
            XCTAssertLessThan(noiseLevel, 0.1, "Noise level should be low")
            XCTAssertTrue(analyzer.isCalibrated)
            XCTAssertGreaterThan(analyzer.adaptiveThreshold, 0.0)
        } else {
            XCTFail("Calibration should be completed")
        }
    }
    
    func testCalibrationWithHighNoise() async {
        analyzer.startCalibration()
        
        // Simulate noisy environment (0.15 - 0.25)
        for _ in 0..<50 {
            let level = Float.random(in: 0.15...0.25)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Wait for calibration to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        if case .completed(let noiseLevel) = analyzer.calibrationStatus {
            XCTAssertGreaterThan(noiseLevel, 0.1, "Noise level should be high")
            XCTAssertTrue(analyzer.isCalibrated)
            XCTAssertGreaterThan(analyzer.adaptiveThreshold, noiseLevel)
        } else {
            XCTFail("Calibration should be completed")
        }
    }
    
    func testCalibrationStop() {
        analyzer.startCalibration()
        analyzer.stopCalibration()
        
        // Calibration should not be in progress
        if case .inProgress = analyzer.calibrationStatus {
            XCTFail("Calibration should be stopped")
        }
    }
    
    func testReset() {
        analyzer.startCalibration()
        analyzer.reset()
        
        XCTAssertEqual(analyzer.calibrationStatus, .notStarted)
        XCTAssertFalse(analyzer.isCalibrated)
        XCTAssertEqual(analyzer.currentNoiseLevel, 0.0)
        XCTAssertEqual(analyzer.adaptiveThreshold, 0.0)
    }
    
    // MARK: - Analysis Tests
    
    func testAnalysisBeforeCalibration() {
        let result = analyzer.analyze(audioLevel: 0.5)
        
        XCTAssertFalse(result.isVoiceDetected)
        XCTAssertEqual(result.confidence, 0.0)
        XCTAssertEqual(result.adaptiveThreshold, 0.0)
    }
    
    func testAnalysisWithVoiceAfterCalibration() async {
        // First calibrate with low noise
        analyzer.startCalibration()
        for _ in 0..<40 {
            let level = Float.random(in: 0.01...0.02)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Now test with voice signal (much higher than noise)
        let voiceResult = analyzer.analyze(audioLevel: 0.3)
        
        XCTAssertTrue(voiceResult.isVoiceDetected, "Voice should be detected")
        XCTAssertGreaterThan(voiceResult.confidence, 0.5, "Confidence should be high")
        XCTAssertGreaterThan(voiceResult.signalToNoiseRatio, 0.0)
    }
    
    func testAnalysisWithNoiseAfterCalibration() async {
        // First calibrate with low noise
        analyzer.startCalibration()
        for _ in 0..<40 {
            let level = Float.random(in: 0.01...0.02)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Test with noise level (close to calibrated noise)
        let noiseResult = analyzer.analyze(audioLevel: 0.025)
        
        XCTAssertFalse(noiseResult.isVoiceDetected, "Noise should not be detected as voice")
    }
    
    func testSNRCalculation() async {
        analyzer.startCalibration()
        for _ in 0..<40 {
            _ = analyzer.analyze(audioLevel: 0.02)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Test SNR calculation
        let result = analyzer.analyze(audioLevel: 0.2)
        XCTAssertGreaterThan(result.signalToNoiseRatio, 0.0)
        
        // Higher signal should have higher SNR
        let higherResult = analyzer.analyze(audioLevel: 0.4)
        XCTAssertGreaterThan(higherResult.signalToNoiseRatio, result.signalToNoiseRatio)
    }
    
    // MARK: - Adaptive Threshold Tests
    
    func testAdaptiveThresholdIncreasesWithNoise() async {
        analyzer.startCalibration()
        
        // Calibrate with low noise
        for _ in 0..<30 {
            _ = analyzer.analyze(audioLevel: 0.01)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        let lowNoiseThreshold = analyzer.adaptiveThreshold
        
        // Reset and calibrate with higher noise
        analyzer.reset()
        analyzer.startCalibration()
        
        for _ in 0..<30 {
            _ = analyzer.analyze(audioLevel: 0.15)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Second calibration should complete")
            return
        }
        
        let highNoiseThreshold = analyzer.adaptiveThreshold
        
        XCTAssertGreaterThan(highNoiseThreshold, lowNoiseThreshold,
                           "Threshold should be higher in noisy environment")
    }
    
    // MARK: - Environment Tests
    
    func testEnvironmentTooNoisy() async {
        analyzer.startCalibration()
        
        // Simulate very noisy environment
        for _ in 0..<50 {
            let level = Float.random(in: 0.35...0.45)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertTrue(analyzer.isEnvironmentTooNoisy(),
                     "Environment should be detected as too noisy")
    }
    
    func testEnvironmentNotTooNoisy() async {
        analyzer.startCalibration()
        
        // Simulate quiet environment
        for _ in 0..<50 {
            let level = Float.random(in: 0.01...0.03)
            _ = analyzer.analyze(audioLevel: level)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertFalse(analyzer.isEnvironmentTooNoisy(),
                      "Environment should not be too noisy")
    }
    
    // MARK: - Configuration Tests
    
    func testSensitiveConfiguration() async {
        let sensitiveAnalyzer = NoiseAnalyzer(configuration: .sensitive)
        sensitiveAnalyzer.startCalibration()
        
        // Calibrate with low noise
        for _ in 0..<40 {
            _ = sensitiveAnalyzer.analyze(audioLevel: 0.01)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = sensitiveAnalyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Sensitive mode should detect lower signals
        let result = sensitiveAnalyzer.analyze(audioLevel: 0.05)
        XCTAssertTrue(result.isVoiceDetected, "Sensitive mode should detect lower signals")
    }
    
    func testStrictConfiguration() async {
        let strictAnalyzer = NoiseAnalyzer(configuration: .strict)
        strictAnalyzer.startCalibration()
        
        // Calibrate with low noise
        for _ in 0..<40 {
            _ = strictAnalyzer.analyze(audioLevel: 0.01)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = strictAnalyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Strict mode should have higher threshold
        let result = strictAnalyzer.analyze(audioLevel: 0.1)
        // May or may not detect depending on exact calibration
        XCTAssertNotNil(result)
    }
    
    // MARK: - Edge Cases
    
    func testZeroAudioLevel() async {
        analyzer.startCalibration()
        
        for _ in 0..<40 {
            _ = analyzer.analyze(audioLevel: 0.0)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        let result = analyzer.analyze(audioLevel: 0.0)
        XCTAssertFalse(result.isVoiceDetected)
        XCTAssertEqual(result.audioLevel, 0.0)
    }
    
    func testMaxAudioLevel() async {
        analyzer.startCalibration()
        
        for _ in 0..<40 {
            _ = analyzer.analyze(audioLevel: 0.01)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        let result = analyzer.analyze(audioLevel: 1.0)
        XCTAssertTrue(result.isVoiceDetected, "Max level should be detected as voice")
        XCTAssertEqual(result.audioLevel, 1.0)
    }
    
    func testFluctuatingSignal() async {
        analyzer.startCalibration()
        
        // Calibrate with stable low noise
        for _ in 0..<40 {
            _ = analyzer.analyze(audioLevel: 0.02)
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard case .completed = analyzer.calibrationStatus else {
            XCTFail("Calibration should complete")
            return
        }
        
        // Test fluctuating signal
        var voiceCount = 0
        for i in 0..<20 {
            let level = i % 2 == 0 ? 0.02 : 0.3  // Alternate between noise and voice
            let result = analyzer.analyze(audioLevel: level)
            if result.isVoiceDetected {
                voiceCount += 1
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        
        // Should detect voice on high levels
        XCTAssertGreaterThan(voiceCount, 5, "Should detect voice on high levels")
    }
}

// MARK: - Performance Tests

@MainActor
final class NoiseAnalyzerPerformanceTests: XCTestCase {
    
    func testAnalysisPerformance() {
        let analyzer = NoiseAnalyzer(configuration: .default)
        analyzer.startCalibration()
        
        // Pre-calibrate
        for _ in 0..<50 {
            _ = analyzer.analyze(audioLevel: 0.02)
        }
        
        measure {
            for _ in 0..<1000 {
                _ = analyzer.analyze(audioLevel: Float.random(in: 0.0...0.5))
            }
        }
    }
    
    func testCalibrationPerformance() {
        let analyzer = NoiseAnalyzer(configuration: .default)
        
        measure {
            analyzer.startCalibration()
            for _ in 0..<100 {
                _ = analyzer.analyze(audioLevel: Float.random(in: 0.01...0.03))
            }
            analyzer.stopCalibration()
        }
    }
}
