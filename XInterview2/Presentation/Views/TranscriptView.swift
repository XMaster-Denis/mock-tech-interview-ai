//
//  TranscriptView.swift
//  XInterview2
//
//  Right panel showing live transcript of conversation
//

import SwiftUI

struct TranscriptView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Transcript")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            Divider()
            
            // Messages
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.session.transcript.isEmpty {
                            Text("No messages yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.session.transcript) { message in
                                MessageRowView(message: message)
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
        .frame(minWidth: 250)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Message Input Area
    
    private var messageInputArea: some View {
        VStack(spacing: 8) {
            // Text Input Field
            TextEditor(text: $viewModel.textInput)
                .font(.body)
                .frame(minHeight: 44, maxHeight: 88) // 2-3 lines
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
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
                        Text(viewModel.isSendingTextMessage ? "Sending..." : "Send")
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
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 4) {
                if message.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                Text(message.role == .user ? "You" : "AI")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            
            Text(message.text)
                .font(.body)
                .textSelection(.enabled)
                .padding(10)
                .background(message.role == .user ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(Color.secondary)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    TranscriptView(viewModel: InterviewViewModel())
}
