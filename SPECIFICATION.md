# SPECIFICATION — RealVoice Tech Interview Simulator

## 1. Purpose

This application is a macOS simulator of a real-time technical interview
with voice-based AI interaction.

Primary goal of the MVP:
- enable natural two-way spoken dialogue with an AI interviewer
- simulate interview-style conversation (short questions, short answers)
- support multiple languages
- allow the user to think aloud and respond verbally
- provide corrections and feedback in real time

This application is NOT a full coding assistant in the MVP phase.
Advanced code analysis features are planned for later phases.

## 2. MVP Scope (Strict)

### INCLUDED in MVP
- Real-time voice dialogue (user ↔ AI)
- Short conversational questions and answers
- Language selection (RU / EN / DE)
- Interview topic selection via text prompts
- Live transcription (user + AI)
- Minimal UI with focus on conversation
- Manual Start / Stop of the interview session
- Smart audio processing (trimming, VAD, silence detection)
- Technical terminology preservation for non-English languages

### EXCLUDED from MVP
- Deep code analysis
- Real-time cursor tracking
- Semantic highlighting of mistakes
- Automatic grading or scoring
- Multi-agent behavior
- Advanced UI customization

## 3. Interview Modes

### 3.1 Mode Selection
Two interview modes are available (global setting):

**Questions Only Mode:**
- Standard interview dialogue without code tasks
- AI asks theoretical questions
- User responds verbally
- Code editor remains available but not actively used by AI

**Code Tasks Mode:**
- AI presents coding challenges
- User writes code in the editor
- AI evaluates the code when user indicates completion (understands from context)
- Tasks are extremely short - 1 line of code maximum

### 3.2 Completion Detection (Code Tasks)
AI understands from context when user indicates their code is ready for evaluation.
Examples of completion phrases (not strict keyword matching):
- Russian: "Я дописал код", "Готово", "Проверь код", "Я закончил"
- English: "I'm done", "My code is ready", "Check my code", "Done"
- German: "Ich bin fertig", "Der Code ist fertig", "Prüfe meinen Code", "Erledigt"

## 4. Application Layout (UI Specification)

### 4.1 Menu Bar
Menu: File
- Settings… (API keys, language, voice options)

### 4.2 Left Panel — Interview Topics
Editable list of prompt topics guiding the interview.

### 4.3 Center Panel — Code Editor
- User can write and edit code at any time
- AI can insert code snippets and hints
- Real-time syntax highlighting
- Error highlighting from AI feedback

### 4.4 Bottom Control
- Interview mode selector (Questions / Code Tasks)
- Start / Stop Interview button
- Audio level visualizer
- Conversation status indicator

### 4.5 Right Panel — Live Transcript
Real-time read-only transcript of user and AI speech.

## 5. Conversation Model

- Short sentences
- One question at a time
- Natural interview tone
- Gentle corrections
- In Code Tasks mode: extremely short coding challenges (1 line)

## 6. Audio Processing (v0.2.0)

### 6.1 Voice Activity Detection (VAD)
- Continuous audio monitoring at 16kHz sample rate
- Configurable voice detection threshold (0.05 - 0.5, default 0.15)
- Automatic calibration period (1 second) on recording start
- Real-time audio level visualization

### 6.2 Silence Detection
- Configurable silence timeout (0.5s - 3.0s, default 1.5s)
- Visual silence timer with progress indicator
- Accurate speech duration calculation (excludes silence timeout)
- Fallback timer ensures speech end event always triggers

### 6.3 Smart Audio Trimming
- Automatic removal of leading silence before speech
- Automatic removal of trailing silence after speech ends
- Uses AVAssetExportSession with passthrough preset (no re-encoding)
- Reduces file size by 30-50% for faster API processing
- Fallback to original audio if trimming fails

### 6.4 Whisper API Optimization
- **Technical Terminology Prompts**: English tech terms preserved in DE/RU transcriptions
  - Programming languages: Swift, Python, JavaScript, Kotlin, Dart, Rust
  - Frameworks: SwiftUI, UIKit, React, SwiftUI, Django, Flask
  - Tools/APIs: API, SDK, HTTP, REST, GraphQL, JSON, XML
  - Architectures: MVC, MVVM, MVP, Redux, Clean Architecture
  - iOS-specific: Combine, Core Data, Core Animation, App Store
- **Temperature Parameter**: Set to 0.0 for more deterministic transcriptions
- **Audio Format**: 16kHz, mono, 16-bit PCM WAV

## 7. Architecture Constraints

- Simplicity over completeness
- Voice-first interaction
- Phased development

## 8. Audio Processing Benefits

The smart audio processing system provides:

1. **Faster Response Times**: 30-50% smaller audio files upload faster to Whisper API
2. **Cost Reduction**: Proportional reduction in Whisper API costs per session
3. **Improved Accuracy**: Only speech data is transcribed, eliminating silence interference
4. **Technical Accuracy**: English technical terms are preserved intact in German/Russian transcriptions
5. **Natural Conversations**: Proper silence detection allows natural speech patterns with pauses

## 9. Technical Specifications

### 9.1 Audio Settings
- Sample Rate: 16,000 Hz
- Channels: 1 (mono)
- Bit Depth: 16-bit PCM
- Audio Format: Linear PCM (WAV)
- Buffer Duration: Continuous recording until speech end

### 9.2 Whisper API Integration
- Model: whisper-1
- Endpoint: https://api.openai.com/v1/audio/transcriptions
- Parameters:
  - `file`: WAV audio data (trimmed)
  - `model`: "whisper-1"
  - `language`: Auto-detected (en, de, ru)
  - `prompt`: Technical terminology prompt based on conversation language
  - `temperature`: 0.0 (deterministic)

### 9.3 TTS API Integration
- Model: tts-1
- Endpoint: https://api.openai.com/v1/audio/speech
- Parameters:
  - `model`: "tts-1"
  - `input`: AI response text
  - `voice`: alloy, echo, fable, onyx, nova, shimmer (configurable)
  - `response_format`: "mp3"
  - `speed`: 1.0 (normal)

### 9.4 Chat API Integration
- Model: gpt-4o
- Endpoint: https://api.openai.com/v1/chat/completions
- Parameters:
  - `model`: "gpt-4o"
  - `messages`: Conversation history with system prompt
  - `temperature`: 0.7 (balanced creativity)
  - `max_tokens`: 300 (short interview responses)

## 10. Success Criteria

The MVP is successful if:
- Conversation feels like a real interview
- Audio trimming reduces file size by 30-50%
- Technical terms are preserved correctly in non-English languages
- Silence detection allows natural speech patterns
