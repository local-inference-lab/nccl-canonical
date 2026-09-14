# SPDX-License-Identifier: BSD-3-Clause
"""Release reuse must preserve the complete independent build."""

import json
import shutil

import pytest

from ci.lil_wheels.verify_release_assets import verify_release

COMMIT = "1" * 40
WHEEL = "local_inference_nccl_cu134-2.31.2-py3-none-linux_x86_64.whl"
ARCHIVE = f"local-inference-nccl-cu134-{COMMIT}.tar.zst"
ASSETS = [
    WHEEL,
    "manifest.json",
    "requirements-github.txt",
    "SHA256SUMS",
    ARCHIVE,
    f"{ARCHIVE}.sha256",
]


@pytest.fixture
def release(tmp_path):
    build = tmp_path / "build"
    bundle = build / "bundle"
    (bundle / "wheels").mkdir(parents=True)
    directory = tmp_path / "release"
    directory.mkdir()
    for name in ASSETS:
        parent = (
            bundle / "wheels"
            if name == WHEEL
            else build
            if name.startswith("local-inference-")
            else bundle
        )
        (parent / name).write_text(name)
        shutil.copyfile(parent / name, directory / name)
    manifest = json.dumps(
        {
            "schema": "local-inference-nccl-cu134-release/v1",
            "source": {"commit": COMMIT},
            "wheel": {"file": WHEEL},
        }
    )
    (bundle / "manifest.json").write_text(manifest)
    (directory / "manifest.json").write_text(manifest)
    return directory, build


def test_complete_release(release):
    verify_release(*release, COMMIT)


@pytest.mark.parametrize("name", ASSETS)
@pytest.mark.parametrize("mutation", ["missing", "modified", "symlink"])
def test_rejects_changed_asset(release, name, mutation):
    directory, build = release
    path = directory / name
    if mutation == "missing":
        path.unlink()
    elif mutation == "modified":
        path.write_text("substituted")
    else:
        path.unlink()
        path.symlink_to(build / "bundle" / "manifest.json")
    with pytest.raises(ValueError):
        verify_release(directory, build, COMMIT)


def test_rejects_extra_asset(release):
    directory, build = release
    (directory / "extra").mkdir()
    with pytest.raises(ValueError, match="asset set"):
        verify_release(directory, build, COMMIT)
