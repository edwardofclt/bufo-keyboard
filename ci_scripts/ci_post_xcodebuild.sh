#!/bin/bash
# Extract screenshot attachments from the Xcode Cloud test result bundle into
# standalone PNG files so they're easier to grab from the Xcode Cloud UI than
# digging into the .xcresult bundle.
#
# Runs after every xcodebuild action. Quietly no-ops on workflows where there's
# no result bundle (e.g. clone-only).
#
# Output:
#   - $CI_ARCHIVE_PATH/Screenshots/*.png  (during archive workflows)
#   - $CI_DERIVED_DATA_PATH/Screenshots/*.png  (otherwise)

set -eo pipefail

if [ -z "${CI_RESULT_BUNDLE_PATH:-}" ] || [ ! -d "$CI_RESULT_BUNDLE_PATH" ]; then
  echo "No xcresult bundle at \$CI_RESULT_BUNDLE_PATH; nothing to extract."
  exit 0
fi

if [ -n "${CI_ARCHIVE_PATH:-}" ] && [ -d "$CI_ARCHIVE_PATH" ]; then
  OUT="$CI_ARCHIVE_PATH/Screenshots"
elif [ -n "${CI_DERIVED_DATA_PATH:-}" ]; then
  OUT="$CI_DERIVED_DATA_PATH/Screenshots"
else
  OUT="$(dirname "$CI_RESULT_BUNDLE_PATH")/Screenshots"
fi
mkdir -p "$OUT"

echo "Extracting screenshots from $CI_RESULT_BUNDLE_PATH -> $OUT"

CI_RESULT_BUNDLE_PATH="$CI_RESULT_BUNDLE_PATH" OUT="$OUT" python3 <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

bundle = os.environ["CI_RESULT_BUNDLE_PATH"]
out = Path(os.environ["OUT"])

result = subprocess.run(
    ["xcrun", "xcresulttool", "get", "--legacy", "--format", "json", "--path", bundle],
    capture_output=True, text=True, check=True,
)
data = json.loads(result.stdout)

count = 0

def walk(node):
    global count
    if isinstance(node, dict):
        type_name = node.get("_type", {}).get("_name")
        if type_name == "ActionTestAttachment":
            name = node.get("name", {}).get("_value", "")
            ref_obj = node.get("payloadRef", {})
            ref = ref_obj.get("id", {}).get("_value") if isinstance(ref_obj, dict) else None
            if name.startswith("snapshot_") and ref:
                # Try to namespace by the simulator/device that produced it.
                # The attachment's parent test summary has the device info, but
                # walking up is awkward here; fastlane handles its own naming.
                clean = name[len("snapshot_"):]
                target = out / f"{clean}.png"
                # Avoid clobbering duplicates from multiple device runs.
                i = 1
                while target.exists():
                    target = out / f"{clean}-{i}.png"
                    i += 1
                subprocess.run(
                    ["xcrun", "xcresulttool", "get", "--legacy",
                     "--path", bundle, "--id", ref,
                     "--output-path", str(target)],
                    check=True,
                )
                count += 1
                print(f"  wrote {target.name}")
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)

walk(data)
print(f"Extracted {count} screenshot(s).")
PY

ls -la "$OUT"
