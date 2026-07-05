import Foundation

/// agent 当前状态。紧急度 v0 只两档:blocked→红,waiting/done→黄,running→灰。
public enum AgentState: String, Sendable {
    case running   // 还在干
    case waiting   // 干完等下一步 / 空闲等输入
    case done      // Stop:干完一轮
    case blocked   // 要权限 / MCP 要输入
}

/// 一个 Claude Code 实例的当前快照。不可变,更新即换新值。
public struct Agent: Identifiable, Sendable {
    public let id: String          // session_id
    public let name: String        // 目录名·分支(如 flowstate·main)
    public let state: AgentState
    public let since: Date         // 进入当前状态的时刻,用来算等待时长
    public let terminalApp: String?
    public let terminalSessionID: String?

    public init(id: String, name: String, state: AgentState, since: Date, terminalApp: String? = nil, terminalSessionID: String? = nil) {
        self.id = id
        self.name = name
        self.state = state
        self.since = since
        self.terminalApp = terminalApp
        self.terminalSessionID = terminalSessionID
    }
}
