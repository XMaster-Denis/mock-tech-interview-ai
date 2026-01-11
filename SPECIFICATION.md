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

### EXCLUDED from MVP
- Deep code analysis
- Real-time cursor tracking
- Semantic highlighting of mistakes
- Automatic grading or scoring
- Multi-agent behavior
- Advanced UI customization

## 3. Application Layout (UI Specification)

### 3.1 Menu Bar
Menu: File
- Settings… (API keys, language, voice options)

### 3.2 Left Panel — Interview Topics
Editable list of prompt topics guiding the interview.

### 3.3 Center Panel — Code Editor (Passive in MVP)
Used as visual context only.

### 3.4 Bottom Control
Single Start / Stop Interview button.

### 3.5 Right Panel — Live Transcript
Real-time read-only transcript of user and AI speech.

## 4. Conversation Model

- Short sentences
- One question at a time
- Natural interview tone
- Gentle corrections

## 5. Architecture Constraints

- Simplicity over completeness
- Voice-first interaction
- Phased development

## 6. Success Criteria

The MVP is successful if the conversation feels like a real interview.
