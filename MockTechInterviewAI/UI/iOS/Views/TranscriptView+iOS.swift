//
//  TranscriptView.swift
//  XInterview2
//
//  Right panel showing live transcript of conversation
//

#if os(iOS)
import SwiftUI
import AVFoundation
import Combine

struct TranscriptView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var audioPlayer = TranscriptAudioPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Messages
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.session.transcript.isEmpty {
                            Text("transcript.empty")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.session.transcript) { message in
                                MessageRowView(
                                    message: message,
                                    onPlayAudio: { audioMessage in
                                        guard let fileName = audioMessage.audioFileName else {
                                            return
                                        }
                                        let fileURL: URL
                                        switch audioMessage.role {
                                        case .assistant:
                                            fileURL = TTSAudioCache.audioFileURL(for: fileName)
                                        case .user:
                                            fileURL = UserAudioCache.audioFileURL(for: fileName)
                                        case .system:
                                            return
                                        }
                                        audioPlayer.onStart = {
                                            viewModel.pauseListeningForPlayback()
                                        }
                                        audioPlayer.onFinish = {
                                            viewModel.resumeListeningAfterPlayback()
                                        }
                                        audioPlayer.play(fileURL)
                                    }
                                )
                            }
                        }
                    }
                    .padding(12)
                    .onChange(of: viewModel.session.transcript.count) { oldValue, newValue in
                        if let lastMessage = viewModel.session.transcript.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Text Input Area
            Divider()
            messageInputArea
        }
        .background(Color.appTextBackground)
    }

    // MARK: - Message Input Area

    private var messageInputArea: some View {
        HStack(spacing: 8) {
            TextField("transcript.message_placeholder", text: $viewModel.textInput)
                .font(.body)
                .frame(height: 36)
                .padding(.horizontal, 10)
                .background(Color.appTextBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .disabled(!viewModel.session.isActive || viewModel.isSendingTextMessage)
                .submitLabel(.send)
                .onSubmit {
                    if canSendMessage {
                        viewModel.sendTextMessage()
                        isTextFieldFocused = true
                    }
                }

            Button(action: {
                viewModel.sendTextMessage()
                isTextFieldFocused = true
            }) {
                if viewModel.isSendingTextMessage {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "paperplane.fill")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(canSendMessage ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(!canSendMessage)
            .accessibilityLabel(LocalizedStringKey("transcript.send"))
        }
        .padding(12)
    }

    private var canSendMessage: Bool {
        !viewModel.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.session.isActive &&
        !viewModel.isSendingTextMessage
    }
}

struct MessageRowView: View {
    let message: TranscriptMessage
    let onPlayAudio: (TranscriptMessage) -> Void
    @State private var isTranslationSheetPresented = false

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }

                Text(message.role == .user ? LocalizedStringKey("transcript.you") : LocalizedStringKey("transcript.ai"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if message.role != .system, message.audioFileName != nil {
                    Button("transcript.listen") {
                        onPlayAudio(message)
                    }
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                }

                if let translation = translationText {
                    Button(action: { isTranslationSheetPresented = true }) {
                        Image(systemName: "globe")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(LocalizedStringKey("transcript.translation"))
                    .sheet(isPresented: $isTranslationSheetPresented) {
                        TranslationSheetView(
                            original: message.text,
                            translation: translation,
                            notes: translationNotes
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            Text(message.text)
                .font(.body)
                .textSelection(.enabled)
                .padding(8)
                .background(message.role == .user ? Color.accentColor.opacity(0.1) : Color.appSecondaryBackground)
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var translationText: String? {
        guard message.role == .assistant, let translation = message.translationText else {
            return nil
        }
        return translation
    }

    private var translationNotes: String? {
        message.translationNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TranslationSheetView: View {
    let original: String
    let translation: String
    let notes: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("transcript.original"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(original)
                        .font(.body)

                    Text(LocalizedStringKey("transcript.translation"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(translation)
                        .font(.body)

                    if let notes, !notes.isEmpty {
                        Text(LocalizedStringKey("transcript.translation_notes"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("transcript.translation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("main.ok") {
                        dismiss()
                    }
                }
            }
        }
    }
}

final class TranscriptAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let objectWillChange = ObservableObjectPublisher()
    private var audioPlayer: AVAudioPlayer?
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    func play(_ fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.error("TTS audio file missing at \(fileURL.lastPathComponent)")
            return
        }

        do {
            onStart?()
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            Logger.error("Failed to play TTS audio", error: error)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinish?()
    }
}

#Preview {
    TranscriptView(viewModel: InterviewViewModel())
}
#endif
