import AppKit
import Carbon

/// NSEvent 修饰键 -> Carbon 修饰键标记。
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    if flags.contains(.control) { m |= UInt32(controlKey) }
    if flags.contains(.option) { m |= UInt32(optionKey) }
    if flags.contains(.shift) { m |= UInt32(shiftKey) }
    return m
}

/// Carbon 修饰键标记 -> CGEventFlags（事件监听引擎用）。
func cgEventFlags(fromCarbon m: UInt32) -> CGEventFlags {
    var f: CGEventFlags = []
    if m & UInt32(cmdKey) != 0 { f.insert(.maskCommand) }
    if m & UInt32(controlKey) != 0 { f.insert(.maskControl) }
    if m & UInt32(optionKey) != 0 { f.insert(.maskAlternate) }
    if m & UInt32(shiftKey) != 0 { f.insert(.maskShift) }
    return f
}
