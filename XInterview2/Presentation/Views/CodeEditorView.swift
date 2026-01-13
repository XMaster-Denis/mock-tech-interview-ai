//
//  CodeEditorView.swift
//  XInterview2
//
//  Code editor with syntax highlighting
//

import SwiftUI
import AppKit

/// Code editor view with syntax highlighting
struct CodeEditorView: View {
    @Binding var code: String
    var language: CodeLanguage
    var isEditable: Bool
    var onCodeChange: ((String) -> Void)?
    
    init(
        code: Binding<String>,
        language: CodeLanguage = .swift,
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
            // Header with language indicator
            HStack {
                Text(language.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Line count
                let lineCount = code.components(separatedBy: "\n").count
                Text("\(lineCount) \(lineCount == 1 ? "line" : "lines")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            
            // Code editor
            SimpleCodeEditor(
                text: $code,
                language: language,
                isEditable: isEditable,
                onTextChange: { newCode in
                    onCodeChange?(newCode)
                }
            )
        }
    }
}

// MARK: - Simple Code Editor

struct SimpleCodeEditor: NSViewRepresentable {
    @Binding var text: String
    var language: CodeLanguage
    var isEditable: Bool
    var onTextChange: ((String) -> Void)?
    
    func makeNSView(context: Context) -> CodeTextView {
        let textView = CodeTextView()
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.string = text
        
        // Set colors
        textView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        textView.textColor = NSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.0)
        textView.insertionPointColor = NSColor(red: 0.68, green: 0.69, blue: 0.68, alpha: 1.0)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(red: 0.15, green: 0.31, blue: 0.47, alpha: 1.0)
        ]
        
        // Set delegate
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        return textView
    }
    
    func updateNSView(_ nsView: CodeTextView, context: Context) {
        guard nsView.string != text else { return }
        
        let selectedRange = nsView.selectedRange()
        nsView.string = text
        
        // Restore cursor position if within bounds
        if selectedRange.location <= text.count {
            nsView.setSelectedRange(selectedRange)
        }
        
        nsView.isEditable = isEditable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SimpleCodeEditor
        var debounceTimer: Timer?
        
        init(_ parent: SimpleCodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.parent.text = textView.string
                    self.parent.onTextChange?(textView.string)
                }
            }
        }
    }
}

// MARK: - Code TextView

class CodeTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        // Draw background
        backgroundColor.setFill()
        dirtyRect.fill()
        
        // Draw text
        super.draw(dirtyRect)
    }
    
    override func drawBackground(in rect: NSRect) {
        // Let the draw method handle background
    }
}

// MARK: - Preview

struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Swift code
            CodeEditorView(
                code: .constant("""
                func isEven(_ number: Int) -> Bool {
                    return number % 2 == 0
                }
                
                func greet(_ name: String) -> String {
                    return "Hello, \\(name)!"
                }
                """),
                language: .swift
            )
            .frame(height: 300)
            
            // Empty state
            CodeEditorView(
                code: .constant("// Write your code here"),
                language: .swift
            )
            .frame(height: 150)
        }
    }
}
