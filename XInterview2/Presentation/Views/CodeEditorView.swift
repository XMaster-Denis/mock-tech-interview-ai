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
    let language: CodeLanguageInterview
    let isEditable: Bool

    @State private var editorState = SourceEditorState()
    @State private var theme: EditorTheme = .dark
    @State private var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    @State private var indentOption: IndentOption = .spaces(count: 4)

    @State private var coordinator: CodeEditorCoordinator

    init(
        code: Binding<String>,
        language: CodeLanguageInterview,
        isEditable: Bool = true
    ) {
        self._code = code
        self.language = language
        self.isEditable = isEditable
        _coordinator = State(initialValue: CodeEditorCoordinator(code: code))
    }

    var body: some View {
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
    }
}
