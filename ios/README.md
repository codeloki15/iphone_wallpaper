# Pocket Walls for iPhone

A SwiftUI app with a WidgetKit extension. It shares its wallpaper art,
themes and icons with the website, and adds what only an app can do: real
Home Screen and Lock Screen widgets that follow the theme you pick, one-tap
saving to Photos, and a Shortcuts action for one-tap wallpaper changes.

## What you need

- A Mac with **Xcode 15 or later** (from the Mac App Store)
- **XcodeGen**, which builds the Xcode project from `project.yml`:
  `brew install xcodegen` (needs [Homebrew](https://brew.sh))
- An Apple ID (free) to run on your own iPhone, or the Apple Developer
  Program (US$99/year) to publish on the App Store

## Build and run

1. `Config.xcconfig` holds the app ID (`BUNDLE_ID_BASE`) and your signing
   team (`DEVELOPMENT_TEAM`). To use your own values without changing that
   file, create `Local.xcconfig` next to it with the same lines; it is not
   committed.
2. In Terminal, in this `ios` folder:
   ```bash
   xcodegen generate
   open PocketWalls.xcodeproj
   ```
3. In Xcode, add your Apple ID under **Settings → Accounts**.
4. Put your team's 10-character ID in `Local.xcconfig`
   (`DEVELOPMENT_TEAM = ABCDE12345`) and run `xcodegen generate` again. Or
   pick the **Team** under **Signing & Capabilities** for both targets, which
   lasts until the project is next regenerated.
5. Pick an iPhone simulator (or your connected iPhone) at the top and press
   **⌘R**.

Run `xcodegen generate` again whenever files are added or `project.yml`
changes. The generated project is not committed.

### Checking the code without Xcode

Apple's Command Line Tools include the Mac Catalyst SDK, which has the same
UIKit, SwiftUI, WidgetKit and AppIntents APIs. Both targets compile against
it with no errors or warnings:

```bash
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk; IOS=$SDK/System/iOSSupport
swiftc -typecheck -parse-as-library -swift-version 5 \
  -target arm64-apple-ios17.0-macabi -sdk $SDK \
  -Fsystem $IOS/System/Library/Frameworks -I $IOS/usr/lib/swift \
  Shared/*.swift App/*.swift
```

For the widgets, add `-application-extension` and use `Widgets/*.swift` in
place of `App/*.swift`.

### On your own iPhone

Connect it with a cable and tap **Trust**. Turn on
**Settings → Privacy & Security → Developer Mode** on the phone, then pick it
in Xcode and press ⌘R. With a free Apple ID the app runs for 7 days before
it needs reinstalling from Xcode.

### Trying the widgets

On the simulator or phone, touch and hold the Home Screen → **Edit** →
**Add Widget** → **Pocket Walls**. Pick a theme in the app and the widgets
redraw in its colors.

## How it fits together

| Folder | What's inside |
|---|---|
| `Shared/` | Used by both targets: wallpaper generators (Core Graphics ports of the website's), themes, icons, time words, widget designs, shared settings |
| `App/` | Gallery, wallpaper detail with phone preview, setup guide, Photos saving, the Shortcuts action |
| `Widgets/` | Widget bundle: Day Sentence, Big Date, Dial Clock, Day Headline, and the Signature and Waveform Lock Screen widgets |

The app and widgets share settings through an **App Group**
(`group.<BUNDLE_ID_BASE>`), created automatically when you choose a Team.

## If something goes wrong

- **Signing errors about App Groups**: some free accounts can't use App
  Groups. The app still works, but widgets fall back to the default theme.
  Send the error text and we'll adjust.
- **Build errors**: copy the first error from Xcode's Issue navigator
  (⌘5) and send it over.
