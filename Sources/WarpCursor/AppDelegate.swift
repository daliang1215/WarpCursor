import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, StatusMenuDelegate, PreferencesDelegate {
    private var statusMenu: StatusMenuController!
    private var preferences: PreferencesWindowController?
    private let hotKeys = HotKeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 用 bundle 运行时 LSUIElement 已保证 accessory；开发模式下手动设置。
        NSApp.setActivationPolicy(.accessory)

        // App 被移动位置后，自动修正开机启动项里的路径
        LaunchAtLogin.healIfNeeded()

        statusMenu = StatusMenuController(delegate: self)
        applyBindings()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyBindings()
            self?.statusMenu.refresh()
        }

        NotificationCenter.default.addObserver(
            forName: .hotKeyEngineNeedsAccessibility,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.promptForAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.clear()
    }

    // MARK: - 热键绑定

    private func applyBindings() {
        hotKeys.engine = Persistence.shared.engine
        let store = Persistence.shared
        let displays = DisplayManager.activeDisplays()
        var bindings: [(combo: HotKeyCombo, action: () -> Void)] = []

        for (index, display) in displays.enumerated() {
            guard let combo = store.combo(for: display, position: index), !combo.isEmpty else { continue }
            bindings.append((combo, { [weak self] in self?.jump(to: display) }))
        }

        let next = store.nextDisplayCombo
        if !next.isEmpty {
            bindings.append((next, { [weak self] in self?.stepDisplay(by: 1) }))
        }
        let prev = store.previousDisplayCombo
        if !prev.isEmpty {
            bindings.append((prev, { [weak self] in self?.stepDisplay(by: -1) }))
        }

        let conflicts = hotKeys.apply(bindings: bindings)
        if !conflicts.isEmpty {
            let names = conflicts.map { KeyCodeNames.displayString(for: $0) }.joined(separator: "、")
            showAlert(title: "快捷键冲突",
                      message: "以下快捷键已被其它程序占用，未生效：\(names)\n\n请在偏好设置中更换。")
        }
    }

    // MARK: - 跳转

    private func jump(to display: DisplayInfo) {
        DisplayManager.warp(to: display)
        CursorFlash.flash(at: display.center)
    }

    private func stepDisplay(by delta: Int) {
        let displays = DisplayManager.activeDisplays()
        guard !displays.isEmpty else { return }
        let point = CGEvent(source: nil)?.location ?? displays[0].center
        let current = displays.firstIndex(where: { $0.bounds.contains(point) }) ?? 0
        let next = (current + delta + displays.count) % displays.count
        let target = displays[next]
        DisplayManager.warp(to: target)
        CursorFlash.flash(at: target.center)
    }

    // MARK: - StatusMenuDelegate

    func jumpToDisplay(_ display: DisplayInfo) { jump(to: display) }

    func identifyDisplays() {
        IdentifyDisplays.flash(displays: DisplayManager.activeDisplays())
    }

    func openPreferences() {
        if preferences == nil {
            let controller = PreferencesWindowController()
            controller.delegate = self
            preferences = controller
        }
        preferences?.show()
    }

    // MARK: - PreferencesDelegate

    func preferencesDidChange() {
        applyBindings()
        statusMenu.refresh()
    }

    // MARK: - 辅助功能权限引导（事件监听引擎）

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "需要“辅助功能”权限"
        alert.informativeText = "“事件监听”热键引擎需要辅助功能权限才能工作。请在系统设置中授予权限后，重新打开偏好设置确认引擎选择。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
