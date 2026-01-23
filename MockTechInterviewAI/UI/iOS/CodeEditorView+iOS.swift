import SwiftUI
import SwiftUICodeEditorView

#if os(iOS)

struct CodeEditorView: View {
    @Binding var code: String
    let hintText: String?
    let hintCode: String?
    let solutionCode: String?
    let solutionExplanation: String?
    let language: CodeLanguageInterview
    let isEditable: Bool

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
    }

    var body: some View {
        VStack(spacing: 0) {
            SwiftUICodeEditorView(
                text: $code,
                language: language.swiftUICodeLanguage,
                isEditable: isEditable,
                showsLineNumbers: true
            )

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

    private var previewCode: String {
        if showSolutionPanel {
            return solutionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return hintCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var showCodePreview: Bool {
        !previewCode.isEmpty
    }

    private var helpPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(showSolutionPanel ? LocalizedStringKey("code_panel.solution") : LocalizedStringKey("code_panel.hint"))
                        .font(.headline)
                    Spacer()
                    Button(isHelpPanelCollapsed ? LocalizedStringKey("code_panel.expand") : LocalizedStringKey("code_panel.collapse")) {
                        isHelpPanelCollapsed.toggle()
                    }
                    .buttonStyle(.bordered)
                }

                if showSolutionPanel {
                    if let explanation = solutionExplanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if showHintPanel {
                    if let hintText, !hintText.isEmpty {
                        Text(hintText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if showCodePreview {
                    SwiftUICodeEditorView(
                        text: .constant(previewCode),
                        language: language.swiftUICodeLanguage,
                        isEditable: false,
                        showsLineNumbers: true
                    )
                    .frame(minHeight: 120, maxHeight: 200)
                }
            }
            .padding(12)
        }
    }

    private var collapsedHelpBar: some View {
        Button(action: { isHelpPanelCollapsed.toggle() }) {
            HStack {
                Image(systemName: "chevron.up")
                Text(showSolutionPanel ? LocalizedStringKey("code_panel.solution") : LocalizedStringKey("code_panel.hint"))
                Spacer()
                Text("code_panel.expand")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#endif
