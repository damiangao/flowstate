# FlowState

A macOS app that tells you which of your Claude Code agents needs you right now.

[中文说明](README.zh-CN.md)

## What it is

Human attention is the bottleneck of AI.

When you run many Claude Code sessions at once, they all finish, block, and wait for you at different times. You forget the ones that are done, miss the ones that are blocked on a permission prompt, and sink half an hour into one while ten others sit idle. FlowState is a thin panel pinned to the right edge of your screen that answers one question: **what deserves my attention right now?**

It is a companion to [Claude Code](https://docs.claude.com/en/docs/claude-code) — it reads Claude Code's hook events and shows nothing on its own. No other agent runners are supported.

## What you see

A collapsed strip on the right edge shows a single signal color, worst-state-wins across all your agents:

- 🔴 **Red** — an agent is blocked (permission prompt, waiting on you)
- 🟡 **Yellow** — an agent finished or is idle, waiting for your next move
- ⚪️ **Gray** — everything is running, nothing needs you

The strip also shows a debt count: how many agents are waiting on you. Hover to expand into the full list — each row is one session (`directory·branch`), its state, and how long it has been waiting. Click a row to jump back to the terminal tab it runs in. Drag the strip vertically to reposition it.

## Requirements

- macOS
- [Claude Code](https://docs.claude.com/en/docs/claude-code) with the FlowState hooks installed (see below)

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

FlowState reads Claude Code events from `~/.flowstate/events.jsonl`, populated by `Stop`, `Notification`, and `UserPromptSubmit` hooks. Install them with:

```bash
./scripts/build-app.sh --install-hooks
```

The installer preserves other hooks in `~/.claude/settings.json` and writes a backup to `~/.claude/settings.json.bak`.

## Terminal jump

Click an agent in the panel to jump back to the terminal tab it runs in — as long as that tab is still open.

| Terminal | Jump precision | How it maps |
| --- | --- | --- |
| Warp | Exact session | `warp://session/<uuid>` |
| Terminal.app | Exact tab | AppleScript match by tty |
| iTerm2 | Exact session | AppleScript match by `ITERM_SESSION_ID` GUID |
| Ghostty | Not supported | no per-surface id exposed to the shell |
