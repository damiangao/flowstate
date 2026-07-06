#!/usr/bin/env bash
# FlowState 事件通道:Claude Code 的 Stop / Notification / UserPromptSubmit hook 触发时调用。
# 只搬运,不解析:把 hook 从 stdin 收到的原始 JSON 附加两个字段(branch、received_at)
# 后追加一行到 ~/.flowstate/events.jsonl。字段名对错留到真机验证时看,脚本不赌。
set -euo pipefail

OUT_DIR="${FLOWSTATE_DIR:-$HOME/.flowstate}"
OUT_FILE="$OUT_DIR/events.jsonl"
mkdir -p "$OUT_DIR"

raw="$(cat)"

# cwd 用来拼 agent 显示名的分支部分;jq 取不到就留空,不让整条链路挂掉。
cwd="$(printf '%s' "$raw" | jq -r '.cwd // empty' 2>/dev/null || true)"
branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
fi

# 当前 tty,Terminal.app 定位靠它;经 hook 调用时 stdin 非 tty,退回父进程的。
resolve_tty() {
  local t
  t="$(tty </dev/tty 2>/dev/null || true)"
  if [[ "$t" != /dev/ttys* ]]; then
    local parent
    parent="$(ps -p "$PPID" -o tty= 2>/dev/null | tr -d ' ' || true)"
    [[ "$parent" == ttys* ]] && t="/dev/$parent"
  fi
  [[ "$t" == /dev/ttys* ]] && printf '%s' "$t"
}

terminal_app=""
terminal_session_id=""
if [ -n "${WARP_TERMINAL_SESSION_UUID:-}" ]; then
  terminal_app="Warp"
  terminal_session_id="$WARP_TERMINAL_SESSION_UUID"
elif [ -n "${WARP_SESSION_ID:-}" ]; then
  terminal_app="Warp"
  terminal_session_id="$WARP_SESSION_ID"
elif [ "${TERM_PROGRAM:-}" = "iTerm.app" ] && [ -n "${ITERM_SESSION_ID:-}" ]; then
  # ITERM_SESSION_ID = w0t0p0:GUID,冒号后的 GUID 即 AppleScript session 的 id。
  terminal_app="iTerm"
  terminal_session_id="${ITERM_SESSION_ID##*:}"
elif [ "${TERM_PROGRAM:-Apple_Terminal}" = "Apple_Terminal" ]; then
  tty_path="$(resolve_tty)"
  if [ -n "$tty_path" ]; then
    terminal_app="Terminal"
    terminal_session_id="$tty_path"
  fi
fi

# 把原始 JSON 原样保留,附加 branch、终端 session 和一个接收时间戳(hook 未必都带时间)。
# --argjson raw 确保原始对象不被转义成字符串。
printf '%s' "$raw" | jq -c \
  --arg branch "$branch" \
  --arg received_at "$(date +%s)" \
  --arg terminal_app "$terminal_app" \
  --arg terminal_session_id "$terminal_session_id" \
  '. + {flowstate_branch: $branch, flowstate_received_at: ($received_at | tonumber), flowstate_terminal_app: $terminal_app, flowstate_terminal_session_id: $terminal_session_id}' \
  >> "$OUT_FILE" 2>/dev/null \
  || printf '%s\n' "$raw" >> "$OUT_FILE"   # jq 万一失败,原样落盘,不丢事件
