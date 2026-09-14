#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 bu56co-del and contributors.
"""Package a committed app with its exact project and dependency sources."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tarfile
import tempfile

from collect_pawly_licenses import ROOT, modules


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def package(version, app):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Use a three-part release version, such as 1.2.0")
    if git("status", "--porcelain"):
        raise RuntimeError("Commit all release source changes before packaging")
    commit = git("rev-parse", "HEAD")
    resources = app / "Contents/Resources"
    metadata = json.loads((resources / "Pawly-build.json").read_text())
    if (metadata["source_commit"] != commit or metadata["source_dirty"]
            or metadata["configuration"] != "release"):
        raise RuntimeError("The app must be a clean release build of the current commit")
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    release_parts = [int(part) for part in version.split(".")]
    app_parts = [int(part) for part in info["CFBundleShortVersionString"].split(".")]
    if release_parts != app_parts + [0] * (3 - len(app_parts)):
        raise RuntimeError("The app version does not match the release")
    for relative in ("Contents/MacOS/Pawly", "Contents/Resources/engine/bin/analyze-go",
                     "Contents/Resources/engine/bin/status-go"):
        arch = subprocess.check_output(["lipo", "-archs", str(app / relative)], text=True).strip()
        if arch != "arm64":
            raise RuntimeError("This release recipe expects Apple Silicon binaries: " + relative)
    for name in ("LICENSE", "NOTICE.md", "UPSTREAM-TRADEMARK.md", "Licenses/index.json"):
        if not (resources / name).is_file():
            raise RuntimeError("Missing notice: " + name)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)

    output = ROOT / "dist/releases" / ("pawly-v" + version)
    output.mkdir(parents=True, exist_ok=True)
    names = [f"Pawly-{version}-macos-arm64.zip", f"Pawly-{version}-source.tar.gz", "SHA256SUMS"]
    if any((output / name).exists() for name in names):
        raise RuntimeError("Release assets already exist; preserve them and choose an empty output directory")
    source_root = "Pawly-" + version
    epoch = int(git("show", "-s", "--format=%ct", commit))

    with tempfile.TemporaryDirectory(prefix="pawly-package-", dir=ROOT / "dist") as temporary:
        scratch = Path(temporary)
        dependencies = scratch / "dependencies"
        dependencies.mkdir()
        entries = []
        for pin in json.loads((ROOT / "macos/Package.resolved").read_text())["pins"]:
            name = "SwiftTerm" if pin["identity"] == "swiftterm" else pin["identity"]
            checkout = ROOT / "macos/.build/checkouts" / name
            revision = pin["state"]["revision"]
            actual = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
            if actual != revision:
                raise RuntimeError("Swift dependency revision mismatch: " + name)
            archive = dependencies / (name + "-" + pin["state"]["version"] + ".tar.gz")
            subprocess.run(["git", "-C", str(checkout), "archive", "--format=tar.gz",
                            "--prefix=" + name + "/", "-o", str(archive), revision], check=True)
            entries.append((name, revision, archive.name, sha256(archive)))
        for module in modules():
            name = re.sub(r"[^A-Za-z0-9._-]", "_", module["Path"] + "@" + module["Version"]) + ".zip"
            archive = dependencies / name
            if archive.exists():
                raise RuntimeError("Dependency filename collision: " + name)
            shutil.copyfile(module["Zip"], archive)
            entries.append((module["Path"], module["Version"], name, sha256(archive)))
        index = scratch / "DEPENDENCY_SOURCES.md"
        index.write_text("# Corresponding dependency sources\n\n"
                         "Project commit: `" + commit + "`\n\n"
                         "These archives contain the pinned Swift packages and Go modules. "
                         "Each retains its upstream license notices. See docs/pawly/BUILDING.md "
                         "for the build recipe and required system tools.\n\n"
                         "| Component | Version or revision | Archive in dependencies/ | SHA-256 |\n"
                         "| --- | --- | --- | --- |\n" + "".join(
                             "| " + " | ".join(row) + " |\n" for row in entries))
        project = scratch / "project.tar"
        subprocess.run(["git", "-C", str(ROOT), "archive", "--format=tar",
                        "--prefix=" + source_root + "/", "-o", str(project), commit], check=True)

        def metadata_filter(member):
            member.uid = member.gid = 0
            member.uname = member.gname = ""
            member.mtime = epoch
            return member

        with tarfile.open(scratch / names[1], "w:gz") as bundle:
            with tarfile.open(project) as source:
                for member in source:
                    stream = source.extractfile(member) if member.isfile() else None
                    bundle.addfile(member, stream)
                    if stream:
                        stream.close()
            bundle.add(dependencies, arcname=source_root + "/dependencies", filter=metadata_filter)
            bundle.add(index, arcname=source_root + "/DEPENDENCY_SOURCES.md", filter=metadata_filter)
        subprocess.run(["ditto", "-c", "-k", "--norsrc", "--keepParent", str(app),
                        str(scratch / names[0])], check=True)
        (scratch / names[2]).write_text("".join(sha256(scratch / name) + "  " + name + "\n" for name in names[:2]))
        for name in names:
            shutil.move(str(scratch / name), output / name)
    print("Packaged commit", commit, "with", len(entries), "dependency source archives")
    print(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--app", required=True, type=Path)
    args = parser.parse_args()
    package(args.version, args.app.resolve())
