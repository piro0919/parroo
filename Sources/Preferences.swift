import Foundation

/// メニューバーの2行に出せるもの。利用者が最大2つまで選ぶ（CLAUDE.md の表）
enum StatusItem: String, CaseIterable {
    case weekPercent
    case weekResetDate
    case weekResetIn
    case fiveHourPercent
    case fiveHourResetTime
    case fiveHourResetIn
    case opusPercent
    case sonnetPercent
    case extraUsage

    /// 設定の窓の選択肢に出す名前
    var label: String {
        switch self {
        case .weekPercent: return Strings.t("週の使用率", "Weekly usage")
        case .weekResetDate: return Strings.t("週のリセット日時", "Weekly reset date")
        case .weekResetIn: return Strings.t("週のリセットまでの時間", "Time until weekly reset")
        case .fiveHourPercent: return Strings.t("5時間枠の使用率", "5-hour usage")
        case .fiveHourResetTime: return Strings.t("5時間枠のリセット時刻", "5-hour reset time")
        case .fiveHourResetIn: return Strings.t("5時間枠のリセットまでの時間", "Time until 5-hour reset")
        case .opusPercent: return Strings.t("Opus の週の使用率", "Opus weekly usage")
        case .sonnetPercent: return Strings.t("Sonnet の週の使用率", "Sonnet weekly usage")
        case .extraUsage: return Strings.t("追加の従量課金の今月の使用額", "Extra usage spent this month")
        }
    }
}

/// 設定の窓で切り替えるもの。言語は Strings.swift の Language が持つ
enum Preferences {
    private static let linesKey = "statusLines"
    private static let claudeDirKey = "claudeDir"

    /// 初めて起動したときに選んでおく2つ。週の使用率とリセット日時を並べれば、リセットまで持つかが分かる
    static let defaultLines: [StatusItem] = [.weekPercent, .weekResetDate]

    /// メニューバーに出すもの。上の行から順に、最大2つ
    static var lines: [StatusItem] {
        get {
            guard let raw = UserDefaults.standard.stringArray(forKey: linesKey) else { return defaultLines }
            return Array(raw.compactMap(StatusItem.init(rawValue:)).prefix(2))
        }
        set {
            UserDefaults.standard.set(newValue.prefix(2).map(\.rawValue), forKey: linesKey)
            NotificationCenter.default.post(name: .statusLinesChanged, object: nil)
        }
    }

    /// 設定の窓で選んだ Claude Code の設定フォルダ。選んでいなければ nil で、CLAUDE_CONFIG_DIR か ~/.claude を使う
    static var claudeDir: String? {
        get { UserDefaults.standard.string(forKey: claudeDirKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: claudeDirKey)
            NotificationCenter.default.post(name: .claudeDirChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let statusLinesChanged = Notification.Name("parroo.statusLinesChanged")
    static let claudeDirChanged = Notification.Name("parroo.claudeDirChanged")
}
