import SwiftUI
import Combine
import AVFoundation

#if os(iOS)
struct MainView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @State private var isSettingsPresented = false
    @State private var silenceTimerProgress: Double = 0.0
    @State private var silenceTimerElapsed: Double = 0.0
    @State private var silenceTimeout: Double = 1.5
    @State private var isSilenceTimerActive: Bool = false
    @State private var selectedTab: Tab = .transcript
    @State private var isTopicsPresented = false

    private enum Tab {
        case code
        case transcript
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .transcript:
                            interviewScreen
                        case .code:
                            codeEditorScreen
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { isTopicsPresented = true }) {
                                Image(systemName: "line.3.horizontal")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.plain)
                        }
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button(action: { isSettingsPresented = true }) {
                                Image(systemName: "gearshape")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    controlPanel
                }

                floatingTabButtons
            }
            .sheet(isPresented: $isTopicsPresented) {
                NavigationStack {
                    TopicsSidebarView(
                        viewModel: viewModel,
                        isSettingsPresented: $isSettingsPresented,
                        onTopicSelected: { _ in
                            selectedTab = .transcript
                            isTopicsPresented = false
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("main.ok") {
                                isTopicsPresented = false
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .preferredColorScheme(.dark)
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
            requestMicrophonePermission()
        }
    }

    private var floatingTabButtons: some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = .transcript
                    }
                }) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 16, weight: .semibold))
                }
                .floatingTabButtonStyle(isSelected: selectedTab == .transcript)
                .accessibilityLabel(LocalizedStringKey("transcript.title"))

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = .code
                    }
                }) {
                    Image(systemName: "chevron.left.slash.chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .floatingTabButtonStyle(isSelected: selectedTab == .code)
                .accessibilityLabel(LocalizedStringKey("main.code_editor"))
            }
            .padding(.trailing, 12)
            .padding(.top, proxy.size.height * 0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private var interviewScreen: some View {
        VStack(spacing: 0) {
            TranscriptView(viewModel: viewModel)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            Divider()

            codeEditorPanel
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var codeEditorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeEditorView(
                code: $viewModel.code,
                hintText: viewModel.hintText,
                hintCode: viewModel.hintCode,
                solutionCode: viewModel.solutionCode,
                solutionExplanation: viewModel.solutionExplanation,
                language: .swift,
                isEditable: false
            )
            .padding(12)
        }
        .background(Color.appSecondaryBackground)
    }

    private var codeEditorScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeEditorView(
                code: $viewModel.code,
                hintText: viewModel.hintText,
                hintCode: viewModel.hintCode,
                solutionCode: viewModel.solutionCode,
                solutionExplanation: viewModel.solutionExplanation,
                language: .swift,
                isEditable: true
            )
            .padding(12)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.session.isActive ? LocalizedStringKey("main.interview_active") : LocalizedStringKey("main.not_started"))
                        .font(.headline)
                    Text(L10n.format("main.topic_label", viewModel.session.topic.title))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.statusText)
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 12) {
                AudioLevelView(
                    audioLevel: viewModel.audioLevel,
                    isRecording: viewModel.isRecording
                )

                if isSilenceTimerActive {
                    HStack(spacing: 8) {
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

                        Text("\(String(format: "%.1f", silenceTimerElapsed))s")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                            .frame(minWidth: 40)
                    }
                    .transition(.opacity.combined(with: .scale))
                }

                Spacer()

                if case .taskPresented = viewModel.taskState {
                    Button(action: { viewModel.requestHelp() }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title3)
                    }
                    .darkIconButtonStyle(tint: .blue)
                    .accessibilityLabel(helpButtonTitle)

                    Button(action: { viewModel.confirmTaskCompletion() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .darkIconButtonStyle(tint: .green, isProminent: true)
                    .accessibilityLabel(LocalizedStringKey("main.done"))
                } else if case .waitingForUserConfirmation = viewModel.taskState {
                    Button(action: { viewModel.confirmUnderstanding() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .darkIconButtonStyle(tint: .green, isProminent: true)
                    .accessibilityLabel(LocalizedStringKey("main.understand"))
                }
                Spacer()

                Button(action: { viewModel.toggleRecording() }) {
                    Image(systemName: viewModel.session.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.session.isActive ? .red : .green)
            }

        }
        .padding(12)
        .background(Color.appSecondaryBackground)
    }

    private var hasHelpContent: Bool {
        let hint = viewModel.hintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hintCode = viewModel.hintCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let solution = viewModel.solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !hint.isEmpty || !hintCode.isEmpty || !solution.isEmpty
    }

    private var helpButtonTitle: LocalizedStringKey {
        let solution = viewModel.solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return solution.isEmpty ? "code_panel.hint" : "code_panel.solution"
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

    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
}

private struct FloatingTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .frame(width: 36, height: 36)
            .background(isSelected ? Color.white : Color.black.opacity(0.55))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.black.opacity(0.2) : Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

private extension View {
    func floatingTabButtonStyle(isSelected: Bool) -> some View {
        buttonStyle(FloatingTabButtonStyle(isSelected: isSelected))
    }
}

private struct DarkIconButtonStyle: ButtonStyle {
    let tint: Color
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let background = isProminent ? tint.opacity(0.5) : Color.white.opacity(0.08)
        let border = isProminent ? tint.opacity(0.8) : Color.white.opacity(0.15)

        return configuration.label
            .foregroundColor(isProminent ? .white : tint)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background.opacity(configuration.isPressed ? 0.7 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isProminent)
    }
}

private extension View {
    func darkIconButtonStyle(tint: Color, isProminent: Bool = false) -> some View {
        buttonStyle(DarkIconButtonStyle(tint: tint, isProminent: isProminent))
    }
}
#endif
