import Foundation
import Security

/// 使用量の枠1つ。使った割合と、リセットされる日時
struct UsageWindow: Equatable {
    /// 0〜100。枠を超えて使うと 100 を超えることがある
    var percent: Double
    var resetsAt: Date?
}

/// モデルごとの週の枠
struct ModelWindow: Equatable {
    var name: String
    var window: UsageWindow
}

/// 追加の従量課金。額は通貨の最小単位（ドルならセント）
struct ExtraUsage: Equatable {
    var used: Int
    var limit: Int?
    var currency: String
}

struct Usage: Equatable {
    var fiveHour: UsageWindow?
    var week: UsageWindow?
    var models: [ModelWindow] = []
    /// 有効にしていない人は nil
    var extra: ExtraUsage?

    func model(_ name: String) -> UsageWindow? {
        models.first { $0.name.localizedCaseInsensitiveContains(name) }?.window
    }
}

enum UsageError: Error, Equatable {
    case noCredentials
    case keychainDenied
    /// Parroo はトークンを更新しない。更新すると古い更新用トークンが使えなくなり、Claude Code のログインが外れるおそれがある。
    /// Claude Code を使えば Claude Code が更新するので、それを待つ
    case expired
    case http(Int)
    case network
    case unreadable

    var message: String {
        switch self {
        case .noCredentials: return Strings.noCredentials
        case .keychainDenied: return Strings.keychainDenied
        case .expired: return Strings.expired
        case .http(let status): return Strings.httpError(status)
        case .network: return Strings.networkError
        case .unreadable: return Strings.unreadable
        }
    }
}

/// 使用量を取る。Claude Code のログイン情報をキーチェーンから読み、Claude Code の `/usage` と同じ経路に問い合わせる。
/// この経路は公開されていないので、Anthropic 側の変更で動かなくなることがある（CLAUDE.md の「決まっていること」）
enum UsageClient {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch(claudeDir: URL, raw: String?) async -> Result<Usage, UsageError> {
        let token: String
        switch accessToken(services: Paths.keychainServices(claudeDir: claudeDir, raw: raw, home: Paths.home)) {
        case .success(let value): token = value
        case .failure(let error): return .failure(error)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        request.setValue("Parroo/\(version)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return .failure(status == 401 ? .expired : .http(status)) }
            guard let usage = parse(data) else { return .failure(.unreadable) }
            return .success(usage)
        } catch {
            return .failure(.network)
        }
    }

    /// 候補の項目名を順に探し、見つかった最初のもので決める
    static func accessToken(services: [String]) -> Result<String, UsageError> {
        for service in services {
            let result = accessToken(service: service)
            if result != .failure(.noCredentials) { return result }
        }
        return .failure(.noCredentials)
    }

    /// キーチェーンから、Claude Code が保存したアクセス用のトークンを読む。
    /// 初回は macOS が「Parroo がキーチェーンの情報を使おうとしています」と尋ねる
    static func accessToken(service: String) -> Result<String, UsageError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: break
        case errSecItemNotFound: return .failure(.noCredentials)
        default: return .failure(.keychainDenied)
        }
        guard let data = item as? Data else { return .failure(.noCredentials) }
        return token(fromCredentials: data)
    }

    /// `{"claudeAiOauth": {"accessToken": "...", "expiresAt": <ミリ秒>}}` の形
    static func token(fromCredentials data: Data, now: Date = Date()) -> Result<String, UsageError> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return .failure(.noCredentials) }
        if let expires = number(oauth["expiresAt"]), Date(timeIntervalSince1970: expires / 1000) <= now {
            return .failure(.expired)
        }
        return .success(token)
    }

    /// 応答を読む。使用率はパーセント（0〜100）、リセットは ISO 8601 の文字列、額は通貨の最小単位で来る
    /// （2.1.299 の本体の型の定義で確認）。知らない欄は読み飛ばす
    static func parse(_ data: Data) -> Usage? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var usage = Usage()
        usage.fiveHour = window(root["five_hour"])
        usage.week = window(root["seven_day"])
        for (key, name) in [("seven_day_opus", "Opus"), ("seven_day_sonnet", "Sonnet")] {
            if let w = window(root[key]) { usage.models.append(ModelWindow(name: name, window: w)) }
        }
        // 新しいアカウントでは、モデルごとの週の枠が名前付きの一覧で来る
        for limit in root["limits"] as? [[String: Any]] ?? [] {
            guard limit["kind"] as? String == "weekly_scoped",
                let scope = limit["scope"] as? [String: Any],
                let model = scope["model"] as? [String: Any],
                let name = model["display_name"] as? String,
                let percent = number(limit["percent"] ?? limit["utilization"])
            else { continue }
            // 固定の欄の「Opus」と、一覧の「Claude Opus 4.1」のように、同じ枠が名前を変えて両方に来ることがある
            let known = usage.models.contains {
                name.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(name)
            }
            guard !known else { continue }
            usage.models.append(
                ModelWindow(name: name, window: UsageWindow(percent: percent, resetsAt: date(limit["resets_at"]))))
        }
        if let extra = root["extra_usage"] as? [String: Any], extra["is_enabled"] as? Bool == true,
            let used = number(extra["used_credits"])
        {
            usage.extra = ExtraUsage(
                used: Int(used), limit: number(extra["monthly_limit"]).map { Int($0) },
                currency: (extra["currency"] as? String)?.uppercased() ?? "USD")
        }
        guard usage.fiveHour != nil || usage.week != nil else { return nil }
        return usage
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let obj = value as? [String: Any], let percent = number(obj["utilization"]) else { return nil }
        return UsageWindow(percent: percent, resetsAt: date(obj["resets_at"]))
    }

    private static func number(_ value: Any?) -> Double? {
        // JSON の true も NSNumber で来る。`is Bool` は数の 1 にも当たるので、型の id で見分ける
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return n.doubleValue
    }

    static func date(_ value: Any?) -> Date? {
        if let seconds = number(value) { return Date(timeIntervalSince1970: seconds) }
        guard let text = value as? String else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
