//
//  CodeEditorView.swift
//  XInterview2
//
//  Center panel code editor with syntax highlighting
//

import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {
    @ObservedObject var viewModel: CodeEditorViewModel
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = HighlightingTextView(viewModel: viewModel)
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = NSColor(hex: "#1E1E1E")
        textView.textColor = NSColor(hex: "#D4D4D4")
        textView.insertionPointColor = NSColor.white
        textView.selectedTextAttributes = [.backgroundColor: NSColor(hex: "#264F78")]
        
        textView.string = viewModel.code
        textView.delegate = context.coordinator
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = textView.backgroundColor
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? HighlightingTextView else { return }
        
        // Update code if it changed externally (e.g., AI edit)
        if textView.string != viewModel.code && viewModel.isAIEditing {
            textView.string = viewModel.code
        }
        
        // Update editable state
        textView.isEditable = viewModel.isUserEditable && !viewModel.isAIEditing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            parent.viewModel.userDidChange(textView.string)
            
            // Update selected range
            if let selectedRange = textView.selectedRanges.first as? NSRange {
                parent.viewModel.selectedRange = selectedRange
            }
        }
    }
}

// MARK: - Highlighting TextView

class HighlightingTextView: NSTextView {
    var viewModel: CodeEditorViewModel?
    
    init(viewModel: CodeEditorViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero, textContainer: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
