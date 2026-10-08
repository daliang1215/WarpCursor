import AppKit

/// 跳转后在落点闪现一个放大的光标（约 1 秒后淡出），让用户一眼看到光标落在哪块屏上。
enum CursorFlash {
    /// - Parameter quartzPoint: 落点，Quartz 全局显示坐标系（与 CGWarpMouseCursorPosition 一致）。
    static func flash(at quartzPoint: CGPoint) {
        DispatchQueue.main.async {
            // 用当前光标的真实图像做放大，什么光标（箭头/工字梁/手型）就放大什么
            let cursorImage = NSCursor.current.image
            // Quartz（原点左上，y 向下）-> Cocoa（原点左下，y 向上）
            let mainH = DisplayManager.mainDisplayBounds.height
            let center = CGPoint(x: quartzPoint.x, y: mainH - quartzPoint.y)

            let side: CGFloat = 260
            let frame = NSRect(x: center.x - side / 2, y: center.y - side / 2,
                               width: side, height: side)
            let window = NSWindow(contentRect: frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.contentView = FlashView(frame: NSRect(origin: .zero, size: frame.size),
                                           cursorImage: cursorImage)
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                window.animator().alphaValue = 1
            }
            // 停留约 1 秒后淡出，还原正常光标
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.25
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    window.orderOut(nil)
                })
            }
        }
    }
}

/// 透明遮罩：中央是 3.5 倍大的光标 + 一圈高亮圆环。
/// 翻转坐标（y 向下），NSImage 绘制方向才正确。
private final class FlashView: NSView {
    override var isFlipped: Bool { true }

    private let cursorImage: NSImage

    init(frame: NSRect, cursorImage: NSImage) {
        self.cursorImage = cursorImage
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)

        // 外圈柔光
        if let glow = NSGradient(starting: NSColor.white.withAlphaComponent(0.28), ending: .clear) {
            glow.draw(in: NSBezierPath(ovalIn: NSRect(x: c.x - 110, y: c.y - 110, width: 220, height: 220)),
                      angle: 90)
        }
        // 高亮圆环
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - 62, y: c.y - 62, width: 124, height: 124))
        NSColor.white.withAlphaComponent(0.8).setStroke()
        ring.lineWidth = 5
        ring.stroke()

        // 放大的光标（约 3.5 倍），居中绘制
        let s = cursorImage.size
        guard s.width > 0, s.height > 0 else { return }
        let scale: CGFloat = 120 / max(s.width, s.height)
        let w = s.width * scale, h = s.height * scale
        cursorImage.draw(in: NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
    }
}
