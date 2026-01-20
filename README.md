# MockTechInterview AI

Live Coding & Voice-Based Technical Interview Training

A macOS application for training technical interviews using live coding, voice interaction, and AI-powered interview simulation.

## Features
- Live Swift code editor
- Voice-based interview simulation
- Teacher Mode & Interview Mode
- Multilingual support (EN / DE / RU)
- Session history & transcript logging
- MVVM architecture


## What This App Is For
MockTechInterview AI is a training environment for technical interviews. It combines a live code editor with voice-based conversation so you can practice explaining concepts, answering questions, and solving small coding tasks in a realistic interview flow.

## How You Can Use It
- Practice answering theory questions out loud in your chosen interview language.
- Solve short coding tasks with a live editor and immediate AI feedback.
- Use Teacher Mode to get hints or full solutions when you get stuck.
- Track progress through session history and transcripts.

## Topic Configuration
Topics define what the AI will ask and how the interview behaves. Each topic includes:
- Title: the topic name shown in the sidebar.
- Prompt: a short description that guides the interviewer behavior.
- Programming Language: used for code tasks and examples.
- Interview Mode: questions-only, code tasks, or hybrid.
- Developer Level: junior to senior difficulty.

## Settings Overview
Key settings available in the app:
- OpenAI API Key: entered inside the app after the first launch.
- Interview Language: the language used by the interviewer.
- Interface Language: UI language (EN / DE / RU).
- Model Selection: choose chat, Whisper (STT), and TTS models.
- Voice: select the AI voice for speech playback.
- TTS Interruption: allow or prevent interrupting spoken answers.
- Microphone Test: live audio meter with logs to diagnose input.
- Voice Threshold: microphone sensitivity for speech detection.
- Noise Calibration: calibrate your environment for better detection.
- Silence Timeout: how quickly speech is considered finished.
- Minimum Speech Level: filter out low-level noise.

## Tech Stack
- Swift
- SwiftUI
- AppKit
- Combine
- MVVM
- OpenAI API (Chat / Whisper / TTS)

## Services and Integrations
- OpenAI Chat models for interview flow, task generation, and response validation
- OpenAI Whisper for speech-to-text transcription
- OpenAI TTS for spoken responses and replayable audio
- Local file storage for session context, transcript history, and cached audio

## Architecture Highlights
- Strict separation of UI (SwiftUI), domain logic, and data access
- Compact LLM prompts with mode separation (check / generate / assist)
- Response validation with retries and safe fallbacks
- Audio pipeline with VAD, silence detection, and TTS interruption handling

## Project Structure (Brief)
- `MockTechInterviewAI/` - Application source code (MVVM)
- Unit tests (Xcode test target)
- `Docs/` - Project documentation and rules

## Setup
- macOS: 14.6+
- Xcode: latest stable recommended
- OpenAI API Key: required

### Run
1. Open `MockTechInterviewAI.xcodeproj` in Xcode.
2. Build and run the `MockInterview AI` target.
3. After the app launches, open Settings and enter your OpenAI API key.

## Disclaimer
This project uses OpenAI APIs and requires a valid API key.
