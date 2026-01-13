# Code Interview Mode

## Overview

The application supports two interview modes to provide flexibility in how interviews are conducted.

## Interview Modes

### 1. Questions Only Mode (`questionsOnly`)
- Standard interview dialogue without code tasks
- AI asks theoretical questions
- User responds verbally
- Code editor remains available but not actively used by AI

### 2. Code Tasks Mode (`codeTasks`)
- AI presents coding challenges
- User writes code in the editor
- AI evaluates the code when user indicates completion

## AI Behavior

### Task Design (Code Tasks Mode)
- Keep tasks extremely short - 1 line of code maximum
- Focus on specific concepts rather than full implementations
- Examples:
  - "Write a function that returns `true` if a number is even"
  - "Complete this property to return the array count"
  - "Add a computed property that doubles the value"

### Completion Detection

The AI should understand from **context** when the user indicates their code is ready for evaluation. This is not a strict keyword match - the AI interprets user intent.

#### Completion Context Examples

**Russian:**
- "Я дописал код" (I finished the code)
- "Готово" (Done)
- "Проверь код" (Check the code)
- "Я закончил" (I finished)
- "Можешь посмотреть?" (Can you take a look?)
- "Вот что получилось" (Here's what I got)
- "Как тебе?" (What do you think?)

**English:**
- "I'm done"
- "My code is ready"
- "Check my code"
- "Done"
- "I finished"
- "Can you take a look?"
- "Here's what I wrote"
- "What do you think?"

**German:**
- "Ich bin fertig" (I'm done)
- "Der Code ist fertig" (The code is ready)
- "Prüfe meinen Code" (Check my code)
- "Erledigt" (Done)
- "Kannst du mal schauen?" (Can you take a look?)
- "Das ist mein Code" (This is my code)
- "Was denkst du?" (What do you think?)

### Code Evaluation

When the AI detects completion intent:
1. Read the current code from the editor
2. Evaluate correctness
3. Provide feedback (brief and encouraging)
4. If incorrect, provide hints without revealing the solution
5. If correct, acknowledge success and optionally move to the next task

### Topic Compatibility

- Global mode setting applies to all topics
- AI decides whether a topic is suitable for code tasks
- If topic doesn't support code tasks, continue with dialogue only
- Example: Code tasks for Swift fundamentals, questions only for soft skills

## Future Enhancements

### Mixed Mode (Planned)
- Combine questions and code tasks within the same interview
- AI switches between question types dynamically based on topic and user progress
- Seamless transitions between verbal and coding exercises

## Implementation Notes

- Mode is a global setting, stored in `InterviewViewModel`
- AI receives current mode via system prompt
- Code editor is always visible (for future mixed mode support)
- User can edit code in editor at any time
- AI only evaluates code when user indicates completion
