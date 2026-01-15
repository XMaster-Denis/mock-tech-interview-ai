//
//  CodeEditorView.swift
//  XInterview2
//
//  Code editor with syntax highlighting using CodeEditSourceEditor
//

import SwiftUI
import AppKit
import CodeEditSourceEditor
import CodeEditLanguages
import CodeEditTextView

/// Code editor view with syntax highlighting
struct CodeEditorView: View {
    @Binding var code: String
    var language: CodeLanguageInterview
    var isEditable: Bool
    
    @State var editorState = SourceEditorState()
    
    @State var theme: EditorTheme = .dark
    @State var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    @State var indentOption : IndentOption = .spaces(count: 4)
    
    
    init(
        
        code: Binding<String>,
        language: CodeLanguageInterview,
        isEditable: Bool = true
    ) {
        self._code = code
        self.language = language
        self.isEditable = isEditable
    }
    
    var body: some View {
        VStack(spacing: 0) {
           
            // Code editor using CodeEditSourceEditor
            SourceEditor(
                $code,
                language: language.codeLanguageOfCodeEditSourceEditor,
                
                // Tons of customization options, with good defaults to get started quickly.
                configuration: SourceEditorConfiguration(
                    appearance: .init(theme: theme, font: font, wrapLines: true),
                    behavior: .init(indentOption: indentOption),
                    peripherals: .init(
                        showGutter: true,
                        showMinimap: false,
                        showReformattingGuide: false,
                        invisibleCharactersConfiguration: .empty,
                        warningCharacters: []
                    )
                    
                ),
                state: $editorState,
                coordinators: []
            )
        }
        .onChange(of: code) { oldValue, newValue in
            // Notify parent view of code changes
        }
    }
}
