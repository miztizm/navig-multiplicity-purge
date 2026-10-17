# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/),
versioning: [SemVer](https://semver.org/).

## [2.0.0] — 2026-10-17

First public release. A one-off cleanup script rewritten as a maintainable tool.

### Added
- `--dry-run` / `-n` — prints every action as `would ...` and changes nothing. No admin needed.
- `--yes` / `-y` — unattended mode for provisioning scripts.
- `--no-pause`, `--no-reboot`, `--log PATH`, `--help`.
- Interactive confirmation that requires typing `PURGE` (a stray Enter aborts).
- Self-elevation through UAC when a live run is not already elevated; a dry run is allowed unelevated.
- Structured log with a timestamp per action, default `%TEMP%\purge-multiplicity.log`.
- Exit codes: `0` success, `1` aborted, `2` elevation refused, `3` one or more actions failed.
- Post-run verification pass — services, directories and registry re-checked, leftovers counted.
- Optional reboot prompt (`shutdown /r /t 10`, cancellable with `shutdown /a`).
- Actionable counters in the summary: removed / skipped / failed.

### Fixed
- **Scheduled-task matching matched almost every Windows task.** The original parsed
  `schtasks /Query /FO LIST` output with space delimiters, so a task path like
  `\Microsoft\Windows\.NET Framework\...` was split and the remainder matched anything. 928 false
  matches on a test machine. Now parsed from `schtasks /Query /FO CSV /NH`, one task per line,
  name as the first quoted field.
- **`%ERRORLEVEL%` inside parenthesised blocks** was expanded at parse time, so failure detection
  was unreliable. All branches now use delayed expansion (`!ERRORLEVEL!`) or `if ... goto`.
- **`DelMaskIf` broke on paths containing spaces** — the `for` loop was unquoted.
- **Registry keys were queried and deleted with inconsistent naming**, so a delete could be
  attempted against a key that had already been tested as absent.
- **Verification reported absent services as leftovers** (inverted test).
- Multi-line `if ( ... ) else ( ... )` chains replaced with explicit `goto` — cmd silently misparses
  deeply nested blocks.

### Changed
- Windows registry keys listed with their full `HKEY_LOCAL_MACHINE` / `HKEY_CURRENT_USER` roots.
- Added Multiplicity 4 install roots (`Stardock\Multiplicity4`) and the MP3/MP4 ProgramData layouts.
- Every mutation funnelled through one guarded helper, so a dry run is structurally incapable of
  changing the machine.
- ASCII-only source with CRLF line endings, enforced in CI (cmd.exe misparses LF-only batch files).

### Removed
- The hard-coded `pause` at the end (now `--no-pause` aware).
- The always-on reboot message (now a real prompt).

## [1.0.0]

Original one-off script: stop services, kill processes, delete tasks, folders, registry keys and
firewall rules for Multiplicity 2/3/4. No dry run, no logging options, no verification,
no arguments.
