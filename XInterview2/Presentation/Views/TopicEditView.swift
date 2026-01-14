//
//  TopicEditView.swift
//  XInterview2
//
//  View for editing or creating interview topics
//

import SwiftUI

struct TopicEditView: View {
    @State var topic: InterviewTopic
    let onSave: (InterviewTopic) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var prompt: String
    @State private var level: DeveloperLevel
    @State private var codeLanguage: CodeLanguageInterview
    @State private var interviewMode: InterviewMode
    
    @Environment(\.dismiss) private var dismiss
    
    init(topic: InterviewTopic, onSave: @escaping (InterviewTopic) -> Void, onCancel: @escaping () -> Void) {
        self._topic = State(initialValue: topic)
        self.onSave = onSave
        self.onCancel = onCancel
        self._title = State(initialValue: topic.title)
        self._prompt = State(initialValue: topic.prompt)
        self._level = State(initialValue: topic.level)
        self._codeLanguage = State(initialValue: topic.codeLanguage)
        self._interviewMode = State(initialValue: topic.interviewMode)
    }
    
    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Topic Information")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextEditor(text: $prompt)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Section(header: Text("Interview Settings")) {
                    Picker("Programming Language", selection: $codeLanguage) {
                        ForEach(CodeLanguageInterview.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Interview Mode", selection: $interviewMode) {
                        ForEach(InterviewMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Developer Level", selection: $level) {
                        ForEach(DeveloperLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(codeLanguage.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            
                            Text(interviewMode.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                            
                            Text(level.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        
                        if !title.isEmpty {
                            Text(title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        
                        if !prompt.isEmpty {
                            Text(prompt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(topic.title.isEmpty ? "New Topic" : "Edit Topic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTopic()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveTopic() {
        let updatedTopic = InterviewTopic(
            id: topic.id == UUID() && topic.title.isEmpty ? UUID() : topic.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            level: level,
            codeLanguage: codeLanguage,
            interviewMode: interviewMode
        )
        onSave(updatedTopic)
    }
}

#Preview {
    TopicEditView(
        topic: InterviewTopic(
            title: "Swift Basics",
            prompt: "Interview about Swift fundamentals",
            level: .junior,
            codeLanguage: .swift,
            interviewMode: .hybrid
        ),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("New Topic") {
    TopicEditView(
        topic: InterviewTopic(
            title: "",
            prompt: "",
            level: .junior,
            codeLanguage: .swift,
            interviewMode: .questionsOnly
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
