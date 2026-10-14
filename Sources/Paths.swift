import CryptoKit
import Foundation

enum Paths {
    static var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }

    /// Claude Code の設定フォルダ。会話の記録と、開いている会話の目印はここにある
    static var claudeDir: URL {
        claudeDir(
            chosen: Preferences.claudeDir, environment: ProcessInfo.processInfo.environment, home: home)
    }

    /// 設定の窓で選んだフォルダ、CLAUDE_CONFIG_DIR、`~/.claude` の順に見る。
    /// Finder から開いたアプリにはシェルの環境変数が届かないので、窓で選べるようにしてある（Hawky と同じ）
    static func claudeDir(chosen: String?, environment: [String: String], home: URL) -> URL {
        for path in [chosen, environment["CLAUDE_CONFIG_DIR"]] {
            guard let path = path?.trimmingCharacters(in: .whitespaces), !path.isEmpty else { continue }
            if path == "~" { return home }
            if path.hasPrefix("~/") { return home.appendingPathComponent(String(path.dropFirst(2))) }
            return URL(fileURLWithPath: path)
        }
        return home.appendingPathComponent(".claude")
    }

    /// Claude Code が動いている間、会話ごとに `<pid>.json` を置く場所
    static var sessionsDir: URL { claudeDir.appendingPathComponent("sessions") }

    /// 会話の記録。`<作業フォルダを詰めた名前>/<会話の id>.jsonl`
    static var projectsDir: URL { claudeDir.appendingPathComponent("projects") }

    /// ログイン情報が入っているキーチェーンの項目名。
    /// Claude Code は設定フォルダを既定から移していると、そのパスの SHA-256 の頭8桁を後ろに付ける
    /// （2.1.299 の本体で `Claude Code${suffix}-credentials${-hash}` の組み立てを確認）
    static func keychainService(claudeDir: URL, home: URL) -> String {
        let base = "Claude Code-credentials"
        let standard = home.appendingPathComponent(".claude").standardizedFileURL.path
        let path = claudeDir.standardizedFileURL.path
        guard path != standard else { return base }
        let digest = SHA256.hash(data: Data(path.precomposedStringWithCanonicalMapping.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(base)-\(hex.prefix(8))"
    }

    /// 画面に出すときは、ホームを `~` に縮める
    static func display(_ url: URL, home: URL = home) -> String {
        let path = url.standardizedFileURL.path
        let root = home.standardizedFileURL.path
        if path == root { return "~" }
        return path.hasPrefix(root + "/") ? "~" + path.dropFirst(root.count) : path
    }
}
