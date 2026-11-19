"""Builds release/LeRep-<version>.zip from the committed addon files (from leprofit's).

The version comes from ## Version in LeRep/LeRep.toc. Only files tracked by git under LeRep/ go in,
so the zip matches what's committed (Build.lua is the empty one: releases carry no build stamp).
The zip holds the LeRep folder at its top level, as players unzip it into AddOns.
Run from anywhere: python3 tools/make_release.py
"""
import pathlib
import re
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def version_of(folder):
    toc = (ROOT / folder / f"{folder}.toc").read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not match:
        sys.exit(f"No ## Version in {folder}/{folder}.toc")
    return match.group(1)


def main():
    folders = ["LeRep"]
    version = version_of("LeRep")
    if subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain", "--", *folders], text=True).strip():
        sys.exit("LeRep/ has uncommitted changes: commit them first, so the zip matches a commit.")
    files = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--", *folders], text=True).split()
    out = ROOT / "release" / f"LeRep-{version}.zip"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name in sorted(files):
            z.write(ROOT / name, name)
    print(f"{out.relative_to(ROOT)}: {', '.join(folders)}; {len(files)} files, {out.stat().st_size} bytes")


if __name__ == "__main__":
    main()
