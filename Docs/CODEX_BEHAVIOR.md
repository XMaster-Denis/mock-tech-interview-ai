# MockTechInterview AI - Codex Behavior

## Principles
- Prefer minimal, targeted changes that preserve current behavior.
- Keep prompts compact and mode-specific.
- Avoid adding conversational history to LLM requests unless required.
- Preserve MVVM boundaries (Views -> ViewModels -> Domain -> Data).

## Response Handling
- Always validate JSON responses from the LLM.
- Retry once with a strict schema reminder if required fields are missing.
- Provide safe fallbacks when validation fails after retry.

## Modes
- CHECK: Validate user code and return is_correct + task_state.
- GEN_TASK: Generate a new task with aicode template.
- ASSIST_HELP: Provide hints or full solution depending on HelpMode.

## Logging
- Log only what is needed for debugging.
- Avoid logging full transcripts or API keys.

## UI Behavior
- UI updates must occur on the main thread.
- Do not block the UI during network calls.
- Keep transcript updates ordered and consistent with TTS playback.
