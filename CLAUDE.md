# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

FlowState now has a minimal SwiftPM macOS menu-bar prototype:

- App target: `swift run FlowState`
- Self-test target: `swift run FlowStateSelfTest`
- Build check: `swift build`

The v0 app reads Claude Code hook events from `~/.flowstate/events.jsonl`, shows
attention debt in the menu bar, and jumps back to Warp sessions when available.
Build artifacts live under `.build/` and are ignored.

## What FlowState is

An **operating system for human attention** in the age of AI agents. The full
product brief is in `SPARK.md` — read it before proposing features or
architecture. The core thesis:

> Human attention, not compute, is the bottleneck of AI. FlowState schedules
> human attention the way an OS schedules CPU time.

Mental model: an **Attention Scheduler / Attention Runtime**, NOT a chat app,
dashboard, workflow builder, task manager, or agent framework. It helps one
person supervise 10 → 100+ concurrent agents without dropping, forgetting, or
over-attending to any of them. The guiding question the product must always
answer for the user is *"What deserves my attention right now?"*

## Design constraints (from SPARK.md)

These are hard filters, not aspirations. Apply them to every proposal:

- Optimize for **lower cognitive load**, never "more features."
- Every interruption has a cost — interrupt only when value exceeds that cost.
- Humans make decisions; agents perform execution.
- AI adapts to human attention; the human never adapts to the AI.
- Sessions must be pausable, resumable, summarizable.
- Justify each feature through attention economics: what attention problem it
  solves, whether it reduces cognitive load / decision latency / context
  switching, whether AI could automate it instead, and whether/why it should
  interrupt the user.

## Working style expected here

`SPARK.md` frames the collaborator role explicitly: challenge assumptions rather
than agree by default, reason from first principles, prefer elegant abstractions
over complex implementations, and reference existing proven interaction patterns
instead of reinventing them. Think like a systems designer, not a frontend dev.
