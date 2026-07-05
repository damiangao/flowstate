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
```

`FlowStateSelfTest` is an assert-based executable, not XCTest. There is no single-test runner yet.

## Architecture

FlowState is a small macOS SwiftPM app that watches Claude Code hook events and shows agent attention state in a right-edge hover panel.

- `Sources/FlowStateCore/` is pure logic shared by the app and self-test:
  - `HookEvent` parses JSONL hook events from `~/.flowstate/events.jsonl`.
  - `AgentLog` folds events into the latest `Agent` per Claude session.
  - `StatusIcon` maps agent states to the red/yellow/gray attention signal and debt count.
  - `HookConfig` checks whether Claude Code Stop/Notification hooks point at `flowstate-hook.sh`.
- `Sources/FlowState/` is the AppKit executable:
  - `EventStore` polls the events file once per second and publishes folded agents.
  - `EdgePanelController` owns the borderless right-edge panel. The collapsed strip expands on hover into the agent list.
  - `main.swift` wires the store to the panel and keeps the current Warp-only jump behavior.
- `scripts/build-app.sh` wraps the SwiftPM release executable into `.build/FlowState.app` and can optionally install/open it.
- `hooks/flowstate-hook.sh` appends Claude hook payloads to `~/.flowstate/events.jsonl`, adding branch and Warp terminal session metadata.
- `settings-snippet.json` shows the Claude Code hook configuration needed to feed the app.

The current terminal jump support is intentionally Warp-only. Terminal.app, iTerm2, and Ghostty support are deferred.
