# SPDX-License-Identifier: BSD-3-Clause
"""Compare downloaded NCCL release assets with an independent source build."""

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    """Hash one regular file without loading the archive into memory."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_release(directory: Path, build_directory: Path, source_commit: str) -> None:
    """Reject missing, extra, symbolic-link or substituted publication assets."""
    bundle = build_directory / "bundle"
    manifest = json.loads((bundle / "manifest.json").read_text())
    if manifest["source"]["commit"] != source_commit:
        raise ValueError("build source commit mismatch")
    if manifest["schema"] != "local-inference-nccl-cu134-release/v1":
        raise ValueError("build manifest schema mismatch")
    wheel = manifest["wheel"]["file"]
    if not (
        wheel.startswith("local_inference_nccl_cu134-")
        and wheel.endswith(".whl")
        and Path(wheel).name == wheel
    ):
        raise ValueError("invalid wheel filename")
    archive = f"local-inference-nccl-cu134-{source_commit}.tar.zst"
    reference = {
        name: bundle / name
        for name in ("manifest.json", "requirements-github.txt", "SHA256SUMS")
    }
    reference[wheel] = bundle / "wheels" / wheel
    reference[archive] = build_directory / archive
    reference[f"{archive}.sha256"] = build_directory / f"{archive}.sha256"
    if {path.name for path in directory.iterdir()} != set(reference):
        raise ValueError("release asset set mismatch")
    for name, expected in reference.items():
        actual = directory / name
        if any(not path.is_file() or path.is_symlink() for path in (actual, expected)):
            raise ValueError(f"release asset must be a regular file: {name}")
        if sha256(actual) != sha256(expected):
            raise ValueError(f"independent build mismatch: {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--build-directory", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    verify_release(args.directory, args.build_directory, args.source_commit)
