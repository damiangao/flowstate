# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build
swift run FlowState
swift run FlowStateSelfTest
./scripts/build-app.sh
open .build/FlowState.app
./scripts/build-app.sh --install --open
./scripts/build-app.sh --install --open --install-hooks
```

`FlowStateSelfTest` is an assert-based executable, not XCTest. There is no single-test runner yet.

## Project status

FlowState is a minimal SwiftPM macOS prototype that reads Claude Code hook events from `~/.flowstate/events.jsonl`, shows attention debt in a right-edge hover panel, and jumps back to Warp sessions when available. Build artifacts live under `.build/` and are ignored.

## What FlowState is

An **operating system for human attention** in the age of AI agents. The full product brief is in `SPARK.md` — read it before proposing features or architecture. The core thesis:

> Human attention, not compute, is the bottleneck of AI. FlowState schedules human attention the way an OS schedules CPU time.

Mental model: an **Attention Scheduler / Attention Runtime**, NOT a chat app, dashboard, workflow builder, task manager, or agent framework. It helps one person supervise 10 → 100+ concurrent agents without dropping, forgetting, or over-attending to any of them. The guiding question the product must always answer for the user is *"What deserves my attention right now?"*

## Architecture

- `Sources/FlowStateCore/` is pure logic shared by the app and self-test:
  - `HookEvent` parses JSONL hook events from `~/.flowstate/events.jsonl`.
  - `AgentLog` folds events into the latest `Agent` per Claude session.
  - `StatusIcon` maps agent states to the red/yellow/gray attention signal and debt count.
  - `HookConfig` checks whether Claude Code Stop/Notification/UserPromptSubmit hooks point at `flowstate-hook.sh`.
- `Sources/FlowState/` is the AppKit executable:
  - `EventStore` polls the events file once per second and publishes folded agents.
  - `EdgePanelController` owns the borderless right-edge panel. The collapsed strip expands on hover into the agent list and can be dragged vertically.
  - `main.swift` wires the store to the panel and keeps the current Warp-only jump behavior.
- `scripts/build-app.sh` wraps the SwiftPM release executable into `.build/FlowState.app` and can optionally install/open it and merge FlowState hooks.
- `hooks/flowstate-hook.sh` appends Claude hook payloads to `~/.flowstate/events.jsonl`, adding branch and Warp terminal session metadata.
- `settings-snippet.json` shows the Claude Code hook configuration needed to feed the app.

The current terminal jump support is intentionally Warp-only. Terminal.app, iTerm2, and Ghostty support are deferred.

## Design constraints (from SPARK.md)

These are hard filters, not aspirations. Apply them to every proposal:

- Optimize for **lower cognitive load**, never "more features."
- Every interruption has a cost — interrupt only when value exceeds that cost.
- Humans make decisions; agents perform execution.
- AI adapts to human attention; the human never adapts to the AI.
- Sessions must be pausable, resumable, summarizable.
- Justify each feature through attention economics: what attention problem it solves, whether it reduces cognitive load / decision latency / context switching, whether AI could automate it instead, and whether/why it should interrupt the user.

## Working style expected here

`SPARK.md` frames the collaborator role explicitly: challenge assumptions rather than agree by default, reason from first principles, prefer elegant abstractions over complex implementations, and reference existing proven interaction patterns instead of reinventing them. Think like a systems designer, not a frontend dev.
