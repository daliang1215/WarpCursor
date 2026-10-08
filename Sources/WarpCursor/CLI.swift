import AppKit

/// 命令行模式：带参数启动时执行单次动作后退出，方便脚本 / 快捷启动工具调用。
enum CLI {
    static func run(arguments: [String]) -> Int32 {
        guard let verb = arguments.first else {
            printHelp()
            return 0
        }
        switch verb {
        case "--list":
            listDisplays()
            return 0
        case "--move":
            guard arguments.count > 1, let n = Int(arguments[1]) else {
                fputs("用法: WarpCursor --move <显示器编号>\n", stderr)
                return 1
            }
            return moveToDisplay(number: n) ? 0 : 1
        case "--move-next":
            stepDisplay(by: 1)
            return 0
        case "--move-prev":
            stepDisplay(by: -1)
            return 0
        case "--help", "-h":
            printHelp()
            return 0
        default:
            fputs("未知参数: \(verb)\n", stderr)
            printHelp()
            return 1
        }
    }

    private static func listDisplays() {
        let displays = DisplayManager.activeDisplays()
        for (i, d) in displays.enumerated() {
            let b = d.bounds
            print("\(i + 1): id=\(d.id) \(d.sizeDescription) origin=(\(Int(b.minX)),\(Int(b.minY)))\(d.isMain ? " [主显示器]" : "")")
        }
    }

    private static func moveToDisplay(number: Int) -> Bool {
        let displays = DisplayManager.activeDisplays()
        guard number >= 1, number <= displays.count else {
            fputs("显示器编号超出范围 (1-\(displays.count))\n", stderr)
            return false
        }
        DisplayManager.warp(to: displays[number - 1])
        return true
    }

    private static func stepDisplay(by delta: Int) {
        let displays = DisplayManager.activeDisplays()
        guard !displays.isEmpty else { return }
        let point = CGEvent(source: nil)?.location ?? displays[0].center
        let current = displays.firstIndex(where: { $0.bounds.contains(point) }) ?? 0
        let next = (current + delta + displays.count) % displays.count
        DisplayManager.warp(to: displays[next])
    }

    private static func printHelp() {
        print("""
        WarpCursor — 用快捷键在显示器之间移动光标

        用法:
          WarpCursor --list        列出显示器（编号、尺寸、位置）
          WarpCursor --move N      将光标移到第 N 块显示器中央
          WarpCursor --move-next   移到下一块显示器
          WarpCursor --move-prev   移到上一块显示器
          WarpCursor --help        显示本帮助

        不带参数启动时，作为菜单栏常驻应用运行。
        """)
    }
}
