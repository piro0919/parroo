import Foundation

/// 画面を出さずに、読み取りと書き方の規則だけを確かめる。`./Parroo --selftest` で走る。
/// キーチェーンにも通信にも触らないので、CI のランナーで動く
@MainActor
enum SelfTest {

    private static var failures = 0

    static func run() -> Int32 {
        failures = 0
        let utc = TimeZone(identifier: "UTC")!

        // 使用量の応答。使用率はパーセント、リセットは ISO 8601、額はセント
        do {
            let json = """
                {"five_hour":{"utilization":42.0,"resets_at":"2026-10-15T16:30:00.123+00:00"},
                 "seven_day":{"utilization":68.6,"resets_at":"2026-10-17T14:00:00Z"},
                 "seven_day_opus":{"utilization":30,"resets_at":null},
                 "seven_day_sonnet":null,
                 "limits":[{"kind":"weekly_scoped","group":"weekly","percent":20,"resets_at":"2026-10-17T14:00:00Z",
                            "scope":{"model":{"display_name":"Sonnet"}}},
                           {"kind":"spend","group":"monthly","percent":5}],
                 "extra_usage":{"is_enabled":true,"monthly_limit":5000,"used_credits":1240,"currency":"usd"}}
                """
            let usage = UsageClient.parse(Data(json.utf8))
            check(usage?.fiveHour?.percent == 42, "5時間枠の使用率を読む")
            check(usage?.week?.percent == 68.6, "週の使用率を読む")
            check(
                usage?.fiveHour?.resetsAt == Date(timeIntervalSince1970: 1_792_081_800.123),
                "小数秒つきのリセット日時を読む")
            check(usage?.week?.resetsAt == Date(timeIntervalSince1970: 1_792_245_600), "小数秒なしのリセット日時を読む")
            check(usage?.model("Opus")?.percent == 30, "固定の欄から Opus を読む")
            check(usage?.model("Sonnet")?.percent == 20, "名前付きの一覧から Sonnet を読む")
            check(usage?.models.count == 2, "週の枠でない一覧の行は読まない")
            check(usage?.extra == ExtraUsage(used: 1240, limit: 5000, currency: "USD"), "追加の従量課金を読む")

            let disabled = UsageClient.parse(
                Data(#"{"seven_day":{"utilization":1},"extra_usage":{"is_enabled":false,"used_credits":0}}"#.utf8))
            check(disabled != nil && disabled?.extra == nil, "追加の従量課金を有効にしていなければ持たない")
            check(UsageClient.parse(Data("{}".utf8)) == nil, "枠が1つも無い応答は読めないとみなす")
            check(UsageClient.parse(Data(#"{"five_hour":{"utilization":true}}"#.utf8)) == nil, "真偽値を使用率と取り違えない")
        }

        // ログイン情報。期限切れなら更新せずに止まる
        do {
            let now = Date(timeIntervalSince1970: 1_000_000)
            let valid = #"{"claudeAiOauth":{"accessToken":"tok","expiresAt":1000001000}}"#
            let expired = #"{"claudeAiOauth":{"accessToken":"tok","expiresAt":999999000}}"#
            check(UsageClient.token(fromCredentials: Data(valid.utf8), now: now) == .success("tok"), "期限内なら使う")
            check(UsageClient.token(fromCredentials: Data(expired.utf8), now: now) == .failure(.expired), "期限切れを見分ける")
            check(
                UsageClient.token(fromCredentials: Data("{}".utf8), now: now) == .failure(.noCredentials),
                "ログイン情報が無いことを見分ける")
        }

        // キーチェーンの項目名。設定フォルダを移していると、パスの SHA-256 の頭8桁が付く
        do {
            let home = URL(fileURLWithPath: "/Users/someone")
            check(
                Paths.keychainService(claudeDir: home.appendingPathComponent(".claude"), home: home)
                    == "Claude Code-credentials", "既定のフォルダなら後ろに何も付けない")
            let moved = Paths.keychainService(claudeDir: URL(fileURLWithPath: "/tmp/claude-work"), home: home)
            check(moved.hasPrefix("Claude Code-credentials-") && moved.count == 24 + 8, "移したフォルダなら8桁を付ける")
        }

        // メニューバーの2行
        do {
            let now = Date(timeIntervalSince1970: 1_792_000_000)
            var usage = Usage()
            usage.week = UsageWindow(percent: 68.6, resetsAt: now.addingTimeInterval(2 * 86400 + 5 * 3600))
            usage.fiveHour = UsageWindow(percent: 42, resetsAt: now.addingTimeInterval(80 * 60))
            check(Format.statusLine(.weekPercent, usage: usage, now: now) == "1w: 69%", "週の使用率は四捨五入")
            check(Format.statusLine(.weekResetIn, usage: usage, now: now) == "1w: 2d 5h", "週の残りは日と時間")
            check(Format.statusLine(.fiveHourResetIn, usage: usage, now: now) == "5h: 1h 20m", "5時間枠の残りは時間と分")
            check(Format.statusLine(.opusPercent, usage: usage, now: now) == "Opus: --", "無い値は --")
            check(!Format.isShown(.extraUsage, usage: usage), "追加の従量課金が無ければ行を出さない")
            check(Format.statusLine(.weekPercent, usage: nil, now: now) == "1w: --", "取れる前は --")
        }

        // 日時と時間の書き方
        do {
            let date = Date(timeIntervalSince1970: 1_792_245_600)  // 2026-10-17 14:00 UTC
            check(Format.date(date, language: .ja, timeZone: utc) == "10/17 14:00", "日本語の日付")
            check(Format.date(date, language: .en, timeZone: utc) == "Oct 17 14:00", "英語の日付")
            check(Format.time(date, timeZone: utc) == "14:00", "時刻だけ")
            check(Format.longDuration(2 * 86400 + 5 * 3600, language: .ja) == "2日5時間", "メニューの時間は省略しない")
            check(Format.longDuration(80 * 60, language: .ja) == "1時間20分", "時間と分")
            check(Format.longDuration(3600, language: .en) == "1 hour", "英語の単数")
            check(Format.longDuration(2 * 86400 + 3600, language: .en) == "2 days 1 hour", "英語の複数")
            check(Format.shortDuration(30) == "1m", "1分未満は1分に切り上げる")
            check(Format.shortDuration(-100) == "0m", "過ぎていたら 0m")
            check(Format.tokens(182_431) == "182,431", "トークン数は丸めずに3桁ごとに区切る")
            check(Format.money(minor: 1240, currency: "USD") == "$12", "ドルはセントから直す")
            check(Format.money(minor: 1200, currency: "JPY") == "¥1,200", "円は最小単位がそのまま円")
        }

        // 会話の記録の集計
        do {
            let lines = [
                #"{"type":"user","origin":{"kind":"human"},"message":{"content":[{"type":"text","text":"<ide_selection>x</ide_selection>"},{"type":"text","text":"アイコンを作って\n詳しくは"}]}}"#,
                #"{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":100,"cache_read_input_tokens":9999}}}"#,
                #"{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":10,"output_tokens":7,"cache_creation_input_tokens":100,"cache_read_input_tokens":9999}}}"#,
                #"{"type":"assistant","message":{"id":"m2","usage":{"input_tokens":1,"output_tokens":2,"cache_creation_input_tokens":3}}}"#,
                #"{"type":"user","origin":{"kind":"human"},"message":{"content":"二つ目"}}"#,
            ]
            let tally = Tally(url: URL(fileURLWithPath: "/dev/null"))
            tally.consume(Data(lines.joined(separator: "\n").utf8))
            check(tally.tokens == 117 + 6, "同じ返答は1つにまとめ、キャッシュの読み込みは足さない")
            check(tally.title == "アイコンを作って", "題名が無ければ最初に送った文の1行目")
            tally.consume(Data(#"{"type":"ai-title","aiTitle":"Parroo のアイコン"}"#.utf8))
            check(tally.title == "Parroo のアイコン", "題名が付いたらそちらを使う")
            check(Tally.shorten(String(repeating: "あ", count: 40)).count == 31, "長い文は30文字で詰める")
        }

        // 開いている会話の目印
        do {
            let session = #"{"pid":123,"sessionId":"abc","cwd":"/Users/piro/Repository/parroo","kind":"interactive"}"#
            check(
                Conversations.parseSession(Data(session.utf8))
                    == .init(pid: 123, sessionID: "abc", cwd: "/Users/piro/Repository/parroo"), "目印を読む")
            let headless = #"{"pid":1,"sessionId":"x","cwd":"/","kind":"print"}"#
            check(Conversations.parseSession(Data(headless.utf8)) == nil, "無人の実行は数えない")
            check(
                Conversations.encode("/Users/piro/.claude/skills") == "-Users-piro--claude-skills",
                "記録のフォルダ名は英数字以外を - にする")
        }

        if failures == 0 { print("selftest: すべて通りました") }
        return failures == 0 ? 0 : 1
    }

    private static func check(_ condition: Bool, _ name: String) {
        if !condition {
            failures += 1
            print("selftest: 失敗: \(name)")
        }
    }
}
