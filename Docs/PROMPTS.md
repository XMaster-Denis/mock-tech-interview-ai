# MockTechInterview AI - Prompts

## Location
System and developer prompts live in `MockTechInterviewAI/Core/Prompts/PromptTemplates.swift`.

## Guidelines
- Keep prompts short and mode-specific.
- Do not mix task generation with solution checking.
- Always request strict JSON without markdown.
- Use compact context: current task, requirements, and current code only.

## Modes
- CHECK: Validate user solution and return is_correct + task_state.
- GEN_TASK: Generate a new short task and aicode template.
- ASSIST_HELP: Provide hints or a full solution based on HelpMode.

## Translation
Translation prompts are used only for UI tooltips and must be concise.
