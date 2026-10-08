import AppKit

/// 备用热键引擎：CGEventTap 监听全局 keyDown 事件。
/// 需要"辅助功能"权限。仅在 Carbon 引擎不可用时使用。
final class EventTapHotKeyCenter {
    private struct Registration {
        let keyCode: UInt32
        let flags: CGEventFlags
        let action: () -> Void
    }

    private var registrations: [Registration] = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    func add(keyCode: UInt32, carbonModifiers: UInt32, action: @escaping () -> Void) {
        registrations.append(Registration(
            keyCode: keyCode,
            flags: cgEventFlags(fromCarbon: carbonModifiers),
            action: action
        ))
    }

    /// 启动事件监听。返回 false 通常意味着缺少辅助功能权限
    /// （此时系统会自动弹出授权提示）。
    @discardableResult
    func start() -> Bool {
        stop()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tap = nil
        registrations.removeAll()
    }

    fileprivate func handle(keyCode: UInt32, flags: CGEventFlags) {
        let relevant = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        for r in registrations where r.keyCode == keyCode && r.flags == relevant {
            DispatchQueue.main.async(execute: r.action)
            break
        }
    }
}

/// 事件回调：顶层函数，符合 CGEventTapCallBack 的 C 函数指针签名。
private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .keyDown, let refcon = refcon {
        let center = Unmanaged<EventTapHotKeyCenter>.fromOpaque(refcon).takeUnretainedValue()
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        center.handle(keyCode: keyCode, flags: event.flags)
    }
    return Unmanaged.passUnretained(event)
}
