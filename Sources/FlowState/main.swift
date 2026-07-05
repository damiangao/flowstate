import AppKit
import SwiftUI
import Combine
import FlowStateCore

// 裸 SwiftPM 可执行文件没有 .app bundle,MenuBarExtra 不显示。
// 用 AppKit NSStatusItem + .accessory 策略,不依赖 bundle,可靠出现在菜单栏。

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = EventStore()
    private let hookStatus = HookConfig.status()
    private var statusItem: NSStatusItem!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // agents 一变就重画图标 + 菜单。
        cancellable = store.$agents.sink { [weak self] agents in
            self?.render(agents)
        }
        render(store.agents)
    }

    private func render(_ agents: [Agent]) {
        let color = StatusIcon.color(for: agents)
        let debt = StatusIcon.debtCount(for: agents)

        // 诊断:每次重画都在终端打印状态,确认 App 活着、读到了什么。
        FileHandle.standardError.write(
            "[FlowState] agents=\(agents.count) color=\(color.rawValue) debt=\(debt) hook=\(hookStatus.ok)\n"
                .data(using: .utf8)!)

        // 用彩色文字标题,不依赖 SF Symbol 图片渲染 —— 保证一定可见。
        // 带 FS 前缀,即使颜色淡也能看到有东西在;红/黄追加欠账数字。
        if let button = statusItem.button {
            let glyph = hookStatus.ok ? (color == .gray ? "○" : "●") : "⚠"
            let text = debt > 0 && hookStatus.ok ? "FS \(glyph)\(debt)" : "FS \(glyph)"
            button.attributedTitle = NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: hookStatus.ok ? nsColor(color) : .systemRed,
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                ])
        }
        statusItem.menu = buildMenu(agents)
    }

    private func buildMenu(_ agents: [Agent]) -> NSMenu {
        let menu = NSMenu()
        if !hookStatus.ok {
            let item = NSMenuItem(title: "Hook 未就绪: \(hookStatus.message)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }
        if agents.isEmpty {
            let item = NSMenuItem(title: "没有等待中的 agent", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for agent in agents {
                let item = NSMenuItem(
                    title: "\(agent.name)  —  \(subtitle(agent))",
                    action: #selector(jump(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = agent
                item.image = dot(nsColor(dotColor(agent.state)))
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 FlowState", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    /// 点一个 agent = 跳到它的 Warp pane。注意 Claude session_id 不是 terminal session_id。
    /// Warp 的 warp://session/ 要 32 字符纯 hex(无连字符),标准 UUID 得先去掉 -。
    @objc private func jump(_ sender: NSMenuItem) {
        guard let agent = sender.representedObject as? Agent else { return }
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

    // --- 视觉 ---
    private func nsColor(_ c: IconColor) -> NSColor {
        switch c { case .red: return .systemRed; case .yellow: return .systemYellow; case .gray: return .secondaryLabelColor }
    }
    private func dotColor(_ s: AgentState) -> IconColor {
        switch s { case .blocked: return .red; case .waiting, .done: return .yellow; case .running: return .gray }
    }
    private func subtitle(_ agent: Agent) -> String {
        let label: String
        switch agent.state {
        case .blocked: label = "卡住,等你"
        case .done: label = "干完了"
        case .waiting: label = "等你输入"
        case .running: label = "运行中"
        }
        let mins = Int(Date().timeIntervalSince(agent.since) / 60)
        return mins <= 0 ? label : "\(label) · 已等 \(mins) 分钟"
    }
    private func dot(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let img = NSImage(size: size)
        img.lockFocus()
        color.set()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 8, height: 8)).fill()
        img.unlockFocus()
        return img
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // 菜单栏 App,无 Dock 图标
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
