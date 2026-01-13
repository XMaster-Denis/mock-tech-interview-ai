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
    var onCodeChange: ((String) -> Void)?

    @State var editorState = SourceEditorState()

    @State var theme: EditorTheme = .dark
    @State var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    @State var indentOption : IndentOption = .spaces(count: 4)
    
    
    init(
        
        code: Binding<String>,
        language: CodeLanguageInterview,
        isEditable: Bool = true,
        onCodeChange: ((String) -> Void)? = nil
    ) {
        self._code = code
        self.language = language
        
        self.isEditable = isEditable
        self.onCodeChange = onCodeChange
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
            onCodeChange?(newValue)
        }
    }
}

extension EditorTheme {
    static var light: EditorTheme {
        EditorTheme(
            text: Attribute(color: NSColor(hex: "000000")),
            insertionPoint: NSColor(hex: "000000"),
            invisibles: Attribute(color: NSColor(hex: "D6D6D6")),
            background: NSColor(hex: "FFFFFF"),
            lineHighlight: NSColor(hex: "ECF5FF"),
            selection: NSColor(hex: "B2D7FF"),
            keywords: Attribute(color: NSColor(hex: "9B2393"), bold: true),
            commands: Attribute(color: NSColor(hex: "326D74")),
            types: Attribute(color: NSColor(hex: "0B4F79")),
            attributes: Attribute(color: NSColor(hex: "815F03")),
            variables: Attribute(color: NSColor(hex: "0F68A0")),
            values: Attribute(color: NSColor(hex: "6C36A9")),
            numbers: Attribute(color: NSColor(hex: "1C00CF")),
            strings: Attribute(color: NSColor(hex: "C41A16")),
            characters: Attribute(color: NSColor(hex: "1C00CF")),
            comments: Attribute(color: NSColor(hex: "267507"))
        )
    }
    static var dark: EditorTheme {
        EditorTheme(
            text: Attribute(color: NSColor(hex: "FFFFFF")),
            insertionPoint: NSColor(hex: "007AFF"),
            invisibles: Attribute(color: NSColor(hex: "53606E")),
            background: NSColor(hex: "292A30"),
            lineHighlight: NSColor(hex: "2F3239"),
            selection: NSColor(hex: "646F83"),
            keywords: Attribute(color: NSColor(hex: "FF7AB2"), bold: true),
            commands: Attribute(color: NSColor(hex: "78C2B3")),
            types: Attribute(color: NSColor(hex: "6BDFFF")),
            attributes: Attribute(color: NSColor(hex: "CC9768")),
            variables: Attribute(color: NSColor(hex: "4EB0CC")),
            values: Attribute(color: NSColor(hex: "B281EB")),
            numbers: Attribute(color: NSColor(hex: "D9C97C")),
            strings: Attribute(color: NSColor(hex: "FF8170")),
            characters: Attribute(color: NSColor(hex: "D9C97C")),
            comments: Attribute(color: NSColor(hex: "7F8C98"))
        )
    }
}
