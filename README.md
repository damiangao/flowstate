# flowstate

Human attention is the bottleneck of AI. FlowState is an attention operating system that helps one person manage, prioritize, and collaborate with dozens of AI agents while staying in flow.

[中文说明](README.zh-CN.md)

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

## Terminal jump

When an agent needs you, click it in the panel to jump back to the terminal tab it is running in — as long as that tab is still open.

| Terminal | Jump precision | How it maps |
| --- | --- | --- |
| Warp | Exact session | `warp://session/<uuid>` |
| Terminal.app | Exact tab | AppleScript match by tty |
| iTerm2 | Exact session | AppleScript match by `ITERM_SESSION_ID` GUID |
| Ghostty | Not supported | no per-surface id exposed to the shell |
