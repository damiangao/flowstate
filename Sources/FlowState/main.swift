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

    /// 点一个 agent = 跳到它的 Warp pane。注意 Claude session_id 不是 terminal session_id。
    /// Warp 的 warp://session/ 要 32 字符纯 hex(无连字符),标准 UUID 得先去掉 -。
    private func jump(_ agent: Agent) {
        guard agent.terminalApp == "Warp", let sid = agent.terminalSessionID, !sid.isEmpty else {
            FileHandle.standardError.write(
                "[FlowState] no terminal session for agent=\(agent.id)\n".data(using: .utf8)!)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hex = sid.replacingOccurrences(of: "-", with: "")
        guard let url = URL(string: "warp://session/\(hex)") else { return }
        store.clear(agent)
        NSWorkspace.shared.open(url)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
