#!/usr/bin/env python3
"""Portable launcher for multiplicity-purge.

Exists so the skill works the same way everywhere:

  * navig runs a command with the skill directory as cwd -> the raw `.bat` works
  * another agent, a cron job, or a human may run from *any* cwd -> this resolves
    the payload relative to its own location instead of relying on cwd
  * `python main.py ...` works even if `.bat` execution is awkward in the host

The payload stays a single `.bat` (it must run on machines where nothing is
installed); this only forwards arguments to it.

Usage:
  python main.py --status      # default when no args: read-only status
  python main.py --dry-run
  python main.py --yes         # destructive: skips the interactive prompt
  python main.py --help
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PAYLOAD = HERE / "multiplicity-purge.bat"

SAFE_DEFAULT = ["--status"]


def main(argv: list[str]) -> int:
    if sys.platform != "win32":
        print("multiplicity-purge targets Windows only: Multiplicity is Windows software.")
        print("There is nothing to clean on this platform.")
        return 2

    if not PAYLOAD.is_file():
        print(f"Payload not found next to this launcher: {PAYLOAD}")
        print("Expected multiplicity-purge.bat in the same directory (or skill folder).")
        return 2

    # Default to the read-only command: a bare `python main.py` must never purge.
    args = argv if argv else SAFE_DEFAULT

    cmd = ["cmd", "/c", str(PAYLOAD), *args]
    try:
        return subprocess.call(cmd, cwd=str(HERE))
    except KeyboardInterrupt:
        return 130
    except OSError as exc:
        print(f"Could not run the payload: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
