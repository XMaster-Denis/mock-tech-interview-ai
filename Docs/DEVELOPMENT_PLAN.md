# MockTechInterview AI - Development Plan

## Goals
- Deliver a stable, responsive interview experience with reliable voice interaction.
- Provide consistent, compact prompts to reduce token usage and latency.
- Improve topic diversity and reduce repetition across sessions.
- Maintain a clean MVVM codebase suitable for public contribution.

## Near-Term Milestones
1. Stability and UX
   - Harden audio capture and transcription boundaries.
   - Improve TTS interruption handling and replay controls.
   - Resolve UI update warnings and edge cases.
2. Interview Flow Quality
   - Enforce mode separation (CHECK / GEN_TASK / ASSIST_HELP).
   - Improve hint vs full-solution handling.
   - Expand topic diversity with recent_topics and avoid lists.
3. Localization and Translation
   - Complete UI translations for EN/DE/RU.
   - Provide inline translation tooltips for AI responses.

## Mid-Term Milestones
- Add richer analytics for user progress (topic mastery, weak areas).
- Provide onboarding and example sessions for new users.
- Add additional interview modes (behavioral, system design).

## Open Items and Constraints
- Module name remains unchanged for build stability. Renaming will be revisited after a full target/module audit.
- Public licensing is pending (see LICENSE for current status).

## Quality Bar
- No regressions in interview flow.
- Compact message payloads (2-4 messages per request).
- Tests cover response validation and retry/fallback logic.
