#!/usr/bin/env python3
"""Refresh the vendored Swift client after pnpm generate in its source repository."""
import pathlib
import shutil
import subprocess
import sys

source = pathlib.Path(sys.argv[1]).resolve()
root = pathlib.Path(__file__).resolve().parents[1]
target = root / "External/EmulatorContentClient"
for name in ("Sources", "Tests"):
    shutil.copytree(source / "clients/swift" / name, target / name, dirs_exist_ok=True)
for name in ("Package.swift",):
    shutil.copyfile(source / "clients/swift" / name, target / name)
shutil.copyfile(source / "LICENSE", target / "LICENSE")
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
(target / "UPSTREAM.md").write_text(
    "# EmulatorContentClient\n\n"
    f"Unmodified Swift package from Provenance-Emu/emulator-content-server, `clients/swift`, commit `{revision}`.\n\n"
    "Models are generated from the OpenAPI contract. SwiftPM cannot depend on a Git subdirectory, so this snapshot is vendored.\n"
    "Refresh: run `pnpm generate` there, then `python3 Scripts/update_content_client.py /path/to/emulator-content-server` here.\n"
    "Never edit GeneratedModels.swift here. MIT license is included.\n"
)
