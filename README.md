# Bufo Keyboard

An iOS app + custom keyboard extension that lets you drop a
[bufo](https://github.com/tfritzy/bufo.fun) into any app as a sticker / image
attachment.

The keyboard has 1300+ bufos searchable by name and tag. Tap a bufo and it's
copied to your clipboard; long-press the message field in Messages, Mail,
Slack, WhatsApp, Discord, Telegram, etc. and tap **Paste** to send it.

## How it works

iOS custom keyboards can only insert *text* into the host app's text field —
they cannot insert image attachments directly. Bufo Keyboard works around this
the same way every sticker keyboard does: tapping a bufo writes the image to
the system pasteboard (under both `public.png` / `com.compuserve.gif` UTIs),
then the user pastes. Apps that accept rich pasted content treat the image as
an attachment.

Writing to the system pasteboard from a keyboard extension requires **Allow
Full Access** in Settings → General → Keyboard → Keyboards → Bufos. The
extension only reads / writes the pasteboard; it doesn't transmit anything.

## Build

You need Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
make            # generates BufoKeyboard.xcodeproj
make open       # generates and opens in Xcode
```

Then in Xcode: pick a development team in the **Signing & Capabilities** tab
for both `BufoKeyboard` and `BufoKeyboardExtension`, choose a simulator or
device, and Run.

To enable the keyboard once the app is installed:

1. Open the **Bufo Keyboard** app once.
2. Settings → General → Keyboard → Keyboards → **Add New Keyboard…** → Bufos.
3. Tap **Bufos** in the keyboards list and toggle **Allow Full Access**.
4. In any app, tap and hold the 🌐 globe key on the keyboard until **Bufos**
   appears.

## Project layout

```
BufoKeyboard/             Main SwiftUI app — onboarding + bufo browser
BufoKeyboardExtension/    Custom keyboard extension (UIInputViewController)
Shared/                   Shared code: catalog loader, sticker service, model
Bufos/                    1339 bufo PNG / GIF / JPG assets (from bufo.fun)
bufo-data.json            Tag metadata (from bufo.fun)
project.yml               XcodeGen project definition
scripts/fetch-bufos.sh    Re-fetches the latest bufos from bufo.fun
```

## Updating bufos

```sh
make fetch
```

This re-clones [tfritzy/bufo.fun](https://github.com/tfritzy/bufo.fun) and
copies the latest images and `bufo-data.json` into the repo. Rebuild after
running it.

## License & attribution

This app is [MIT licensed](./LICENSE).

The bundled bufo assets come from
[tfritzy/bufo.fun](https://github.com/tfritzy/bufo.fun), which states the
collection is distributed under the MIT License. The collection is itself
derived from
[knobiknows/all-the-bufo](https://github.com/knobiknows/all-the-bufo).
See [NOTICE](./NOTICE) for the full attribution and license text.
