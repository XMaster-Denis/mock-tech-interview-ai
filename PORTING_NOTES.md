# iOS Porting Notes

- Shared core code now lives under `MockTechInterviewAI/Shared` (Domain, Data, Core, and ViewModels) and is included in both targets.
- Platform adapters:
  - `MockTechInterviewAI/Shared/Core/Utils/PlatformTypes.swift` defines `PlatformColor`/`PlatformFont` and shared `Color` helpers.
  - `MockTechInterviewAI/UI/Shared/View+PlatformHelp.swift` hides `.help` on iOS while keeping macOS tooltips.
- UI split:
  - macOS UI remains under `MockTechInterviewAI/UI/macOS` and uses CodeEditSourceEditor for the code editor.
  - iOS UI lives under `MockTechInterviewAI/UI/iOS` and uses a CodeMirror-powered web editor for syntax highlighting and line numbers.
- iOS editor assets live under `MockTechInterviewAI/Resources/CodeMirror` and are loaded locally in the WebView.
- Assets:
  - iOS uses `MockTechInterviewAI/Assets-iOS.xcassets` with `AppIcon-iOS` generated from the existing 1024px icon.
- Info.plist:
  - iOS uses `Info-iOS.plist` to avoid copying conflicts in the synchronized resource group.
- iOS-specific behavior:
  - Microphone permission is explicitly requested via `AVAudioSession` in the iOS main view.
