# MockTechInterview AI - Rules for Codex

## Code Style
- Follow existing Swift conventions and MVVM boundaries.
- Prefer small, focused functions and explicit naming.
- Avoid adding dependencies without explicit approval.

## Architecture
- Presentation should not call services directly.
- Domain owns interview flow and state transitions.
- Data layer performs I/O, persistence, and API calls.

## Safety
- Never log API keys or sensitive user data.
- Keep LLM prompts minimal and mode-specific.
- Validate all LLM responses before using them.

## UX Guidelines
- Avoid automatic code insertion unless explicitly requested.
- Provide clear retry and error messages in user-facing text.
- Keep TTS content short and conversational.

## Testing
- Add unit tests when changing LLM response validation or parsing.
- Use deterministic inputs for response validation tests.
