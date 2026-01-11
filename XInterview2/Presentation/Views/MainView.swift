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
            
            // Recording status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                Text(viewModel.recordingButtonText)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if !viewModel.session.isActive {
                    Button(action: { viewModel.startInterview() }) {
                        Label("Start Interview", systemImage: "play.fill")
                    }
                    .disabled(viewModel.session.isActive)
                } else {
                    Button(action: { viewModel.stopInterview() }) {
                        Label("Stop Interview", systemImage: "stop.fill")
                    }
                }
                
                Button(action: { viewModel.toggleRecording() }) {
                    Label(viewModel.isRecording ? "Stop" : "Record", systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                }
                .disabled(!viewModel.canRecord)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() {
        #if os(macOS)
        // Microphone permission is automatically requested on first use in macOS
        // But we can show a setup prompt here if needed
        #endif
    }
}

#Preview {
    MainView()
}
