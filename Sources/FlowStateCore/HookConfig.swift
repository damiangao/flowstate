import Foundation

public struct HookStatus: Sendable {
    public let ok: Bool
    public let message: String

    public init(ok: Bool, message: String) {
        self.ok = ok
        self.message = message
    }
}

public enum HookConfig {
    private static let events = ["Stop", "Notification", "UserPromptSubmit"]

    public static func status(settingsJSON: String, fileExists: (String) -> Bool) -> HookStatus {
        guard let data = settingsJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any] else {
            return HookStatus(ok: false, message: "Claude settings 里没有 hooks")
        }

        let commands = events.reduce(into: [String: String]()) { result, event in
            guard let blocks = hooks[event] as? [[String: Any]] else { return }
            for block in blocks {
                guard let hookList = block["hooks"] as? [[String: Any]] else { continue }
                if let command = hookList.compactMap({ $0["command"] as? String }).first(where: { $0.hasSuffix("flowstate-hook.sh") }) {
                    result[event] = command
                    return
                }
            }
        }

        let missing = events.filter { commands[$0] == nil }
        if !missing.isEmpty {
            return HookStatus(ok: false, message: "缺少 Claude hook: \(missing.joined(separator: ", "))")
        }

        if let missingFile = commands.values.first(where: { !fileExists($0) }) {
            return HookStatus(ok: false, message: "hook 脚本不存在: \(missingFile)")
        }

        return HookStatus(ok: true, message: "Claude hooks 已配置")
    }

    public static func status(settingsURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")) -> HookStatus {
        guard let settingsJSON = try? String(contentsOf: settingsURL, encoding: .utf8) else {
            return HookStatus(ok: false, message: "读不到 \(settingsURL.path)")
        }
        return status(settingsJSON: settingsJSON) { FileManager.default.fileExists(atPath: $0) }
    }
}
