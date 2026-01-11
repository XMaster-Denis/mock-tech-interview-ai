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
                if !viewModel.session.isActive {
                    Button(action: { viewModel.startInterview() }) {
                        Label("Start Interview", systemImage: "play.fill")
                    }
                    .disabled(viewModel.session.isActive)
                } else {
                    Button(action: { viewModel.stopInterview() }) {
                        Label("Stop Interview", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: { viewModel.toggleRecording() }) {
                    Label(viewModel.recordingButtonText, systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.fill")
                }
                .disabled(!viewModel.canRecord)
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

// MARK: - Audio Level View

struct AudioLevelView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                Rectangle()
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 8)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = audioLevel * 20
        let barIndex = Float(index)
        return barIndex < normalizedLevel ? CGFloat(20) : CGFloat(4)
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedLevel = audioLevel * 20
        let barIndex = Float(index)
        
        if !isRecording {
            return Color.gray.opacity(0.3)
        } else if barIndex >= normalizedLevel {
            return Color.gray.opacity(0.5)
        } else {
            // Color gradient based on intensity
            let intensity = Float(index) / 20.0
            if intensity < 0.5 {
                return Color.green
            } else if intensity < 0.8 {
                return Color.orange
            } else {
                return Color.red
            }
        }
    }
}

#Preview {
    MainView()
}
