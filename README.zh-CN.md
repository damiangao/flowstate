# flowstate

人的注意力才是 AI 时代的瓶颈。FlowState 是一个注意力操作系统，帮助一个人在保持心流的同时管理、排序并协作数十个 AI agents。

[English README](README.md)

## 运行

构建一个可双击打开的 macOS app：

```bash
./scripts/build-app.sh
open .build/FlowState.app
```

安装到 Applications，安装/更新 Claude Code hooks，并打开：

```bash
./scripts/build-app.sh --install --install-hooks --open
```

开发运行：

```bash
swift run FlowState
```

自测：

```bash
swift run FlowStateSelfTest
```

## Hooks 配置

FlowState 需要 Claude Code 的 `Stop`、`Notification` 和 `UserPromptSubmit` hooks。使用下面命令安装：

```bash
./scripts/build-app.sh --install-hooks
```

安装脚本会保留 `~/.claude/settings.json` 里的其他 hooks，并备份到 `~/.claude/settings.json.bak`。

## 终端跳转

当某个 agent 需要你时，在面板上点它就能跳回它所在的终端标签页——只要那个标签页还开着。

| 终端 | 跳转精度 | 定位方式 |
| --- | --- | --- |
| Warp | 精确到 session | `warp://session/<uuid>` |
| Terminal.app | 精确到标签页 | AppleScript 按 tty 匹配 |
| iTerm2 | 精确到 session | AppleScript 按 `ITERM_SESSION_ID` 的 GUID 匹配 |
| Ghostty | 不支持 | 未向 shell 暴露 per-surface id |
