import AppKit
import ServiceManagement

/// 开机启动统一入口。
/// - 正式签名版：走 SMAppService（系统登录项，原生体验）。
/// - ad-hoc 免费版：走 LaunchAgent plist（~/Library/LaunchAgents），零签名要求、永久有效。
enum LaunchAtLogin {
    /// ad-hoc 签名每次构建身份都变，SMAppService 会留下删不掉的残留记录，改用 LaunchAgent。
    /// 启动时检测一次即可（签名方式运行中不会变）。
    static let usesLaunchAgent: Bool = isAdHocSigned()

    static var isEnabled: Bool {
        if usesLaunchAgent { return LaunchAgentPlist.isEnabled }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if usesLaunchAgent {
            try enabled ? LaunchAgentPlist.enable() : LaunchAgentPlist.disable()
        } else if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// App 每次启动时调用：如果 LaunchAgent 已启用但 plist 里记的路径
    /// 与当前实际路径不一致（App 被移动过），自动修正，无需用户重新勾选。
    static func healIfNeeded() {
        guard usesLaunchAgent, LaunchAgentPlist.isEnabled else { return }
        guard let current = Bundle.main.executablePath, !current.isEmpty else { return }
        if LaunchAgentPlist.programPath != current {
            do {
                try LaunchAgentPlist.enable() // 用当前路径重写 plist
                NSLog("WarpCursor: 检测到 App 位置变化，已自动更新开机启动项")
            } catch {
                NSLog("WarpCursor: 开机启动项自动修复失败: \(error)")
            }
        }
    }

    /// 偏好设置里显示的机制说明。
    static var mechanismDescription: String {
        if usesLaunchAgent {
            return "免费版通过 LaunchAgent 实现（~/Library/LaunchAgents/com.warpcursor.app.plist），无需签名；App 移动位置后会自动修正。"
        }
        return "通过系统登录项（SMAppService）实现。"
    }

    private static func isAdHocSigned() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", Bundle.main.bundlePath]
        let pipe = Pipe()
        task.standardError = pipe // codesign -dv 输出到 stderr
        do { try task.run() } catch { return true }
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.contains("Signature=adhoc")
    }
}

/// 传统的 LaunchAgent 方案：写一个 plist 到 ~/Library/LaunchAgents，
/// 登录时 launchd 自动启动 App。不需要任何代码签名。
private enum LaunchAgentPlist {
    static let label = "com.warpcursor.app"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// plist 里记录的可执行文件路径（App 被移动后会与实际路径不一致）。
    static var programPath: String? {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String] else { return nil }
        return args.first
    }

    static func enable() throws {
        guard let exe = Bundle.main.executablePath, !exe.isEmpty else {
            throw NSError(domain: "WarpCursor", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "找不到 App 可执行文件路径"])
        }
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }

    static func disable() throws {
        if isEnabled {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
