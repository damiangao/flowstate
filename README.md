# flowstate

Human attention is the bottleneck of AI. FlowState is an attention operating system that helps one person manage, prioritize, and collaborate with dozens of AI agents while staying in flow.

> 中文：人的注意力才是 AI 时代的瓶颈。FlowState 是一个注意力操作系统，帮助一个人在保持心流的同时管理、排序并协作数十个 AI agents。

## Run / 运行

Build a double-clickable macOS app:

构建一个可双击打开的 macOS app：

```bash
./scripts/build-app.sh
open .build/FlowState.app
```

Install it to Applications, install/update Claude Code hooks, and open it:

安装到 Applications，安装/更新 Claude Code hooks，并打开：

```bash
./scripts/build-app.sh --install --install-hooks --open
```

Development run:

开发运行：

```bash
swift run FlowState
```

Self-test:

自测：

```bash
swift run FlowStateSelfTest
```

## Hooks / Hooks 配置

FlowState needs Claude Code `Stop`, `Notification`, and `UserPromptSubmit` hooks. Install them with:

FlowState 需要 Claude Code 的 `Stop`、`Notification` 和 `UserPromptSubmit` hooks。使用下面命令安装：

```bash
./scripts/build-app.sh --install-hooks
```

The installer preserves other hooks in `~/.claude/settings.json` and writes a backup to `~/.claude/settings.json.bak`.

安装脚本会保留 `~/.claude/settings.json` 里的其他 hooks，并备份到 `~/.claude/settings.json.bak`。
