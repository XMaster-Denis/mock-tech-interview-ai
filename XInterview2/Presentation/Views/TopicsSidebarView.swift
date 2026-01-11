//
//  TopicsSidebarView.swift
//  XInterview2
//
//  Left panel showing interview topics
//

import SwiftUI

struct TopicsSidebarView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @Binding var isSettingsPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Settings button
            HStack {
                Text("Topics")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                
                Spacer()
                
                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, 12)
                .help("Settings")
            }
            
            Divider()
            
            // Topics list
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(InterviewTopic.defaultTopics) { topic in
                        TopicRowView(
                            topic: topic,
                            isSelected: viewModel.selectedTopic.id == topic.id
                        ) {
                            viewModel.selectTopic(topic)
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 220)
    }
}

struct TopicRowView: View {
    let topic: InterviewTopic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)
                
                Text(topic.prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TopicsSidebarView(
        viewModel: InterviewViewModel(),
        isSettingsPresented: .constant(false)
    )
}
