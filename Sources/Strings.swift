import Foundation

/// 画面の言語。既定はシステムに従い、日本語の環境なら日本語、それ以外は英語にする（Hawky と同じ）
enum Language: String, CaseIterable {
    case system, ja, en

    private static let key = "language"

    /// 設定で選ばれている言語
    static var chosen: Language {
        get { UserDefaults.standard.string(forKey: key).flatMap(Language.init(rawValue:)) ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    /// 実際に使う言語
    static var resolved: Language {
        switch chosen {
        case .ja: return .ja
        case .en: return .en
        case .system: return (Locale.preferredLanguages.first ?? "en").hasPrefix("ja") ? .ja : .en
        }
    }

    var label: String {
        switch self {
        case .system: return Strings.t("システムに従う", "Follow system")
        case .ja: return "日本語"
        case .en: return "English"
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("parroo.languageChanged")
}

/// 画面に出す文言。言語は設定で切り替えられるので、読むたびに選び直す
enum Strings {
    static func t(_ ja: String, _ en: String) -> String { Language.resolved == .ja ? ja : en }

    // メニュー
    static var statusDescription: String { t("Claude Code の使用量", "Claude Code usage") }
    static var weekHeader: String { t("週の枠", "Weekly limit") }
    static var fiveHourHeader: String { t("5時間枠", "5-hour limit") }
    static var modelsHeader: String { t("モデルごとの週の枠", "Weekly limits by model") }
    static func used(_ percent: String) -> String { t("\(percent) 使用", "\(percent) used") }
    static func resetsAt(_ when: String, in left: String) -> String {
        t("\(when) にリセット ・ あと \(left)", "Resets \(when) · in \(left)")
    }
    static func updatedAt(_ time: String) -> String { t("\(time) に更新", "Updated at \(time)") }
    static var neverUpdated: String { t("まだ取得できていません", "Not fetched yet") }
    static var noConversations: String { t("開いている会話はありません", "No open conversations") }
    static var settings: String { t("設定…", "Settings…") }
    static var quit: String { t("終了", "Quit") }

    // 取れなかったとき。利用者が何をすれば戻るかを書く
    static var noCredentials: String {
        t("Claude Code のログイン情報が見つかりません", "Claude Code login not found")
    }
    static var expired: String {
        t("ログイン情報の期限切れ。Claude Code を使うと戻ります", "Login expired. Using Claude Code will renew it")
    }
    static var keychainDenied: String {
        t("キーチェーンの読み取りが許可されていません", "Keychain access was not allowed")
    }
    static func httpError(_ status: Int) -> String {
        t("使用量を取得できません（HTTP \(status)）", "Could not fetch usage (HTTP \(status))")
    }
    static var networkError: String { t("使用量を取得できません（通信エラー）", "Could not fetch usage (network error)") }
    static var unreadable: String { t("使用量の応答を読めません", "Could not read the usage response") }

    // 設定の窓
    static var settingsTitle: String { t("設定", "Settings") }
    static var firstLine: String { t("1行目", "First line") }
    static var secondLine: String { t("2行目", "Second line") }
    static var none: String { t("表示しない", "None") }
    static var configFolder: String { t("設定フォルダ", "Config Folder") }
    static var chooseFolder: String { t("変更…", "Change…") }
    static var language: String { t("言語", "Language") }
    static var launchAtLogin: String { t("ログイン時に起動", "Launch at Login") }
    static var launchFailed: String { t("ログイン時の起動を切り替えられませんでした", "Could not change Launch at Login") }
    static var checkForUpdates: String { t("アップデートを確認", "Check for Updates") }
}
