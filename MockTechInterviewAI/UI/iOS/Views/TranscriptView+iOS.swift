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
            // Header
            Text("transcript.title")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Divider()

            // Messages
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 8) {
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
        VStack(spacing: 8) {
            // Text Input Field
            TextEditor(text: $viewModel.textInput)
                .font(.body)
                .frame(minHeight: 44, maxHeight: 88) // 2-3 lines
                .scrollContentBackground(.hidden)
                .background(Color.appTextBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .disabled(!viewModel.session.isActive || viewModel.isSendingTextMessage)

            // Send Button
            HStack {
                Spacer()

                Button(action: {
                    viewModel.sendTextMessage()
                    isTextFieldFocused = true
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isSendingTextMessage {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(viewModel.isSendingTextMessage ? LocalizedStringKey("transcript.sending") : LocalizedStringKey("transcript.send"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(canSendMessage ? Color.accentColor : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!canSendMessage)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
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

                if let tooltip = translationTooltip {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .helpIfAvailable(tooltip)
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

    private var translationTooltip: String? {
        guard message.role == .assistant, let translation = message.translationText else {
            return nil
        }

        let notes = message.translationNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let notes, !notes.isEmpty {
            return "\(translation)\n\n\(notes)"
        }

        return translation
    }
}

final class TranscriptAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let objectWillChange = ObservableObjectPublisher()
    private var audioPlayer: AVAudioPlayer?

    func play(_ fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.error("TTS audio file missing at \(fileURL.lastPathComponent)")
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            Logger.error("Failed to play TTS audio", error: error)
        }
    }
}

#Preview {
    TranscriptView(viewModel: InterviewViewModel())
}
#endif
