#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 bu56co-del and contributors.
"""Collect notices from the exact resolved dependencies into an app bundle."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def go_environment():
    env = dict(os.environ)
    env.update(GOTOOLCHAIN="local", GOPATH=str(ROOT / "macos/.toolchain/gopath"),
               GOMODCACHE=str(ROOT / ".gomod"), GOCACHE=str(ROOT / ".gocache"))
    local = ROOT / "macos/.toolchain/go/bin/go"
    go = env.get("PAWLY_GO") or (str(local) if local.is_file() else shutil.which("go"))
    if not go:
        raise RuntimeError("Install Go or set PAWLY_GO to its executable")
    return go, env


def json_objects(text):
    decoder = json.JSONDecoder()
    while text.strip():
        value, end = decoder.raw_decode(text.lstrip())
        yield value
        text = text.lstrip()[end:]


def modules():
    go, env = go_environment()
    # Fetch source as well as metadata, including transitive build/test modules.
    output = subprocess.check_output([go, "mod", "download", "-json", "all"], cwd=ROOT, env=env, text=True)
    return list(json_objects(output))


def notices(source, output, prefix):
    found = []
    for path in sorted(source.iterdir()):
        if path.is_file() and re.match(r"^(LICENSE|LICENCE|COPYING|NOTICE|PATENTS)([.-]|$)", path.name, re.I):
            name = prefix + "--" + path.name
            shutil.copyfile(path, output / name)
            found.append(name)
    if not found:
        # Some upstream releases put their only licensing notice in README.
        for path in sorted(source.glob("README*")):
            if path.is_file() and re.search(r"^#+\s+Licen[cs]e\b", path.read_text(), re.M | re.I):
                name = prefix + "--" + path.name
                shutil.copyfile(path, output / name)
                found.append(name)
        if not found:
            raise RuntimeError("No license notice found for " + prefix)
    return found


def collect(output):
    output.mkdir(parents=True, exist_ok=True)
    index = []
    for module in modules():
        prefix = re.sub(r"[^A-Za-z0-9._-]", "_", module["Path"] + "@" + module["Version"])
        files = notices(Path(module["Dir"]), output, prefix)
        index.append({"component": module["Path"], "version": module["Version"], "files": files})
    pins = json.loads((ROOT / "macos/Package.resolved").read_text())["pins"]
    for pin in pins:
        name = "SwiftTerm" if pin["identity"] == "swiftterm" else pin["identity"]
        checkout = ROOT / "macos/.build/checkouts" / name
        revision = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        if revision != pin["state"]["revision"]:
            raise RuntimeError("Dependency revision mismatch: " + name)
        files = notices(checkout, output, name)
        index.append({"component": name, "version": pin["state"]["version"], "revision": revision, "files": files})
    go, env = go_environment()
    goroot = Path(subprocess.check_output([go, "env", "GOROOT"], cwd=ROOT, env=env, text=True).strip())
    files = notices(goroot, output, "Go")
    index.append({"component": "Go", "files": files})
    (output / "index.json").write_text(json.dumps(index, indent=2) + "\n")
    print("Bundled notices for", len(index), "components")


if __name__ == "__main__":
    collect(Path(sys.argv[1]))
