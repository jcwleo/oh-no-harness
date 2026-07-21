#!/usr/bin/env python3
"""Shared marketplace-source classification and origin parsing.

Both ``scripts/release`` and ``scripts/test-claude-plugin.sh`` use this single
primitive so their source handling cannot drift. Python 3 is already a
prerequisite for the harness.

Subcommands:
  classify-source <src>          local | remote | invalid  (exit 0)
  github-slug <url>              owner/repo (exit 0) or a generic error on
                                 stderr (exit 1); never echoes the raw URL, so
                                 credentials in a bad origin cannot leak.
  redact <src>                   src with any URL userinfo/token masked to ***
  config-identity <cfg> <home>   default | isolated  (symlink/`.`/`..`/trailing
                                 slash aware realpath identity; empty cfg is
                                 normalized to <home>/.claude)

"local" means the source can register the working-tree checkout (a real
directory, a file:// URL, or an absolute/relative/home path). "remote" is
reserved for validated credential-free GitHub forms only. Anything else is
"invalid" and must be treated as fail-closed by callers.
"""

from __future__ import annotations

import os
import re
import sys

# Conservative GitHub owner/repo shorthand (no scheme, exactly one slash).
_SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$")

# Validated, credential-free GitHub URL forms. The host is pinned to github.com,
# userinfo (if any) must be exactly ``git`` for SSH, and no port/query/fragment
# is permitted (the anchored patterns reject them by construction).
_REPO = r"([A-Za-z0-9][A-Za-z0-9._-]*)/([A-Za-z0-9][A-Za-z0-9._-]*?)"
_HTTPS_RE = re.compile(r"^https://github\.com/" + _REPO + r"(?:\.git)?/?$")
_SSH_RE = re.compile(r"^ssh://git@github\.com/" + _REPO + r"(?:\.git)?/?$")
_SCP_RE = re.compile(r"^git@github\.com:" + _REPO + r"(?:\.git)?$")


def github_slug(url: str):
    """Return ``owner/repo`` for a supported credential-free GitHub URL, else None."""
    url = url.strip()
    for rx in (_HTTPS_RE, _SSH_RE, _SCP_RE):
        m = rx.match(url)
        if m:
            return f"{m.group(1)}/{m.group(2)}"
    return None


def classify_source(src: str) -> str:
    src = src.strip()
    if not src:
        return "invalid"
    # Local first, so a directory that happens to look like a slug stays local.
    if os.path.isdir(src):
        return "local"
    if src.startswith("file://"):
        return "local"
    if src.startswith("~") or src.startswith("/") or src.startswith("./") or src.startswith("../"):
        return "local"
    # Remote: validated GitHub URL forms or a bare owner/repo shorthand.
    if github_slug(src) is not None:
        return "remote"
    if _SLUG_RE.match(src):
        return "remote"
    return "invalid"


def redact(src: str) -> str:
    """Mask ``scheme://userinfo@host...`` credentials to ``scheme://***@host...``."""
    m = re.match(r"^([A-Za-z][A-Za-z0-9+.-]*://)([^/@]+)@(.*)$", src)
    if m:
        return f"{m.group(1)}***@{m.group(3)}"
    return src


def config_identity(cfg: str, home: str) -> str:
    cfg = (cfg or "").strip()
    home = home or ""
    default_home = os.path.join(home, ".claude")
    effective = cfg if cfg else default_home
    if os.path.realpath(effective) == os.path.realpath(default_home):
        return "default"
    return "isolated"


def main(argv) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "usage: marketplace_source.py "
            "<classify-source|github-slug|redact|config-identity> ...\n"
        )
        return 2
    cmd = argv[1]
    if cmd == "classify-source":
        print(classify_source(argv[2] if len(argv) > 2 else ""))
        return 0
    if cmd == "github-slug":
        slug = github_slug(argv[2] if len(argv) > 2 else "")
        if slug is None:
            sys.stderr.write(
                "error: origin remote is not a supported credential-free GitHub "
                "URL. Use https://github.com/OWNER/REPO(.git), "
                "ssh://git@github.com/OWNER/REPO(.git), or "
                "git@github.com:OWNER/REPO(.git).\n"
            )
            return 1
        print(slug)
        return 0
    if cmd == "redact":
        print(redact(argv[2] if len(argv) > 2 else ""))
        return 0
    if cmd == "config-identity":
        print(config_identity(
            argv[2] if len(argv) > 2 else "",
            argv[3] if len(argv) > 3 else "",
        ))
        return 0
    sys.stderr.write(f"unknown subcommand: {cmd}\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
