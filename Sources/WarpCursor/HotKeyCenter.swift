import AppKit

extension Notification.Name {
    /// 事件监听引擎启动失败（通常是缺少辅助功能权限）时发出。
    static let hotKeyEngineNeedsAccessibility = Notification.Name("hotKeyEngineNeedsAccessibility")
}

/// 统一管理当前热键引擎（Carbon / 事件监听），负责绑定的一键重装。
final class HotKeyCenter {
    enum Engine: String, Codable, CaseIterable {
        case carbon
        case eventTap

        var displayName: String {
            switch self {
            case .carbon: return "Carbon 全局热键（免权限，推荐）"
            case .eventTap: return "事件监听（需辅助功能权限）"
            }
        }
    }

    var engine: Engine = .carbon

    /// 是否运行在 App Sandbox 中（Mac App Store 版）。沙盒下事件监听引擎不可用。
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    private let carbon = CarbonHotKeyCenter.shared
    private let eventTap = EventTapHotKeyCenter()

    /// 用当前引擎重新注册所有绑定。返回与其它程序冲突的组合。
    @discardableResult
    func apply(bindings: [(combo: HotKeyCombo, action: () -> Void)]) -> [HotKeyCombo] {
        carbon.unregisterAll()
        eventTap.stop()
        var conflicts: [HotKeyCombo] = []

        // 沙盒下强制使用 Carbon（事件监听需要监听全局按键，沙盒不允许）
        let effectiveEngine: Engine = Self.isSandboxed ? .carbon : engine
        switch effectiveEngine {
        case .carbon:
            for b in bindings {
                switch carbon.register(keyCode: b.combo.keyCode, modifiers: b.combo.carbonModifiers, action: b.action) {
                case .registered: break
                case .conflict: conflicts.append(b.combo)
                case .failed(let status):
                    NSLog("WarpCursor: Carbon 热键注册失败: \(status)")
                }
            }
        case .eventTap:
            for b in bindings {
                eventTap.add(keyCode: b.combo.keyCode, carbonModifiers: b.combo.carbonModifiers, action: b.action)
            }
            if !eventTap.start() {
                NotificationCenter.default.post(name: .hotKeyEngineNeedsAccessibility, object: nil)
            }
        }
        return conflicts
    }

    func clear() {
        carbon.unregisterAll()
        eventTap.stop()
    }
}
