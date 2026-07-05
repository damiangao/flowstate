import Foundation

/// hook 脚本写进 events.jsonl 的一行。字段名来自二手源(官方文档被墙),
/// 全部 optional + 宽松解析 —— 真机验证时若字段名不符,只需改这里的 CodingKeys。
public struct HookEvent: Decodable, Sendable {
    public let sessionID: String?
    public let hookEventName: String?
    public let notificationType: String?
    public let message: String?
    public let cwd: String?
    public let branch: String?
    public let receivedAt: TimeInterval?
    public let terminalApp: String?
    public let terminalSessionID: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case hookEventName = "hook_event_name"
        case notificationType = "notification_type"
        case message
        case cwd
        case branch = "flowstate_branch"
        case receivedAt = "flowstate_received_at"
        case terminalApp = "flowstate_terminal_app"
        case terminalSessionID = "flowstate_terminal_session_id"
    }

    /// 事件 → 状态。真机确认 Notification 带 notification_type,直接用它分类,
    /// 比猜 message 文本可靠;缺 type 时退回 message 关键字启发式。
    /// - permission_prompt / elicitation_dialog → blocked(要我操作)
    /// - idle_prompt → waiting(空闲等输入)
    /// - auth_success → nil(忽略)
    public func derivedState() -> AgentState? {
        switch hookEventName {
        case "Stop", "SubagentStop":
            return .done
        case "Notification":
            switch notificationType {
            case "permission_prompt", "elicitation_dialog": return .blocked
            case "idle_prompt": return .waiting
            case "auth_success": return nil
            case .some: return .waiting          // 未知子类型:当等待,别漏
            case nil:                            // 老版本无此字段,退回文本启发式
                let m = (message ?? "").lowercased()
                if m.contains("auth") { return nil }
                if m.contains("permission") || m.contains("approve")
                    || m.contains("mcp") || m.contains("elicit") { return .blocked }
                return .waiting
            }
        default:
            return nil
        }
    }

    /// 显示名:目录名·分支。cwd 缺失时退化成 session 短 id。
    public func displayName() -> String {
        let dir = cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        let b = branch ?? ""
        switch (dir.isEmpty, b.isEmpty) {
        case (false, false): return "\(dir)·\(b)"
        case (false, true):  return dir
        default:             return String((sessionID ?? "?").prefix(8))
        }
    }

    /// 解析一整个 events.jsonl 的内容成事件序列,跳过坏行(不让一行坏 JSON 断流)。
    public static func parseLog(_ contents: String) -> [HookEvent] {
        let dec = JSONDecoder()
        return contents.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? dec.decode(HookEvent.self, from: data)
        }
    }
}
