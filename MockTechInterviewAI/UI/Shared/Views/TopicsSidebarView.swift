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
    let onTopicSelected: ((InterviewTopic) -> Void)?

    init(
        viewModel: InterviewViewModel,
        isSettingsPresented: Binding<Bool>,
        onTopicSelected: ((InterviewTopic) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self._isSettingsPresented = isSettingsPresented
        self.onTopicSelected = onTopicSelected
    }
    
    var body: some View {
        Group {
            #if os(iOS)
            List {
                ForEach(viewModel.topics) { topic in
                    TopicRowView(
                        topic: topic,
                        isSelected: viewModel.selectedTopic.id == topic.id
                    ) {
                        viewModel.selectTopic(topic)
                        onTopicSelected?(topic)
                    } onEdit: {
                        viewModel.startEditingTopic(topic)
                    } onClearHistory: {
                        viewModel.clearInterviewHistory(for: topic)
                    } onDelete: {
                        viewModel.deleteTopic(id: topic.id)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("topics.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                }
            }
            #else
            VStack(alignment: .leading, spacing: 0) {
                // Header with Add and Settings buttons
                HStack {
                    Text("topics.title")
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
                    .helpIfAvailable("topics.add")
                    
                    Button(action: { isSettingsPresented = true }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    .helpIfAvailable("topics.settings")
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
                            } onClearHistory: {
                                viewModel.clearInterviewHistory(for: topic)
                            } onDelete: {
                                viewModel.deleteTopic(id: topic.id)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            #if os(macOS)
            .frame(width: 260)
            #endif
            #endif
        }
        .sheet(isPresented: $viewModel.isEditingTopic) {
            if let topicToEdit = viewModel.topicToEdit {
                TopicEditView(
                    topic: topicToEdit,
                    onSave: { updatedTopic in
                        let isExisting = viewModel.topics.contains { $0.id == topicToEdit.id }
                        if isExisting {
                            viewModel.updateTopic(updatedTopic)
                        } else {
                            viewModel.addTopic(updatedTopic)
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
    let onClearHistory: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        #if os(iOS)
        topicContent
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Label("topics.delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button(action: onEdit) {
                    Label("topics.edit", systemImage: "pencil")
                }
                Button(action: onClearHistory) {
                    Label("topics.clear_history", systemImage: "arrow.counterclockwise")
                }
                .tint(.orange)
            }
        #else
        HStack(alignment: .top, spacing: 6) {
            Button(action: onTap) {
                topicContent
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 2) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .helpIfAvailable("topics.edit")
                
                Button(action: onClearHistory) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .helpIfAvailable("topics.clear_history")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .helpIfAvailable("topics.delete")
            }
            .padding(.top, 2)
        }
        #endif
    }

    private var topicContent: some View {
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
                
                Text(topic.interviewMode.uiDisplayName)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(3)
                
                Text(topic.level.uiDisplayName)
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
}

#Preview {
    TopicsSidebarView(
        viewModel: InterviewViewModel(),
        isSettingsPresented: .constant(false)
    )
}
