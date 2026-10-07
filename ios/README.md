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
| `App/` | Gallery, wallpaper detail with phone preview, the Set up theme flow, setup guide, Photos saving, the Shortcuts action, live wallpapers (`LiveWallpapers.swift`) |
| `Widgets/` | Widget bundle: the moving widgets (Orbit, Zodiac, Race Day, Rivers of the USA, Asia, Canada and Japan), eight watch faces, Dial Clock, Day Sentence, Big Date, Day Headline, and the Seconds Ring, Running Clock, Signature and Waveform Lock Screen widgets |
| `tools/` | Python scripts that make the artwork: `make_motion_fonts.py` (the fonts that keep widgets moving), `make_watch_faces.py` (watch dials), `make_zodiac.py` (constellations), `make_space_art.py` (night sky), `make_river_maps.py` (river maps) |

The app and widgets share settings through an **App Group**
(`group.<BUNDLE_ID_BASE>`), created automatically when you choose a Team.

## Moving widgets

WidgetKit has no way to run a view's own animation. A widget is redrawn
only when its timeline moves on to a new entry, with one exception: text
that shows a running timer, which iOS itself updates every second.

### Motion fonts

Everything that moves is that timer text, drawn in a font whose glyphs are
the frames of an animation (`Shared/MotionFonts.swift`, fonts in
`Shared/Fonts`, built by `tools/make_motion_fonts.py`). The technique is from
Bryce Bostwick's [WidgetAnimation](https://github.com/brycebostwick/WidgetAnimation).

- The timer counts from the top of the hour, so it reads "7:05" 425 seconds
  in. The font's digits are blank, and a ligature replaces the whole of
  "M:SS" or "MM:SS" with one glyph: the scene as it should look at that
  second. A scene may take up to an hour to repeat (the planets do).
- A glyph is either an outline, which the widget colors like any text (the
  second hands, the river lights, the race cars), or an SVG drawing with
  its own colors (planets, watch scenes, sparkles).
- The widget needs one timeline entry an hour to restart the timer
  (`HourlyProvider`); watches have one a minute, for their hour and minute
  hands. Nothing depends on how often iOS refreshes the widget.
- Motion is in steps of a second, because that is how often iOS updates
  timer text. Smoother motion is possible by stacking several timers a
  fraction of a second apart, each masked to show in turn; not done here.

Things learned the hard way:

- **In a widget, timer text takes all the width it is offered**, and with
  `fixedSize()` far more, which pushes the glyph out of sight. `TimerGlyph`
  gives it a frame three glyphs wide with trailing alignment and moves the
  frame. An app lays the same text out differently, so check both.
- **Set each glyph's left side bearing to its outline's left edge**
  (`hmtx`). With 0 the outline is drawn shifted to the left edge of the em.
- **What the system's SVG glyphs support**, found by trying: gradients in
  both kinds of units, clip paths, opacity, arcs, and `<use xlink:href>`
  with transforms. `<use href>` without `xlink:` draws nothing, and SVG
  text is not available, which is why the roulette wheel's numbers are
  stroked lines.
- If iOS is late with the next hour's entry the timer reads "1:00:07"; the
  fonts cover that first minute.

Checked so far: the scenes run in the app, and show the right frame as real
widgets in the simulator. The simulator never advances a widget's timer, so
the ticking itself can only be seen on a phone.

### What was tried first

WidgetKit also animates a widget from one timeline entry to the next, for
two seconds at most, so the first version supplied entries two seconds
apart, each animating linearly into the next. It could only move for a few
minutes after each refresh, and on a phone its timelines came out too large
(see below), so the widgets showed grey placeholders. Nothing uses it now.

### Limits that make a widget fail

When a widget shows grey placeholder shapes, or stays blank, iOS refused
what the extension produced. `chronod` logs why: on a phone,
`idevicesyslog -p chronod` (from libimobiledevice); in the simulator,
`xcrun simctl spawn <id> log show`.

- **A timeline is limited to about 10 MB**, and iOS stores every entry's
  whole view ("too large timeline archive"). The reload is then not retried
  for an hour. A phone's archive is about half as large again as the
  simulator's for the same timeline, so measure with room to spare. Each
  `Text` costs about 1 KB per entry and each shape 0.3 to 1 KB. The
  timelines here are small: 24 entries a day, or 120 for a watch.
- **An image may not be much larger than the widget** ("imageTooLarge"). For
  a small widget 164 points across at 3x the limit was 1084 by 986 pixels,
  about twice the widget's own size. So the night sky has a picture for
  each widget size and the watch dials have a smaller one for small widgets.
- A widget's `configurationDisplayName` and `description` must be plain
  strings; a literal with interpolation stops the extension.

### Checking widgets

- **Check real widgets, not only previews.** The simulator stores its Home
  Screen layout in `data/Library/SpringBoard/IconState.plist`; adding
  widget entries there (simulator shut down) puts real widgets on the Home
  Screen without tapping. Timeline archives appear under
  `Containers/Data/PluginKitPlugin/*/SystemData/com.apple.chrono/timelines/`.
- **The simulator shows widgets as still snapshots.** Timer text doesn't
  tick and entry animations don't play there, so motion can only be judged
  on a phone (`xcrun devicectl device capture screenshot` works).
- **After reinstalling, give widgets a minute.** A widget can stay blank
  while iOS replaces the timeline archived by the previous build; if it
  logs `badTimelineData` in a loop it backs off for half an hour. In the
  simulator, deleting the extension's `SystemData/com.apple.chrono` folder
  while it is shut down clears that.

### Where the artwork comes from

- **Rivers**: Natural Earth (public domain). `python3 tools/make_river_maps.py`
  from the `ios` folder. Natural Earth has only three rivers in Japan, so
  five more are traced in the script from the cities they pass and are
  approximate.
- **Zodiac**: star positions and constellation figures from
  [d3-celestial](https://github.com/ofrohn/d3-celestial) (BSD 3-Clause,
  Copyright (c) 2015 Olaf Frohn). `tools/make_zodiac.py` writes
  `Shared/ZodiacData.swift`; touch and hold the widget and choose Edit
  Widget to pick a sign, or leave it on the current one.
- **Night sky**: painted by `tools/make_space_art.py`.
- **Planets** and every other scene are drawn in `tools/make_motion_fonts.py`.

After changing a tool, run it, and add any new font to both `UIAppFonts`
lists in `project.yml` (the font tool prints the list).

## Watch faces

Eight original designs with no brand names or logos. `tools/make_watch_faces.py`
draws each dial with Pillow, including its own stroke font for the numerals,
so no typeface is embedded. The hour and minute hands are views in
`Shared/WatchFaces.swift`, measured in the same case-radius units as the
generator, with a timeline entry each minute. What moves by the second is a
motion font:

- **Diver, Traveller, Chronograph**: the second hand.
- **Skeleton**: a balance wheel, a globe that circles once a minute and a gem.
- **Engine, Roulette, Carousel, Dragon**: the dial is a scene (pistons under
  a rev counter; a wheel and its ball; a four-armed orrery; two dragons
  round a turning cage), and the image is only the case and what stays still.

## Live wallpapers

iOS plays a Live Photo wallpaper when the Lock Screen wakes, and offers no
way for an app to set a wallpaper. So `App/LiveWallpapers.swift` renders an
animated Core Graphics scene into a Live Photo and saves it to Photos, and
the person picks it in the wallpaper chooser. A Live Photo is a JPEG and a
QuickTime movie that share an identifier: the JPEG carries it in its Apple
maker note (key 17), the movie as `com.apple.quicktime.content.identifier`,
and the movie also needs a metadata track with one
`com.apple.quicktime.still-image-time` sample. In Debug builds,
`pocketwalls://debug/live/<id>` makes and saves one and leaves copies of both
files in the app's Documents folder for inspection (`ffprobe` shows the
`mebx` track; the simulator's `Photos.sqlite` shows `ZKINDSUBTYPE` 2).
Whether iOS lets a given Live Photo move as a wallpaper is its own decision
and can only be checked on a phone.

## Running seconds in widgets

Besides the motion fonts above, the plain seconds on the Dial Clock and the
Lock Screen widgets use the two views the system keeps moving between
entries (`Shared/WidgetViews.swift`, "Live seconds"):

- `Text(date, style: .timer)`, clipped to its last two digits, for ticking
  seconds.
- `ProgressView(timerInterval:)` for a ring or bar that fills each minute.
  Inside an app the circular style draws as a spinner, so `SecondsRing`
  draws its own ring there and uses the system one only in the extension.

The timeline has one entry per minute, which restarts both.

## How "Set up theme" works

iOS gives apps no way to set the wallpaper, place widgets or change other
apps' icons, so one button can't do all three silently. The button does as
much as iOS allows (`App/SetupCoordinator.swift`):

- **Widgets**: saving the theme to the App Group is enough; they redraw.
- **Wallpaper**: runs the user's "Pocket Walls Wallpaper" shortcut (Get
  Current Wallpaper → Set Wallpaper Photo) through an x-callback link, and
  Shortcuts reports back to `pocketwalls://shortcut/...`. The shortcut is
  made once.
- **Icons**: `App/IconProfile.swift` builds a configuration profile of web
  clips, one per app, each with a themed icon and the app's URL scheme.
  `App/ProfileServer.swift` serves it to Safari from localhost, because iOS
  only installs profiles that Safari downloads. The user approves it in
  Settings.

Links into the app: `pocketwalls://theme/<id>` opens a wallpaper, and
`pocketwalls://theme/<id>/setup` opens it and starts setup. In Debug builds,
launching with `-openURL <link>` does the same without a prompt, which is
how the simulator screens are reached from the command line.

## If something goes wrong

- **Signing errors about App Groups**: some free accounts can't use App
  Groups. The app still works, but widgets fall back to the default theme.
  Send the error text and we'll adjust.
- **Build errors**: copy the first error from Xcode's Issue navigator
  (⌘5) and send it over.
