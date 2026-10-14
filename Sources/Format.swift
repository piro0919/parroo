import Foundation

/// 数と日時の書き方。メニューバーの2行は省略形、メニューの中は省略しない（CLAUDE.md）
enum Format {
    /// 69%。小数は四捨五入する
    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    /// 182,431。言語によらず3桁ごとにコンマ
    static func tokens(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 日本語は 10/17 14:00、英語は Oct 17 14:00。曜日だけだと「何日？」となるので日付で書く
    static func date(_ date: Date, language: Language = Language.resolved, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: language == .ja ? "ja_JP" : "en_US_POSIX")
        formatter.dateFormat = language == .ja ? "M/d HH:mm" : "MMM d HH:mm"
        return formatter.string(from: date)
    }

    /// 16:30。5時間枠は日をまたいでも5時間以内なので、時刻だけで足りる
    static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 残り時間を日・時間・分に分ける。大きい方から2つだけ使う
    private static func parts(_ seconds: TimeInterval) -> [(Int, Unit)] {
        let minutes = max(0, Int((seconds / 60).rounded(.up)))
        let d = minutes / (60 * 24)
        let h = minutes / 60 % 24
        let m = minutes % 60
        if d > 0 { return h > 0 ? [(d, .day), (h, .hour)] : [(d, .day)] }
        if h > 0 { return m > 0 ? [(h, .hour), (m, .minute)] : [(h, .hour)] }
        return [(m, .minute)]
    }

    private enum Unit { case day, hour, minute }

    /// メニューバー用。2d 5h、1h 20m。日本語でも同じ
    static func shortDuration(_ seconds: TimeInterval) -> String {
        parts(seconds).map { value, unit in
            switch unit {
            case .day: return "\(value)d"
            case .hour: return "\(value)h"
            case .minute: return "\(value)m"
            }
        }.joined(separator: " ")
    }

    /// メニュー用。2日5時間、2 days 5 hours
    static func longDuration(_ seconds: TimeInterval, language: Language = Language.resolved) -> String {
        let words = parts(seconds).map { value, unit -> String in
            switch (unit, language) {
            case (.day, .ja): return "\(value)日"
            case (.hour, .ja): return "\(value)時間"
            case (.minute, .ja): return "\(value)分"
            case (.day, _): return value == 1 ? "1 day" : "\(value) days"
            case (.hour, _): return value == 1 ? "1 hour" : "\(value) hours"
            case (.minute, _): return value == 1 ? "1 minute" : "\(value) minutes"
            }
        }
        return words.joined(separator: language == .ja ? "" : " ")
    }

    /// $12。円なら ¥1,200。通貨は応答に従い、換算はしない（請求の額とずれるため）
    static func money(minor: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_US")
        // 最小単位から主単位へ。ドルは 2 桁、円は 0 桁
        let digits = formatter.maximumFractionDigits
        let major = Double(minor) / pow(10, Double(digits))
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .down
        return formatter.string(from: NSNumber(value: major)) ?? "\(major) \(currency)"
    }

    /// メニューバーの1行。値が無ければ「--」
    static func statusLine(_ item: StatusItem, usage: Usage?, now: Date = Date()) -> String {
        func remaining(_ w: UsageWindow?) -> String {
            guard let at = w?.resetsAt else { return "--" }
            return shortDuration(at.timeIntervalSince(now))
        }
        switch item {
        case .weekPercent:
            return "1w: " + (usage?.week.map { percent($0.percent) } ?? "--")
        case .weekResetDate:
            return "1w: " + (usage?.week?.resetsAt.map { date($0) } ?? "--")
        case .weekResetIn:
            return "1w: " + remaining(usage?.week)
        case .fiveHourPercent:
            return "5h: " + (usage?.fiveHour.map { percent($0.percent) } ?? "--")
        case .fiveHourResetTime:
            return "5h: " + (usage?.fiveHour?.resetsAt.map { time($0) } ?? "--")
        case .fiveHourResetIn:
            return "5h: " + remaining(usage?.fiveHour)
        case .opusPercent:
            return "Opus: " + (usage?.model("Opus").map { percent($0.percent) } ?? "--")
        case .sonnetPercent:
            return "Sonnet: " + (usage?.model("Sonnet").map { percent($0.percent) } ?? "--")
        case .extraUsage:
            guard let extra = usage?.extra else { return "--" }
            let used = money(minor: extra.used, currency: extra.currency)
            guard let limit = extra.limit else { return used }
            return "\(used)/\(money(minor: limit, currency: extra.currency))"
        }
    }

    /// 追加の従量課金を有効にしていない人には、使用額の行を出さない
    static func isShown(_ item: StatusItem, usage: Usage?) -> Bool {
        item != .extraUsage || usage?.extra != nil
    }

    /// メニューバーに描く行。まだ一度も取れていないときは「1w: --」を並べず空にし、鸚鵡だけを出させる
    static func statusLines(_ items: [StatusItem], usage: Usage?, now: Date = Date()) -> [String] {
        guard let usage else { return [] }
        return items.filter { isShown($0, usage: usage) }.map { statusLine($0, usage: usage, now: now) }
    }
}
