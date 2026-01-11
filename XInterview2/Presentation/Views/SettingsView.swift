//
//  SettingsView.swift
//  XInterview2
//
//  Settings view for configuring API key and preferences
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init() {
        viewModel = SettingsViewModel()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API Key")
                    .font(.headline)
                
                SecureField("Enter your API key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 400)
                
                if viewModel.hasValidAPIKey {
                    Text("API key is valid ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("API key is required - Get one at platform.openai.com")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // Language Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Interview Language")
                    .font(.headline)
                
                Picker("Language", selection: $viewModel.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 400)
            }
            
            Divider()
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Voice")
                    .font(.headline)
                
                Picker("Voice", selection: $viewModel.selectedVoice) {
                    ForEach(viewModel.availableVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }
                .frame(minWidth: 400)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Save") {
                    viewModel.saveSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(30)
        .frame(width: 500, height: 450)
    }
}

#Preview {
    SettingsView()
}
