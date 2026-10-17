# navig-multiplicity-purge

**Unofficial cleaner for Stardock / EdgeRunner Multiplicity 2, 3 and 4 leftovers.**

> **Part of the [NAVIG](https://navig.run) ecosystem.** This repo ships a
> [NAVIG](https://navig.run) skill, so the cleaner can be installed and run through the
> [NAVIG registry](https://github.com/navig-run/registry) — see [navig-skill/](navig-skill/README.md).
> Naming follows the `navig-*` family (`navig-menu`, `navig-vault`, `navig-dedupe`, …) so it is
> discoverable alongside the other NAVIG tools.

Multiplicity's own uninstaller regularly leaves the machine in a half-uninstalled state: the
service survives, `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Multiplicity` stays behind,
ProgramData keeps its session data, and the firewall keeps the rules. Windows then refuses to
reinstall, or the installer insists the product is "already installed".

`multiplicity-purge` removes exactly those leftovers, logs every action, and refuses to touch
anything else.

```
        dry run first  ->  confirm  ->  purge  ->  verify  ->  reboot
```

> **Not affiliated with Stardock or EdgeRunner.** "Multiplicity" is a trademark of its respective
> owner. This is an independent cleanup utility for people who already decided to uninstall.

---

## Quick start

```cmd
:: 1. See exactly what would be removed. Changes nothing. No admin needed.
multiplicity-purge.bat --dry-run

:: 2. Run it (asks for confirmation, then self-elevates)
multiplicity-purge.bat

:: 3. Unattended, e.g. from a provisioning script
multiplicity-purge.bat --yes --no-reboot --log C:\logs\mp-purge.log
```

Requirements: Windows 10/11, `cmd.exe`. Admin rights for a live run (the script re-launches
itself elevated through UAC). A dry run needs no rights at all.

## Am I actually using it?

Before removing anything, ask the machine. `--status` is read-only and prints what the install is
doing right now — role, peers, ports:

```cmd
multiplicity-purge.bat --status
```

```
 --- status ---------------------------------------------------------------
  version     : 4.0.7.2
  service     : RUNNING
  service exe : C:\Program Files (x86)\Stardock\Multiplicity\Multisrv64.exe
  role flag   : Primary=0
  interpreted : SECONDARY - another PC drives this one's keyboard and mouse
  listening   :
   TCP    0.0.0.0:30564   0.0.0.0:0   LISTENING   151788
   TCP    0.0.0.0:30565   0.0.0.0:0   LISTENING   22680
   TCP    0.0.0.0:30567   0.0.0.0:0   LISTENING   151788
  peers       :
   TCP    192.168.1.18:59755   192.168.1.13:30564   ESTABLISHED   22680
   TCP    192.168.1.18:30567   192.168.1.13:49225   ESTABLISHED   151788
  firewall    : 4 of 4 feature rules present
  license     : present
  idd driver  : present (indirect display driver, MP4)
  uninstaller : present
```

Read it like this:

| What you see | What it means |
|---|---|
| `Primary=0x1` | This PC **is** the primary. Other machines depend on it — purging disconnects them. |
| `Primary=0x0` + a peer on `:30564` | This PC is a **secondary, currently in use**. Purging kills a live session. |
| `Primary=0x0` + no peers | Installed, licensed, **idle**. This is the safe-to-clean case. |
| No `Multiplicity` service | Already uninstalled — leftovers only. |

## Options

| Option | Effect |
|---|---|
| `--dry-run`, `-n` | Print every action as `would ...`, change nothing. Structurally safe — each action passes through a guarded helper. |
| `--status`, `-s` | Read-only report: version, service, role, ports, peers, firewall rules, licence, driver. Answers "am I using this?". |
| `--yes`, `-y` | Skip the interactive `PURGE` confirmation (for scripting). |
| `--no-pause` | Do not wait for a keypress at the end. |
| `--no-reboot` | Do not offer the reboot at the end. |
| `--log PATH` | Write the log elsewhere (default `%TEMP%\multiplicity-purge.log`). |
| `--help`, `-h` | Usage. |

Exit codes: `0` success · `1` aborted by you · `2` elevation refused · `3` at least one action failed.

## What it removes

| Category | Detail |
|---|---|
| **Services** | `SDMultiplicityService`, `Multiplicity`, `MultiSrv`, `MultiSrv64`, `SdDisplay` — stopped, then deleted. |
| **Processes** | `multipl.exe`, `multipl2.exe`, `MultiPLV64.exe`, `MP2Drag.exe`, `MP2Control.exe`, `MPBar.exe`, `MultiplicityConfig.exe`, `MultiSrv.exe`, `MultiSrv64.exe`, `MPRDP64.exe`, `SdDisplay.exe`, `DeElevate64.exe`, `Multiplicity.exe`. |
| **Scheduled tasks** | Any task whose name contains `Multiplicity`. |
| **Legacy uninstallers** | `Multisrv64.exe -uninstall` / `Multisrv.exe -uninstall` under EdgeRunner and Stardock install roots, if present. |
| **Directories** | The Multiplicity folders under `Program Files`, `Program Files (x86)`, `ProgramData`, `%LOCALAPPDATA%` and `%APPDATA%` — across the MP2/MP3/MP4 layouts. |
| **Registry** | Multiplicity's own keys: the `Stardock\Multiplicity*` subtree entries, the `Uninstall` entries, and the service keys under `CurrentControlSet\Services`. |
| **Firewall** | The 14 known Multiplicity rule names. |

Feature-by-feature port map, component list and version notes: [docs/background.md](docs/background.md).
Full detail, including what is deliberately **not** touched: [docs/removal-map.md](docs/removal-map.md).

## Safety design

The script is not "careful by vibes" — it is careful by construction:

1. **One choke point.** Every mutation goes through a helper (`:StopService`, `:RmDir`, `:RegDel`,
   `:DelFirewall`, …). Each helper begins with the dry-run guard, so a dry run cannot mutate.
2. **Verify, don't assume.** Deletions are confirmed afterwards (`if exist`, `sc query`,
   `reg query`); failures are counted, not swallowed.
3. **Nothing is deleted by pattern.** No registry wildcards, no `rmdir` on a parent of unrelated
   software. The only wildcard is the `Registrations\mp*.bin` cleanup inside Multiplicity's own
   ProgramData folder.
4. **Confirmation by typing `PURGE`.** A stray Enter does nothing.
5. **Log first, always.** `%TEMP%\multiplicity-purge.log` with a timestamp per action.

**No undo.** Make a restore point (`SystemPropertiesProtection.exe`) or a VM snapshot first if the
machine matters. The script is written to be readable precisely so you can audit it before running
it — it is ~500 lines of batch, and every destructive line is on the same line as its guard.

## Verification

Tested against a live Windows 11 machine running **Multiplicity 4.0.7.2** as a secondary:

```
[1/9] Stopping services...        would stop service Multiplicity
[2/9] Ending processes...         would kill process Multipl2_64.exe, Mp2control_64.exe, MP32.exe,
                                  MultiSrv64.exe, MP2Drag.exe, MultiplicityConfig.exe
[3/9] Removing scheduled tasks... (none matched — the CSV parse keeps task paths intact)
[6/9] Removing directories...     Program Files (x86)\Stardock\Multiplicity, ProgramData\Stardock\MP2, ...
[9/9] Verifying leftovers...      service Multiplicity ... leftover
Actions that WOULD run: 25   Skipped: 98   Would fail: 0
```

A `--dry-run` on your machine should produce a short, plausible list. If it ever lists a scheduled
task or a directory that has nothing to do with Multiplicity, **stop and open an issue** — that is a
bug, not a quirk.

## Background

[docs/background.md](docs/background.md) covers what Multiplicity is, its EdgeRunner → Stardock
version history, every file and driver an MP4 install places on disk, the port map
(30564/30565/30567/30568/30569) and the five specific reasons an uninstall leaves residue. Read it
before a purge on a machine you care about.

## Install

Three ways, depending on where you are running it from. The skill is a standard `SKILL.md` folder,
so it is not navig-specific — the repo root **is** a valid skill.

**1. Any agent that loads `SKILL.md`** (Claude Code, navig, your own harness) — clone or point at
the repo root:

```bash
git clone https://github.com/miztizm/navig-multiplicity-purge
cd navig-multiplicity-purge
python main.py --status      # the launcher finds the payload itself; cwd does not matter
```

`main.py` resolves `multiplicity-purge.bat` relative to its own location and defaults to the
**read-only** `--status`, so a bare invocation can never purge.

**2. NAVIG** (its native packaging, with `status` / `dry-run` / `purge` as skill commands):

```bash
python -m navig skill install github:miztizm/navig-multiplicity-purge/navig-skill/cli-skills/system/multiplicity-purge
python -m navig skill run multiplicity-purge:status --dir ~/.navig/data/store/skills
python -m navig install remove multiplicity-purge
```

**3. No tooling at all** — download the script and run it:

```cmd
curl -L -o multiplicity-purge.bat https://github.com/miztizm/navig-multiplicity-purge/releases/latest/download/multiplicity-purge.bat
multiplicity-purge.bat --status
```

**It is not submitted to the official NAVIG registry** — it is packaged here and installable
directly from this repo. Windows only (Multiplicity is Windows software); the launcher says so and
exits cleanly on other platforms.

Packaging notes, the pillar rationale and the three frontmatter spellings navig disagrees with
itself about: [navig-skill/README.md](navig-skill/README.md).

## Development

Single-file batch, on purpose: it must run on a machine where nothing is installed.

- Keep the file **ASCII-only** and **CRLF** line endings. Both are enforced in CI
  (`.github/workflows/lint.yml`) because cmd.exe misparses LF-only batch files.
- Keep every mutation inside a helper that has the `%DRY%` guard.
- Prefer `if ... goto` over multi-line `if ( ... ) else ( ... )` — nested blocks in cmd are a
  reliable source of silent misbehaviour.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 miztizm.
