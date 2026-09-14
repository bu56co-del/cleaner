#!/usr/bin/env python3
"""Verify the selected-file identity guard. Restore the source even on failure."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
source = root / "macos/Sources/PawlyCore/PathPolicy.swift"
original = source.read_bytes()
needle = b"current == item.identity"
assert original.count(needle) == 1
command = ["swift", "test", "--package-path", str(root / "macos")]
mutant_result = None
try:
    source.write_bytes(original.replace(needle, b"current == current"))
    mutant_result = subprocess.run(
        command + ["--filter", "testChangedFileInvalidatesSelectionWithoutWaitingForClockTick"],
        cwd=root, capture_output=True, text=True, timeout=120
    )
finally:
    source.write_bytes(original)
assert mutant_result is not None
assert mutant_result.returncode != 0, "Mutation survived: identity test did not detect the missing guard"
assert "XCTAssertFalse failed" in mutant_result.stdout, mutant_result.stdout + mutant_result.stderr
print("MUTATION DETECTED: removing selected-file identity enforcement failed the behavior test.", flush=True)
result = subprocess.run(command, cwd=root, timeout=120)
assert source.read_bytes() == original
raise SystemExit(result.returncode)
