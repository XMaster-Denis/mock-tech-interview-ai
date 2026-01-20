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
    @AppStorage(UserDefaultsKeys.selectedInterfaceLanguage) private var interfaceLanguageRaw = Language.english.rawValue
    
    init() {
        // Initialize on MainActor
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
        _audioTestViewModel = StateObject(wrappedValue: AudioTestViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    leftColumn
                    rightColumn
                }
                .padding(30)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("settings.save") {
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                
                Button("settings.cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 860, height: 800)
        .environment(\.locale, interfaceLanguage.locale)
    }
    
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.api_key")
                    .font(.headline)
                
                SecureField("settings.api_key_placeholder", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                
                if viewModel.hasValidAPIKey {
                    Text("settings.api_key_valid")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("settings.api_key_required")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // Language Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.interview_language")
                    .font(.headline)
                
                Picker("settings.language_label", selection: $viewModel.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.interface_language")
                    .font(.headline)
                
                Picker("settings.language_label", selection: interfaceLanguageBinding) {
                    ForEach(Language.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Divider()
            
            // AI Models
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.ai_models")
                    .font(.headline)
                
                Picker("settings.chat_model", selection: $viewModel.selectedChatModel) {
                    ForEach(viewModel.availableChatModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("settings.whisper_model", selection: $viewModel.selectedWhisperModel) {
                    ForEach(viewModel.availableWhisperModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("settings.tts_model", selection: $viewModel.selectedTTSModel) {
                    ForEach(viewModel.availableTTSModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.ai_voice")
                    .font(.headline)
                
                Picker("settings.voice_label", selection: $viewModel.selectedVoice) {
                    ForEach(viewModel.availableVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // TTS Interruption
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.tts_interruption")
                    .font(.headline)
                
                Text("settings.tts_interruption_desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("settings.allow_interruption", isOn: $viewModel.allowTTSInterruption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interfaceLanguage: Language {
        Language(rawValue: interfaceLanguageRaw) ?? .english
    }
    
    private var interfaceLanguageBinding: Binding<Language> {
        Binding(
            get: { interfaceLanguage },
            set: { newValue in
                interfaceLanguageRaw = newValue.rawValue
                DispatchQueue.main.async {
                    viewModel.selectedInterfaceLanguage = newValue
                }
            }
        )
    }
    
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Audio Test Section
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.audio_test")
                    .font(.headline)
                
                Text("settings.audio_test_desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                AudioLevelView(
                    audioLevel: audioTestViewModel.audioLevel,
                    isRecording: audioTestViewModel.isRecording
                )
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await audioTestViewModel.startTest()
                        }
                    }) {
                        Label("settings.test_microphone", systemImage: "mic.fill")
                    }
                    .disabled(audioTestViewModel.isRecording)
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        Task {
                            await audioTestViewModel.stopTest()
                        }
                    }) {
                        Label("settings.stop", systemImage: "stop.fill")
                    }
                    .disabled(!audioTestViewModel.isRecording)
                }
                
                Text(audioTestViewModel.statusText)
                    .font(.caption)
                    .monospacedDigit()
                
                Button(action: {
                    audioTestViewModel.clearLogs()
                }) {
                    Label("settings.clear_logs", systemImage: "trash")
                }
                .font(.caption)
                
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
                    .frame(height: 180)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Voice Threshold (Microphone Sensitivity)
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.voice_threshold")
                    .font(.headline)
                
                Text("settings.voice_threshold_desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Text("settings.less_sensitive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.voiceThreshold, in: 0.05...0.5, step: 0.01)
                    
                    Text("settings.more_sensitive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("settings.current_threshold")
                        .font(.caption)
                    Text(String(format: "%.2f", viewModel.voiceThreshold))
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if viewModel.voiceThreshold < 0.15 {
                        Label("settings.very_sensitive", systemImage: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if viewModel.voiceThreshold < 0.25 {
                        Label("settings.sensitive", systemImage: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if viewModel.voiceThreshold < 0.35 {
                        Label("settings.normal", systemImage: "speaker.wave.1.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("settings.less_sensitive_label", systemImage: "speaker.slash.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.calibrateNoiseLevel()
                        }
                    }) {
                        Label("settings.calibrate_noise", systemImage: "waveform.path")
                    }
                    .disabled(viewModel.isCalibrating)
                    .buttonStyle(.bordered)
                    
                    if viewModel.isCalibrating {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    if viewModel.calibrationProgress > 0 {
                        Text("\(Int(viewModel.calibrationProgress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                
                if let calibratedThreshold = viewModel.calibratedNoiseLevel {
                    HStack {
                        Text("settings.calibrated_threshold")
                            .font(.caption)
                        Text(String(format: "%.2f", calibratedThreshold))
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Label("settings.applied", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Divider()
            
            // Silence Timeout
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.silence_timeout")
                    .font(.headline)
                
                Text("settings.silence_timeout_desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Text("settings.silence_timeout_min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.silenceTimeout, in: 0.5...5.0, step: 0.5)
                    
                    Text("settings.silence_timeout_max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("settings.current_timeout")
                        .font(.caption)
                    Text(L10n.format("settings.current_timeout_value", viewModel.silenceTimeout))
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if viewModel.silenceTimeout <= 1.0 {
                        Label("settings.quick", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if viewModel.silenceTimeout <= 2.0 {
                        Label("settings.normal", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if viewModel.silenceTimeout <= 3.0 {
                        Label("settings.slow", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("settings.very_slow", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text("settings.shorter_timeout_warning")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            Divider()
            
            // Min Speech Level
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.min_speech_level")
                    .font(.headline)
                
                Text("settings.min_speech_desc")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Text("settings.less_strict")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $viewModel.minSpeechLevel, in: 0.01...0.1, step: 0.005)
                    
                    Text("settings.more_strict")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("settings.current_level")
                        .font(.caption)
                    Text(String(format: "%.3f", viewModel.minSpeechLevel))
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if viewModel.minSpeechLevel < 0.03 {
                        Label("settings.very_permissive", systemImage: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if viewModel.minSpeechLevel < 0.05 {
                        Label("settings.permissive", systemImage: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else if viewModel.minSpeechLevel < 0.07 {
                        Label("settings.normal", systemImage: "speaker.wave.1.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("settings.strict", systemImage: "speaker.slash.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text("settings.min_speech_tip")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Published var statusText: String = L10n.text("settings.ready_to_test")
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
        statusText = L10n.text("settings.testing")
        logs.removeAll()
        
        addLog(L10n.format("settings.starting_mic_test", Int(testDuration)))
        addLog(L10n.text("settings.speak_to_test"))
        
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
                    addLog(L10n.format("settings.audio_level_log", levelStr))
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await stopTest()
        }
    }
    
    func stopTest() async {
        guard isRecording else { return }
        
        isRecording = false
        statusText = L10n.text("settings.stopped")
        
        voiceDetector.stopListening()
        
        testTask?.cancel()
        testTask = nil
        
        addLog(L10n.text("settings.test_stopped"))
        
        await MainActor.run {
            statusText = L10n.text("settings.ready_to_test")
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        addLog(L10n.text("settings.logs_cleared"))
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
