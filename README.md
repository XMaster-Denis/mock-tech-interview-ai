# XTechInterview

**Live coding interviews with real-time AI feedback**

---

## Overview

XTechInterview is a macOS application for Swift developers that simulates live coding interviews with an AI interviewer. The application supports voice and text-based conversations, code editing with syntax highlighting, and session history tracking.

### Key Features

- 🎤 **Real-Time Voice Interview** - Voice input with Whisper transcription and TTS playback
- 💻 **Code Editor** - Swift syntax highlighting with NSTextView
- 🤖 **AI Interview Modes** - Teacher (coaching) and Interview (probing questions)
- 🌍 **Multi-Language Support** - Russian, English, German
- 📊 **Experience Levels** - Junior, Middle, Senior
- 📝 **Session History** - Persistent transcript and code history

### Technology Stack

- **Platform:** macOS 14+
- **UI Framework:** SwiftUI
- **Language:** Swift 5.9+
- **AI:** OpenAI GPT-4o, Whisper, TTS
- **Audio:** AVAudioEngine, AVAudioPlayer
- **Persistence:** JSON files in Application Support

---

## Getting Started

### Prerequisites

1. macOS 14 or later
2. Xcode 15 or later
3. OpenAI API key (get it at https://platform.openai.com/api-keys)
4. Microphone permission (granted on first use)

### Installation

1. Clone the repository
2. Open `XTechInterview.xcodeproj` in Xcode
3. Build and run (⌘R)

### First Run

1. **Configure API Key** - Open Settings (⚙️) and enter your OpenAI API key
2. **Select Topic** - Choose an interview topic from the sidebar
3. **Start Interview** - Voice interview starts automatically with task briefing
4. **Write Code** - Type Swift code in the editor with syntax highlighting
5. **Get Feedback** - AI provides contextual feedback based on your code and conversation

---

## Documentation

### Specification

**[SPECIFICATION.md](SPECIFICATION.md)** is the authoritative source of truth for the project. It contains:

- **Architecture** - MVVM + Coordinators pattern
- **Domain Model** - All entities and enums
- **Use Cases** - Complete user scenarios
- **API Specification** - OpenAI integration details
- **Business Logic** - AI behavior, modes, languages, levels
- **Engineering Principles** - Coding standards and best practices
- **Project Structure** - File organization
- **Implementation Plan** - Phases and tasks

### Legacy Documentation

Old documentation files have been moved to the **[legacy/](legacy/)** directory for reference only. They may contain contradictions or outdated information. Always refer to **SPECIFICATION.md** for authoritative information.

---

## Project Status

### Current Implementation

The current project is in development. See [SPECIFICATION.md](SPECIFICATION.md#implementation-plan) for the detailed implementation plan.

### Known Limitations

- **No voice-activity detection yet** - Manual stop required for recording
- **Regex-based syntax highlighting** - May miss exotic Swift tokens (raw strings, nested comments)
- **Mock AI responses** - Actual OpenAI API integration in progress
- **No session analysis dashboard** - Planned for Phase 5

---

## Troubleshooting

### Microphone Not Working

1. Check System Settings → Privacy → Microphone
2. Ensure XTechInterview has microphone permission
3. Restart the application

### API Connection Issues

1. Verify your API key is valid
2. Check internet connection
3. Test OpenAI API directly: https://platform.openai.com/playground

See [legacy/VOICE_TROUBLESHOOTING.md](legacy/VOICE_TROUBLESHOOTING.md) for detailed troubleshooting.

### DNS Problems

If you see "A server with a specific hostname couldn't be found" error:

1. Check DNS resolution: `nslookup api.openai.com`
2. Try changing DNS to Google (8.8.8.8) or Cloudflare (1.1.1.1)
3. Use VPN if DNS issues persist

See [legacy/DNS_CHECK.md](legacy/DNS_CHECK.md) for detailed DNS diagnostics.

---

## Development

### Building from Source

```bash
# Clone the repository
git clone <repository-url>
cd XTechInterview

# Open in Xcode
open XTechInterview.xcodeproj

# Build and run (⌘R)
```

### Running Tests

```bash
# Run unit tests
⌘U

# Run UI tests
⌘⌃U
```

### Code Style

Follow the engineering principles outlined in [SPECIFICATION.md](SPECIFICATION.md#engineering-principles):

- **MVVM** - Strict separation of concerns
- **Protocol-first** - Define protocols before implementations
- **MainActor** - All ViewModels must be `@MainActor`
- **No magic values** - Promote to constants
- **Feature-based structure** - Organize by feature, not file type

---

## Roadmap

### Phase 1-4 ✅ (Completed)

- App Skeleton, Navigation, Settings Storage
- Code Editor & Topics Sidebar
- Voice Input/Output (scaffolded)
- AI Interview Logic (scaffolded)

### Phase 5 (In Progress)

- Session Analysis Dashboard
- Progress Metrics and Insights
- Transcript Playback

### Future Enhancements

- Voice Activity Detection (VAD) streaming
- Full parser-based syntax highlighting (SwiftSyntax)
- Keychain storage for API keys
- Session export functionality
- Multi-session comparison

---

## Contributing

Contributions are welcome! Please:

1. Read [SPECIFICATION.md](SPECIFICATION.md) thoroughly
2. Follow engineering principles
3. Keep changes small and buildable
4. Add tests for new features
5. Update documentation

---

## License

This project is proprietary software.

---

## Support

For issues, questions, or feature requests, please open an issue in the repository.

---

**Version:** 0.1.0-dev  
**Last Updated:** 2026-01-10
