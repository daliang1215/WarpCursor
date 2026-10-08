import Foundation

/// 一个全局热键：Carbon 虚拟键码 + Carbon 修饰键标记
/// （cmdKey / controlKey / optionKey / shiftKey）。
struct HotKeyCombo: Codable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// 修饰键为空视为"未设置"。
    var isEmpty: Bool { carbonModifiers == 0 }
}
