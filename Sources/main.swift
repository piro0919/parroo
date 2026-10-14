import AppKit

/// メニューバーに常駐し、Claude Code の使用量を出す
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindow = SettingsWindowController()
    private let conversations = ConversationStore()
    /// 裏で読んだ会話の一覧。メニューはこれを出し、読み終わったら差し替える
    private var openConversations: [Conversation] = []
    private var loadingConversations = false

    private var usage: Usage?
    private var lastError: UsageError?
    /// 最後に値を取れた時刻。メニューの「10:42 に更新」に出す
    private var fetchedAt: Date?
    private var lastAttempt: Date?
    private var fetching = false
    /// 取っている最中に取り直しを頼まれた。終わったらもう一度取る
    private var refetch = false
    /// 設定フォルダを変えるたびに進める。変える前に出した問い合わせの結果は捨てる
    private var generation = 0
    private var menuIsOpen = false
    private var timers: [Timer] = []

    /// 問い合わせの間隔。公開されていない経路なので、叩きすぎない
    private static let fetchInterval: TimeInterval = 120
    /// メニューを開いたとき、これより古ければ取り直す
    private static let staleAfter: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        // 情報の行は押しても何もしないが、灰色にせず普通の濃さで出す
        menu.autoenablesItems = false
        item.menu = menu

        // リセットまでの時間は、取り直さなくても毎分進む
        timers.append(repeating(30) { [weak self] in self?.drawStatus() })
        timers.append(repeating(Self.fetchInterval) { [weak self] in self?.fetch() })
        // 会話の記録は増え続ける。開いたときに待たせないよう、裏で読み進めておく
        timers.append(repeating(30) { [weak self] in self?.refreshConversations() })

        let center = NotificationCenter.default
        for name in [Notification.Name.statusLinesChanged, .languageChanged] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.drawStatus() }
            }
        }
        // 言語を変えたら、設定の窓を作り直す。文字は窓を作るときに焼き込んでいる
        center.addObserver(forName: .languageChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let wasVisible = self.settingsWindow.window?.isVisible ?? false
                self.settingsWindow.close()
                self.settingsWindow = SettingsWindowController()
                if wasVisible { self.settingsWindow.show() }
            }
        }
        // 設定フォルダを変えたら、別のアカウントかもしれない。前の値を捨てて取り直す
        center.addObserver(forName: .claudeDirChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.generation += 1
                self.usage = nil
                self.lastError = nil
                self.fetchedAt = nil
                self.openConversations = []
                self.drawStatus()
                self.fetch()
                self.refreshConversations()
            }
        }
        // スリープの間に枠がリセットされていることがある
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetch() }
        }

        drawStatus()
        fetch()
        refreshConversations()
        Updater.shared.checkQuietly()
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    private func repeating(_ interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            // Timer は主の実行ループから呼ぶ。飛ばずに入り、違ったら落とす
            MainActor.assumeIsolated { action() }
        }
        // メニューを開いている間も進める
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func fetch() {
        guard !fetching else {
            refetch = true
            return
        }
        fetching = true
        lastAttempt = Date()
        let dir = Paths.claudeDir
        let raw = Paths.claudeDirRaw
        let started = generation
        Task {
            let result = await UsageClient.fetch(claudeDir: dir, raw: raw)
            fetching = false
            defer {
                if refetch {
                    refetch = false
                    fetch()
                }
            }
            guard started == generation else { return }
            switch result {
            case .success(let value):
                usage = value
                lastError = nil
                fetchedAt = Date()
            case .failure(let error):
                // 前に取れた値は残す。古いことは「更新」の時刻で分かる
                lastError = error
            }
            drawStatus()
            if menuIsOpen, let menu = item.menu { rebuildMenu(menu) }
        }
    }

    private func refreshConversations() {
        guard !loadingConversations else { return }
        loadingConversations = true
        let dir = Paths.claudeDir
        let started = generation
        Task {
            let list = await conversations.load(claudeDir: dir)
            loadingConversations = false
            guard started == generation, list != openConversations else { return }
            openConversations = list
            if menuIsOpen, let menu = item.menu { rebuildMenu(menu) }
        }
    }

    /// 鸚鵡の影絵。テンプレート画像にして、明暗の色付けは macOS に任せる
    private let statusIcon: NSImage? = {
        guard let image = NSImage(named: "StatusIcon") else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }()

    private func drawStatus() {
        guard let button = item.button else { return }
        let lines = Format.statusLines(Preferences.lines, usage: usage)
        let image = StatusTitle.image(icon: statusIcon, lines: lines)
        image.accessibilityDescription = ([Strings.statusDescription] + lines).joined(separator: ", ")
        button.image = image
        button.title = ""
        // まだ一度も取れていないときは薄くする
        button.appearsDisabled = usage == nil
    }

    // MARK: - メニュー

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()

        // 取れなかったときは、何をすれば戻るかを一番上に出す
        if let lastError {
            let warning = NSMenuItem(title: lastError.message, action: nil, keyEquivalent: "")
            warning.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(warning)
        }

        if let usage {
            addWindow(Strings.weekHeader, usage.week, to: menu, now: now) { Format.date($0) }
            addWindow(Strings.fiveHourHeader, usage.fiveHour, to: menu, now: now) { Format.time($0) }
            if !usage.models.isEmpty {
                menu.addItem(.sectionHeader(title: Strings.modelsHeader))
                let separator = Language.resolved == .ja ? " ・ " : " · "
                let text = usage.models.map { "\($0.name) \(Strings.used(Format.percent($0.window.percent)))" }
                    .joined(separator: separator)
                menu.addItem(info(text))
            }
        }
        menu.addItem(.separator())

        // 開いている会話を、フォルダごとに見出しで分ける
        let open = openConversations
        if open.isEmpty {
            let empty = NSMenuItem(title: Strings.noConversations, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let font = NSFont.menuFont(ofSize: 0)
            let titles = open.map { $0.title }
            let tokenWidth = open.map { width(Format.tokens($0.tokens), font: font) }.max() ?? 0
            let titleWidth = titles.map { width($0, font: font) }.max() ?? 0
            // 題名の右に間を空け、トークン数を右で揃える
            let tab = ceil(titleWidth + 32 + tokenWidth)
            let headers = ConversationStore.headers(for: open.map(\.cwd))
            let groups = Dictionary(grouping: open, by: \.cwd).map { (headers[$0.key] ?? $0.key, $0.value) }
                .sorted { $0.0 < $1.0 }
            for (header, items) in groups {
                menu.addItem(.sectionHeader(title: header))
                for c in items.sorted(by: { $0.title < $1.title }) {
                    menu.addItem(conversationRow(c, tab: tab, font: font))
                }
            }
        }
        menu.addItem(.separator())

        let updated = NSMenuItem(
            title: fetchedAt.map { Strings.updatedAt(Format.time($0)) } ?? Strings.neverUpdated,
            action: nil, keyEquivalent: "")
        updated.isEnabled = false
        menu.addItem(updated)

        let settings = NSMenuItem(title: Strings.settings, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        let quit = NSMenuItem(title: Strings.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil)
        menu.addItem(quit)
    }

    /// 枠1つ。見出し、使用率、リセットの日時と残り時間
    private func addWindow(
        _ header: String, _ window: UsageWindow?, to menu: NSMenu, now: Date, when: (Date) -> String
    ) {
        guard let window else { return }
        menu.addItem(.sectionHeader(title: header))
        menu.addItem(info(Strings.used(Format.percent(window.percent))))
        if let at = window.resetsAt {
            menu.addItem(info(Strings.resetsAt(when(at), in: Format.longDuration(at.timeIntervalSince(now)))))
        }
    }

    /// 情報だけの行。押しても何もしない
    private func info(_ text: String) -> NSMenuItem {
        NSMenuItem(title: text, action: nil, keyEquivalent: "")
    }

    /// 会話の行。題名とトークン数。押したときの動きは未決なので、何もしない（CLAUDE.md）
    private func conversationRow(_ c: Conversation, tab: CGFloat, font: NSFont) -> NSMenuItem {
        let row = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: tab)]
        row.attributedTitle = NSAttributedString(
            string: "\(c.title)\t\(Format.tokens(c.tokens))",
            attributes: [.font: font, .paragraphStyle: style])
        return row
    }

    private func width(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    @objc private func openSettings() { settingsWindow.show() }
}

extension AppDelegate: NSMenuDelegate {
    /// 開かれる直前に組み直す。古ければ取り直し、届いたら開いたまま差し替える
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
        refreshConversations()
        if lastAttempt.map({ Date().timeIntervalSince($0) > Self.staleAfter }) ?? true { fetch() }
    }

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }
}

if CommandLine.arguments.contains("--selftest") {
    exit(MainActor.assumeIsolated { SelfTest.run() })
}

// メニューバーの絵を見本の値で PNG に書き出す。常駐アイコンが埋まって画面の外に追いやられていても、
// 見た目を確かめられるようにする。`--render-status <出力先.png>`
if let index = CommandLine.arguments.firstIndex(of: "--render-status"),
    CommandLine.arguments.indices.contains(index + 1)
{
    exit(MainActor.assumeIsolated { StatusTitle.renderSample(to: CommandLine.arguments[index + 1]) })
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
