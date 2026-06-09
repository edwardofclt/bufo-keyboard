# Project notes

## Xcode project generation

The `.xcodeproj` is generated from `project.yml` by xcodegen. Run `xcodegen generate` after editing `project.yml`. Xcode Cloud regenerates it from scratch on every build via `ci_scripts/ci_post_clone.sh`, so the committed `.xcodeproj` is mostly for local development convenience.

## Sticker pack extension — one Messages extension per app

`BufoStickerPackExtension` is a **code-free sticker pack** (`app-extension.messages-sticker-pack`, `NSExtensionPrincipalClass: StickerBrowserViewController` with no binary). It replaced the old `BufoMessagesExtension` iMessage app because:

- An iOS app may contain only **one** Messages extension — App Store upload fails with "Multiple message payload provider extensions found in app but only one is allowed".
- Only code-free sticker packs appear in the iOS 17+ system sticker drawer; iMessage apps are relegated to the "More" list.
- There is no real `com.apple.messages.usersticker-pack-extension` extension point; the only Messages extension point is `com.apple.message-payload-provider`.

It reuses the registered `com.edwardofclt.bufoKeyboard.messages` bundle ID (the `.stickers` ID was never registered in the portal).

`Stickers.xcstickers/Sticker Pack.stickerpack/` is **build-generated and gitignored** — a pre-build phase runs `scripts/generate-sticker-pack.py`, which builds one `.sticker` per file in `Bufos/` (skipping files over Apple's 500 KB sticker limit, preferring `.gif` over a same-name static image). Don't add stickers to the catalog by hand; add files to `Bufos/`.

## iMessage app icon catalog — do not hand-edit Contents.json

`BufoStickerPackExtension/Stickers.xcstickers/iMessage App Icon.stickersiconset/Contents.json` is **build-generated**. The `BufoStickerPackExtension` target has a pre-build phase that runs `scripts/write-imessage-iconset-json.py`, which overwrites this file from a Python manifest on every build.

**The manifest is the source of truth.** To add or change an icon, edit `scripts/write-imessage-iconset-json.py`. Do not edit `Contents.json` directly — your changes will be overwritten on the next build.

### Why this exists

App Store Connect's validator (error **ITMS-90649**) rejects an iMessage app archive unless:

- the `60x45` entries declare `"idiom": "iphone"`
- the `67x50` and `74x55` entries declare `"idiom": "ipad"`

Xcode's asset catalog editor silently normalizes these to `"idiom": "universal"` (and adds `"platform": "ios"`) when it saves the file, which makes the icons ship without being recognized as iMessage app icons — even though `actool` packs the bytes into the `.car`. This has regressed twice in the project's short history (commits `290b1dd`, `bb905da`). The pre-build phase makes a third regression impossible.

`scripts/generate-icons.swift` (which renders the icon PNGs from a source image) no longer writes `Contents.json` for this reason; the build phase is the sole writer.

## App Group identifier

The shared App Group is `group.com.edwardofclt.bufoKeyboard`. It's declared in three places that must stay in sync:

- `BufoKeyboard/BufoKeyboard.entitlements`
- `BufoKeyboardExtension/BufoKeyboardExtension.entitlements`
- `Shared/RecentsStore.swift` (`appGroupID` constant)

If the identifier ever changes, all three locations must be updated, AND the new group must be registered under team `6SHL6PHRS9` in the Apple Developer portal and associated with the App IDs that use it (`com.edwardofclt.bufoKeyboard`, `.keyboard`). Otherwise `xcodebuild -exportArchive` fails with "Automatic signing cannot update bundle identifier". (`.messages` is now the code-free sticker pack and carries no entitlements.)

## Bundle ID prefix

The `bundleIdPrefix: fun.bufo` line at the top of `project.yml` is inert — every target sets its own explicit `PRODUCT_BUNDLE_IDENTIFIER: com.edwardofclt.bufoKeyboard.*`. The stale prefix has caused confusion in the past (it was the source of the original `group.fun.bufo.BufoKeyboard` App Group ID that didn't match anything in App Store Connect).
