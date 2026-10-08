import AppKit

/// 一块显示器的信息。bounds 使用 Quartz 全局显示坐标系，
/// 与 CGWarpMouseCursorPosition 是同一坐标系，可直接使用，无需换算。
struct DisplayInfo: Equatable {
    let id: CGDirectDisplayID
    let uuid: String
    let bounds: CGRect
    let isMain: Bool

    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    var sizeDescription: String {
        "\(Int(bounds.width))×\(Int(bounds.height))"
    }
}

enum DisplayManager {
    /// 所有活跃显示器：主显示器排第一，其余按在全局桌面中的位置从左到右排序。
    static func activeDisplays() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count).rawValue == 0, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count).rawValue == 0 else { return [] }
        return ids.prefix(Int(count)).map { id in
            DisplayInfo(
                id: id,
                uuid: uuid(for: id),
                bounds: CGDisplayBounds(id),
                isMain: CGDisplayIsMain(id) != 0
            )
        }.sorted {
            // 主显示器排第一，其余按从左到右排列
            if $0.isMain != $1.isMain { return $0.isMain }
            return $0.bounds.minX < $1.bounds.minX
        }
    }

    /// 把光标瞬间移到该显示器中央。不需要辅助功能权限。
    static func warp(to display: DisplayInfo) {
        CGWarpMouseCursorPosition(display.center)
    }

    /// 显示器的稳定身份标识，热插拔 / 换接口后不变，用于持久化快捷键绑定。
    static func uuid(for id: CGDirectDisplayID) -> String {
        // 新 SDK 中该函数返回 Unmanaged<CFUUID>；按文档调用方持有 +1 引用，用 takeRetainedValue 接管。
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let s = CFUUIDCreateString(nil, cfUUID) as String? else {
            return "display-\(id)"
        }
        return s
    }

    static var mainDisplayBounds: CGRect {
        CGDisplayBounds(CGMainDisplayID())
    }
}
