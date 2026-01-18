import SwiftUI
import AppKit
import CodeEditSourceEditor
import CodeEditLanguages
import CodeEditTextView

// MARK: - Coordinator

final class CodeEditorCoordinator: TextViewCoordinator {

    @Binding private var code: String
    private weak var controller: TextViewController?
    private var isApplyingExternalChange = false

    init(code: Binding<String>) {
        self._code = code
    }

    func prepareCoordinator(controller: TextViewController) {
        self.controller = controller

        // первичная синхронизация — тоже через replaceCharacters
        applyExternalChange(code)
    }

    func textViewDidChangeText(controller: TextViewController) {
        guard !isApplyingExternalChange else { return }
        code = controller.text
    }

    func applyExternalChange(_ newValue: String) {
        guard let controller else { return }
        guard controller.text != newValue else { return }

        isApplyingExternalChange = true

        // полный диапазон текущего текста
        let oldLen = (controller.text as NSString).length
        let full = NSRange(location: 0, length: oldLen)

        controller.textView.replaceCharacters(in: full, with: newValue)
        controller.textView.needsDisplay = true
        controller.textView.layoutSubtreeIfNeeded()

        isApplyingExternalChange = false
    }
}

// MARK: - View


struct CodeEditorView: View {

    @Binding var code: String
    let hintText: String?
    let hintCode: String?
    let solutionCode: String?
    let solutionExplanation: String?
    let language: CodeLanguageInterview
    let isEditable: Bool

    @State private var editorState = SourceEditorState()
    @State private var theme: EditorTheme = .dark
    @State private var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    @State private var indentOption: IndentOption = .spaces(count: 4)

    @State private var coordinator: CodeEditorCoordinator
    @State private var isHelpPanelCollapsed = false

    init(
        code: Binding<String>,
        hintText: String? = nil,
        hintCode: String? = nil,
        solutionCode: String? = nil,
        solutionExplanation: String? = nil,
        language: CodeLanguageInterview,
        isEditable: Bool = true
    ) {
        self._code = code
        self.hintText = hintText
        self.hintCode = hintCode
        self.solutionCode = solutionCode
        self.solutionExplanation = solutionExplanation
        self.language = language
        self.isEditable = isEditable
        _coordinator = State(initialValue: CodeEditorCoordinator(code: code))
    }

    var body: some View {
        VStack(spacing: 0) {
            SourceEditor(
                $code,
                language: language.codeLanguageOfCodeEditSourceEditor,
                configuration: SourceEditorConfiguration(
                    appearance: .init(
                        theme: theme,
                        font: font,
                        wrapLines: true
                    ),
                    behavior: .init(
                        isEditable: isEditable,
                        indentOption: indentOption
                    ),
                    peripherals: .init(
                        showGutter: true,
                        showMinimap: false,
                        showReformattingGuide: false,
                        invisibleCharactersConfiguration: .empty,
                        warningCharacters: []
                    )
                ),
                state: $editorState,
                coordinators: [coordinator]
            )
            .onChange(of: code) { _, newValue in
                coordinator.applyExternalChange(newValue)
            }
            
            if showHintPanel || showSolutionPanel {
                Divider()
                if isHelpPanelCollapsed {
                    collapsedHelpBar
                } else {
                    helpPanel
                        .frame(maxHeight: 220)
                }
            }
        }
    }
    
    private var showHintPanel: Bool {
        let hint = hintText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let code = hintCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !hint.isEmpty || !code.isEmpty
    }
    
    private var showSolutionPanel: Bool {
        let solution = solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !solution.isEmpty
    }
    
    private var helpPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(showSolutionPanel ? "Solution" : "Hint")
                        .font(.headline)
                    Spacer()
                    Button(isHelpPanelCollapsed ? "Expand" : "Collapse") {
                        isHelpPanelCollapsed.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                
                if showSolutionPanel {
                    if let explanation = solutionExplanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if showHintPanel {
                    if let hintText, !hintText.isEmpty {
                        Text(hintText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if showCodePreview {
                    SourceEditor(
                        .constant(previewCode),
                        language: language.codeLanguageOfCodeEditSourceEditor,
                        configuration: SourceEditorConfiguration(
                            appearance: .init(
                                theme: theme,
                                font: font,
                                wrapLines: true
                            ),
                            behavior: .init(
                                isEditable: false,
                                indentOption: indentOption
                            ),
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
                    .frame(minHeight: 120, maxHeight: 200)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
    
    private var collapsedHelpBar: some View {
        HStack {
            Text(showSolutionPanel ? "Solution" : "Hint")
                .font(.headline)
            Spacer()
            Button("Expand") {
                isHelpPanelCollapsed = false
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var previewCode: String {
        let solution = solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !solution.isEmpty {
            return solution
        }
        let hint = hintCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hint
    }
    
    private var showCodePreview: Bool {
        !previewCode.isEmpty
    }
}
