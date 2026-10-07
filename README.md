# Pocket Walls

A free iPhone wallpaper gallery. Every wallpaper is generated in the browser with
`<canvas>`, so downloads are rendered at the **exact native resolution** of the
iPhone model you choose. There are no image files to host.

## Features

- **Complete looks**: one-tap presets (such as Black Vision) that set wallpaper, icons, clock and layout together
- Gallery of 56 wallpapers in 9 categories, including **Art** (torn paper, diagonal tears, folded silk, doodles), **Live** animated 3D wallpapers and
  **Spatial** wallpapers: two depth layers with the lock-screen clock tucked between them,
  in the style of iOS 26 Spatial Scenes
- A spinning 3D iPhone in the hero (three.js): drag to spin, click to open the wallpaper on its screen
- **Matching theme** for every wallpaper: 24 icons in four styles (Color, Light, Dark, Mono), a widget and a clock color
  made from its palette, shown live on the Home Screen preview. Download it as a theme pack
  (.zip with the wallpaper, icons and steps) and follow the built-in guide to apply it with
  iOS icon tinting or custom icons via the Shortcuts app
- **Clock faces** for the Lock Screen preview: Classic, Dial, Vertical and Words, plus optional
  Lock Screen widgets (music waveform and a handwritten signature you can personalize)
- **Home Screen setups**: Grid, Minimal (day headline, time sentence, weather, music and an
  app-list widget), Diagonal (outlined widgets and icons stepping along a tear) and Dial, built on the real iOS grid and widget sizes so they can be
  recreated with a widget app; the theme pack includes reference images of the widgets
- 3D tilt on gallery cards and an iOS-style depth effect in the preview, where the clock floats above the wallpaper
- Search, plus favorites saved in your browser
- Full-screen preview on an iPhone mockup, with lock screen (live clock) and home screen views
- 12 iPhone screen sizes, from SE to 17 Pro Max; the model is auto-detected when browsing on an iPhone
- **Remix**: re-roll any design with a new random seed
- Save at full resolution: opens the image to press-and-hold save on iPhone, with a direct download link as well

## Install it like an app

On iPhone, open the site in Safari, tap **Share → Add to Home Screen**. It opens
full screen with its own icon and works offline (via `sw.js` and
`manifest.webmanifest`). Bump `VERSION` in `sw.js` when you change files, so
installed copies pick up the update.

## iPhone app

The `ios/` folder holds a native SwiftUI version with real Home Screen and Lock
Screen widgets that follow the chosen theme, including moving ones (the
planets, zodiac constellations, race cars, and river maps of the USA, Asia,
Canada and Japan), eight original watch faces, and live wallpapers saved as
Live Photos. See [ios/README.md](ios/README.md)
for building it on a Mac with Xcode.

## Run locally

It's a static site with no build step:

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

## Deploy

Push to GitHub and enable **Settings → Pages → Deploy from branch** (root folder).
Netlify, Vercel or Cloudflare Pages also work without any configuration.

## Adding wallpapers

Open `wallpapers.js` and add a row to `CATALOGUE`:

```js
['My Wallpaper', 'Nature', 'mountains', ['#skyTop', '#skyBottom', '#sun', '#ridgeFar', '#ridgeNear']],
```

Available generators are `aurora`, `linear`, `waves`, `mountains`, `night`,
`rings`, `lowpoly`, `bauhaus`, `dots`, `synthwave`, `contours` and `blobs`.
Each one documents its palette order in a comment.

## Files

- `index.html`: page structure
- `styles.css`: styling (dark/light aware, mobile-first)
- `wallpapers.js`: generators and wallpaper catalogue
- `app.js`: gallery, viewer, device list and downloads
- `live.js` / `live.css`: Live animated wallpapers
- `spatial.js` / `spatial.css`: Spatial (layered depth) wallpapers
- `theme.js` / `theme.css`: matching themes, icon drawing, theme pack (.zip) and setup guide
- `art.js`: Art wallpapers (torn paper, folded silk)
- `faces.js`: Lock Screen clock faces
- `setups.js` / `setups.css`: Home Screen layouts and widgets
- `tilt.js` / `tilt.css`: 3D tilt and depth effects
- `hero3d.js` / `hero3d.css`: the 3D iPhone (loads three.js r128 from cdnjs)

All motion respects the system's Reduce Motion setting.
