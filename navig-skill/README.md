# NAVIG skill packaging

Part of the [NAVIG](https://navig.run) ecosystem — the operator runtime this packages into, with
its [registry](https://github.com/navig-run/registry) and the [navig-run](https://github.com/navig-run)
GitHub org.

This folder holds a **ready-to-submit** [NAVIG](https://github.com/navig-run/registry) skill for
`multiplicity-purge`, kept here so the tool and its skill packaging cannot drift apart.

**Status: not submitted to the official registry.** Nothing in this folder is published to
`navig-run/registry`; it is a local, installable package. Submitting is a separate decision —
see [Publishing](#publishing) below.

```
navig-skill/
├── test_skill.py                                  # static + behavioural checks
├── registry-entry.json                            # snippet for cli-skills/registry.json
└── cli-skills/system/multiplicity-purge/
    ├── SKILL.md                                   # what navig discovers and runs
    ├── multiplicity-purge.yaml                    # registry submission form
    └── multiplicity-purge.bat                     # vendored payload (byte-identical to root)
```

## Why a cli-skill, and why this shape

The registry defines **cli-skills** as *"YAML command skills for one tool each (git, docker,
network, security, system)"*. A Multiplicity uninstaller is exactly that, so the pillar is
`cli-skills`, category `system`.

Three details come from reading `core/navig-skill/commands/skills.py` rather than the docs:

| Detail | Consequence here |
|---|---|
| Skills are discovered by `rglob("SKILL.md")`; category = first path segment | `SKILL.md` is the real artifact, `cli-skills/system/` is the category |
| Only `.py`/`.js` may be `entrypoint:` | No `entrypoint:` — commands use the raw-shell path instead |
| A `syntax:` not starting with `navig ` runs as `shell=True` with **cwd = the skill directory** | `multiplicity-purge.bat` lives beside `SKILL.md`; no download, no PATH dependency |

Two documented-but-not-implemented field names are also handled: the loader reads `risk-level`,
`user-invocable` and `confirmation_msg` (hyphenated / suffixed), while `SKILL_STANDARD.md`
documents `risk_level`, `user_invocable` and `confirmation`. `SKILL.md` uses what the loader reads;
the registry YAML follows the standard **and** sets `confirmation_msg`, so the custom prompt
survives either path.

## Install it from this repo

```bash
# from GitHub (works once the commit is pushed)
python -m navig skill install github:miztizm/navig-multiplicity-purge/navig-skill/cli-skills/system/multiplicity-purge

# or from a local checkout
python -m navig install add navig-skill/cli-skills/system/multiplicity-purge
```

Then:

```bash
STORE="$HOME/.navig/data/store/skills"      # where navig installs skills
python -m navig skill list --dir "$STORE"   # should show multiplicity-purge
python -m navig skill run multiplicity-purge:status  --dir "$STORE"
python -m navig skill run multiplicity-purge:dry-run --dir "$STORE"
python -m navig skill run multiplicity-purge:purge   --dir "$STORE"   # destructive; prompts first
```

Remove it again:

```bash
python -m navig install remove multiplicity-purge
python -m navig install list                # confirm it is gone
```

> **`--dir` matters.** Skills are resolved relative to the current navig project, *not* the global
> store, so from an arbitrary directory `skill run` reports `Skill not found` even though
> `navig install list` shows the asset. Run it inside a navig project, or pass
> `--dir <store>/skills` as above. This was found by testing the install cycle, not by reading docs.

## Verified install → run → remove cycle

On navig 3.27.1 / Windows 11, against the public repo:

```
$ python -m navig skill install github:miztizm/navig-multiplicity-purge/navig-skill/cli-skills/system/multiplicity-purge
  > Installed skill 'multiplicity-purge' -> C:\Users\...\.navig\data\store\skills\multiplicity-purge

$ ls <store>/multiplicity-purge
  SKILL.md   multiplicity-purge.yaml   multiplicity-purge.bat     # payload travelled with it

$ python -m navig skill run multiplicity-purge:status --dir <store>/skills
  > multiplicity-purge.bat --status
   version 4.0.7.2 · service RUNNING · role flag Primary=0 · peers: 192.168.1.13:30564 ...

$ python -m navig skill run multiplicity-purge:dry-run --dir <store>/skills
   Actions that WOULD run: 25   Skipped: 98   Would fail: 0

$ python -m navig install remove multiplicity-purge
  > Removed 'multiplicity-purge'
$ test -d <store>/multiplicity-purge    # False — clean removal, nothing left behind
```

## Test it

```bash
python navig-skill/test_skill.py           # static: frontmatter, YAML, agreement, payload hygiene
python navig-skill/test_skill.py --live    # also runs the payload the way navig does
```

`--live` runs `multiplicity-purge.bat --status` with `shell=True` and `cwd` set to the skill
directory — the same dispatch as `_invoke_shell` — and requires exit 0 plus a real status report.
It is read-only, and it works whether or not Multiplicity is installed.

CI runs the static form on every push, including the byte-identical payload check, so the vendored
copy can never silently drift from `../multiplicity-purge.bat`.

## Publishing

Not done, and not required for the tool to be useful. When you do want it in the official registry:

1. Copy `cli-skills/system/multiplicity-purge.yaml` **and** `multiplicity-purge.bat` into
   `navig-run/registry` at `cli-skills/system/`.
2. Add the entry from `registry-entry.json` to `cli-skills/registry.json`.
3. PR with the note that the payload is resolved via the skill's working directory.
4. `navig skill validate` / `navig skill lint` the derived `SKILL.md`.

Open question for the maintainers: the registry's canonical form is a flat `<category>/<id>.yaml`,
which has no room for a payload file. Either they accept a sibling `.bat`, or the skill needs a
folder form. That is worth asking in the PR rather than guessing.
