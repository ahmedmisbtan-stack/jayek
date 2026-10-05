# Three-AI Bridge: ChatGPT + Gemini + Claude

This repository uses GitHub as the shared workspace.

## Roles
- ChatGPT: coordinator and final reviewer.
- Gemini: execution/engineering agent.
- Claude: independent reviewer and second-opinion agent.
- GitHub Actions: secure asynchronous transport between agents.

## Flow
1. ChatGPT writes a task to `ai_bridge/inbox/`.
2. The task can request Gemini execution and/or Claude review.
3. Agents read the repository directly.
4. Gemini writes execution results to `ai_bridge/results/gemini/`.
5. Claude writes review results to `ai_bridge/results/claude/`.
6. ChatGPT reads both results and decides whether the task is complete.

## Secrets
API keys must never be committed. Configure:
- `GEMINI_API_KEY` (already used by the existing Gemini bridge)
- `ANTHROPIC_API_KEY` (required for the Claude bridge)

Claude is intentionally an independent reviewer; it does not receive the user's credentials.
