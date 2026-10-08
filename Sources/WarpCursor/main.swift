import AppKit

// 命令行模式：`WarpCursor --list` 等只执行一次动作然后退出，不启动菜单栏应用。
if CommandLine.arguments.count > 1 {
    exit(CLI.run(arguments: Array(CommandLine.arguments.dropFirst())))
}

let app = NSApplication.shared
// delegate 属性是 weak，必须用顶层 let 强引用，否则实例会立即释放
let delegate = AppDelegate()
app.delegate = delegate
app.run()
