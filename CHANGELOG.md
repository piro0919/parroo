# Changelog

Notable changes to Parroo. `release.sh` publishes the section for the version being released as
its release notes, and stops if that section is missing or empty — so before releasing, rename
`Unreleased` to `[x.y.z] - YYYY-MM-DD` and commit.

## [0.1.0] - 2026-10-15

### Added

- First release. Shows how much of your Claude Code plan you have used, and when it resets,
  in the menu bar — in English or Japanese.
- Pick up to two things for the menu bar, stacked in two lines: weekly usage, the weekly reset
  date, the time until the weekly reset, the same three for the 5-hour limit, Opus and Sonnet
  weekly usage, and extra usage spent this month.
- The menu lists the weekly and 5-hour limits in full words, per-model weekly limits, and the
  token count of each Claude Code conversation that is open now, grouped by folder.
