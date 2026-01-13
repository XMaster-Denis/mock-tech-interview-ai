# Code Interview Mode

## Overview

The application supports two interview modes to provide flexibility in how interviews are conducted. The AI responds with structured JSON that indicates the type of task and any actions to perform on the code editor.

## JSON Response Format

The AI always responds with valid JSON containing the following structure:

```json
{
  "task_type": "question|code_task",
  "spoken_text": "text to be spoken by TTS",
  "code_template": "code template (for code tasks)",
  "editor_action": {...},
  "evaluation": {...},
  "hint_context": {...}
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `task_type` | `"question"` or `"code_task"` | Type of task being presented |
| `spoken_text` | string | Text to be spoken aloud to user |
| `code_template` | string (optional) | Code template for user to complete |
| `editor_action` | object (optional) | Action to perform on the code editor |
| `evaluation` | object (optional) | Code evaluation result |
| `hint_context` | object (optional) | Hint when AI provides assistance |

## Interview Modes

### 1. Questions Only Mode (`questionsOnly`)

**Purpose:** Standard interview dialogue without code tasks

**Behavior:**
- AI asks theoretical questions
- User responds verbally
- Code editor remains available but not actively used by AI
- `task_type` is always `"question"`
- `editor_action` is always `{"type": "none"}`
- `code_template` is always `null`

**Example Response:**
```json
{
  "task_type": "question",
  "spoken_text": "What are optionals in Swift?",
  "code_template": null,
  "editor_action": {"type": "none"},
  "evaluation": null,
  "hint_context": null
}
```

### 2. Code Tasks Mode (`codeTasks`)

**Purpose:** AI presents coding challenges that user solves in the editor

**Behavior:**
- AI gives short coding challenges (1 line of code maximum)
- When presenting a task, AI provides a code template
- User writes code in the editor
- AI evaluates code when user indicates completion
- AI provides hints when user is stuck

**Task Presentation:**
```json
{
  "task_type": "code_task",
  "spoken_text": "Write a function that returns true if a number is even",
  "code_template": "func isEven(_ number: Int) -> Bool {\n  // TODO: implement\n}",
  "editor_action": {
    "type": "replace",
    "range": {"location": 0, "length": 0},
    "text": "func isEven(_ number: Int) -> Bool {\n  // TODO: implement\n}"
  },
  "evaluation": null,
  "hint_context": null
}
```

## Editor Actions

### Insert
Insert code at cursor position:
```json
{
  "type": "insert",
  "text": " number % 2 == 0",
  "location": 50
}
```

### Replace
Replace existing code with new code:
```json
{
  "type": "replace",
  "range": {"location": 0, "length": 0},
  "text": "func isEven(_ number: Int) -> Bool {\n  // TODO\n}"
}
```

### Clear
Clear entire editor:
```json
{
  "type": "clear"
}
```

### Highlight
Highlight specific ranges:
```json
{
  "type": "highlight",
  "ranges": [{"location": 10, "length": 20}]
}
```

### None
No action:
```json
{
  "type": "none"
}
```

## Hint System

When user is stuck and says phrases like "I don't know" or "Help me", AI provides hints.

### Code Insertion Hints

AI inserts actual code into the editor and explains what it does:

```json
{
  "task_type": "code_task",
  "spoken_text": "Use modulo operator % to check for even numbers",
  "hint_context": {
    "type": "code_insertion",
    "code": " number % 2 == 0",
    "explanation": "The % operator returns remainder of division",
    "highlight_range": {"location": 50, "length": 17}
  }
}
```

### Text Hints

AI only provides verbal hints without inserting code:

```json
{
  "task_type": "code_task",
  "spoken_text": "Think about what operator could help you check if a number is divisible by 2",
  "hint_context": {
    "type": "text_hint",
    "explanation": "Suggest using modulo operator"
  }
}
```

### Hint Detection Phrases

**Russian:**
- "Не знаю" (I don't know)
- "Не понимаю" (I don't understand)
- "Не получается" (It's not working)
- "Помоги" (Help me)
- "Как это сделать?" (How do I do this?)
- "Я застрял" (I'm stuck)

**English:**
- "I don't know"
- "I don't get it"
- "I'm not sure"
- "Help me"
- "How do I do this?"
- "I'm stuck"

**German:**
- "Ich weiß nicht"
- "Ich verstehe nicht"
- "Ich bekomme es nicht hin"
- "Hilf mir"
- "Wie mache ich das?"
- "Ich komme nicht weiter"

## Completion Detection

The AI should understand from **context** when the user indicates their code is ready for evaluation. This is not a strict keyword match - the AI interprets user intent.

### Completion Context Examples

**Russian:**
- "Я дописал код" (I finished the code)
- "Готово" (Done)
- "Проверь код" (Check the code)
- "Я закончил" (I finished)
- "Можешь посмотреть?" (Can you take a look?)
- "Вот что получилось" (Here's what I got)
- "Как тебе?" (What do you think?)
- "Проверяй" (Check it)
- "Все готово" (Everything is ready)

**English:**
- "I'm done"
- "My code is ready"
- "Check my code"
- "Done"
- "I finished"
- "Can you take a look?"
- "Here's what I wrote"
- "What do you think?"
- "Check it"
- "Everything is ready"

**German:**
- "Ich bin fertig"
- "Der Code ist fertig"
- "Prüfe meinen Code"
- "Erledigt"
- "Kannst du mal schauen?"
- "Das ist mein Code"
- "Was denkst du?"
- "Überprüfe es"
- "Alles ist fertig"

### Code Evaluation

When the AI detects completion intent:

1. Read the current code from the editor
2. Evaluate correctness
3. Provide feedback (brief and encouraging)
4. If incorrect, provide hints without revealing the solution
5. If correct, acknowledge success and optionally move to the next task

**Successful Evaluation:**
```json
{
  "task_type": "code_task",
  "spoken_text": "Excellent! That's correct.",
  "evaluation": {
    "is_correct": true,
    "feedback": "Excellent! That's correct.",
    "suggestions": [],
    "severity": "info",
    "issue_lines": []
  }
}
```

**Incorrect Evaluation:**
```json
{
  "task_type": "code_task",
  "spoken_text": "Almost there! Think about what operator checks for divisibility.",
  "evaluation": {
    "is_correct": false,
    "feedback": "Almost there! Think about what operator checks for divisibility.",
    "suggestions": ["Consider the modulo operator"],
    "severity": "warning",
    "issue_lines": [2]
  }
}
```

## Task Design Guidelines

### Code Tasks Mode

- Keep tasks extremely short - **1 line of code maximum**
- Focus on specific concepts rather than full implementations
- Provide clear, minimal code templates
- Examples:
  - "Write a function that returns `true` if a number is even"
  - "Complete this property to return the array count"
  - "Add a computed property that doubles the value"
  - "Implement a guard statement that checks if a string is empty"

**Code Template Examples:**

```swift
// Function completion
func isEven(_ number: Int) -> Bool {
    // TODO: implement
}

// Property completion
var count: Int {
    // TODO: return array count
}

// Guard statement
func process(_ text: String) {
    // TODO: add guard for empty string
}
```

## Implementation Architecture

### Flow

1. **Mode Selection**: User selects interview mode (Questions Only / Code Tasks)
2. **Opening**: AI starts conversation
3. **Task Presentation**:
   - For `question`: AI asks verbally
   - For `code_task`: AI inserts code template + speaks description
4. **User Response**:
   - User responds verbally or edits code
5. **Completion Detection**: AI detects when user indicates readiness
6. **Evaluation**: AI evaluates code if applicable
7. **Hints**: If user is stuck, AI provides hints
8. **Next Task**: Cycle continues

### Code of Conduct

- Global mode setting applies to all topics
- AI receives current mode via system prompt
- Code editor is always visible (for future mixed mode support)
- User can edit code in editor at any time
- AI only evaluates code when user indicates completion
- Hints should be progressive (text hints first, then code hints)

## Topic Compatibility

- Global mode setting applies to all topics
- AI decides whether a topic is suitable for code tasks
- If topic doesn't support code tasks, continue with dialogue only
- Example: Code tasks for Swift fundamentals, questions only for soft skills

## Future Enhancements

### Mixed Mode (Planned)
- Combine questions and code tasks within the same interview
- AI switches between question types dynamically based on topic and user progress
- Seamless transitions between verbal and coding exercises

### Hint Progression
- First hint: Text hint only
- Second hint: Text hint with stronger clue
- Third hint: Code insertion with explanation
- After 3 failed attempts: Reveal solution (optional)

## Example Session (Code Tasks Mode)

```
AI: [Inserts template] "Write a function that returns true if a number is even"
    
Code Editor:
    func isEven(_ number: Int) -> Bool {
        // TODO: implement
    }

User: [Writes code] return number % 2 == 0
User: "Done"

AI: "Excellent! That's correct. Next task..."
AI: [Inserts template] "Add a guard statement to check if text is empty"

Code Editor:
    func process(_ text: String) {
        guard !text.isEmpty else { return }
        // ...rest of function
    }

User: "I don't know how to write the guard"

AI: [Inserts hint] "Use guard followed by a condition, then return if empty"
    [Inserts code] "guard !text.isEmpty else { return }"

User: "Thanks, I get it now!"
