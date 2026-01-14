//
//  SettingsView.swift
//  XInterview2
//
//  Settings view for configuring API key and preferences
//

import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var audioTestViewModel = AudioTestViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init() {
        // Initialize on MainActor
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
        _audioTestViewModel = StateObject(wrappedValue: AudioTestViewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    
                    SecureField("Enter your API key", text: $viewModel.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 400)
                    
                    if viewModel.hasValidAPIKey {
                        Text("API key is valid ✓")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("API key is required - Get one at platform.openai.com")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Divider()
                
                // Audio Test Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio System Test")
                        .font(.headline)
                    
                    Text("Test your microphone to ensure voice recognition works properly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Audio level visualizer
                    AudioLevelView(
                        audioLevel: audioTestViewModel.audioLevel,
                        isRecording: audioTestViewModel.isRecording
                    )
                    
                    // Control buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await audioTestViewModel.startTest()
                            }
                        }) {
                            Label("Test Microphone (5s)", systemImage: "mic.fill")
                        }
                        .disabled(audioTestViewModel.isRecording)
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            Task {
                                await audioTestViewModel.stopTest()
                            }
                        }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .disabled(!audioTestViewModel.isRecording)
                    }
                    
                    // Status text
                    Text(audioTestViewModel.statusText)
                        .font(.caption)
                        .monospacedDigit()
                    
                    // Clear logs button
                    Button(action: {
                        audioTestViewModel.clearLogs()
                    }) {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    .font(.caption)
                    
                    // Audio logs display
                    if !audioTestViewModel.logs.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(audioTestViewModel.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(logColor(for: log))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(height: 200)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // Language Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interview Language")
                        .font(.headline)
                    
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(Language.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 400)
                }
                
                Divider()
                
                // Voice Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Voice")
                        .font(.headline)
                    
                    Picker("Voice", selection: $viewModel.selectedVoice) {
                        ForEach(viewModel.availableVoices, id: \.self) { voice in
                            Text(voice.capitalized).tag(voice)
                        }
                    }
                    .frame(minWidth: 400)
                }
                
                Divider()
                
                // Voice Threshold (Microphone Sensitivity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Threshold")
                        .font(.headline)
                    
                    Text("Microphone sensitivity for voice detection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Text("Less Sensitive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $viewModel.voiceThreshold, in: 0.05...0.5, step: 0.01)
                            .frame(minWidth: 200)
                        
                        Text("More Sensitive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current threshold:")
                            .font(.caption)
                        Text(String(format: "%.2f", viewModel.voiceThreshold))
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        // Show sensitivity level indicator
                        if viewModel.voiceThreshold < 0.15 {
                            Label("Very Sensitive", systemImage: "speaker.wave.3.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if viewModel.voiceThreshold < 0.25 {
                            Label("Sensitive", systemImage: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if viewModel.voiceThreshold < 0.35 {
                            Label("Normal", systemImage: "speaker.wave.1.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Label("Less Sensitive", systemImage: "speaker.slash.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Divider()
                
                // Silence Timeout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Silence Timeout")
                        .font(.headline)
                    
                    Text("How long to wait for silence after speech ends before processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Text("0.5s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $viewModel.silenceTimeout, in: 0.5...5.0, step: 0.5)
                            .frame(minWidth: 200)
                        
                        Text("5.0s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current timeout:")
                            .font(.caption)
                        Text("\(String(format: "%.1f", viewModel.silenceTimeout)) seconds")
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        // Show timeout indicator
                        if viewModel.silenceTimeout <= 1.0 {
                            Label("Quick", systemImage: "bolt.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if viewModel.silenceTimeout <= 2.0 {
                            Label("Normal", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if viewModel.silenceTimeout <= 3.0 {
                            Label("Slow", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Label("Very Slow", systemImage: "hourglass")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text("⚠️ Shorter timeout = faster but may cut off early speech")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button("Save") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(30)
        }
        .frame(width: 600, height: 850)
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("❌") {
            return .red
        } else if log.contains("⚠️") {
            return .orange
        } else if log.contains("✅") {
            return .green
        } else if log.contains("🗣️") {
            return .blue
        } else if log.contains("🎚️") {
            return .cyan
        } else {
            return .primary
        }
    }
}

// MARK: - Audio Test ViewModel

@MainActor
class AudioTestViewModel: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var statusText: String = "Ready to test"
    @Published var logs: [String] = []
    
    private let voiceDetector = VoiceDetector()
    private var testTask: Task<Void, Never>?
    private let testDuration: TimeInterval = 5.0
    
    init() {
        setupObservations()
    }
    
    private func setupObservations() {
        // Observe audio level
        voiceDetector.$audioLevel
            .assign(to: &$audioLevel)
    }
    
    func startTest() async {
        guard !isRecording else { return }
        
        isRecording = true
        statusText = "Testing..."
        logs.removeAll()
        
        addLog("🎙️ Starting microphone test for \(Int(testDuration)) seconds...")
        addLog("💡 Speak into your microphone to test voice detection")
        
        voiceDetector.startListening()
        
        // Monitor audio level during test
        testTask = Task {
            let startTime = Date()
            
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed >= testDuration {
                    break
                }
                
                // Log audio level periodically
                if Int(elapsed * 10) % 5 == 0 { // Every 0.5 seconds
                    let levelStr = String(format: "%.3f", audioLevel)
                    addLog("🎚️ Audio level: \(levelStr)")
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await stopTest()
        }
    }
    
    func stopTest() async {
        guard isRecording else { return }
        
        isRecording = false
        statusText = "Stopped"
        
        voiceDetector.stopListening()
        
        testTask?.cancel()
        testTask = nil
        
        addLog("🛑 Test stopped")
        
        await MainActor.run {
            statusText = "Ready to test"
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        addLog("🗑️ Logs cleared")
    }
    
    private func addLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logs.append("[\(timestamp)] \(message)")
        
        // Keep only last 100 logs
        if logs.count > 100 {
            logs.removeFirst()
        }
    }
}
