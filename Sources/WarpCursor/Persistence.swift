import AppKit
import Carbon

/// 持久化：UserDefaults（JSON 编码）。
/// 显示器绑定按显示器 UUID 存储，热插拔 / 换接口后不丢失。
final class Persistence {
    static let shared = Persistence()

    private let defaults = UserDefaults.standard
    private let overridesKey = "displayHotKeyOverrides" // [displayUUID: HotKeyCombo]
    private let positionalKey = "positionalHotKeys"     // [HotKeyCombo] 左/中/右
    private let nextKey = "nextDisplayHotKey"
    private let prevKey = "prevDisplayHotKey"
    private let engineKey = "hotKeyEngine"
    private let launchAtLoginKey = "launchAtLogin"

    private init() {}

    // MARK: - 快捷键绑定

    /// 用户为某块具体显示器自定义的绑定（按 UUID）。
    var overrides: [String: HotKeyCombo] {
        get { decode([String: HotKeyCombo].self, forKey: overridesKey) ?? [:] }
        set { encode(newValue, forKey: overridesKey) }
    }

    /// 左 / 中 / 右三个位置的默认组合。
    var positionalDefaults: [HotKeyCombo] {
        get { decode([HotKeyCombo].self, forKey: positionalKey) ?? Self.factoryPositionalDefaults }
        set { encode(newValue, forKey: positionalKey) }
    }

    var nextDisplayCombo: HotKeyCombo {
        get { decode(HotKeyCombo.self, forKey: nextKey) ?? Self.factoryNext }
        set { encode(newValue, forKey: nextKey) }
    }

    var previousDisplayCombo: HotKeyCombo {
        get { decode(HotKeyCombo.self, forKey: prevKey) ?? Self.factoryPrevious }
        set { encode(newValue, forKey: prevKey) }
    }

    /// 某块显示器的生效组合：优先用它的 UUID 定制绑定，否则用位置默认。
    func combo(for display: DisplayInfo, position: Int) -> HotKeyCombo? {
        if let custom = overrides[display.uuid] { return custom }
        let defaults = positionalDefaults
        guard position < defaults.count else { return nil }
        return defaults[position]
    }

    // MARK: - 热键引擎

    var engine: HotKeyCenter.Engine {
        get {
            guard let raw = defaults.string(forKey: engineKey),
                  let e = HotKeyCenter.Engine(rawValue: raw) else { return .carbon }
            return e
        }
        set { defaults.set(newValue.rawValue, forKey: engineKey) }
    }

    // MARK: - 开机启动

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: launchAtLoginKey) }
        set { defaults.set(newValue, forKey: launchAtLoginKey) }
    }

    // MARK: - 出厂默认

    static var factoryPositionalDefaults: [HotKeyCombo] {
        let mods = UInt32(controlKey) | UInt32(cmdKey) // ⌃⌘
        return [
            HotKeyCombo(keyCode: UInt32(kVK_ANSI_Comma), carbonModifiers: mods),  // ⌃⌘,
            HotKeyCombo(keyCode: UInt32(kVK_ANSI_Period), carbonModifiers: mods), // ⌃⌘.
            HotKeyCombo(keyCode: UInt32(kVK_ANSI_Slash), carbonModifiers: mods),  // ⌃⌘/
        ]
    }

    static var factoryNext: HotKeyCombo {
        HotKeyCombo(keyCode: UInt32(kVK_RightArrow), carbonModifiers: UInt32(controlKey) | UInt32(optionKey)) // ⌃⌥→
    }

    static var factoryPrevious: HotKeyCombo {
        HotKeyCombo(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: UInt32(controlKey) | UInt32(optionKey)) // ⌃⌥←
    }

    // MARK: - 编解码

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
