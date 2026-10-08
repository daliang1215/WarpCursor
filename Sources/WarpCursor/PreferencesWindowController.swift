import AppKit

protocol PreferencesDelegate: AnyObject {
    /// 绑定 / 引擎 / 开机启动变化后调用，App 重新注册热键。
    func preferencesDidChange()
}

/// 偏好设置窗口（纯代码构建，无 xib）。
final class PreferencesWindowController: NSWindowController {
    weak var delegate: PreferencesDelegate?

    private var stack: NSStackView!
    private var enginePopup: NSPopUpButton!
    private var loginCheckbox: NSButton!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WarpCursor 偏好设置"
        super.init(window: window)
        buildUI()
        refreshDisplayRows()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.window?.isVisible == true else { return }
            self.refreshDisplayRows()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refreshDisplayRows()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 界面构建

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    private func clearRows() {
        for v in stack.arrangedSubviews {
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    private func refreshDisplayRows() {
        clearRows()
        let store = Persistence.shared
        let displays = DisplayManager.activeDisplays()

        addSectionTitle("显示器快捷键")
        if displays.isEmpty {
            addRow(label: "未检测到显示器", recorder: nil)
        }
        for (index, display) in displays.enumerated() {
            let recorder = ShortcutRecorder()
            recorder.combo = store.combo(for: display, position: index)
            recorder.onChange = { [weak self] combo in
                if let combo = combo {
                    store.overrides[display.uuid] = combo
                } else {
                    store.overrides.removeValue(forKey: display.uuid)
                }
                self?.delegate?.preferencesDidChange()
            }
            let mainTag = display.isMain ? "（主）" : ""
            addRow(label: "显示器 \(index + 1)\(mainTag)（\(display.sizeDescription)）", recorder: recorder)
        }

        addSectionTitle("切换显示器")
        let nextRecorder = ShortcutRecorder()
        nextRecorder.combo = store.nextDisplayCombo
        nextRecorder.onChange = { [weak self] combo in
            if let combo = combo { store.nextDisplayCombo = combo }
            self?.delegate?.preferencesDidChange()
        }
        addRow(label: "下一个显示器", recorder: nextRecorder)

        let prevRecorder = ShortcutRecorder()
        prevRecorder.combo = store.previousDisplayCombo
        prevRecorder.onChange = { [weak self] combo in
            if let combo = combo { store.previousDisplayCombo = combo }
            self?.delegate?.preferencesDidChange()
        }
        addRow(label: "上一个显示器", recorder: prevRecorder)

        addSectionTitle("热键引擎")
        enginePopup = NSPopUpButton()
        enginePopup.addItems(withTitles: HotKeyCenter.Engine.allCases.map { $0.displayName })
        enginePopup.selectItem(at: store.engine == .carbon ? 0 : 1)
        enginePopup.target = self
        enginePopup.action = #selector(engineChanged(_:))
        if HotKeyCenter.isSandboxed {
            // App Store 沙盒版：事件监听不可用，直接禁用该选项
            enginePopup.item(at: 1)?.isEnabled = false
            enginePopup.selectItem(at: 0)
        }
        let engineRow = NSStackView()
        engineRow.orientation = .horizontal
        engineRow.spacing = 12
        engineRow.alignment = .centerY
        let engineLabel = NSTextField(labelWithString: "引擎")
        engineLabel.widthAnchor.constraint(equalToConstant: 220).isActive = true
        engineRow.addArrangedSubview(engineLabel)
        engineRow.addArrangedSubview(enginePopup)
        stack.addArrangedSubview(engineRow)
        if HotKeyCenter.isSandboxed {
            // App Store 沙盒版在 macOS 15+ 上有个系统 bug：只用 Option/Option+Shift
            // 做修饰键的全局热键不会触发（FB15168205），提醒用户避开这种组合
            let note = NSTextField(wrappingLabelWithString:
                "提示：Mac App Store 版在 macOS 15 及更高版本上，请避免只用 Option 做修饰键的组合（系统限制，不会触发）。")
            note.font = NSFont.systemFont(ofSize: 11)
            note.textColor = .secondaryLabelColor
            stack.addArrangedSubview(note)
        }

        let engineNote = NSTextField(wrappingLabelWithString: "Carbon 引擎无需任何系统权限；事件监听引擎需要“辅助功能”权限，仅建议在 Carbon 不可用时使用。")
        engineNote.font = NSFont.systemFont(ofSize: 11)
        engineNote.textColor = .secondaryLabelColor
        engineNote.widthAnchor.constraint(equalToConstant: 448).isActive = true
        stack.addArrangedSubview(engineNote)

        addSectionTitle("通用")
        loginCheckbox = NSButton(checkboxWithTitle: "开机自动启动", target: self, action: #selector(loginChanged(_:)))
        loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        stack.addArrangedSubview(loginCheckbox)
        let loginNote = NSTextField(wrappingLabelWithString: LaunchAtLogin.mechanismDescription)
        loginNote.font = NSFont.systemFont(ofSize: 11)
        loginNote.textColor = .secondaryLabelColor
        stack.addArrangedSubview(loginNote)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        let identifyButton = NSButton(title: "识别显示器", target: self, action: #selector(identifyClicked(_:)))
        identifyButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(identifyButton)
        let resetButton = NSButton(title: "恢复默认快捷键", target: self, action: #selector(resetClicked(_:)))
        resetButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(resetButton)
        stack.addArrangedSubview(buttonRow)

        fitWindowToContent()
    }

    private func addSectionTitle(_ title: String) {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(label)
    }

    private func addRow(label: String, recorder: ShortcutRecorder?) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        let labelField = NSTextField(labelWithString: label)
        labelField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        row.addArrangedSubview(labelField)
        if let recorder = recorder {
            row.addArrangedSubview(recorder)
        }
        stack.addArrangedSubview(row)
    }

    private func fitWindowToContent() {
        guard let window = window else { return }
        window.layoutIfNeeded()
        let size = stack.fittingSize
        window.setContentSize(NSSize(width: max(480, size.width + 32), height: size.height + 32))
    }

    // MARK: - 事件

    @objc private func engineChanged(_ sender: NSPopUpButton) {
        Persistence.shared.engine = sender.indexOfSelectedItem == 0 ? .carbon : .eventTap
        delegate?.preferencesDidChange()
    }

    @objc private func loginChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        do {
            try LaunchAtLogin.setEnabled(enabled)
            Persistence.shared.launchAtLogin = enabled
        } catch {
            NSLog("WarpCursor: 开机启动设置失败: \(error)")
            Persistence.shared.launchAtLogin = false
            sender.state = .off
            showAlert(title: "开机启动设置失败",
                      message: "设置失败：\(error.localizedDescription)")
        }
    }

    @objc private func identifyClicked(_ sender: NSButton) {
        IdentifyDisplays.flash(displays: DisplayManager.activeDisplays())
    }

    @objc private func resetClicked(_ sender: NSButton) {
        let store = Persistence.shared
        store.overrides = [:]
        store.positionalDefaults = Persistence.factoryPositionalDefaults
        store.nextDisplayCombo = Persistence.factoryNext
        store.previousDisplayCombo = Persistence.factoryPrevious
        delegate?.preferencesDidChange()
        refreshDisplayRows()
    }

    // MARK: - 开机启动

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
