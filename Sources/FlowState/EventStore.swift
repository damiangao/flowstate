import Foundation
import FlowStateCore
import Combine

/// 读 ~/.flowstate/events.jsonl,监听变化,把事件折叠成"每个 session 的当前状态"。
/// 折叠规则:同一 session_id 后来的事件覆盖前面的;状态变化时更新 since(用于等待时长)。
@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var agents: [Agent] = []

    private let fileURL: URL
    private var timer: Timer?
    private var lastSignature: String = ""   // size+mtime,变了才 reload

    init(fileURL: URL? = nil) {
        let dir = ProcessInfo.processInfo.environment["FLOWSTATE_DIR"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowstate")
        self.fileURL = fileURL ?? dir.appendingPathComponent("events.jsonl")
        reload()
        startWatching()
    }

    /// 重读整个文件并重建状态。文件小(3 个 agent 一下午),全量重读最省心。
    /// ponytail: 全量重读,量级大到卡顿再改增量。
    func reload() {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            agents = []
            return
        }
        agents = AgentLog.fold(HookEvent.parseLog(contents))  // 等最久的排前面
    }

    func clear(_ agent: Agent) {
        append(clearLine(for: agent.id))
    }

    /// 一键清空:给当前每个 agent 各追加一条 FlowStateClear,一次写入。
    func clearAll() {
        guard !agents.isEmpty else { return }
        append(agents.map { clearLine(for: $0.id) }.joined())
    }

    private func clearLine(for sessionID: String) -> String {
        "{\"session_id\":\"\(sessionID)\",\"hook_event_name\":\"FlowStateClear\",\"flowstate_received_at\":\(Int(Date().timeIntervalSince1970))}\n"
    }

    private func append(_ text: String) {
        if let data = text.data(using: .utf8), let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
            reload()
        }
    }

    private func startWatching() {
        // 轮询而非 vnode 监听:监听目录 fd 对子文件 `>>` 追加不可靠触发,
        // 监听文件 fd 又会因 rm+重建 inode 失效。1 秒轮询最省心,文件小,零风险。
        // ponytail: 全量轮询,3 个 agent 的文件量级下无所谓;真大了再上增量。
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reloadIfChanged() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 只在文件大小/修改时间变了时才 reload,避免每秒白解析。
    private func reloadIfChanged() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = (attrs?[.size] as? Int) ?? -1
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
        let sig = "\(size)-\(mtime)"
        guard sig != lastSignature else { return }
        lastSignature = sig
        reload()
    }
}
