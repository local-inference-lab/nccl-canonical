"""Paths and identity for the source-addressed NCCL runtime package."""

from __future__ import annotations

import argparse
from importlib.resources import files
from pathlib import Path

from ._build_meta import NCCL_VERSION, SOURCE_COMMIT


def library_path() -> Path:
    """Return the absolute path to the packaged NCCL shared library."""

    return Path(str(files(__package__) / "lib" / f"libnccl.so.{NCCL_VERSION}"))


def include_path() -> Path:
    """Return the absolute path to the packaged NCCL headers."""

    return Path(str(files(__package__) / "include"))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print paths from the installed LIL NCCL runtime wheel."
    )
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--include", action="store_true")
    selection.add_argument("--source-commit", action="store_true")
    args = parser.parse_args()
    if args.include:
        print(include_path())
    elif args.source_commit:
        print(SOURCE_COMMIT)
    else:
        print(library_path())


__all__ = ["NCCL_VERSION", "SOURCE_COMMIT", "include_path", "library_path"]
