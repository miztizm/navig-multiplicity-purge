# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/),
versioning: [SemVer](https://semver.org/).

## [2.2.0] — 2026-10-17

NAVIG skill packaging. The tool is unchanged (still 2.1.0); this release adds a tested,
installable skill around it. **Not submitted to the official registry** — installable straight
from this repo.

### Added
- `navig-skill/cli-skills/system/purge-multiplicity/` — `SKILL.md` (the form navig discovers),
  the registry-submission `purge-multiplicity.yaml`, and a vendored `purge-multiplicity.bat`.
  Commands: `status` (safe), `dry-run` (safe), `purge` (destructive, with a confirmation message).
- `navig-skill/test_skill.py` — 72 static checks + a 3-assertion behavioural run that executes the
  payload exactly the way navig does (`shell=True`, `cwd` = skill directory). `--live` enables it.
- `navig-skill/registry-entry.json` — the object to paste into `cli-skills/registry.json`.
- CI step running the static checks, including a byte-identical check that the vendored payload
  cannot drift from the root script.

### Discovered in navig 3.27.1 (documented in `navig-skill/README.md`)
- **Three different key spellings for one field.** The runtime (`core/navig/commands/skills.py`)
  reads `risk-level`; `SKILL_STANDARD.md` documents `risk_level`; `navig skill validate` reads
  `safety`. Setting only one leaves a destructive skill silently `safe` on the other paths — the
  skill now sets all three and a test pins them together.
- **A folder named `navig/` shadows the installed `navig` package** for anything run from the repo
  root, crashing its CLI with `ImportError: cannot import name '__version__'`. Hence `navig-skill/`.
- **`navig skill validate` / `list --dir` fail on relative paths** and succeed on absolute ones.
- `entrypoint:` only accepts `.py`/`.js`, so a `.bat` payload must use the raw-shell command path
  (a `syntax:` that does not start with `navig `), which runs with `cwd` = the skill directory.

### Fixed
- Nothing in the tool itself.

## [2.1.0] — 2026-10-17

Research pass plus a read-only diagnostic mode. Verified against **Multiplicity 4.0.7.2** on
Windows 11 — see [docs/background.md](docs/background.md).

### Added
- **`--status` / `-s`** — read-only report: installed version, service state and path, the
  `Primary` role flag with a plain-English interpretation, bound ports, live peers, how many of the
  four feature firewall rules exist, licence presence, IDD driver presence, uninstaller presence.
  Answers "am I actually using this?" without changing anything. No admin needed.
- `docs/background.md` — what Multiplicity is, its version lines, every component it installs, the
  documented port map, and the five concrete reasons an uninstall leaves residue. Sourced from
  Stardock's product/support pages and verified on a live install.
- Kill list extended with the actual MP4 binaries: `Multipl2_64.exe`, `Multipl2_A64.exe`,
  `Mp2control_64.exe`, `Mp2control_A64.exe`, `MP32.exe`, `MP64.exe`, `MultiPLVA64.exe`,
  `MultiSrv32.exe`, `MultiSrvA64.exe`, `MPRDP.exe`, `MPRDISP.exe`, `MPRDISP64.exe`,
  `EventFilter.exe`, `DeElevate.exe`.

### Changed
- README: new "Am I actually using it?" section, background link, updated verification numbers
  (25 actions / 98 skipped on the reference machine).

### Notes
- `EventFilter.exe` is killed because it lives in the Multiplicity folder and can hold it open;
  it is not a service and is not removed from any other product's folder.

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
