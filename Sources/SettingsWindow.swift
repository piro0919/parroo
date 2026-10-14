import AppKit
import ServiceManagement

/// 設定の窓。作りは Hawky に揃えてある。左に項目名を右寄せで置き、右に操作を並べる
@MainActor
final class SettingsWindowController: NSWindowController {
    private let linePopUps = [NSPopUpButton(), NSPopUpButton()]
    private let folderLabel = NSTextField(labelWithString: "")
    private let languagePopUp = NSPopUpButton()
    private let launchCheckbox = NSButton(checkboxWithTitle: Strings.launchAtLogin, target: nil, action: nil)
    private let messageLabel = NSTextField(labelWithString: "")
    private lazy var messageRow: NSView = aligned(messageLabel)
    private var dividers: [NSView] = []

    /// 見出しの幅。操作の左端を一列に揃えるための基準
    private static let labelWidth: CGFloat = 110
    private static let width: CGFloat = 460

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = Strings.settingsTitle
        window.isReleasedWhenClosed = false
        self.init(window: window)
        build()
    }

    private func build() {
        guard let window else { return }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"

        for popUp in linePopUps {
            popUp.target = self
            popUp.action = #selector(changeLines)
            popUp.addItem(withTitle: Strings.none)
            for item in StatusItem.allCases { popUp.addItem(withTitle: item.label) }
        }

        // 長いパスは真ん中を詰める。窓の幅は広げない
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let folderButton = NSButton(title: Strings.chooseFolder, target: self, action: #selector(chooseFolder))
        folderButton.bezelStyle = .rounded

        languagePopUp.target = self
        languagePopUp.action = #selector(changeLanguage)
        for language in Language.allCases {
            languagePopUp.addItem(withTitle: language.label)
        }

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunch)

        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = Self.width - 24 * 2 - Self.labelWidth - 10
        // 文字が無いときは畳む。空のまま置くと、その行のぶんだけ間延びする
        messageLabel.isHidden = true
        messageRow.isHidden = true

        let updateButton = NSButton(title: Strings.checkForUpdates, target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .rounded

        let about = NSTextField(labelWithString: "Parroo \(version)")
        about.textColor = .secondaryLabelColor
        about.font = .systemFont(ofSize: 11)

        let stack = NSStackView(views: [
            row(Strings.firstLine, linePopUps[0]),
            row(Strings.secondLine, linePopUps[1]),
            divider(),
            row(Strings.configFolder, folderLabel, folderButton),
            divider(),
            row(Strings.language, languagePopUp),
            aligned(launchCheckbox),
            messageRow,
            aligned(updateButton),
            aligned(about),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        let margin: CGFloat = 24
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: margin),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -margin),
        ])
        for line in dividers {
            line.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: Self.width, height: content.fittingSize.height))
    }

    func show() {
        // 開くたびに読み直す。ログイン項目は、この窓の外でも変えられる
        showLines()
        folderLabel.stringValue = Paths.display(Paths.claudeDir)
        folderLabel.toolTip = Paths.claudeDir.path
        languagePopUp.selectItem(at: Language.allCases.firstIndex(of: Language.chosen) ?? 0)
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        report("")

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func showLines() {
        let lines = Preferences.lines
        for (index, popUp) in linePopUps.enumerated() {
            // 0 番は「表示しない」
            let item = lines.indices.contains(index) ? lines[index] : nil
            popUp.selectItem(at: item.flatMap { StatusItem.allCases.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
    }

    // MARK: - 操作

    /// 2つの選択から、メニューバーに出すものを決め直す。同じものを2つ選んだら1つにまとめる
    @objc private func changeLines() {
        var lines: [StatusItem] = []
        for popUp in linePopUps {
            let index = popUp.indexOfSelectedItem - 1
            guard StatusItem.allCases.indices.contains(index) else { continue }
            let item = StatusItem.allCases[index]
            if !lines.contains(item) { lines.append(item) }
        }
        Preferences.lines = lines
        showLines()
    }

    /// Claude Code の設定フォルダを選ぶ。Finder から開いたアプリには CLAUDE_CONFIG_DIR が届かないので、ここで合わせる
    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        // .claude は隠しフォルダなので、見せないと選べない
        panel.showsHiddenFiles = true
        panel.directoryURL = Paths.claudeDir
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fallback = Paths.claudeDir(
            chosen: nil, environment: ProcessInfo.processInfo.environment, home: Paths.home)
        Preferences.claudeDir = url.standardizedFileURL == fallback.standardizedFileURL ? nil : url.path
        folderLabel.stringValue = Paths.display(Paths.claudeDir)
        folderLabel.toolTip = Paths.claudeDir.path
    }

    @objc private func changeLanguage() {
        let index = languagePopUp.indexOfSelectedItem
        guard Language.allCases.indices.contains(index) else { return }
        Language.chosen = Language.allCases[index]
    }

    /// 常駐して見せるのが役目なので、ログイン時に起動しないと意味が薄い
    @objc private func toggleLaunch() {
        do {
            if launchCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            report("")
        } catch {
            report(Strings.launchFailed, failed: true)
        }
        // OS 側の状態に見た目を合わせる。失敗したときは元に戻る
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func checkForUpdates() { Updater.shared.checkNow() }

    // MARK: - 組み立て

    private func row(_ title: String, _ controls: NSView...) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: Self.labelWidth).isActive = true
        label.alignment = .right

        let stack = NSStackView(views: [label] + controls)
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 10
        return stack
    }

    /// 見出しの無い行。操作の左端を見出しのある行に揃える
    private func aligned(_ views: NSView...) -> NSView {
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: Self.labelWidth).isActive = true

        let stack = NSStackView(views: [spacer] + views)
        stack.orientation = .horizontal
        stack.spacing = 10
        return stack
    }

    private func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        dividers.append(line)
        return line
    }

    private func report(_ text: String, failed: Bool = false) {
        messageLabel.textColor = failed ? .systemRed : .secondaryLabelColor
        messageLabel.stringValue = text
        messageLabel.isHidden = text.isEmpty
        messageRow.isHidden = text.isEmpty
    }
}
