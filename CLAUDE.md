# Parroo

開発者向けの設計メモ。

Claude Code の使用量の残りと、次のリセット日時を、日本語でリアルタイムに見るためのアプリ。
2026-10-15 にホームのセッションで話して決めた。経緯の全文は
`~/.claude/projects/-Users-piro/0995354d-5d72-4e58-b3c9-380ff34740b8.jsonl`。

## 作る理由

- Max プランでも1週間持たなくなってきた。残りとリセットまでの時間を常に見ていたい
- 同じことをする既存のアプリは、調べた範囲ではどれも英語だった。日本語対応を明記したものは見つからなかった
  - Mac のメニューバー: claude-usage-menubar（csyio）、ClaudeUsageBar、Usagebar（9ドル買い切り）、simple-claude-usage（macOS 26 以降）、modeldeck
  - 同じ機能で名前も近いもの: CC Watcher（5時間枠のトークン使用量を出す Mac のオーバーレイ）
- Claude Code の statusLine に出す方法は、Cursor の拡張機能のパネルで使っていると見えない（見えるかは未確認）。それがわずらわしい
- 標準の `/usage` と claude.ai の「設定 → 使用状況」は、都度開かないと見られない

## 決まっていること

- 名前は **Parroo**
  - 鸚鵡（parrot）から。しゃべる鳥なので「残りを日本語で教えてくれる」に結び付く
  - Hawky（鷹）・Owler（梟）と並ぶ、Claude Code まわりの鳥のシリーズ
  - 末尾は Hawky の y、Owler の er と揃えない（本人の希望）。o を重ねたのは parrot と区別するためで、他の意味はない
  - 同名の確認: Homebrew の cask・GitHub・App Store に Parroo は無かった（2026-10-15）。似た名前は Parroot、Parrooot（どちらも小さな別物）

## 落とした案

- **Claude Code Watcher**: 名前に Claude を入れると商標の苦情のおそれがある。Anthropic の商標の決まりは提携と誤解される使い方を禁じ、
  有志のアプリ「Claude Remote」が 2026-03 に苦情を受けている。CC Watcher という同じ機能のアプリも既にある
- **CC ◯◯**（CC Nokori など）: 鳥のシリーズにする方へ移った
- **Parroty / Parroter**: Hawky・Owler と末尾が同じになる
- **Parroot**: parrot の打ち間違いに見える
- その他に出して選ばれなかった候補: Nokori、Hakari、Anbai、Meyasu、Tokebo、Crowly、Kotori、Atonan、Nokorin、Tokenwatch、Roosty、Larky、Kitey、Wrenly、Polly、Inko、Parro、Parrotto

## 未決

- 形: Mac のメニューバーに常駐するアプリの日本語版として話が出たが、画面の形はまだ決めていない
- 使用率とリセット時刻をどこから取るか。どちらも一長一短
  - 既存のアプリと同じく、Claude Code のログイン情報をキーチェーンから読み、公開されていない経路で取る。
    Claude Code を開いていなくても取れる。Anthropic 側の変更で一斉に動かなくなるおそれがあり、配るならそのたびに直す手間を抱える
  - Claude Code 本体が statusLine のスクリプトに渡す値を使う。手元の 2.1.283 では `rate_limits.five_hour` と
    `rate_limits.seven_day` に `used_percentage` と `resets_at` があった（バイナリの文字列で確認）。
    公開されていない経路に頼らずに済むが、Claude Code が動いている間しか値が更新されない
- 日本語だけにするか、英語も持つか
- アイコン。案として「鸚鵡が吹き出しで『あと42%』としゃべる絵」を出したが、決めていない
- 見た目、文言、配り方、LP、ライセンス
