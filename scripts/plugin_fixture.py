"""Helpers for disposable plugin fixtures used by repository test tooling."""

from __future__ import annotations

import shutil
from pathlib import Path


def copy_plugin_fixture(source: Path, destination: Path) -> Path:
    """Copy a plugin fixture without traversing its runtime state."""
    source = source.resolve()
    shutil.copytree(
        source,
        destination,
        ignore=lambda directory, names: {".oh-no"}
        if Path(directory) == source and ".oh-no" in names
        else set(),
    )
    return destination
