//
//  MainView.swift
//  XInterview2
//
//  Main window view with three-column layout
//

import SwiftUI
import Foundation
import Combine

// MARK: - Notification Extensions

extension Notification.Name {
    static let silenceTimerUpdated = Notification.Name("silenceTimerUpdated")
    static let silenceTimerReset = Notification.Name("silenceTimerReset")
}

struct MainView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @State private var isSettingsPresented = false
    @State private var code: String = ""
    @State private var silenceTimerProgress: Double = 0.0
    @State private var isSilenceTimerActive: Bool = false
    
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
                    Text("Code Editor")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    
                    Divider()
                    
                    CodeEditorView(code: $code)
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
        }
        .onNotification(.silenceTimerReset) { _ in
            silenceTimerProgress = 0.0
            isSilenceTimerActive = false
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
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
                Text(viewModel.session.isActive ? "Interview Active" : "Not Started")
                    .font(.headline)
                Text("Topic: \(viewModel.session.topic.title)")
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
                        
                        Text("\(Int(silenceTimerProgress * 100))%")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                            .frame(minWidth: 30)
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
            HStack(spacing: 12) {
                Button(action: { viewModel.toggleRecording() }) {
                    Label(
                        viewModel.session.isActive ? "Stop Interview" : "Start Interview",
                        systemImage: viewModel.session.isActive ? "stop.circle.fill" : "play.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
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
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() {
        #if os(macOS)
        // Microphone permission is automatically requested on first use in macOS
        // But we can show a setup prompt here if needed
        #endif
    }
}

// MARK: - View Extension for Notifications

extension View {
    func onNotification(_ name: Notification.Name, perform action: @escaping (Notification) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: name), perform: action)
    }
}
