import Darwin
import Foundation

/// 今開いている会話1つ
struct Conversation: Equatable {
    var sessionID: String
    /// 会話を開いているフォルダ。メニューではこの名前で分ける
    var cwd: String
    var title: String
    var tokens: Int

    var folderName: String { URL(fileURLWithPath: cwd).lastPathComponent }
}

/// 今開いている会話と、それぞれのトークン数を集める。
/// 会話の記録は長くなるので、前回読んだところから先だけを読む
@MainActor
final class Conversations {
    private var tallies: [String: Tally] = [:]

    func load() -> [Conversation] {
        let open = Self.openSessions(in: Paths.sessionsDir)
        // 閉じた会話の集計は捨てる
        tallies = tallies.filter { id, _ in open.contains { $0.sessionID == id } }
        return open.compactMap { session in
            let tally: Tally
            if let known = tallies[session.sessionID] {
                tally = known
            } else {
                guard let url = Self.transcript(for: session, in: Paths.projectsDir) else { return nil }
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
    }

    /// Claude Code は動いている間 `sessions/<pid>.json` を置き、会話の id と作業フォルダを書く。
    /// そのプロセスが居て、エディタに置き去りにされていなければ、開いているとみなす
    static func openSessions(in dir: URL) -> [Session] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                let session = parseSession(data),
                Processes.isAlive(session.pid), !Processes.isOrphanedFromEditor(session.pid)
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
        return Session(pid: pid, sessionID: id, cwd: cwd)
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
}

/// 会話の記録1つの集計。読んだところまでを覚えておき、増えた分だけ読む
@MainActor
final class Tally {
    let url: URL
    private var offset: UInt64 = 0
    /// 同じ返答が何行かに分けて書かれることがある。返答の id ごとに最後の行の値を使う
    private var perMessage: [String: Int] = [:]
    private var aiTitle: String?
    private var firstPrompt: String?

    init(url: URL) { self.url = url }

    /// 入力・出力・キャッシュの作成を足す。キャッシュの読み込みは、返答のたびに会話をまるごと読み直した分で、
    /// 足すとほぼそれで占められ、会話どうしを比べにくい（CLAUDE.md）
    var tokens: Int { perMessage.values.reduce(0, +) }

    /// Claude Code が付けた題名。まだ付いていなければ、最初に送った文の頭
    var title: String? { aiTitle ?? firstPrompt }

    func read() {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return }
        // 記録が作り直されて短くなったら、頭から読み直す
        if end < offset { reset() }
        guard end > offset else { return }
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.read(upToCount: Int(end - offset)) else { return }
        // 書きかけの行は次に回す。最後の改行までを読む
        guard let last = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        consume(data[data.startIndex...last])
        offset += UInt64(last - data.startIndex + 1)
    }

    private func reset() {
        offset = 0
        perMessage = [:]
        aiTitle = nil
        firstPrompt = nil
    }

    func consume(_ data: Data) {
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
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
