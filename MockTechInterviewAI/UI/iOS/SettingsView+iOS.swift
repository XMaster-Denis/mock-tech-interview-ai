import SwiftUI
import Combine

#if os(iOS)
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var audioTestViewModel = AudioTestViewModel()
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.selectedInterfaceLanguage) private var interfaceLanguageRaw = Language.english.rawValue

    init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
        _audioTestViewModel = StateObject(wrappedValue: AudioTestViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("settings.api_key_placeholder", text: $viewModel.apiKey)
                        .textFieldStyle(.roundedBorder)

                    Text(viewModel.hasValidAPIKey ? LocalizedStringKey("settings.api_key_valid") : LocalizedStringKey("settings.api_key_required"))
                        .font(.caption)
                        .foregroundColor(viewModel.hasValidAPIKey ? .green : .orange)
                } header: {
                    Text("settings.api_key")
                }

                Section {
                    Text("settings.language_interview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("settings.language_label", selection: interviewLanguageBinding) {
                        ForEach(Language.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("settings.language_interface")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("settings.language_label", selection: interfaceLanguageBinding) {
                        ForEach(Language.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("settings.interview_language")
                }

                Section {
                    Picker("settings.chat_model", selection: $viewModel.selectedChatModel) {
                        ForEach(viewModel.availableChatModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    Picker("settings.whisper_model", selection: $viewModel.selectedWhisperModel) {
                        ForEach(viewModel.availableWhisperModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    Picker("settings.tts_model", selection: $viewModel.selectedTTSModel) {
                        ForEach(viewModel.availableTTSModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                } header: {
                    Text("settings.ai_models")
                }

                Section {
                    Picker("settings.voice_label", selection: $viewModel.selectedVoice) {
                        ForEach(viewModel.availableVoices, id: \.self) { voice in
                            Text(voice.capitalized).tag(voice)
                        }
                    }
                } header: {
                    Text("settings.ai_voice")
                }

                Section {
                    Text("settings.tts_interruption_desc")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("settings.allow_interruption", isOn: $viewModel.allowTTSInterruption)
                } header: {
                    Text("settings.tts_interruption")
                }

                Section {
                    AudioLevelView(
                        audioLevel: audioTestViewModel.audioLevel,
                        isRecording: audioTestViewModel.isRecording
                    )

                    HStack(spacing: 12) {
                        Button(action: {
                            Task { await audioTestViewModel.startTest() }
                        }) {
                            Label("settings.test_microphone", systemImage: "mic.fill")
                        }
                        .disabled(audioTestViewModel.isRecording)

                        Button(action: {
                            Task { await audioTestViewModel.stopTest() }
                        }) {
                            Label("settings.stop", systemImage: "stop.fill")
                        }
                        .disabled(!audioTestViewModel.isRecording)
                    }

                    Text(audioTestViewModel.statusText)
                        .font(.caption)
                        .monospacedDigit()

                    Button(action: { audioTestViewModel.clearLogs() }) {
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
                        .frame(height: 160)
                        .background(Color.appTextBackground)
                        .cornerRadius(8)
                    }
                } header: {
                    Text("settings.audio_test")
                } footer: {
                    Text("settings.audio_test_desc")
                        .font(.caption)
                }

                Section {
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
                            Task { await viewModel.calibrateNoiseLevel() }
                        }) {
                            Label("settings.calibrate_noise", systemImage: "waveform.path")
                        }
                        .disabled(viewModel.isCalibrating)

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
                } header: {
                    Text("settings.voice_threshold")
                } footer: {
                    Text("settings.voice_threshold_desc")
                        .font(.caption)
                }

                Section {
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
                } header: {
                    Text("settings.silence_timeout")
                } footer: {
                    Text("settings.silence_timeout_desc")
                        .font(.caption)
                }
            }
            .navigationTitle("settings.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.save") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, interfaceLanguage.locale)
    }

    private var interfaceLanguage: Language {
        Language(rawValue: interfaceLanguageRaw) ?? .english
    }

    private var interviewLanguageBinding: Binding<Language> {
        Binding(
            get: { viewModel.selectedLanguage },
            set: { newValue in
                DispatchQueue.main.async {
                    viewModel.selectedLanguage = newValue
                }
            }
        )
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

    private func logColor(for log: String) -> Color {
        if log.contains("ERROR") {
            return .red
        }
        if log.contains("WARN") {
            return .orange
        }
        return .secondary
    }
}
#endif
