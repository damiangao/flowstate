import Foundation
import FlowStateCore

// v0 唯一非平凡逻辑的 check:状态→颜色/欠账数,以及事件→状态映射。无框架,assert 到底。

func agent(_ id: String, _ s: AgentState) -> Agent {
    Agent(id: id, name: id, state: s, since: Date(), terminalApp: nil, terminalSessionID: nil)
}

// --- StatusIcon.color:红 > 黄 > 灰 ---
assert(StatusIcon.color(for: []) == .gray, "空 = 灰")
assert(StatusIcon.color(for: [agent("a", .running)]) == .gray, "全跑 = 灰")
assert(StatusIcon.color(for: [agent("a", .running), agent("b", .done)]) == .yellow, "有干完 = 黄")
assert(StatusIcon.color(for: [agent("a", .waiting)]) == .yellow, "等待 = 黄")
assert(StatusIcon.color(for: [agent("a", .done), agent("b", .blocked)]) == .red, "有卡住 = 红(压过黄)")

// --- debtCount:非 running 计数 ---
assert(StatusIcon.debtCount(for: []) == 0)
assert(StatusIcon.debtCount(for: [agent("a", .running)]) == 0, "跑着的不算欠账")
assert(StatusIcon.debtCount(for: [agent("a", .done), agent("b", .blocked), agent("c", .running)]) == 2)

// --- HookEvent.derivedState:事件 → 状态 ---
func ev(_ name: String, _ msg: String? = nil) -> HookEvent {
    let json = "{\"session_id\":\"s\",\"hook_event_name\":\"\(name)\"" +
        (msg.map { ",\"message\":\"\($0)\"" } ?? "") + "}"
    return HookEvent.parseLog(json).first!
}
assert(ev("Stop").derivedState() == .done, "Stop = done")
assert(ev("Notification", "MCP tool wants input").derivedState() == .blocked, "无 type 退回文本:mcp = blocked")
assert(ev("Notification", "Claude is waiting for your input").derivedState() == .waiting, "无 type 退回文本:idle = waiting")
assert(ev("Notification", "auth_success").derivedState() == nil, "无 type 退回文本:auth = 忽略")
assert(ev("PreToolUse").derivedState() == nil, "无关事件 = 忽略")

// notification_type 优先(真机确认的字段),压过 message 文本
func evType(_ type: String) -> HookEvent {
    HookEvent.parseLog("{\"session_id\":\"s\",\"hook_event_name\":\"Notification\",\"notification_type\":\"\(type)\",\"message\":\"任意\"}").first!
}
assert(evType("permission_prompt").derivedState() == .blocked, "permission_prompt = blocked")
assert(evType("elicitation_dialog").derivedState() == .blocked, "elicitation = blocked")
assert(evType("idle_prompt").derivedState() == .waiting, "idle_prompt = waiting")
assert(evType("auth_success").derivedState() == nil, "auth_success = 忽略")

// --- displayName:目录·分支 ---
func nameEvent(cwd: String?, branch: String?) -> HookEvent {
    var parts = ["\"session_id\":\"abcdef123456\""]
    if let cwd { parts.append("\"cwd\":\"\(cwd)\"") }
    if let branch { parts.append("\"flowstate_branch\":\"\(branch)\"") }
    return HookEvent.parseLog("{\(parts.joined(separator: ","))}").first!
}
assert(nameEvent(cwd: "/Users/x/flowstate", branch: "main").displayName() == "flowstate·main")
assert(nameEvent(cwd: "/Users/x/flowstate", branch: "").displayName() == "flowstate")
assert(nameEvent(cwd: nil, branch: nil).displayName() == "abcdef12", "都缺 = session 短 id")

// --- terminal 字段:点击跳转用 terminal id,不是 Claude session_id ---
let terminalEvent = HookEvent.parseLog("{\"session_id\":\"claude-session\",\"hook_event_name\":\"Stop\",\"flowstate_terminal_app\":\"Warp\",\"flowstate_terminal_session_id\":\"warp-session\"}").first!
assert(terminalEvent.terminalApp == "Warp")
assert(terminalEvent.terminalSessionID == "warp-session")
let terminalAppEvent = HookEvent.parseLog("{\"session_id\":\"claude-session\",\"hook_event_name\":\"Stop\",\"flowstate_terminal_app\":\"Terminal\",\"flowstate_terminal_session_id\":\"/dev/ttys003\"}").first!
assert(terminalAppEvent.terminalApp == "Terminal")
assert(terminalAppEvent.terminalSessionID == "/dev/ttys003")

// --- HookConfig:启动时检查 Stop/Notification/UserPromptSubmit hook ---
let goodSettings = """
{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/tmp/flowstate-hook.sh"}]}],"Notification":[{"hooks":[{"type":"command","command":"/tmp/flowstate-hook.sh"}]}],"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/tmp/flowstate-hook.sh"}]}]}}
"""
assert(HookConfig.status(settingsJSON: goodSettings, fileExists: { _ in true }).ok)
let missingSettings = """
{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/tmp/flowstate-hook.sh"}]}]}}
"""
let missingHookStatus = HookConfig.status(settingsJSON: missingSettings, fileExists: { _ in true })
assert(!missingHookStatus.ok)
assert(missingHookStatus.message.contains("Notification"))
let missingFileStatus = HookConfig.status(settingsJSON: goodSettings, fileExists: { _ in false })
assert(!missingFileStatus.ok)
assert(missingFileStatus.message.contains("不存在"))

// --- AgentLog:点击清账后从菜单消失 ---
let clearLog = """
{"session_id":"s","hook_event_name":"Stop","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"FlowStateClear","flowstate_received_at":2}
"""
assert(AgentLog.fold(HookEvent.parseLog(clearLog)).isEmpty, "FlowStateClear = 清掉该 session")
// 一键清空:每个 session 各一条 FlowStateClear,全部清空
let clearAllLog = """
{"session_id":"a","hook_event_name":"Stop","flowstate_received_at":1}
{"session_id":"b","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":2}
{"session_id":"a","hook_event_name":"FlowStateClear","flowstate_received_at":3}
{"session_id":"b","hook_event_name":"FlowStateClear","flowstate_received_at":3}
"""
assert(AgentLog.fold(HookEvent.parseLog(clearAllLog)).isEmpty, "一键清空 = 每个 session 各一条 FlowStateClear")
let keepTerminalLog = """
{"session_id":"s","hook_event_name":"Stop","flowstate_terminal_app":"Warp","flowstate_terminal_session_id":"warp","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":2}
"""
let keepWarpAgent = AgentLog.fold(HookEvent.parseLog(keepTerminalLog)).first
assert(keepWarpAgent?.terminalApp == "Warp", "后续事件缺 terminal 时保留 Warp")
assert(keepWarpAgent?.terminalSessionID == "warp", "后续事件缺 terminal 时保留旧值")
let keepTerminalAppLog = """
{"session_id":"s","hook_event_name":"Stop","flowstate_terminal_app":"Terminal","flowstate_terminal_session_id":"/dev/ttys003","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":2}
"""
let keepTerminalAppAgent = AgentLog.fold(HookEvent.parseLog(keepTerminalAppLog)).first
assert(keepTerminalAppAgent?.terminalApp == "Terminal", "后续事件缺 terminal 时保留 Terminal.app")
assert(keepTerminalAppAgent?.terminalSessionID == "/dev/ttys003", "Terminal.app 用 tty 作为 terminal id")
let latestSessionLog = """
{"session_id":"s","hook_event_name":"Stop","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":2}
"""
let latestAgents = AgentLog.fold(HookEvent.parseLog(latestSessionLog))
assert(latestAgents.count == 1, "同 session 只保留一条")
assert(latestAgents.first?.state == .waiting, "同 session 后续状态覆盖旧状态")
assert(latestAgents.first?.since.timeIntervalSince1970 == 2, "状态变化时 since 使用最新事件")
let sameStateLog = """
{"session_id":"s","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"Notification","notification_type":"idle_prompt","flowstate_received_at":2}
"""
assert(AgentLog.fold(HookEvent.parseLog(sameStateLog)).first?.since.timeIntervalSince1970 == 1, "同状态事件保留原 since")
let newPromptLog = """
{"session_id":"s","hook_event_name":"Stop","flowstate_received_at":1}
{"session_id":"s","hook_event_name":"UserPromptSubmit","flowstate_received_at":2}
"""
assert(AgentLog.fold(HookEvent.parseLog(newPromptLog)).isEmpty, "UserPromptSubmit = 新任务清旧状态")

// --- parseLog:坏行不断流 ---
let mixed = "{\"session_id\":\"a\",\"hook_event_name\":\"Stop\"}\nGARBAGE\n{\"session_id\":\"b\",\"hook_event_name\":\"Stop\"}"
assert(HookEvent.parseLog(mixed).count == 2, "坏行被跳过,好行保留")

print("✅ FlowStateSelfTest: all assertions passed")
