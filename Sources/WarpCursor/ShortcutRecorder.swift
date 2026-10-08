import AppKit

/// 快捷键录制控件：点击后进入录制状态，按下组合键即保存。
/// Esc 取消本次录制，Delete 清空绑定。
final class ShortcutRecorder: NSControl {
    var combo: HotKeyCombo? {
        didSet { needsDisplay = true }
    }
    var onChange: ((HotKeyCombo?) -> Void)?

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 30) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 53: // Esc：取消
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        case 51: // Delete：清空
            isRecording = false
            combo = nil
            onChange?(nil)
            window?.makeFirstResponder(nil)
            return
        default:
            break
        }
        let mods = carbonModifiers(from: event.modifierFlags)
        guard mods != 0 else { return } // 全局热键必须带修饰键
        let c = HotKeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
        isRecording = false
        combo = c
        onChange?(c)
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        if isRecording {
            NSColor.systemBlue.setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()
        NSColor.gridColor.setStroke()
        path.stroke()

        let text: String
        let color: NSColor
        if isRecording {
            text = "按下快捷键…"
            color = .white
        } else if let combo = combo {
            text = KeyCodeNames.displayString(for: combo)
            color = .labelColor
        } else {
            text = "点击设置"
            color = .secondaryLabelColor
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
