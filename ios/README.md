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

1. Open `project.yml` and change `BUNDLE_ID_BASE` to something unique to
   you, such as `com.yourname.pocketwalls`.
2. In Terminal, in this `ios` folder:
   ```bash
   xcodegen generate
   open PocketWalls.xcodeproj
   ```
3. In Xcode, add your Apple ID under **Settings → Accounts**.
4. Select the **PocketWalls** target → **Signing & Capabilities** → choose
   your **Team**. Do the same for the **PocketWallsWidgets** target.
5. Pick an iPhone simulator (or your connected iPhone) at the top and press
   **⌘R**.

Run `xcodegen generate` again whenever files are added or `project.yml`
changes. The generated project is not committed.

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
