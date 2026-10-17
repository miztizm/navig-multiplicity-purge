#!/usr/bin/env python3
"""Checks for the packaged NAVIG skill.

Static checks (always run):
  * SKILL.md frontmatter is valid, starts with `---`, uses the keys the loader
    actually reads (`risk-level`, `user-invocable`, `navig-commands`,
    `confirmation_msg`)
  * the registry YAML is valid per registry/docs/SKILL_STANDARD.md
  * SKILL.md and the YAML agree on version + commands + risk
  * the vendored payload is byte-identical to the repo's root script, is
    ASCII-only and CRLF (cmd.exe misparses LF-only batch files)

Behavioural check (only with --live, and only if Multiplicity is present):
  * runs `multiplicity-purge.bat --status` exactly the way navig does it —
    shell=True with cwd = the skill directory — and requires exit 0 plus a
    recognisable status report

Usage:
  python navig-skill/test_skill.py          # static only (safe anywhere)
  python navig-skill/test_skill.py --live   # also exercise the payload on this machine
"""

from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML is required: python -m pip install pyyaml")

ROOT = Path(__file__).resolve().parents[1]
SKILL_DIR = ROOT / "navig-skill" / "cli-skills" / "system" / "multiplicity-purge"
SKILL_MD = SKILL_DIR / "SKILL.md"
SKILL_YAML = SKILL_DIR / "multiplicity-purge.yaml"
PAYLOAD = SKILL_DIR / "multiplicity-purge.bat"
ROOT_BAT = ROOT / "multiplicity-purge.bat"
# Repo root doubles as a plain Agent Skill folder so non-navig agents can install it.
ROOT_SKILL = ROOT / "SKILL.md"
ROOT_MAIN = ROOT / "main.py"
PKG_MAIN = SKILL_DIR / "main.py"

VALID_CATEGORIES = {
    "network", "system", "cloud", "docker", "database", "security",
    "developer", "media", "ai", "homelab", "productivity", "custom",
}
VALID_RISK = {"safe", "elevated", "destructive", "moderate"}

failures: list[str] = []
passes: list[str] = []


def ok(msg: str) -> None:
    passes.append(msg)
    print(f"  PASS  {msg}")


def bad(msg: str) -> None:
    failures.append(msg)
    print(f"  FAIL  {msg}")


def check(cond: bool, msg: str) -> None:
    ok(msg) if cond else bad(msg)


def frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise SystemExit(f"{path.name}: must start with a '---' frontmatter block (no code fence)")
    end = text.index("\n---", 3)
    return yaml.safe_load(text[3:end]) or {}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def static() -> None:
    print("SKILL.md (installed / discoverable form)")
    fm = frontmatter(SKILL_MD)
    for key in ("name", "description", "version", "risk-level", "navig-commands", "examples"):
        check(key in fm, f"frontmatter has '{key}'")
    check(str(fm.get("risk-level", "")).lower() in VALID_RISK,
          f"risk-level '{fm.get('risk-level')}' is one of {sorted(VALID_RISK)}")
    check(fm.get("user-invocable") is True, "user-invocable is true")
    # navig reads hyphenated keys at runtime, but `navig skill validate` reads
    # underscored ones. Setting only one makes a destructive skill validate as safe.
    check(fm.get("risk_level") == fm.get("risk-level"),
          "risk_level mirrors risk-level (validator + runtime agreement)")
    check(fm.get("safety") == fm.get("risk-level"),
          "safety mirrors risk-level (navig skill validate reads 'safety')")
    check(fm.get("user_invocable") is True, "user_invocable mirrors user-invocable (validator)")
    desc = str(fm.get("description", ""))
    check('"' in desc and "use when" in desc.lower(),
          "description carries verbatim trigger phrases (validator, guide section 2)")

    cmds = fm.get("navig-commands") or []
    check(isinstance(cmds, list) and len(cmds) >= 1, "at least one navig-command")
    names = [c.get("name", "") for c in cmds if isinstance(c, dict)]
    check(len(names) == len(set(names)), f"command names unique ({', '.join(names)})")
    for c in cmds:
        if not isinstance(c, dict):
            bad(f"command entry is not a mapping: {c!r}")
            continue
        for field in ("name", "syntax", "description", "risk"):
            check(bool(c.get(field)), f"command '{c.get('name')}' has '{field}'")
        check(c.get("risk") in VALID_RISK, f"command '{c.get('name')}' risk '{c.get('risk')}' valid")
        check(not str(c.get("syntax", "")).lower().startswith("navig "),
              f"command '{c.get('name')}' uses the raw-shell path (not a navig subcommand)")
        if c.get("risk") == "destructive":
            check(bool(c.get("confirmation_msg")),
                  f"destructive command '{c.get('name')}' carries confirmation_msg")

    examples = fm.get("examples") or []
    check(isinstance(examples, list) and len(examples) >= 1, "at least one example")
    for e in examples:
        check(all(k in e for k in ("title", "user", "command")),
              f"example '{e.get('title', '?')}' has title/user/command")

    hints = fm.get("agent_hints") or {}
    check(bool(hints.get("when_to_use")), "agent_hints.when_to_use present")

    print("\nregistry YAML (submission form)")
    ry = yaml.safe_load(SKILL_YAML.read_text(encoding="utf-8")) or {}
    for key in ("name", "description", "version", "category", "license",
                "user_invocable", "risk_level", "commands", "examples", "agent_hints"):
        check(key in ry, f"yaml has '{key}'")
    check(ry.get("category") in VALID_CATEGORIES, f"category '{ry.get('category')}' is valid")
    check(str(ry.get("risk_level", "")).lower() in VALID_RISK,
          f"risk_level '{ry.get('risk_level')}' valid")
    for c in ry.get("commands") or []:
        for field in ("name", "syntax", "description", "risk"):
            check(bool(c.get(field)), f"yaml command '{c.get('name')}' has '{field}'")
        if c.get("risk") == "destructive":
            check(bool(c.get("confirmation") or c.get("confirmation_msg")),
                  f"yaml destructive command '{c.get('name')}' has a confirmation message")

    print("\nSKILL.md <-> registry YAML agreement")
    check(fm.get("version") == ry.get("version"),
          f"version matches ({fm.get('version')})")
    y_cmds = [(c.get("name"), c.get("syntax"), c.get("risk")) for c in ry.get("commands") or []]
    m_cmds = [(c.get("name"), c.get("syntax"), c.get("risk")) for c in cmds]
    check(y_cmds == m_cmds, "command names, syntax and risk match in both files")
    check(str(ry.get("risk_level")).lower() == str(fm.get("risk-level")).lower(),
          "top-level risk matches")

    print("\npayload")
    check(PAYLOAD.is_file(), "multiplicity-purge.bat sits beside SKILL.md (cwd for navig)")
    check(ROOT_BAT.is_file(), "root script present")
    check(sha256(PAYLOAD) == sha256(ROOT_BAT),
          "vendored payload is byte-identical to the root script")

    raw = PAYLOAD.read_bytes()
    check(all(b < 128 for b in raw), "payload is ASCII-only")
    lf = raw.count(b"\n")
    crlf = raw.count(b"\r\n")
    check(lf == crlf, f"payload line endings are CRLF ({crlf}/{lf})")
    check(b'set "VER=' in raw, "payload declares a version")

    print("\nportable skill folder (repo root, for agents other than navig)")
    check(ROOT_SKILL.is_file(), "repo root has SKILL.md")
    check(sha256(ROOT_SKILL) == sha256(SKILL_MD),
          "root SKILL.md is byte-identical to the packaged one")
    check(ROOT_MAIN.is_file() and PKG_MAIN.is_file(), "main.py present at root and in the package")
    check(sha256(ROOT_MAIN) == sha256(PKG_MAIN), "main.py is byte-identical in both places")
    main_src = ROOT_MAIN.read_text(encoding="utf-8")
    check("Path(__file__).resolve().parent" in main_src,
          "main.py resolves the payload relative to itself (cwd-independent)")
    check('SAFE_DEFAULT = ["--status"]' in main_src,
          "main.py defaults to the read-only command")


def live() -> None:
    print("\nbehavioural check (navig execution model: shell=True, cwd=skill dir)")
    # Exactly what core/navig/commands/skills.py:_invoke_shell does for a command
    # whose syntax does not start with "navig ".
    cmd = "multiplicity-purge.bat --status"
    try:
        proc = subprocess.run(  # noqa: S602 - mirrors navig's own dispatch
            cmd, shell=True, cwd=str(SKILL_DIR), text=True,
            capture_output=True, timeout=120,
        )
    except Exception as exc:  # noqa: BLE001
        bad(f"could not run payload: {exc}")
        return
    out = (proc.stdout or "") + (proc.stderr or "")
    check(proc.returncode == 0, f"'{cmd}' exited 0 (got {proc.returncode})")
    check("status" in out.lower(), "payload produced a status report")
    check("role flag" in out.lower(), "report includes the role flag (Primary/Secondary)")
    if "not present" in out.lower():
        print("        note: Multiplicity is not installed on this machine — leftovers-only run")

    # Portability: the launcher must work from a DIFFERENT cwd than the skill folder,
    # which is the case for any agent that does not use navig's cwd convention.
    print("\nportability check (main.py run from the repo root, not the skill dir)")
    cmd = [sys.executable, str(ROOT_MAIN), "--status"]
    try:
        proc = subprocess.run(cmd, cwd=str(ROOT), text=True, capture_output=True, timeout=120)
    except Exception as exc:  # noqa: BLE001
        bad(f"could not run main.py: {exc}")
        return
    out = (proc.stdout or "") + (proc.stderr or "")
    check(proc.returncode == 0, f"'python main.py --status' exited 0 (got {proc.returncode})")
    check("role flag" in out.lower(), "launcher found the payload without relying on cwd")

    print("\nportability check (main.py with no args defaults to read-only)")
    try:
        proc = subprocess.run([sys.executable, str(ROOT_MAIN)], cwd=str(ROOT),
                              text=True, capture_output=True, timeout=120)
    except Exception as exc:  # noqa: BLE001
        bad(f"could not run bare main.py: {exc}")
        return
    out = (proc.stdout or "") + (proc.stderr or "")
    check(proc.returncode == 0, f"bare 'python main.py' exited 0 (got {proc.returncode})")
    check("role flag" in out.lower() and "actions that would run" not in out.lower(),
          "bare invocation stayed read-only (status report, no action list)")


def main() -> int:
    print(f"skill dir: {SKILL_DIR}")
    static()
    if "--live" in sys.argv:
        live()
    print(f"\n{len(passes)} passed, {len(failures)} failed")
    if failures:
        print("\nfailures:")
        for f in failures:
            print(f"  - {f}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
