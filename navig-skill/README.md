# NAVIG skill packaging

This folder holds a **ready-to-submit** [NAVIG](https://github.com/navig-run/registry) skill for
`purge-multiplicity`, kept here so the tool and its skill packaging cannot drift apart.

**Status: not submitted to the official registry.** Nothing in this folder is published to
`navig-run/registry`; it is a local, installable package. Submitting is a separate decision —
see [Publishing](#publishing) below.

```
navig-skill/
├── test_skill.py                                  # static + behavioural checks
├── registry-entry.json                            # snippet for cli-skills/registry.json
└── cli-skills/system/purge-multiplicity/
    ├── SKILL.md                                   # what navig discovers and runs
    ├── purge-multiplicity.yaml                    # registry submission form
    └── purge-multiplicity.bat                     # vendored payload (byte-identical to root)
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
| A `syntax:` not starting with `navig ` runs as `shell=True` with **cwd = the skill directory** | `purge-multiplicity.bat` lives beside `SKILL.md`; no download, no PATH dependency |

Two documented-but-not-implemented field names are also handled: the loader reads `risk-level`,
`user-invocable` and `confirmation_msg` (hyphenated / suffixed), while `SKILL_STANDARD.md`
documents `risk_level`, `user_invocable` and `confirmation`. `SKILL.md` uses what the loader reads;
the registry YAML follows the standard **and** sets `confirmation_msg`, so the custom prompt
survives either path.

## Install it from this repo

```bash
# from GitHub (works once the commit is pushed)
python -m navig skill install github:miztizm/multiplicity-purge/navig-skill/cli-skills/system/purge-multiplicity

# or from a local checkout
python -m navig install add navig-skill/cli-skills/system/purge-multiplicity
```

Then:

```bash
python -m navig skill list                  # should show purge-multiplicity
python -m navig skill run purge-multiplicity:status
python -m navig skill run purge-multiplicity:dry-run
python -m navig skill run purge-multiplicity:purge   # destructive; prompts first
```

Remove it again:

```bash
python -m navig install list                # find the exact asset name
python -m navig install remove purge-multiplicity
```

## Test it

```bash
python navig-skill/test_skill.py           # static: frontmatter, YAML, agreement, payload hygiene
python navig-skill/test_skill.py --live    # also runs the payload the way navig does
```

`--live` runs `purge-multiplicity.bat --status` with `shell=True` and `cwd` set to the skill
directory — the same dispatch as `_invoke_shell` — and requires exit 0 plus a real status report.
It is read-only, and it works whether or not Multiplicity is installed.

CI runs the static form on every push, including the byte-identical payload check, so the vendored
copy can never silently drift from `../purge-multiplicity.bat`.

## Publishing

Not done, and not required for the tool to be useful. When you do want it in the official registry:

1. Copy `cli-skills/system/purge-multiplicity.yaml` **and** `purge-multiplicity.bat` into
   `navig-run/registry` at `cli-skills/system/`.
2. Add the entry from `registry-entry.json` to `cli-skills/registry.json`.
3. PR with the note that the payload is resolved via the skill's working directory.
4. `navig skill validate` / `navig skill lint` the derived `SKILL.md`.

Open question for the maintainers: the registry's canonical form is a flat `<category>/<id>.yaml`,
which has no room for a payload file. Either they accept a sibling `.bat`, or the skill needs a
folder form. That is worth asking in the PR rather than guessing.
