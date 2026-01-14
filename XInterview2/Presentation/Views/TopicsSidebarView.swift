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
            // Header with Add and Settings buttons
            HStack {
                Text("Topics")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                
                Spacer()
                
                Button(action: { 
                    viewModel.startEditingTopic(InterviewTopic(
                        title: "",
                        prompt: "",
                        level: .junior,
                        codeLanguage: .swift,
                        interviewMode: .questionsOnly
                    ))
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .help("Add new topic")
                
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
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.topics) { topic in
                        TopicRowView(
                            topic: topic,
                            isSelected: viewModel.selectedTopic.id == topic.id
                        ) {
                            viewModel.selectTopic(topic)
                        } onEdit: {
                            viewModel.startEditingTopic(topic)
                        } onDelete: {
                            viewModel.deleteTopic(id: topic.id)
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 260)
        .sheet(isPresented: $viewModel.isEditingTopic) {
            if let topicToEdit = viewModel.topicToEdit {
                TopicEditView(
                    topic: topicToEdit,
                    onSave: { updatedTopic in
                        if topicToEdit.id == UUID() && topicToEdit.title.isEmpty {
                            // New topic
                            viewModel.addTopic(updatedTopic)
                        } else {
                            // Existing topic
                            viewModel.updateTopic(updatedTopic)
                        }
                        viewModel.cancelEditing()
                    },
                    onCancel: {
                        viewModel.cancelEditing()
                    }
                )
            }
        }
    }
}

struct TopicRowView: View {
    let topic: InterviewTopic
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Topic content - clickable entire area
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(topic.title)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 3) {
                        Text(topic.codeLanguage.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                        
                        Text(topic.interviewMode.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                        
                        Text(topic.level.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                    
                    Text(topic.prompt)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Action buttons - always visible
            VStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit topic")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete topic")
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    TopicsSidebarView(
        viewModel: InterviewViewModel(),
        isSettingsPresented: .constant(false)
    )
}
