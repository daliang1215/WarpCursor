import AppKit
import Carbon

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for unit in string.utf16.prefix(4) {
        result = (result << 8) | OSType(unit)
    }
    return result
}

/// Carbon 事件回调：顶层函数，可直接作为 C 函数指针传入 InstallEventHandler。
private func carbonHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    CarbonHotKeyCenter.shared.handleCarbonEvent(event)
    return 0 // noErr
}

/// 全局热键：Carbon RegisterEventHotKey。
/// 系统级注册，应用在后台时也能触发，不需要任何系统权限。
/// 在 macOS 14 / 15 / 26 / 27 上均可用（头文件标 deprecated，但链接与运行正常）。
final class CarbonHotKeyCenter {
    static let shared = CarbonHotKeyCenter()

    enum RegistrationResult {
        case registered(UInt32)
        case conflict   // 已被其他程序占用
        case failed(OSStatus)
    }

    private var refs = [UInt32: EventHotKeyRef?]()
    private var actions = [UInt32: () -> Void]()
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> RegistrationResult {
        installHandlerIfNeeded()
        let id = nextID
        nextID &+= 1
        let hotKeyID = EventHotKeyID(signature: fourCharCode("WRPC"), id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == 0, let ref = ref { // noErr
            refs[id] = ref
            actions[id] = action
            return .registered(id)
        }
        if status == OSStatus(eventHotKeyExistsErr) {
            return .conflict
        }
        return .failed(status)
    }

    func unregisterAll() {
        for (_, ref) in refs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func handleCarbonEvent(_ event: EventRef?) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == 0 else { return } // noErr
        if let action = actions[hotKeyID.id] {
            DispatchQueue.main.async(execute: action)
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyCallback, 1, &spec, nil, nil)
    }
}
