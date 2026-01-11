//
//  MainView.swift
//  XInterview2
//
//  Main window view with three-column layout
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @State private var isSettingsPresented = false
    @State private var code: String = ""
    
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
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            isSettingsPresented = true
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
            AudioLevelView(
                audioLevel: viewModel.audioLevel,
                isRecording: viewModel.isRecording
            )
            
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
