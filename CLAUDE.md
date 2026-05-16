# Project notes

## Xcode project generation

The `.xcodeproj` is generated from `project.yml` by xcodegen. Run `xcodegen generate` after editing `project.yml`. Xcode Cloud regenerates it from scratch on every build via `ci_scripts/ci_post_clone.sh`, so the committed `.xcodeproj` is mostly for local development convenience.

## iMessage app icon catalog — do not hand-edit Contents.json

`BufoMessagesExtension/Assets.xcassets/iMessage App Icon.stickersiconset/Contents.json` is **build-generated**. The `BufoMessagesExtension` target has a pre-build phase that runs `scripts/write-imessage-iconset-json.py`, which overwrites this file from a Python manifest on every build.

**The manifest is the source of truth.** To add or change an icon, edit `scripts/write-imessage-iconset-json.py`. Do not edit `Contents.json` directly — your changes will be overwritten on the next build.

### Why this exists

App Store Connect's validator (error **ITMS-90649**) rejects an iMessage app archive unless:

- the `60x45` entries declare `"idiom": "iphone"`
- the `67x50` and `74x55` entries declare `"idiom": "ipad"`

Xcode's asset catalog editor silently normalizes these to `"idiom": "universal"` (and adds `"platform": "ios"`) when it saves the file, which makes the icons ship without being recognized as iMessage app icons — even though `actool` packs the bytes into the `.car`. This has regressed twice in the project's short history (commits `290b1dd`, `bb905da`). The pre-build phase makes a third regression impossible.

`scripts/generate-icons.swift` (which renders the icon PNGs from a source image) no longer writes `Contents.json` for this reason; the build phase is the sole writer.

## App Group identifier

The shared App Group is `group.com.edwardofclt.bufoKeyboard`. It's declared in four places that must stay in sync:

- `BufoKeyboard/BufoKeyboard.entitlements`
- `BufoKeyboardExtension/BufoKeyboardExtension.entitlements`
- `BufoMessagesExtension/BufoMessagesExtension.entitlements`
- `Shared/RecentsStore.swift` (`appGroupID` constant)

If the identifier ever changes, all four locations must be updated, AND the new group must be registered under team `6SHL6PHRS9` in the Apple Developer portal and associated with each of the three App IDs (`com.edwardofclt.bufoKeyboard`, `.keyboard`, `.messages`). Otherwise `xcodebuild -exportArchive` fails with "Automatic signing cannot update bundle identifier".

## Bundle ID prefix

The `bundleIdPrefix: fun.bufo` line at the top of `project.yml` is inert — every target sets its own explicit `PRODUCT_BUNDLE_IDENTIFIER: com.edwardofclt.bufoKeyboard.*`. The stale prefix has caused confusion in the past (it was the source of the original `group.fun.bufo.BufoKeyboard` App Group ID that didn't match anything in App Store Connect).
