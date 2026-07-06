import AppKit
import Combine
import FlowStateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = EventStore()
    private let hookStatus = HookConfig.status()
    private var edgePanel: EdgePanelController!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        edgePanel = EdgePanelController { [weak self] agent in
            self?.jump(agent)
        }

        cancellable = store.$agents.sink { [weak self] agents in
            self?.render(agents)
        }
        render(store.agents)
    }

    private func render(_ agents: [Agent]) {
        let color = StatusIcon.color(for: agents)
        let debt = StatusIcon.debtCount(for: agents)
        FileHandle.standardError.write(
            "[FlowState] agents=\(agents.count) color=\(color.rawValue) debt=\(debt) hook=\(hookStatus.ok)\n"
                .data(using: .utf8)!)
        edgePanel.render(agents: agents, hookStatus: hookStatus)
    }

    /// 点一个 agent = 跳回它所在的终端会话。Claude session_id 不是 terminal session_id。
    private func jump(_ agent: Agent) {
        switch (agent.terminalApp, agent.terminalSessionID) {
        case ("Warp", let sid?) where !sid.isEmpty:
            jumpToWarp(agent, sid)
        case ("Terminal", let tty?) where !tty.isEmpty:
            if activateTerminal(tty: tty) {
                store.clear(agent)
            }
        case ("iTerm", let sid?) where !sid.isEmpty:
            if activateITerm(sessionID: sid) {
                store.clear(agent)
            }
        default:
            FileHandle.standardError.write(
                "[FlowState] no terminal session for agent=\(agent.id)\n".data(using: .utf8)!)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Warp 的 warp://session/ 要 32 字符纯 hex(无连字符),标准 UUID 得先去掉 -。
    private func jumpToWarp(_ agent: Agent, _ sid: String) {
        let hex = sid.replacingOccurrences(of: "-", with: "")
        guard let url = URL(string: "warp://session/\(hex)") else { return }
        store.clear(agent)
        NSWorkspace.shared.open(url)
    }

    private func activateTerminal(tty: String) -> Bool {
        let quotedTTY = tty
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            repeat with terminalWindow in windows
                repeat with terminalTab in tabs of terminalWindow
                    if tty of terminalTab is "\(quotedTTY)" then
                        set selected tab of terminalWindow to terminalTab
                        set index of terminalWindow to 1
                        activate
                        return true
                    end if
                end repeat
            end repeat
            activate
        end tell
        return false
        """
        return runAppleScript(script, context: "Terminal")
    }

    /// iTerm2 每个 session 有稳定 id(= ITERM_SESSION_ID 冒号后的 GUID),按它选中并激活。
    private func activateITerm(sessionID: String) -> Bool {
        let quoted = sessionID
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "iTerm2"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if id of aSession is "\(quoted)" then
                            select aWindow
                            select aTab
                            select aSession
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
            activate
        end tell
        return false
        """
        return runAppleScript(script, context: "iTerm")
    }

    private func runAppleScript(_ script: String, context: String) -> Bool {
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            FileHandle.standardError.write(
                "[FlowState] \(context) jump failed: \(error)\n".data(using: .utf8)!)
        }
        return result?.booleanValue == true
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // 无 Dock 图标
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
