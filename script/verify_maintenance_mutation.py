#!/usr/bin/env python3
"""Deliberately break two maintenance boundaries, verify red, restore and verify green.

Only generated test homes are used. The selected-pass test mocks logging,
authorization and health probes before calling the mutated function.
"""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
bats = shutil.which("bats") or root / "macos/.toolchain/bats-core/bin/bats"
environment = {**os.environ, "MOLE_TEST_NO_AUTH": "1"}
cases = [
    (
        root / "bin/optimize.sh",
        b'optimize_catalog_index_for "$selected_action" > /dev/null',
        b":",
        [str(bats), "tests/pawly_maintenance.bats", "--filter", "validates every task"],
        "not ok 1",
    ),
    (
        root / "lib/manage/whitelist.sh",
        b' && "${MOLE_DRY_RUN:-0}" != "1"',
        b"",
        ["swift", "test", "--package-path", "macos", "--scratch-path", "macos/.build", "--skip-build",
         "--filter", "MaintenanceTests.testCatalogAndPreviewHonorLegacyExclusionsWithoutWritingConfig"],
        "XCTAssertFalse failed",
    ),
]
for source, needle, replacement, command, expected_failure in cases:
    original = source.read_bytes()
    assert original.count(needle) == 1, f"Mutation anchor drifted: {source}"
    try:
        source.write_bytes(original.replace(needle, replacement))
        red = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True, timeout=90)
    finally:
        source.write_bytes(original)
    assert red.returncode != 0 and expected_failure in red.stdout + red.stderr, red.stdout + red.stderr
    green = subprocess.run(command, cwd=root, env=environment, capture_output=True, text=True, timeout=90)
    assert green.returncode == 0, green.stdout + green.stderr
    assert source.read_bytes() == original
    print(f"RED -> RESTORED -> GREEN: {source.relative_to(root)}", flush=True)
