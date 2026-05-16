#!/usr/bin/env python3
"""Regenerate the iMessage app icon set's Contents.json from a canonical manifest.

Xcode's asset catalog editor silently rewrites Contents.json to use
`"idiom": "universal"` for the per-device iMessage icon entries when it
normalizes them on save. App Store Connect's validator (ITMS-90649) matches
on explicit `iphone` / `ipad` idioms for the 60x45, 67x50, and 74x55 entries,
so the "universal" form ships without those icons being recognized as iMessage
app icons. Running this script as a pre-build step makes the regression
impossible — every build overwrites Contents.json from the manifest below.

If you need to add or change an icon, edit the manifest in this file. Do not
edit Contents.json by hand; your changes will be overwritten on the next build.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ICONSET = REPO_ROOT / "BufoMessagesExtension" / "Assets.xcassets" / "iMessage App Icon.stickersiconset"

IMAGES = [
    {"filename": "icon-27x20@2x.png",   "idiom": "universal",     "platform": "ios", "scale": "2x", "size": "27x20"},
    {"filename": "icon-27x20@3x.png",   "idiom": "universal",     "platform": "ios", "scale": "3x", "size": "27x20"},
    {"filename": "icon-32x24@2x.png",   "idiom": "universal",     "platform": "ios", "scale": "2x", "size": "32x24"},
    {"filename": "icon-32x24@3x.png",   "idiom": "universal",     "platform": "ios", "scale": "3x", "size": "32x24"},
    {"filename": "icon-60x45@2x.png",   "idiom": "iphone",                            "scale": "2x", "size": "60x45"},
    {"filename": "icon-60x45@3x.png",   "idiom": "iphone",                            "scale": "3x", "size": "60x45"},
    {"filename": "icon-67x50@2x.png",   "idiom": "ipad",                              "scale": "2x", "size": "67x50"},
    {"filename": "icon-74x55@2x.png",   "idiom": "ipad",                              "scale": "2x", "size": "74x55"},
    {"filename": "icon-1024x768.png",   "idiom": "ios-marketing", "platform": "ios", "scale": "1x", "size": "1024x768"},
]

CONTENTS = {
    "images": IMAGES,
    "info": {"author": "xcode", "version": 1},
}


def main() -> int:
    if not ICONSET.is_dir():
        print(f"error: iconset directory not found: {ICONSET}", file=sys.stderr)
        return 1
    target = ICONSET / "Contents.json"
    new_text = json.dumps(CONTENTS, indent=2) + "\n"
    if target.exists() and target.read_text() == new_text:
        return 0
    target.write_text(new_text)
    print(f"regenerated {target.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
