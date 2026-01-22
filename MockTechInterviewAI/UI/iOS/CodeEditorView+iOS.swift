import SwiftUI

#if os(iOS)
import WebKit

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
            CodeMirrorEditorView(
                text: $code,
                language: language,
                isEditable: isEditable,
                showsLineNumbers: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
                    CodeMirrorEditorView(
                        text: .constant(previewCode),
                        language: language,
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

private struct CodeMirrorEditorView: UIViewRepresentable {
    @Binding var text: String
    let language: CodeLanguageInterview
    let isEditable: Bool
    let showsLineNumbers: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, language: language)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "codeDidChange")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.processPool = WebKitProcessPool.shared

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)
        webView.scrollView.isScrollEnabled = true

        if let url = Bundle.main.url(forResource: "editor", withExtension: "html"),
           let rootURL = Bundle.main.resourceURL {
            webView.loadFileURL(url, allowingReadAccessTo: rootURL)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.isEditable = isEditable
        context.coordinator.showsLineNumbers = showsLineNumbers
        context.coordinator.language = language
        context.coordinator.syncIfNeeded(with: uiView, text: text)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var text: String
        var language: CodeLanguageInterview
        var isEditable = true
        var showsLineNumbers = true
        private var isLoaded = false
        private var isApplyingExternalChange = false
        private var lastAppliedText = ""

        init(text: Binding<String>, language: CodeLanguageInterview) {
            self._text = text
            self.language = language
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "codeDidChange" else { return }
            guard !isApplyingExternalChange else { return }
            if let newText = message.body as? String {
                text = newText
                lastAppliedText = newText
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            applyConfiguration(to: webView, text: text)
        }

        func syncIfNeeded(with webView: WKWebView, text: String) {
            guard isLoaded else { return }
            if text != lastAppliedText {
                applyText(text, to: webView)
            }
            applyMode(to: webView)
            applyReadOnly(to: webView)
            applyLineNumbers(to: webView)
        }

        private func applyConfiguration(to webView: WKWebView, text: String) {
            applyText(text, to: webView)
            applyMode(to: webView)
            applyReadOnly(to: webView)
            applyLineNumbers(to: webView)
        }

        private func applyText(_ text: String, to webView: WKWebView) {
            isApplyingExternalChange = true
            let js = "window.setEditorText(\(jsonString(text)));"
            webView.evaluateJavaScript(js) { [weak self] _, _ in
                self?.isApplyingExternalChange = false
            }
            lastAppliedText = text
        }

        private func applyReadOnly(to webView: WKWebView) {
            let js = "window.setEditorReadOnly(\(isEditable ? "false" : "true"));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func applyLineNumbers(to webView: WKWebView) {
            let js = "window.setEditorLineNumbers(\(showsLineNumbers ? "true" : "false"));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func applyMode(to webView: WKWebView) {
            let modeConfig = modeConfiguration(for: language)
            let js = "window.setEditorMode(\(jsonString(modeConfig)));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func jsonString(_ value: Any) -> String {
            if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
               var json = String(data: data, encoding: .utf8) {
                if json.hasPrefix("[") && json.hasSuffix("]") {
                    json.removeFirst()
                    json.removeLast()
                }
                return json
            }
            return "\"\""
        }

        private func modeConfiguration(for language: CodeLanguageInterview) -> [String: Any] {
            switch language {
            case .swift:
                return ["name": "swift"]
            case .python:
                return ["name": "python"]
            case .javascript:
                return ["name": "javascript"]
            case .typescript:
                return ["name": "javascript", "options": ["typescript": true]]
            case .java:
                return ["name": "text/x-java"]
            case .cpp:
                return ["name": "text/x-c++src"]
            case .csharp:
                return ["name": "text/x-csharp"]
            case .go:
                return ["name": "text/x-go"]
            case .php:
                return ["name": "php"]
            case .ruby:
                return ["name": "ruby"]
            case .kotlin:
                return ["name": "text/x-kotlin"]
            case .rust:
                return ["name": "rust"]
            }
        }
    }
}
#endif
