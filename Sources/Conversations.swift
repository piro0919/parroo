import Darwin
import Foundation

/// 今開いている会話1つ
struct Conversation: Equatable, Sendable {
    var sessionID: String
    /// 会話を開いているフォルダ。メニューではフォルダごとに見出しで分ける
    var cwd: String
    var title: String
    var tokens: Int
}

/// 今開いている会話と、それぞれのトークン数を集める。
/// 会話の記録は数百 MB になることがある（手元の最大は 262MB）。主のスレッドを止めないよう actor で読み、
/// 前回読んだところから先だけを少しずつ読む
actor ConversationStore {
    private var tallies: [String: Tally] = [:]

    func load(claudeDir: URL) -> [Conversation] {
        let open = Self.openSessions(in: claudeDir.appendingPathComponent("sessions"))
        // 閉じた会話の集計は捨てる
        tallies = tallies.filter { id, _ in open.contains { $0.sessionID == id } }
        return open.compactMap { session in
            let tally: Tally
            if let known = tallies[session.sessionID] {
                tally = known
            } else {
                let projects = claudeDir.appendingPathComponent("projects")
                guard let url = Self.transcript(for: session, in: projects) else { return nil }
                tally = Tally(url: url)
                tallies[session.sessionID] = tally
            }
            tally.read()
            return Conversation(
                sessionID: session.sessionID, cwd: session.cwd, title: tally.title ?? "", tokens: tally.tokens)
        }
    }

    struct Session: Equatable {
        var pid: Int32
        var sessionID: String
        var cwd: String
        /// プロセスが起動した時刻。番号が別のプロセスに使い回されていないかを見るのに使う
        var processStart: Date?
    }

    /// Claude Code は動いている間 `sessions/<pid>.json` を置き、会話の id と作業フォルダを書く。
    /// そのプロセスが居て、エディタに置き去りにされておらず、起動時刻も合っていれば、開いているとみなす
    static func openSessions(in dir: URL) -> [Session] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                let session = parseSession(data),
                Processes.isAlive(session.pid), !Processes.isOrphanedFromEditor(session.pid),
                Processes.startMatches(session.pid, session.processStart)
            else { return nil }
            return session
        }
    }

    /// `claude -p` のような無人の実行は数えない。画面に会話が無いため
    static func parseSession(_ data: Data) -> Session? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let pid = (obj["pid"] as? NSNumber)?.int32Value,
            let id = obj["sessionId"] as? String,
            let cwd = obj["cwd"] as? String
        else { return nil }
        if let kind = obj["kind"] as? String, kind != "interactive" { return nil }
        return Session(pid: pid, sessionID: id, cwd: cwd, processStart: processStart(obj["procStart"]))
    }

    /// `Wed Oct 14 18:59:59 2026` の形で、UTC で書かれている（`ps -o lstart` と照らして確認）
    static func processStart(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        return formatter.date(from: text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " "))
    }

    /// 記録は `projects/<作業フォルダの英数字以外を - にした名前>/<id>.jsonl`。
    /// 名前の詰め方が合わなかったときのために、無ければ全フォルダから探す
    static func transcript(for session: Session, in projects: URL) -> URL? {
        let name = "\(session.sessionID).jsonl"
        let guess = projects.appendingPathComponent(encode(session.cwd)).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: guess.path) { return guess }
        let dirs = (try? FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? []
        return dirs.map { $0.appendingPathComponent(name) }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    static func encode(_ cwd: String) -> String {
        String(cwd.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" })
    }

    /// メニューの見出し。ふつうはフォルダ名だけ。同じ名前のフォルダが2つ以上あるときは、
    /// 違いが出るところまで親のフォルダ名を足す（~/work/app と ~/personal/app を分ける）
    static func headers(for cwds: [String]) -> [String: String] {
        let unique = Array(Set(cwds))
        let parts = Dictionary(uniqueKeysWithValues: unique.map { ($0, URL(fileURLWithPath: $0).pathComponents) })
        var result: [String: String] = [:]
        for cwd in unique {
            let mine = parts[cwd] ?? []
            var depth = 1
            while depth < mine.count {
                let label = mine.suffix(depth)
                let clash = unique.contains { other in other != cwd && (parts[other] ?? []).suffix(depth) == label }
                if !clash { break }
                depth += 1
            }
            result[cwd] = mine.suffix(depth).filter { $0 != "/" }.joined(separator: "/")
        }
        return result
    }
}

/// 会話の記録1つの集計。読んだところまでを覚えておき、増えた分だけ読む
final class Tally {
    let url: URL
    private var offset: UInt64 = 0
    /// 読んでいるファイルの番号。置き換えられたら、長さに関わらず頭から読み直す
    private var fileNumber: Int?
    /// 同じ返答が何行かに分けて書かれることがある。返答の id ごとに最後の行の値を使う
    private var perMessage: [String: Int] = [:]
    private var aiTitle: String?
    private var firstPrompt: String?

    /// 一度に読む量。数百 MB の記録を丸ごと抱えない
    private static let chunk = 4 << 20

    init(url: URL) { self.url = url }

    /// 入力・出力・キャッシュの作成を足す。キャッシュの読み込みは、返答のたびに会話をまるごと読み直した分で、
    /// 足すとほぼそれで占められ、会話どうしを比べにくい（CLAUDE.md）
    var tokens: Int { perMessage.values.reduce(0, +) }

    /// Claude Code が付けた題名。まだ付いていなければ、最初に送った文の頭
    var title: String? { aiTitle ?? firstPrompt }

    func read() {
        let number = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.systemFileNumber] as? Int
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return }
        // 記録が作り直されたら、頭から読み直す
        if end < offset || number != fileNumber { reset() }
        fileNumber = number
        while offset < end {
            try? handle.seek(toOffset: offset)
            guard let data = try? handle.read(upToCount: min(Self.chunk, Int(end - offset))), !data.isEmpty
            else { return }
            // 書きかけの行は次に回す。最後の改行までを読む
            guard let last = data.lastIndex(of: UInt8(ascii: "\n")) else {
                // 1行が一度に読む量より長い。改行が見つかるまで広げて読む
                guard let line = readLine(handle, from: offset, end: end) else { return }
                consume(line)
                offset += UInt64(line.count)
                continue
            }
            consume(data[data.startIndex...last])
            offset += UInt64(last - data.startIndex + 1)
        }
    }

    /// 改行までの1行を、改行ごと読む。改行がまだ書かれていなければ nil
    private func readLine(_ handle: FileHandle, from start: UInt64, end: UInt64) -> Data? {
        var line = Data()
        var position = start
        while position < end {
            try? handle.seek(toOffset: position)
            guard let data = try? handle.read(upToCount: min(Self.chunk, Int(end - position))), !data.isEmpty
            else { return nil }
            if let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
                line.append(data[data.startIndex...newline])
                return line
            }
            line.append(data)
            position += UInt64(data.count)
        }
        return nil
    }

    private func reset() {
        offset = 0
        perMessage = [:]
        aiTitle = nil
        firstPrompt = nil
    }

    private static let assistantMark = Data(#""type":"assistant""#.utf8)
    private static let titleMark = Data(#""type":"ai-title""#.utf8)
    private static let userMark = Data(#""type":"user""#.utf8)

    func consume(_ data: Data) {
        for line in data.split(separator: UInt8(ascii: "\n")) {
            // 行の大半はツールの出力で、要らない。JSON として読む前に、印の文字列で振り分ける
            let wanted =
                line.range(of: Self.assistantMark) != nil || line.range(of: Self.titleMark) != nil
                || (firstPrompt == nil && line.range(of: Self.userMark) != nil)
            guard wanted, let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            apply(obj)
        }
    }

    private func apply(_ obj: [String: Any]) {
        switch obj["type"] as? String {
        case "ai-title":
            if let title = obj["aiTitle"] as? String, !title.isEmpty { aiTitle = title }
        case "assistant":
            guard let message = obj["message"] as? [String: Any],
                let id = message["id"] as? String,
                let usage = message["usage"] as? [String: Any]
            else { return }
            let keys = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
            perMessage[id] = keys.reduce(0) { $0 + ((usage[$1] as? NSNumber)?.intValue ?? 0) }
        case "user":
            // 人が送った文には origin.kind が human と付く。中断の印や無人の実行の文には付かない
            guard firstPrompt == nil,
                (obj["origin"] as? [String: Any])?["kind"] as? String == "human",
                let message = obj["message"] as? [String: Any],
                let text = Self.promptText(message["content"])
            else { return }
            firstPrompt = Self.shorten(text)
        default:
            return
        }
    }

    /// 本文の最初の段落。エディタが足す `<ide_selection>` のような包みは飛ばす
    static func promptText(_ content: Any?) -> String? {
        let texts: [String]
        if let text = content as? String {
            texts = [text]
        } else if let parts = content as? [[String: Any]] {
            texts = parts.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
        } else {
            return nil
        }
        return texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("<") }
    }

    /// 1行目の頭 30 文字
    static func shorten(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > 30 ? String(line.prefix(30)) + "…" : line
    }
}

/// プロセスの見張り。Hawky の Store と同じ規則（CLAUDE.md）
enum Processes {
    /// シグナル 0 は何も送らずに、居るかどうかだけを返す。他人のプロセスなら EPERM になるが、居ることには変わりない
    static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// エディタに置き去りにされたか。Cursor を再起動すると、前の拡張ホストが死なずに
    /// launchd に引き取られて残ることがあり、そこから起動した Claude Code も生き続ける。
    /// 拡張ホストは「〜 Helper (Plugin)」という名前で、本来はエディタの本体の子になる。
    /// 親が launchd になっていれば置き去りとみなす。ターミナルから起動した Claude Code は親がシェルなので当たらない
    static func isOrphanedFromEditor(_ pid: Int32) -> Bool {
        let parent = parentPID(of: pid)
        guard parent > 1, processName(parent).contains("Helper") else { return false }
        return parentPID(of: parent) == 1
    }

    /// 目印に書かれた起動時刻と、その番号のプロセスの起動時刻が合うか。
    /// Claude Code が強制終了すると目印が残り、のちに同じ番号が別のプロセスに付くことがある。
    /// 目印に時刻が無ければ確かめようがないので、合っているとみなす
    static func startMatches(_ pid: Int32, _ expected: Date?) -> Bool {
        guard let expected, let actual = startTime(of: pid) else { return true }
        return abs(actual.timeIntervalSince(expected)) < 2
    }

    static func startTime(of pid: Int32) -> Date? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
    }

    static func parentPID(of pid: Int32) -> Int32 {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return Int32(info.pbi_ppid)
    }

    static func processName(_ pid: Int32) -> String {
        var name = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &name, UInt32(name.count)) > 0 else { return "" }
        return String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
