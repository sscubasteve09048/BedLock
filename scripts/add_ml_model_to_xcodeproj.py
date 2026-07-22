#!/usr/bin/env python3
"""
add_ml_model_to_xcodeproj.py

Adds a trained BedMadeClassifier.mlpackage into the BedLock Xcode project as
a bundle resource, entirely by editing project.pbxproj as text — no Xcode
required. Xcode's build system automatically compiles any .mlpackage placed
in the "Copy Bundle Resources" build phase into a .mlmodelc at build time,
which is exactly what CoreMLBedVerificationService.swift looks for.

Usage:
    python3 scripts/add_ml_model_to_xcodeproj.py path/to/BedMadeClassifier.mlpackage

Run from anywhere; it locates the repo root relative to this script's location.
"""
import re
import sys
import shutil
import uuid
import pathlib


def uid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 add_ml_model_to_xcodeproj.py path/to/BedMadeClassifier.mlpackage")
        sys.exit(1)

    src = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not src.exists():
        print(f"Error: {src} not found")
        sys.exit(1)
    if src.suffix != ".mlpackage":
        print(f"Error: expected a .mlpackage folder, got {src.name}")
        print("(Core ML packages are folders, not single files — make sure you passed the .mlpackage directory itself, not a file inside it.)")
        sys.exit(1)

    repo_root = pathlib.Path(__file__).resolve().parent.parent
    pbxproj_path = repo_root / "BedLock.xcodeproj" / "project.pbxproj"
    if not pbxproj_path.exists():
        print(f"Error: couldn't find {pbxproj_path} — run this from inside the repo (or keep this script in its original scripts/ location).")
        sys.exit(1)

    resources_dir = repo_root / "BedLock" / "Resources"
    model_name = src.name
    dest = resources_dir / model_name

    # Copy (overwriting any previous version of the model).
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest)
    print(f"Copied {model_name} -> {dest.relative_to(repo_root)}")

    content = pbxproj_path.read_text()
    original_content = content

    file_ref_id = uid()
    build_file_id = uid()

    # Idempotency: if a reference to this filename already exists (e.g. from
    # a previous run), bail out with a clear message rather than duplicating it.
    if f'/* {model_name} */' in content:
        print(f"'{model_name}' is already referenced in project.pbxproj — nothing to add.")
        print("If you're replacing the model with new training data, this is expected: the file on disk was overwritten above and Xcode will pick up the new contents automatically.")
        sys.exit(0)

    # 1. PBXBuildFile entry (registers it in the Resources build phase's file list)
    build_file_line = (
        f'\t\t{build_file_id} /* {model_name} in Resources */ = '
        f'{{isa = PBXBuildFile; fileRef = {file_ref_id} /* {model_name} */; }};\n'
    )
    content, n = re.subn(
        r'(/\* End PBXBuildFile section \*/)',
        build_file_line + r'\1',
        content,
        count=1,
    )
    if n != 1:
        print("Error: couldn't find PBXBuildFile section marker — aborting without changes.")
        sys.exit(1)

    # 2. PBXFileReference entry
    file_ref_line = (
        f'\t\t{file_ref_id} /* {model_name} */ = {{isa = PBXFileReference; '
        f'lastKnownFileType = folder.mlpackage; path = {model_name}; sourceTree = "<group>"; }};\n'
    )
    content, n = re.subn(
        r'(/\* End PBXFileReference section \*/)',
        file_ref_line + r'\1',
        content,
        count=1,
    )
    if n != 1:
        print("Error: couldn't find PBXFileReference section marker — aborting without changes.")
        sys.exit(1)

    # 3. Add to the Resources group's children (next to Assets.xcassets)
    resources_group_pattern = re.compile(
        r'(children = \(\n(?:\t+[0-9A-F]+ /\* [^\n]+\*/,\n)*)(\t+\);\n\t+path = Resources;)'
    )
    match = resources_group_pattern.search(content)
    if not match:
        print("Error: couldn't locate the Resources group's children array — aborting without changes.")
        sys.exit(1)
    content = (
        content[:match.end(1)]
        + f'\t\t\t\t{file_ref_id} /* {model_name} */,\n'
        + content[match.end(1):]
    )

    # 4. Add to the app target's Resources build phase file list
    resources_phase_pattern = re.compile(
        r'(isa = PBXResourcesBuildPhase;\n\t+buildActionMask = 2147483647;\n\t+files = \(\n'
        r'(?:\t+[0-9A-F]+ /\* [^\n]+\*/,\n)*)(\t+\);)'
    )
    match2 = resources_phase_pattern.search(content)
    if not match2:
        print("Error: couldn't locate the Resources build phase's file list — aborting without changes.")
        sys.exit(1)
    content = (
        content[:match2.end(1)]
        + f'\t\t\t\t{build_file_id} /* {model_name} in Resources */,\n'
        + content[match2.end(1):]
    )

    # Sanity check before writing: brace/paren balance should be unchanged in
    # kind (we added 2 new lines each ending in a value, no new braces/parens
    # beyond what was already balanced) — if this ever goes wrong, refuse to
    # write a possibly-corrupt project file.
    if content.count("{") != content.count("}") or content.count("(") != content.count(")"):
        print("Error: resulting project.pbxproj would be unbalanced — aborting without changes.")
        pbxproj_path.write_text(original_content)  # no-op, but explicit
        sys.exit(1)

    pbxproj_path.write_text(content)
    print(f"Registered {model_name} in project.pbxproj.")
    print()
    print("Next steps:")
    print("  git add -A")
    print('  git commit -m "Add custom-trained bed classifier model"')
    print("  git push")


if __name__ == "__main__":
    main()
