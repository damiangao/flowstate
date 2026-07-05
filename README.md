# flowstate

Human attention is the bottleneck of AI. FlowState is an attention operating system that helps one person manage, prioritize, and collaborate with dozens of AI agents while staying in flow.

## Run

Build a double-clickable macOS app:

```bash
./scripts/build-app.sh
open .build/FlowState.app
```

Install it to Applications, install/update Claude Code hooks, and open it:

```bash
./scripts/build-app.sh --install --install-hooks --open
```

Development run:

```bash
swift run FlowState
```

Self-test:

```bash
swift run FlowStateSelfTest
```

## Hooks

FlowState needs Claude Code `Stop`, `Notification`, and `UserPromptSubmit` hooks. Install them with:

```bash
./scripts/build-app.sh --install-hooks
```

The installer preserves other hooks in `~/.claude/settings.json` and writes a backup to `~/.claude/settings.json.bak`.
