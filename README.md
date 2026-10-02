# Pocket Walls

A free iPhone wallpaper gallery. Every wallpaper is generated in the browser with
`<canvas>`, so downloads are rendered at the **exact native resolution** of the
iPhone model you choose. There are no image files to host.

## Features

- Gallery of 40 wallpapers in 7 categories, including **Live** animated 3D wallpapers
- A spinning 3D iPhone in the hero (three.js): drag to spin, click to open the wallpaper on its screen
- 3D tilt on gallery cards and an iOS-style depth effect in the preview, where the clock floats above the wallpaper
- Search, plus favorites saved in your browser
- Full-screen preview on an iPhone mockup, with lock screen (live clock) and home screen views
- 12 iPhone screen sizes, from SE to 17 Pro Max; the model is auto-detected when browsing on an iPhone
- **Remix**: re-roll any design with a new random seed
- Save at full resolution: opens the image to press-and-hold save on iPhone, with a direct download link as well

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
- `tilt.js` / `tilt.css`: 3D tilt and depth effects
- `hero3d.js` / `hero3d.css`: the 3D iPhone (loads three.js r128 from cdnjs)

All motion respects the system's Reduce Motion setting.
