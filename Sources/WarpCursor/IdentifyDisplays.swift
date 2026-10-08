import AppKit

/// 在每块显示器上闪现一个大数字（2 秒），方便确认显示器编号。
/// 数字用自定义 view 直接绘制并居中，避免 NSTextField 固定高度裁剪文字。
enum IdentifyDisplays {
    static func flash(displays: [DisplayInfo]) {
        var windows: [NSWindow] = []
        for (index, display) in displays.enumerated() {
            // 直接用 NSScreen 的 frame（已是 Cocoa 坐标），不手动换算坐标系
            guard let frame = cocoaFrame(for: display.id) else { continue }
            let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.contentView = NumberView(frame: NSRect(origin: .zero, size: frame.size),
                                            number: index + 1, isMain: display.isMain)
            window.orderFrontRegardless()
            windows.append(window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            for w in windows { w.orderOut(nil) }
        }
    }

    /// 显示器 ID -> 该屏的 Cocoa 坐标 frame。
    private static func cocoaFrame(for displayID: CGDirectDisplayID) -> NSRect? {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               num.uint32Value == displayID {
                return screen.frame
            }
        }
        return nil
    }
}

/// 全屏半透明遮罩 + 居中大数字；主显示器在数字下方标注"主显示器"。
/// 翻转坐标（y 向下），NSString 绘制行为与直觉一致。
private final class NumberView: NSView {
    override var isFlipped: Bool { true }

    private let number: Int
    private let isMain: Bool

    init(frame: NSRect, number: Int, isMain: Bool) {
        self.number = number
        self.isMain = isMain
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.6).setFill()
        dirtyRect.fill()

        let unit = min(bounds.width, bounds.height)
        let numberAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: unit * 0.4, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let text = "\(number)" as NSString
        let size = text.size(withAttributes: numberAttrs)

        var captionH: CGFloat = 0
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(14, unit * 0.05), weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        ]
        let caption = "主显示器" as NSString
        let captionSize = caption.size(withAttributes: captionAttrs)
        if isMain { captionH = captionSize.height + unit * 0.03 }

        // 数字 + 标注作为整体垂直居中（翻转坐标：y 从上往下）
        let blockH = size.height + captionH
        var y = (bounds.height - blockH) / 2
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: y),
                  withAttributes: numberAttrs)
        if isMain {
            y += size.height + unit * 0.03
            caption.draw(at: NSPoint(x: (bounds.width - captionSize.width) / 2, y: y),
                         withAttributes: captionAttrs)
        }
    }
}
