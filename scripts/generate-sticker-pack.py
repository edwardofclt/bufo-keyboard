#!/usr/bin/env python3
"""Generates the code-free sticker pack catalog from the Bufos/ directory.

Builds `BufoStickerPackExtension/Stickers.xcstickers/Sticker Pack.stickerpack/`
— one `<id>.sticker` folder (image copy + Contents.json) per bufo — so every
bufo appears in the iOS 17+ system sticker drawer with native drag-to-send.

The .stickerpack directory is generated at build time (pre-build phase on the
BufoStickerPackExtension target) and is gitignored; the Bufos/ directory is
the source of truth. Files over Apple's 500 KB per-sticker limit are skipped
with a warning. When both a .gif and a static variant exist for the same id,
the animated one wins (mirrors generate-bufo-index.py).
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
BUFOS_DIR = PROJECT_ROOT / "Bufos"
STICKERPACK = (
    PROJECT_ROOT
    / "BufoStickerPackExtension"
    / "Stickers.xcstickers"
    / "Sticker Pack.stickerpack"
)

# Apple: sticker image files must be PNG, APNG, GIF, or JPEG, at most 500 KB.
VALID_EXTS = {"png", "gif", "jpg", "jpeg"}
MAX_BYTES = 500_000

INFO = {"author": "xcode", "version": 1}


def select_files() -> dict[str, Path]:
    """Pick one file per bufo id, preferring animated gifs, skipping oversized."""
    by_id: dict[str, Path] = {}
    skipped_oversize = 0
    for path in sorted(BUFOS_DIR.iterdir()):
        if path.name.startswith("."):
            continue
        ext = path.suffix.lstrip(".").lower()
        if ext not in VALID_EXTS:
            continue
        if path.stat().st_size > MAX_BYTES:
            print(f"warning: skipping {path.name} (> {MAX_BYTES // 1000} KB sticker limit)")
            skipped_oversize += 1
            continue
        existing = by_id.get(path.stem)
        if existing and existing.suffix.lstrip(".").lower() == "gif":
            continue
        if existing and ext != "gif":
            continue
        by_id[path.stem] = path
    if skipped_oversize:
        print(f"skipped {skipped_oversize} oversized file(s)")
    return by_id


def write_json_if_changed(target: Path, payload: dict) -> None:
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    if target.exists() and target.read_text() == text:
        return
    target.write_text(text)


def copy_if_changed(src: Path, dst: Path) -> None:
    if dst.exists():
        s, d = src.stat(), dst.stat()
        if s.st_size == d.st_size and s.st_mtime <= d.st_mtime:
            return
    shutil.copy2(src, dst)


def main() -> int:
    if not BUFOS_DIR.is_dir():
        print(f"error: {BUFOS_DIR} not found", file=sys.stderr)
        return 1

    files = select_files()
    if not files:
        print("error: no sticker-eligible files found in Bufos/", file=sys.stderr)
        return 1

    STICKERPACK.mkdir(parents=True, exist_ok=True)

    expected_dirs = {f"{bufo_id}.sticker" for bufo_id in files}
    for bufo_id in sorted(files):
        src = files[bufo_id]
        sticker_dir = STICKERPACK / f"{bufo_id}.sticker"
        sticker_dir.mkdir(exist_ok=True)
        copy_if_changed(src, sticker_dir / src.name)
        write_json_if_changed(
            sticker_dir / "Contents.json",
            {"info": INFO, "properties": {"filename": src.name}},
        )
        # Remove stale image variants (e.g. a png replaced by a gif).
        for leftover in sticker_dir.iterdir():
            if leftover.name not in {src.name, "Contents.json"}:
                leftover.unlink()

    # Remove stickers whose source bufo no longer exists.
    for entry in STICKERPACK.iterdir():
        if entry.name == "Contents.json":
            continue
        if entry.is_dir() and entry.name not in expected_dirs:
            shutil.rmtree(entry)

    write_json_if_changed(
        STICKERPACK / "Contents.json",
        {
            "info": INFO,
            "properties": {"grid-size": "regular"},
            "stickers": [{"filename": f"{bufo_id}.sticker"} for bufo_id in sorted(files)],
        },
    )

    print(f"Sticker pack up to date ({len(files)} stickers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
