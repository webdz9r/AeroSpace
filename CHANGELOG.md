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
descriptive version suffix (e.g. `0.20.0-controltower`) to distinguish them from stock releases.

## [Unreleased]

_Nothing yet._

## [0.20.0-controltower] — 2026-06-26

Baseline: rebased onto upstream `nikitabobko/AeroSpace` at `v0.20.0-Beta`.

### Added

- **Control Tower — visual workspace switcher.** New `control-tower` command toggles a
  Mission-Control-style overlay showing every non-empty workspace as a schematic map: each workspace
  is drawn as its real tiling layout with the app icon, name, and window title in each tile, grouped
  by monitor. Navigate with the keyboard or mouse to switch workspaces.
  - `aerospace control-tower` toggles the overlay open/closed.
  - Bound to `alt-shift-tab` by default (replacing the `move-workspace-to-monitor` binding on that key).
  - Keyboard: arrows to move, type a workspace name to jump, `Enter` to switch, `Esc` to cancel;
    mouse: click a workspace to switch, click the dimmed background to cancel.
  - Schematic is built entirely from the in-memory window tree (tiling geometry + app icons) — **no
    Screen Recording permission and no private APIs**. Window titles are fetched asynchronously and
    pop in so the overlay opens instantly. Floating windows render non-overlapping (a grid when a
    workspace is all-floating; a separate strip when mixed with tiled windows).
  - Frosted-glass backdrop (`NSVisualEffectView`); the overlay is never managed by AeroSpace itself.
  - Fork-only GUI feature (against upstream's no-GUI value); not upstream-mergeable.

### Changed

- **Rebased the fork onto upstream `v0.20.0-Beta`** (previously based on ~`0.12`). Sticky windows and
  the runaway-CPU fix below now ride on the new upstream base.

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
[0.20.0-controltower]: https://github.com/webdz9r/AeroSpace/commits/main
[0.12.0-sticky]: https://github.com/webdz9r/AeroSpace/commits/main
