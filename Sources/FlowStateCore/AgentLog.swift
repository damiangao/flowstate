import Foundation

public enum AgentLog {
    public static func fold(_ events: [HookEvent]) -> [Agent] {
        var latest: [String: Agent] = [:]
        for e in events {
            guard let sid = e.sessionID else { continue }
            if e.hookEventName == "FlowStateClear" || e.hookEventName == "UserPromptSubmit" {
                latest.removeValue(forKey: sid)
                continue
            }
            guard let state = e.derivedState() else { continue }
            let since = e.receivedAt.map { Date(timeIntervalSince1970: $0) } ?? Date()
            let prev = latest[sid]
            let eventTerminalApp = e.terminalApp?.isEmpty == false ? e.terminalApp : nil
            let eventTerminalSessionID = e.terminalSessionID?.isEmpty == false ? e.terminalSessionID : nil
            let terminalApp = eventTerminalApp ?? prev?.terminalApp
            let terminalSessionID = eventTerminalSessionID ?? prev?.terminalSessionID
            // 状态没变就保留原 since(别让等待时长被同状态的新事件刷新)。
            if let prev, prev.state == state {
                latest[sid] = Agent(id: sid, name: e.displayName(), state: state, since: prev.since, terminalApp: terminalApp, terminalSessionID: terminalSessionID)
            } else {
                latest[sid] = Agent(id: sid, name: e.displayName(), state: state, since: since, terminalApp: terminalApp, terminalSessionID: terminalSessionID)
            }
        }
        return latest.values.sorted { $0.since < $1.since }
    }
}
