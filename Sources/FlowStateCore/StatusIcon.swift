import Foundation

/// 顶栏图标该显示的颜色。这是 v0 唯一非平凡逻辑,配 SelfTest 里的 assert。
public enum IconColor: String, Sendable {
    case red    // 有 agent 卡住(blocked)—— 最急
    case yellow // 无卡住,但有 agent 干完/等待 —— 有欠账
    case gray   // 全在跑 / 无 agent —— 无需注意
}

public enum StatusIcon {
    /// 一堆 agent → 图标颜色。红 > 黄 > 灰,取最急的。
    public static func color(for agents: [Agent]) -> IconColor {
        if agents.contains(where: { $0.state == .blocked }) { return .red }
        if agents.contains(where: { $0.state == .waiting || $0.state == .done }) { return .yellow }
        return .gray
    }

    /// 欠账数 = 正在等我的 agent 数(非 running)。给红点上的数字。
    public static func debtCount(for agents: [Agent]) -> Int {
        agents.filter { $0.state != .running }.count
    }
}
