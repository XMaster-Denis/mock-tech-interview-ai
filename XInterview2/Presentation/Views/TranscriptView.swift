//
//  TranscriptView.swift
//  XInterview2
//
//  Right panel showing live transcript of conversation
//

import SwiftUI

struct TranscriptView: View {
    @ObservedObject var viewModel: InterviewViewModel
    
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
                        if viewModel.session.messages.isEmpty {
                            Text("No messages yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.session.messages) { message in
                                MessageRowView(message: message)
                            }
                        }
                    }
                    .padding(12)
                    .onChange(of: viewModel.session.messages.count) { oldValue, newValue in
                        if let lastMessage = viewModel.session.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 250)
        .background(Color(nsColor: .textBackgroundColor))
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
