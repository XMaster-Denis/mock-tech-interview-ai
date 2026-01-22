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
    @State private var isHelpSheetPresented = false

    private enum Tab {
        case code
        case transcript
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    interviewScreen
                        .tabItem {
                            Label("transcript.title", systemImage: "text.bubble")
                        }
                        .tag(Tab.transcript)

                    codeEditorScreen
                        .tabItem {
                            Label("main.code_editor", systemImage: "chevron.left.slash.chevron.right")
                        }
                        .tag(Tab.code)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { isTopicsPresented = true }) {
                            Image(systemName: "line.3.horizontal")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isSettingsPresented = true }) {
                            Image(systemName: "gearshape")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                }
                controlPanel
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
        .sheet(isPresented: $isHelpSheetPresented) {
            NavigationStack {
                helpEditorSheet
            }
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
            WebKitPrewarmer.shared.warmUp()
        }
    }

    private var interviewScreen: some View {
        VStack(spacing: 0) {
            TranscriptView(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            Divider()

            codeEditorScreen
        }
    }

//    private var codeEditorPanel: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            CodeEditorView(
//                code: $viewModel.code,
//                hintText: viewModel.hintText,
//                hintCode: viewModel.hintCode,
//                solutionCode: viewModel.solutionCode,
//                solutionExplanation: viewModel.solutionExplanation,
//                language: .swift,
//                isEditable: false
//            )
//            .padding(12)
//        }
//        .frame(height: 150)
//        .background(Color.appSecondaryBackground)
//    }

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
//        .frame(height: 150)
        .background(Color.appSecondaryBackground)
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

                Button(action: { viewModel.toggleRecording() }) {
                    Image(systemName: viewModel.session.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.session.isActive ? .red : .green)
            }

            HStack(spacing: 8) {
                if hasHelpContent {
                    Button(action: { isHelpSheetPresented = true }) {
                        Label(helpButtonTitle, systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                }
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

    private var helpEditorSheet: some View {
        CodeEditorView(
            code: .constant(viewModel.code),
            hintText: viewModel.hintText,
            hintCode: viewModel.hintCode,
            solutionCode: viewModel.solutionCode,
            solutionExplanation: viewModel.solutionExplanation,
            language: .swift,
            isEditable: false
        )
        .navigationTitle(helpButtonTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("main.ok") {
                    isHelpSheetPresented = false
                }
            }
        }
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
#endif
