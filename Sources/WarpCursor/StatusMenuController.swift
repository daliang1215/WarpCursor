import AppKit

protocol StatusMenuDelegate: AnyObject {
    func jumpToDisplay(_ display: DisplayInfo)
    func identifyDisplays()
    func openPreferences()
}

/// 菜单栏图标 + 菜单。
final class StatusMenuController {
    private let statusItem: NSStatusItem
    private weak var delegate: StatusMenuDelegate?

    init(delegate: StatusMenuDelegate) {
        self.delegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
        }
        refresh()
    }

    /// 菜单栏图标：与 App 图标同一套设计（全彩 PNG，随包发布）。
    /// 资源缺失时（比如直接 swift run）回退到矢量线稿 template 图标。
    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 22, height: 22)
            return img
        }
        return templateGlyph()
    }

    /// 回退用的线稿图标：显示器框 + warp 箭头，随系统浅色/深色主题自动变色。
    private static func templateGlyph() -> NSImage {
        let img = NSImage(size: NSSize(width: 22, height: 22))
        img.lockFocus()
        NSColor.white.setStroke()
        // 显示器外框
        let monitor = NSBezierPath(roundedRect: NSRect(x: 3, y: 7.5, width: 16, height: 10),
                                   xRadius: 2.5, yRadius: 2.5)
        monitor.lineWidth = 2
        monitor.stroke()
        // 底座
        let stand = NSBezierPath()
        stand.move(to: NSPoint(x: 11, y: 7.5))
        stand.line(to: NSPoint(x: 11, y: 5))
        stand.move(to: NSPoint(x: 8, y: 5))
        stand.line(to: NSPoint(x: 14, y: 5))
        stand.lineWidth = 2
        stand.lineCapStyle = .round
        stand.stroke()
        // warp 箭头
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 8.5, y: 10.5))
        arrow.line(to: NSPoint(x: 14, y: 15.5))
        arrow.move(to: NSPoint(x: 14, y: 15.5))
        arrow.line(to: NSPoint(x: 14, y: 12.8))
        arrow.move(to: NSPoint(x: 14, y: 15.5))
        arrow.line(to: NSPoint(x: 11.3, y: 15.5))
        arrow.lineWidth = 2
        arrow.lineCapStyle = .round
        arrow.stroke()
        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    /// 显示器热插拔后重建菜单。
    func refresh() {
        let menu = NSMenu()
        let displays = DisplayManager.activeDisplays()
        for (index, display) in displays.enumerated() {
            let combo = Persistence.shared.combo(for: display, position: index)
            var title = "跳到显示器 \(index + 1)\(display.isMain ? "（主）" : "")（\(display.sizeDescription)）"
            if let combo = combo {
                title += "  \(KeyCodeNames.displayString(for: combo))"
            }
            let item = NSMenuItem(title: title, action: #selector(didSelectDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = display
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let identify = NSMenuItem(title: "识别显示器", action: #selector(didSelectIdentify(_:)), keyEquivalent: "")
        identify.target = self
        menu.addItem(identify)

        let prefs = NSMenuItem(title: "偏好设置…", action: #selector(didSelectPreferences(_:)), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 WarpCursor", action: #selector(didSelectQuit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func didSelectDisplay(_ sender: NSMenuItem) {
        guard let display = sender.representedObject as? DisplayInfo else { return }
        delegate?.jumpToDisplay(display)
    }

    @objc private func didSelectIdentify(_ sender: NSMenuItem) {
        delegate?.identifyDisplays()
    }

    @objc private func didSelectPreferences(_ sender: NSMenuItem) {
        delegate?.openPreferences()
    }

    @objc private func didSelectQuit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
