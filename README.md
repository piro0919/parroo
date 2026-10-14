# Parroo

A macOS menu bar app that shows how much of your Claude Code plan you have used,
and when it resets — in English or Japanese.

On a Max plan the weekly limit can run out before the week does. Claude Code's
`/usage` and the usage page on claude.ai tell you where you stand, but only when
you go and open them. Parroo keeps it in the menu bar instead.

You choose up to two things for the menu bar, stacked in two lines — for
example how much of the week you have used and when the week resets:

```text
1w: 69%
1w: Oct 17 14:00
```

Click it for the rest: the weekly and 5-hour limits spelled out, per-model
weekly limits, and the tokens spent in each Claude Code conversation you have
open right now, grouped by folder.

macOS 14+. No Xcode needed: `./build.sh` compiles with the Swift that ships with
the Command Line Tools.

## Installing

With Homebrew:

```bash
brew install --cask piro0919/tap/parroo
```

Or download the DMG from [Releases](https://github.com/piro0919/parroo/releases/latest)
and drag Parroo into Applications.

The first launch will be blocked: Parroo is signed with a self-signed certificate,
not an Apple Developer ID, so macOS cannot verify who made it. To let it through,
open **System Settings → Privacy & Security**, scroll to the bottom, and click
**Open Anyway** next to the message about Parroo. You only do this once.

Then macOS asks whether Parroo may use the confidential information stored in
"Claude Code-credentials" in your keychain. Enter your login password and click
**Always Allow**. **Allow** works too, but then macOS asks again every time
Parroo refreshes.

You need to be signed in to Claude Code with a Claude subscription (Pro, Max,
Team or Enterprise). With an API key there are no plan limits to show.

Updates arrive through Sparkle. Parroo looks once at launch and only says
something when there is one.

## What it shows

In the menu bar, any two of:

| Item | Looks like |
| --- | --- |
| Weekly usage | `1w: 69%` |
| Weekly reset date | `1w: Oct 17 14:00` |
| Time until the weekly reset | `1w: 2d 5h` |
| 5-hour usage | `5h: 42%` |
| 5-hour reset time | `5h: 16:30` |
| Time until the 5-hour reset | `5h: 1h 20m` |
| Opus weekly usage | `Opus: 30%` |
| Sonnet weekly usage | `Sonnet: 20%` |
| Extra usage spent this month | `$12/$50` |

Percentages are how much you have *used*, the same way claude.ai shows them.
Extra usage is shown in the currency you are billed in, without conversion, and
only when extra usage is turned on for your account.

In the menu:

- **Weekly limit** and **5-hour limit** — usage, the reset time and the time
  left, in full words ("2 days 5 hours").
- **Weekly limits by model**, when your plan has them.
- **Open conversations**, grouped by the folder they were opened in. Each row is
  the title Claude Code gave the conversation, and the tokens it has used so
  far: input, output and cache writes. Cache reads are left out — they are the
  whole conversation read again on every reply, and would drown out everything
  else.
- **Updated at …** — when the usage was last fetched, so you can tell when the
  numbers have gone stale.
- **Settings…** — the two menu bar lines, Claude Code's config folder, the
  language (follow the system, English or Japanese), Launch at Login and Check
  for Updates.

## How it works

**Usage.** Parroo reads the sign-in Claude Code saved in your keychain and asks
the same endpoint Claude Code's `/usage` uses, every two minutes and when you
open the menu. That endpoint is not a public API: if Anthropic changes it,
Parroo stops showing usage until it is updated. Parroo never refreshes the
sign-in itself — doing so would replace the refresh token Claude Code holds. If
the sign-in has expired, the menu says so, and using Claude Code renews it.

**Conversations.** While Claude Code runs, it keeps a small file per
conversation in `~/.claude/sessions/`. Parroo lists the ones whose process is
still alive, and reads the token counts from the conversation's transcript in
`~/.claude/projects/` — only the part added since the last read.

If you keep Claude Code's settings somewhere else with `CLAUDE_CONFIG_DIR`,
choose that folder under **Config Folder**. An app opened from the Finder or the
Dock does not see variables set in your shell.

Nothing leaves your Mac except the request to Anthropic's usage endpoint.

## Building and checking

```bash
./build.sh
./Parroo.app/Contents/MacOS/Parroo --selftest
./Parroo.app/Contents/MacOS/Parroo --render-status /tmp/status.png
```

`--selftest` checks the response parsing, the formats and the token counting
without touching the keychain or the network. CI runs it together with
`swift format lint --strict`. `--render-status` draws the menu bar item with
sample values, light and dark, for when the menu bar is too full to show it.
Sparkle is fetched into `Vendor/` on the first build.

The icon comes from `assets/icon-source.png`. `python3 Tools/make-icon.py` rounds
it, writes `AppIcon.icns`, and cuts the parrot out as the menu bar template. The
prompts that produced the artwork are in [docs/art-prompt.md](docs/art-prompt.md).

## License

MIT
