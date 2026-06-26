# Changelog

All notable changes **made in this fork** ([webdz9r/AeroSpace](https://github.com/webdz9r/AeroSpace))
on top of upstream [nikitabobko/AeroSpace](https://github.com/nikitabobko/AeroSpace) are documented
here.

This file tracks **fork-specific** work only — features, fixes, and behavior changes authored here.
Changes pulled in from upstream are not re-listed; see the upstream
[CHANGELOG](https://github.com/nikitabobko/AeroSpace/blob/main/CHANGELOG.adoc) for those. The fork
periodically rebases/merges upstream `main`; the **Baseline** note in each release records the
upstream point we diverged from.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Fork builds carry a
`-sticky` version suffix (e.g. `0.12.0-sticky`) to distinguish them from stock releases.

## [Unreleased]

_Nothing yet._

## [0.12.0-sticky] — 2026-06-26

Baseline: upstream `nikitabobko/AeroSpace` at `a60f963` ("Treat Outlook reminders as popups",
2026-05-27) plus subsequent upstream `main` commits merged in.

### Added

- **Sticky / pinned windows.** New `sticky` command pins a window so it follows you across
  workspaces and monitors instead of staying on one workspace. (PR
  [#1](https://github.com/webdz9r/AeroSpace/pull/1); upstream discussion
  [#2030](https://github.com/nikitabobko/AeroSpace/discussions/2030).)
  - `aerospace sticky [on|off|toggle]` — pin/unpin the focused (or `--window-id`) window. Works
    inside `on-window-detected` rules.
  - `%{window-is-sticky}` placeholder for `list-windows --format`, so sticky state is queryable.
  - **Menu-bar sticky indicator** — the tray icon shows when a sticky window is active.
  - Docs: `aerospace-sticky.adoc`, a `goodies.adoc` section on highlighting sticky windows with
    [JankyBorders](https://github.com/FelixKratz/JankyBorders), and a `default-config.toml` example.

### Fixed

- **Runaway CPU from infinite app-registration retry loop.** `MacApp.getOrRegister` retried an
  app's Accessibility (AX) subscription forever when it could never succeed (a terminated or hung
  app), pegging a CPU core indefinitely — observed accumulating 80+ hours of CPU time after a
  short-lived `com.google.chrome.for.testing` process exited. This is the "phantom window holding an
  empty space until you restart" symptom. The retry loop now makes a single registration attempt
  (returning `nil` on failure, naturally re-attempted on the next refresh cycle) and skips apps that
  have already terminated. (`Sources/AppBundle/tree/MacApp.swift`; branch
  `fix/runaway-app-registration-loop`.)

[Unreleased]: https://github.com/webdz9r/AeroSpace/compare/main...HEAD
[0.12.0-sticky]: https://github.com/webdz9r/AeroSpace/commits/main
