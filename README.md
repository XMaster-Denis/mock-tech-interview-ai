# XInterview2

**Live voice interview practice with AI tutor**

---

## Overview

XInterview2 is a macOS application that enables voice-based interview practice with an AI tutor. The app uses OpenAI's APIs for speech recognition, text-to-speech, and conversation to provide an interactive interview experience.

### Key Features

- 🎤 **Full Duplex Audio** - Continuous voice input and interruptible AI responses
- 🎯 **Voice Activity Detection** - Automatic speech detection with configurable threshold
- ✂️ **Smart Audio Trimming** - Automatically removes silence before and after speech for faster API processing
- 🗣️ **Speech-to-Text** - OpenAI Whisper API with technical terminology prompts
- 🔊 **Text-to-Speech** - 6 OpenAI TTS voices (alloy, echo, fable, onyx, nova, shimmer)
- 💬 **AI Conversation** - GPT-4 powered interview conversations
- 🌍 **Multi-Language Support** - English, German, Russian with tech term preservation
- 📝 **Transcript History** - Real-time chat history display
- 🎛️ **Configurable Settings** - API key, language, voice, voice threshold, silence timeout

### Technology Stack

- **Platform:** macOS 14+
- **UI Framework:** SwiftUI
- **Language:** Swift 5.9+
- **AI Services:** OpenAI GPT-4, Whisper v1, TTS-1
- **Audio:** AVAudioRecorder, AVAudioPlayer
- **Architecture:** Clean Architecture (MVVM)

---

## Getting Started

### Prerequisites

1. macOS 14 or later
2. Xcode 15 or later
3. OpenAI API key (get it at https://platform.openai.com/api-keys)
4. Microphone permission (granted on first use)

### Installation

1. Clone repository
2. Open `XInterview2.xcodeproj` in Xcode
3. Build and run (⌘R)

### First Run

1. **Configure API Key** - Open Settings (⚙️) and enter your OpenAI API key
2. **Select Topic** - Choose an interview topic (Swift Basics, iOS Development, System Design)
3. **Select Language** - Choose preferred conversation language
4. **Start Interview** - Voice interview starts with AI greeting
5. **Speak** - AI will listen and respond to your answers

---

## Current Status

### ✅ Version 0.1.0-Baseline (Working)

The application is now in a stable baseline state with all core features working:

#### Working Features
- ✅ Full duplex audio conversation
- ✅ Voice activity detection with configurable threshold (default 0.15)
- ✅ Smart audio trimming with AVFoundation - removes leading/trailing silence
- ✅ Speech-to-text via OpenAI Whisper API with technical term preservation
- ✅ Technical prompts for EN/DE/RU languages - preserves English tech terms in non-English speech
- ✅ Temperature optimization (0.0) for more accurate transcriptions
- ✅ Text-to-speech via OpenAI TTS API
- ✅ Interruptible AI responses during conversation
- ✅ Non-interruptible opening AI greeting
- ✅ Transcript view with real-time chat history
- ✅ Audio level visualization with silence timer
- ✅ Settings with API key, language, voice, voice threshold, silence timeout
- ✅ Multi-language support (English, German, Russian)
- ✅ Multiple interview topics
- ✅ Proper error handling with audio trimming fallback

#### Known Issues
- ⚠️ Swift 6 Sendable warnings in DefaultHTTPClient (non-blocking)
- ⚠️ Voice detection may need adjustment in noisy environments
- ⚠️ AVAssetExportPassthrough may not work on all macOS versions (fallback to original audio if trim fails)

#### Architecture
The project follows Clean Architecture principles:
- **Core Layer:** Constants, Logger utility
- **Domain Layer:** Models (Settings, Language, InterviewTopic, TranscriptMessage)
- **Data Layer:** Services (Whisper, Chat, TTS), Repositories, Audio components
- **Presentation Layer:** ViewModels, Views (Main, Settings, Transcript, AudioLevel)

---

## Project Documentation

### Engineering Rules

The project follows strict engineering guidelines documented in:
- **[Docs/ENGINEERING_RULES.md](Docs/ENGINEERING_RULES.md)** - Coding standards and best practices
- **[Docs/ARCHITECTURE_GUIDELINES.md](Docs/ARCHITECTURE_GUIDELINES.md)** - Architecture patterns
- **[Docs/REFERENCE_PATTERNS.md](Docs/REFERENCE_PATTERNS.md)** - Reference implementation patterns
- **[Docs/TESTING_AND_QA_RULES.md](Docs/TESTING_AND_QA_RULES.md)** - Testing guidelines
- **[Docs/WEB_RESEARCH_RULES.md](Docs/WEB_RESEARCH_RULES.md)** - Research guidelines

### Specification

**[SPECIFICATION.md](SPECIFICATION.md)** contains the authoritative specification for the project.

---

## Troubleshooting

### Microphone Issues

1. Check System Settings → Privacy → Microphone
2. Ensure XInterview2 has microphone permission
3. Adjust voice threshold in Settings if false positives occur

### Voice Detection Issues

- If speech is detected too often (background noise): **Increase voice threshold** (move slider right)
- If speech is not detected when speaking: **Decrease voice threshold** (move slider left)
- Threshold range: 0.05 (very sensitive) to 0.5 (least sensitive)

### Silence Detection Issues

- If speech is cut off too quickly: **Increase silence timeout** (move slider right)
- If silence takes too long to trigger: **Decrease silence timeout** (move slider left)
- Silence timeout range: 0.5s (fast) to 3.0s (slow)

### Audio Trimming Benefits

The smart audio trimming feature provides significant benefits:
- **Faster API response** - 30-50% smaller files upload faster to Whisper API
- **Cost savings** - Reduced file size proportionally reduces Whisper API costs
- **Better accuracy** - Only speech data is transcribed, no silence interference
- **Technical term preservation** - English tech terms kept intact in DE/RU transcriptions

### API Connection Issues

1. Verify your API key is valid
2. Check internet connection
3. Test OpenAI API directly: https://platform.openai.com/playground

### Build Warnings

- Swift 6 Sendable warnings in DefaultHTTPClient are expected and do not affect functionality
- These will be addressed in a future update

---

## Development

### Building from Source

```bash
# Clone repository
git clone <repository-url>
cd XInterview2

# Open in Xcode
open XInterview2.xcodeproj

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

Follow engineering principles outlined in the documentation:
- **Clean Architecture** - Strict layer separation
- **Protocol-first** - Define protocols before implementations
- **MVVM** - Model-View-ViewModel pattern
- **@MainActor** - All ViewModels are main actor isolated
- **No magic values** - Use named constants
- **Comprehensive logging** - Use Logger utility with timestamps

---

## Roadmap

### ✅ Completed (v0.1.0-Baseline)

- App skeleton with Clean Architecture
- Settings management (API key, language, voice, threshold)
- Full duplex audio system
- Voice activity detection
- Whisper API integration
- TTS API integration
- Chat API integration
- Transcript view
- Audio level visualization

### Future Enhancements

- Session history persistence
- Session export functionality
- Code editor integration
- Interview performance analytics
- Multiple session comparison
- Enhanced voice detection (streaming VAD)
- UI/UX improvements
- Fix Swift 6 Sendable warnings
- Custom technical term lists per interview topic

---

## Contributing

Contributions are welcome! Please:

1. Read all documentation in the `Docs/` directory
2. Follow engineering principles and coding standards
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

**Version:** 0.2.0-audio-optimization  
**Last Updated:** 2026-01-12
**Git Tags:** v0.1.0-baseline, v0.2.0-audio-optimization
