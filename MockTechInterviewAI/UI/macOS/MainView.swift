//
//  MainView.swift
//  XInterview2
//
//  Main window view with three-column layout
//

import SwiftUI
import Foundation
import Combine

#if os(macOS)
struct MainView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @State private var isSettingsPresented = false
    @State private var silenceTimerProgress: Double = 0.0
    @State private var silenceTimerElapsed: Double = 0.0  // Elapsed seconds in silence
    @State private var silenceTimeout: Double = 1.5  // Timeout from settings
    @State private var isSilenceTimerActive: Bool = false
    @State private var showAudioDebug: Bool = false  // Toggle for audio debug info
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area with three columns
            HSplitView {
                // Left: Topics Sidebar
                TopicsSidebarView(
                    viewModel: viewModel,
                    isSettingsPresented: $isSettingsPresented
                )
                
                // Center: Code Editor
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("main.code_editor")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Divider()
                    
                    CodeEditorView(
                        code: $viewModel.code,
                        hintText: viewModel.hintText,
                        hintCode: viewModel.hintCode,
                        solutionCode: viewModel.solutionCode,
                        solutionExplanation: viewModel.solutionExplanation,
                        language: .swift,
                        isEditable: true
                    )
                }
                
                // Right: Transcript
                TranscriptView(viewModel: viewModel)
            }
            
            // Bottom: Control Panel
            Divider()
            
            controlPanel
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .onNotification(.openSettings) { _ in
            isSettingsPresented = true
        }
        .onNotification(.silenceTimerUpdated) { notification in
            if let progress = notification.userInfo?["progress"] as? Double {
                silenceTimerProgress = progress
                isSilenceTimerActive = true
            }
            if let elapsed = notification.userInfo?["elapsed"] as? Double {
                silenceTimerElapsed = elapsed
            }
            if let timeout = notification.userInfo?["timeout"] as? Double {
                silenceTimeout = timeout
            }
        }
        .onNotification(.silenceTimerReset) { _ in
            silenceTimerProgress = 0.0
            silenceTimerElapsed = 0.0
            isSilenceTimerActive = false
        }
        .alert("main.error_title", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("main.ok") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            // Request microphone permission
            requestMicrophonePermission()
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        HStack(spacing: 20) {
            // Session status
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.session.isActive ? LocalizedStringKey("main.interview_active") : LocalizedStringKey("main.not_started"))
                    .font(.headline)
                Text(L10n.format("main.topic_label", viewModel.session.topic.title))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Audio level visualizer
            HStack(spacing: 12) {
                // Audio level indicator
                AudioLevelView(
                    audioLevel: viewModel.audioLevel,
                    isRecording: viewModel.isRecording
                )
                
                // Audio debug info (toggleable)
                if showAudioDebug {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("main.level_short")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", viewModel.audioLevel))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(audioLevelColor)
                        }
                        HStack(spacing: 4) {
                            Text("main.threshold_short")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f", viewModel.voiceThreshold))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.gray)
                        }
                    }
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                }
                
                // Silence detection indicator
                if isSilenceTimerActive {
                    HStack(spacing: 8) {
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(silenceTimerProgress))
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(Angle(degrees: -90))
                                .frame(width: 20, height: 20)
                                .animation(.easeInOut(duration: 0.1), value: silenceTimerProgress)
                        }
                        
                        // Show seconds instead of percentage
                        Text("\(String(format: "%.1f", silenceTimerElapsed))s")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                            .frame(minWidth: 40)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            
            // Conversation status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                // Debug toggle button
                Button(action: { showAudioDebug.toggle() }) {
                    Image(systemName: showAudioDebug ? "waveform.circle.fill" : "waveform.circle")
                }
                .help("main.audio_debug_toggle")
                
                // Task control buttons (only show when task is active)
                if case .taskPresented = viewModel.taskState {
                    // Help button
                    Button(action: { viewModel.requestHelp() }) {
                        Label("main.help", systemImage: "questionmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("main.help_hint")
                    
                    // Done button
                    Button(action: { viewModel.confirmTaskCompletion() }) {
                        Label("main.done", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("main.done_hint")
                } else if case .waitingForUserConfirmation = viewModel.taskState {
                    // Understanding confirmation button
                    Button(action: { viewModel.confirmUnderstanding() }) {
                        Label("main.understand", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("main.understand_hint")
                }
                
                // Start/Stop interview button
                Button(action: { viewModel.toggleRecording() }) {
                    Label(
                        viewModel.session.isActive ? LocalizedStringKey("main.stop_interview") : LocalizedStringKey("main.start_interview"),
                        systemImage: viewModel.session.isActive ? "stop.circle.fill" : "play.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color.appSecondaryBackground)
    }
    
    private var statusColor: Color {
        switch viewModel.conversationState {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        }
    }
    
    private var audioLevelColor: Color {
        if viewModel.audioLevel >= viewModel.voiceThreshold {
            return .green  // Above threshold - speech detected
        } else if viewModel.audioLevel >= viewModel.voiceThreshold * 0.5 {
            return .orange  // Close to threshold
        } else {
            return .red  // Below threshold
        }
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() {
        #if os(macOS)
        // Microphone permission is automatically requested on first use in macOS
        // But we can show a setup prompt here if needed
        #endif
    }

}

#endif
