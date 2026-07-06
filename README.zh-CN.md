# FlowState

一个 macOS app，告诉你此刻哪个 Claude Code agent 需要你。

[English README](README.md)

## 这是什么

当你同时跑很多个 Claude Code 会话时，它们会在不同时刻各自干完、卡住、等你。你会忘掉已经干完的，漏掉卡在权限确认上的，在一个 agent 上耗掉半小时，而另外十个正干等着。FlowState 是一条钉在屏幕右缘的窄面板，只回答一个问题：**此刻什么最值得我关注？**

它是 [Claude Code](https://docs.claude.com/en/docs/claude-code) 的伴侣——读取 Claude Code 的 hook 事件，自己不产生任何数据。不支持其他 agent 运行器。

## 你会看到什么

右缘的收起窄条显示一个信号色，跨所有 agent 取最紧急的那个：

- 🔴 **红** — 有 agent 卡住了（权限确认，等你）
- 🟡 **黄** — 有 agent 干完了或空闲，等你下一步
- ⚪️ **灰** — 全在跑，无需你介入

窄条上还有一个欠账数字：多少个 agent 正在等你。悬停展开成完整列表——每行是一个会话（`目录·分支`）、它的状态、以及已等待多久。点某一行就跳回它所在的终端标签页。上下拖动窄条可调整位置。

## 前提

- macOS
- 装了 FlowState hooks 的 [Claude Code](https://docs.claude.com/en/docs/claude-code)（见下）

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

FlowState 从 `~/.flowstate/events.jsonl` 读取 Claude Code 事件，该文件由 `Stop`、`Notification`、`UserPromptSubmit` 三个 hook 写入。使用下面命令安装：

```bash
./scripts/build-app.sh --install-hooks
```

安装脚本会保留 `~/.claude/settings.json` 里的其他 hooks，并备份到 `~/.claude/settings.json.bak`。

## 终端跳转

在面板上点某个 agent，就能跳回它所在的终端标签页——只要那个标签页还开着。

| 终端 | 跳转精度 | 定位方式 |
| --- | --- | --- |
| Warp | 精确到 session | `warp://session/<uuid>` |
| Terminal.app | 精确到标签页 | AppleScript 按 tty 匹配 |
| iTerm2 | 精确到 session | AppleScript 按 `ITERM_SESSION_ID` 的 GUID 匹配 |
| Ghostty | 不支持 | 未向 shell 暴露 per-surface id |
