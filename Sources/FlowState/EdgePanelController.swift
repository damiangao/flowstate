import AppKit
import FlowStateCore

@MainActor
final class EdgePanelController {
    private let collapsedWidth: CGFloat = 42
    private let expandedWidth: CGFloat = 320
    private let minHeight: CGFloat = 132
    private let maxHeight: CGFloat = 520
    private let edgePadding: CGFloat = 12
    private static let yFractionKey = "FlowStateEdgePanelYFraction"

    private let panel: NSPanel
    private let edgeView: EdgePanelView
    private var isExpanded = false
    private var agents: [Agent] = []
    private var hookStatus = HookStatus(ok: true, message: "")
    private var pendingCollapse: DispatchWorkItem?
    private var yFraction: CGFloat = {
        guard let value = UserDefaults.standard.object(forKey: EdgePanelController.yFractionKey) as? Double else { return 0.5 }
        return min(max(CGFloat(value), 0), 1)
    }()
    private var dragOffsetY: CGFloat = 0

    init(onSelect: @escaping (Agent) -> Void) {
        edgeView = EdgePanelView()
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = edgeView

        edgeView.onEnter = { [weak self] in self?.expandNow() }
        edgeView.onExit = { [weak self] in self?.collapseIfMouseReallyLeft() }
        edgeView.onMouseDown = { [weak self] y in self?.beginDrag(mouseY: y) }
        edgeView.onDrag = { [weak self] y in self?.drag(toMouseY: y) }
        edgeView.onSelect = onSelect
        edgeView.onQuit = { NSApp.terminate(nil) }

        render(agents: [], hookStatus: hookStatus)
        panel.orderFrontRegardless()
    }

    func render(agents: [Agent], hookStatus: HookStatus) {
        self.agents = agents
        self.hookStatus = hookStatus
        edgeView.render(agents: agents, hookStatus: hookStatus, expanded: isExpanded)
        movePanel(animated: false)
    }

    private func expandNow() {
        pendingCollapse?.cancel()
        pendingCollapse = nil
        setExpanded(true)
    }

    private func collapseIfMouseReallyLeft() {
        pendingCollapse?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.setExpanded(false)
            self.pendingCollapse = nil
        }
        pendingCollapse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        edgeView.render(agents: agents, hookStatus: hookStatus, expanded: expanded)
        movePanel(animated: true)
    }

    private func beginDrag(mouseY: CGFloat) {
        dragOffsetY = mouseY - panel.frame.midY
    }

    private func drag(toMouseY mouseY: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panelSize()
        let minY = visible.minY + edgePadding
        let maxY = visible.maxY - size.height - edgePadding
        let y = min(max(mouseY - dragOffsetY - size.height / 2, minY), maxY)
        yFraction = fraction(forY: y, size: size, visible: visible)
        UserDefaults.standard.set(Double(yFraction), forKey: Self.yFractionKey)
        movePanel(animated: false)
    }

    private func movePanel(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panelSize()
        let x = visible.maxX - size.width
        let y = yPosition(size: size, visible: visible)
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func yPosition(size: NSSize, visible: NSRect) -> CGFloat {
        let minY = visible.minY + edgePadding
        let maxY = visible.maxY - size.height - edgePadding
        guard maxY > minY else { return visible.midY - size.height / 2 }
        return minY + (maxY - minY) * yFraction
    }

    private func fraction(forY y: CGFloat, size: NSSize, visible: NSRect) -> CGFloat {
        let minY = visible.minY + edgePadding
        let maxY = visible.maxY - size.height - edgePadding
        guard maxY > minY else { return 0.5 }
        return min(max((y - minY) / (maxY - minY), 0), 1)
    }

    private func panelSize() -> NSSize {
        if !isExpanded { return NSSize(width: collapsedWidth, height: minHeight) }
        let hookRows = hookStatus.ok ? 0 : 1
        let agentRows = max(agents.count, 1)
        let contentHeight = CGFloat(hookRows * 34 + agentRows * 46 + 54)
        return NSSize(width: expandedWidth, height: min(max(contentHeight, minHeight), maxHeight))
    }
}

@MainActor
private final class EdgePanelView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    var onMouseDown: ((CGFloat) -> Void)?
    var onDrag: ((CGFloat) -> Void)?
    var onSelect: ((Agent) -> Void)?
    var onQuit: (() -> Void)?

    private var tracking: NSTrackingArea?
    private var agents: [Agent] = []
    private var hookStatus = HookStatus(ok: true, message: "")
    private var expanded = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        tracking = next
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
    override func mouseDown(with event: NSEvent) { onMouseDown?(NSEvent.mouseLocation.y) }
    override func mouseDragged(with event: NSEvent) { onDrag?(NSEvent.mouseLocation.y) }

    func render(agents: [Agent], hookStatus: HookStatus, expanded: Bool) {
        self.agents = agents
        self.hookStatus = hookStatus
        self.expanded = expanded
        subviews.forEach { $0.removeFromSuperview() }
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

        expanded ? renderExpanded() : renderCollapsed()
    }

    private func renderCollapsed() {
        let color = hookStatus.ok ? nsColor(StatusIcon.color(for: agents)) : .systemRed
        let debt = StatusIcon.debtCount(for: agents)
        let glyph = hookStatus.ok ? (StatusIcon.color(for: agents) == .gray ? "○" : "●") : "⚠"
        let text = debt > 0 && hookStatus.ok ? "FS\n\(glyph)\(debt)" : "FS\n\(glyph)"
        let label = NSTextField(labelWithString: text)
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func renderExpanded() {
        let root = NSStackView()
        root.orientation = .horizontal
        root.spacing = 0
        root.edgeInsets = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 10)
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let strip = NSTextField(labelWithString: collapsedText())
        strip.alignment = .center
        strip.font = .systemFont(ofSize: 13, weight: .bold)
        strip.textColor = hookStatus.ok ? nsColor(StatusIcon.color(for: agents)) : .systemRed
        strip.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(strip)
        strip.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(scrollView)
        scrollView.widthAnchor.constraint(equalToConstant: 258).isActive = true

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 6
        list.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = list
        NSLayoutConstraint.activate([
            list.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            list.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            list.widthAnchor.constraint(equalToConstant: 250),
        ])

        if !hookStatus.ok { list.addArrangedSubview(messageLabel("Hook 未就绪: \(hookStatus.message)", color: .systemRed)) }

        if agents.isEmpty {
            list.addArrangedSubview(messageLabel("没有等待中的 agent", color: .secondaryLabelColor))
        } else {
            agents.forEach { list.addArrangedSubview(row(for: $0)) }
        }

        let quit = NSButton(title: "退出 FlowState", target: self, action: #selector(quitClicked))
        quit.bezelStyle = .inline
        quit.alignment = .left
        list.addArrangedSubview(quit)
    }

    private func row(for agent: Agent) -> NSView {
        let button = AgentButton(agent: agent)
        button.target = self
        button.action = #selector(agentClicked(_:))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.alignment = .left
        let title = NSMutableAttributedString(
            string: "●  ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: nsColor(dotColor(agent.state)),
            ]
        )
        title.append(NSAttributedString(
            string: "\(agent.name)\n   \(subtitle(agent))",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ]
        ))
        button.attributedTitle = title
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return button
    }

    private func messageLabel(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return label
    }

    private func collapsedText() -> String {
        let debt = StatusIcon.debtCount(for: agents)
        let color = StatusIcon.color(for: agents)
        let glyph = hookStatus.ok ? (color == .gray ? "○" : "●") : "⚠"
        return debt > 0 && hookStatus.ok ? "FS\n\(glyph)\(debt)" : "FS\n\(glyph)"
    }

    @objc private func agentClicked(_ sender: AgentButton) { onSelect?(sender.agent) }
    @objc private func quitClicked() { onQuit?() }

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
}

@MainActor
private final class AgentButton: NSButton {
    let agent: Agent

    init(agent: Agent) {
        self.agent = agent
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
