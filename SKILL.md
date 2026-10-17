---
name: multiplicity-purge
description: >-
  Remove Stardock/EdgeRunner Multiplicity 2/3/4 leftovers - service, folders, registry keys and
  firewall rules - with a dry run first and a verification pass after. Use when the user says
  "uninstall multiplicity", "remove multiplicity", "purge multiplicity", or reports a failed
  uninstall, a service that will not stop, or an installer that claims it is already installed.
version: 2.1.0
category: system
license: MIT
author: miztizm
# Three spellings on purpose. navig is inconsistent about this field:
#   core/navig/commands/skills.py  (runtime)   -> risk-level   (hyphenated)
#   registry/docs/SKILL_STANDARD.md            -> risk_level   (underscored)
#   `navig skill validate`                     -> safety
# Setting only one leaves the skill silently `safe` in some path.
user-invocable: true
user_invocable: true
risk-level: destructive
risk_level: destructive
safety: destructive
platforms: [windows]
navig-commands:
  - name: status
    syntax: multiplicity-purge.bat --status
    description: Read-only report - version, service state, Primary/Secondary role, bound ports, live peers, firewall rules, licence
    risk: safe
  - name: dry-run
    syntax: multiplicity-purge.bat --dry-run --no-pause
    description: Print every action a purge would take; changes nothing, needs no admin
    risk: safe
  - name: purge
    syntax: multiplicity-purge.bat --yes --no-pause
    description: Elevate, stop and delete the service, kill processes, remove leftover folders, registry keys and firewall rules, then verify
    risk: destructive
    confirmation_msg: "This removes Multiplicity services, folders, registry keys and firewall rules. No undo. Run dry-run first?"
examples:
  - title: Am I actually using Multiplicity?
    user: Is Multiplicity doing anything on this machine?
    command: navig skill run multiplicity-purge:status
  - title: What would a cleanup remove?
    user: What Multiplicity leftovers could I clean up?
    command: navig skill run multiplicity-purge:dry-run
  - title: Purge it
    user: Purge the Multiplicity leftovers
    command: navig skill run multiplicity-purge:purge
agent_hints:
  when_to_use: >-
    Use when the user wants to remove or clean up Stardock Multiplicity or EdgeRunner
    Multiplicity, or reports a failed uninstall, a service that will not stop, an installer that
    claims the product is still installed, or leftover firewall rules. Trigger on "uninstall
    multiplicity", "remove multiplicity", "multiplicity service", "purge multiplicity".
  output_format: >-
    status and dry-run print a plain-text report (version, role, ports, peers, candidate
    actions). purge prints one line per action plus a summary: removed / skipped / failed and
    the log path.
  follow_up: >-
    Always run status or dry-run before purge. Warn the user if the role flag is PRIMARY or a
    peer is connected - purging then disconnects other machines. After a purge, offer a reboot.
---

# multiplicity-purge

Unofficial cleaner for **Stardock / EdgeRunner Multiplicity 2, 3 and 4** leftovers. Packaged for
[NAVIG](https://navig.run) — the operator runtime this skill installs into. Multiplicity's
own uninstaller regularly leaves the service running, ghost `CurrentControlSet\Services` keys, an
installed IDD driver, `ProgramData` session data and per-feature firewall rules — which is why a
reinstall can claim the product is still there.

Full product notes, the port map and the reasons residue survives:
<https://github.com/miztizm/navig-multiplicity-purge/blob/main/docs/background.md>

## Commands

| Command | Risk | What it does |
|---|---|---|
| `status` | safe | Read-only: version, service, role flag with interpretation, ports, peers, firewall rules, licence, driver. |
| `dry-run` | safe | Prints every action as `would ...`. No admin, cannot mutate. |
| `purge` | destructive | Stops and deletes the service, kills processes, removes folders, registry keys and firewall rules, then re-verifies. Self-elevates via UAC. |

## Two things to know

1. **`status` before `purge`, always.** If it reports `PRIMARY` or a connected peer, other machines
   are using this one — purging disconnects them mid-session.
2. **Windows only.** Multiplicity is Windows software; on any other platform the launcher exits
   with a clear message instead of doing something surprising.

## Running it in any agent (not just navig)

This file is a standard `SKILL.md`, so any agent that loads skills can use it. The `navig-commands`
block above is navig-specific sugar; everything below works everywhere, from any working directory:

```bash
python main.py --status     # default when run with no args — read-only
python main.py --dry-run    # what a purge would remove; changes nothing
python main.py --yes        # destructive, non-interactive (prompts are skipped)
```

`main.py` resolves `multiplicity-purge.bat` **relative to its own location**, so cwd never matters.
If Python is unavailable, call the batch file directly:

```bat
multiplicity-purge.bat --status
```

## Licence

MIT. Not affiliated with Stardock or EdgeRunner; "Multiplicity" is a trademark of its owner.
