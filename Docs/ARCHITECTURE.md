# MockTechInterview AI - Architecture

## Overview
MockTechInterview AI is a macOS app built with SwiftUI using MVVM. The app combines live coding, voice interaction, and AI-driven interview simulation. Core responsibilities are split across Presentation, Domain, and Data layers with a thin Core utilities layer.

## Layers
- Presentation: SwiftUI views and view models. Owns UI state, binds to Domain services, and renders transcripts, code editor, and settings.
- Domain: Business logic and core models (InterviewSession, InterviewTopic, InterviewContext, LLMMode, HelpMode). Orchestrates interview flow via managers.
- Data: Integrations and persistence (OpenAI services, audio capture, repositories, file storage).
- Core: Cross-cutting utilities (logging, localization, prompt templates, constants).

## Key Components
- ConversationManager: Orchestrates the interview flow, connects speech recognition, LLM requests, and TTS playback.
- Repositories: Persist settings, context, and history (SettingsRepository, ContextRepository, TopicsRepository).
- Audio Pipeline: Full-duplex audio manager with VAD, silence detection, and TTS playback interruption handling.
- OpenAI Services: Chat, Whisper, and TTS services with strict JSON response handling.

## Data Flow (High Level)
1. User speaks or types.
2. Audio pipeline transcribes speech -> user message.
3. ConversationManager builds compact prompt and calls LLM.
4. LLM JSON response parsed into AIResponse.
5. UI updates transcript, code editor, and task state.
6. TTS plays spoken_text (cached for replay).

## Storage
- Settings: UserDefaults-backed configuration.
- Context: Interview session context (recent topics/questions, last task).
- Transcript: Session message history (lightweight, not full chat history).

## Build and Targets
- Main app target: MockInterview AI
- Test target: Unit tests for response validation, helpers, and audio analysis
