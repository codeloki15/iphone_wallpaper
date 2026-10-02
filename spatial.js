/*
 * Spatial wallpapers: two depth layers in the spirit of iOS Spatial Scenes.
 *
 * Each generator draws a background and a foreground subject. Rendered whole
 * it is an ordinary image; rendered by layer, the viewer puts the clock
 * between the two and shifts them at different depths as the phone tilts.
 * The foreground subjects rise into the clock area (about 9-21% of the
 * height) so the clock tucks behind them.
 */
(function () {
  'use strict';

  const { rgba, mix, vertical, grain, ridge } = Walls.util;
  const TAU = Math.PI * 2;

  function fill(ctx, w, h, style) {
    ctx.fillStyle = style;
    ctx.fillRect(0, 0, w, h);
  }

  function glow(ctx, x, y, radius, color, alpha) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, radius);
    g.addColorStop(0, rgba(color, alpha));
    g.addColorStop(1, rgba(color, 0));
    ctx.fillStyle = g;
    ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  function stars(ctx, w, h, list, maxY) {
    const u = w / 1000;
    for (const [x, y, s, a] of list) {
      if (y > maxY) continue;
      ctx.fillStyle = `rgba(255,255,255,${a})`;
      ctx.beginPath();
      ctx.arc(x * w, y * h, s * u, 0, TAU);
      ctx.fill();
    }
  }

  function makeStars(r, n) {
    const list = [];
    for (let i = 0; i < n; i++) list.push([r(), r(), 0.6 + Math.pow(r(), 3) * 3, 0.25 + r() * 0.75]);
    return list;
  }

  // Draws the background and/or foreground, then grain on whatever was drawn.
  function layered(scene, back, front) {
    return (ctx, w, h, r, p, t, layer) => {
      const s = scene(r);
      if (layer !== 'front') back(ctx, w, h, s, p);
      if (layer !== 'back') front(ctx, w, h, s, p);
      grain(ctx, w, h, r, 8);
    };
  }

  const GENS = {
    // palette: [skyTop, skyBottom, moon, rim light, far rock, near rock]
    peak: layered(
      (r) => ({
        stars: makeStars(r, 260),
        mx: 0.6 + r() * 0.14, my: 0.2 + r() * 0.04, mr: 0.19 + r() * 0.04,
        peakX: 0.36 + r() * 0.16,
        far: ridge(r, 65, 0.55), near: ridge(r, 129, 0.6), fore: ridge(r, 65, 0.5),
      }),
      (ctx, w, h, s, p) => {
        fill(ctx, w, h, vertical(ctx, 0, h * 0.7, [p[0], p[1]]));
        stars(ctx, w, h, s.stars, 0.6);
        const mx = s.mx * w, my = s.my * h, mr = s.mr * w;
        glow(ctx, mx, my, mr * 4, p[2], 0.35);
        ctx.fillStyle = p[2];
        ctx.beginPath();
        ctx.arc(mx, my, mr, 0, TAU);
        ctx.fill();
        ctx.fillStyle = 'rgba(0,0,0,0.06)';
        [[-0.3, -0.2, 0.22], [0.25, 0.1, 0.3], [-0.1, 0.4, 0.15]].forEach(([dx, dy, k]) => {
          ctx.beginPath();
          ctx.arc(mx + dx * mr, my + dy * mr, k * mr, 0, TAU);
          ctx.fill();
        });
        drawProfile(ctx, w, h, s.far, (v) => h * (0.5 - v * 0.08), mix(p[4], p[1], 0.45));
      },
      (ctx, w, h, s, p) => {
        const u = w / 1000;
        const n = s.near.length;
        const top = h * 0.182;
        // The summit plus two lower shoulders; the outline is whichever is highest.
        const peaks = [[s.peakX, top, 0.95], [s.peakX - 0.27, h * 0.3, 0.8], [s.peakX + 0.3, h * 0.33, 0.7]];
        const pts = s.near.map((v, i) => {
          const x = i / (n - 1);
          let y = h;
          for (const [px, py, slope] of peaks) {
            const d = x - px;
            const k = d < 0 ? slope * 1.15 : slope;
            y = Math.min(y, py + Math.pow(Math.abs(d), 0.9) * h * k);
          }
          const d = Math.abs(x - s.peakX);
          y += (v - 0.5) * h * 0.06 * Math.min(1, d * 4);
          return [x * w, Math.max(top, y)];
        });
        const mountain = new Path2D();
        mountain.moveTo(0, h);
        pts.forEach(([x, y]) => mountain.lineTo(x, y));
        mountain.lineTo(w, h);
        mountain.closePath();
        ctx.fillStyle = vertical(ctx, top, h * 0.75, [mix(p[5], p[3], 0.3), p[5]]);
        ctx.fill(mountain);
        // Shade the face turned away from the moon.
        ctx.save();
        ctx.clip(mountain);
        const away = s.mx > s.peakX ? -1 : 1;
        const shade = ctx.createLinearGradient(s.peakX * w, 0, s.peakX * w + away * w * 0.5, 0);
        shade.addColorStop(0, 'rgba(0,0,0,0)');
        shade.addColorStop(0.3, 'rgba(0,0,0,0.3)');
        shade.addColorStop(1, 'rgba(0,0,0,0.2)');
        ctx.fillStyle = shade;
        ctx.fillRect(0, 0, w, h);
        ctx.restore();
        // Rim light along the ridge on the moon side.
        const rim = ctx.createLinearGradient(0, 0, w, 0);
        rim.addColorStop(away > 0 ? 1 : 0, rgba(p[3], 0.05));
        rim.addColorStop(s.peakX, rgba(p[3], 0.95));
        rim.addColorStop(away > 0 ? 0 : 1, rgba(p[3], 0.45));
        ctx.strokeStyle = rim;
        ctx.lineWidth = 3.5 * u;
        ctx.lineJoin = 'round';
        ctx.beginPath();
        pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
        ctx.stroke();
        drawProfile(ctx, w, h, s.fore, (v) => h * (0.84 - v * 0.06), mix(p[5], '#000000', 0.45));
      }
    ),

    // palette: [spaceTop, spaceBottom, nebula, planet light, planet dark, atmosphere]
    planet: layered(
      (r) => ({
        stars: makeStars(r, 320),
        nebula: [[r(), r() * 0.5, 0.5 + r() * 0.4], [r(), r() * 0.5, 0.4 + r() * 0.4]],
        cx: 0.45 + r() * 0.1,
        bands: Array.from({ length: 9 }, () => [r(), r(), 0.02 + r() * 0.05]),
        moon: [0.18 + r() * 0.2, 0.34 + r() * 0.08],
      }),
      (ctx, w, h, s, p) => {
        fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
        s.nebula.forEach(([x, y, k]) => glow(ctx, x * w, y * h, k * w, p[2], 0.35));
        stars(ctx, w, h, s.stars, 1);
        const [mx, my] = s.moon;
        ctx.fillStyle = vertical(ctx, my * h - w * 0.05, my * h + w * 0.05, [mix(p[3], '#ffffff', 0.4), p[4]]);
        ctx.beginPath();
        ctx.arc(mx * w, my * h, w * 0.045, 0, TAU);
        ctx.fill();
      },
      (ctx, w, h, s, p) => {
        const u = w / 1000;
        const R = w * 1.15;
        const cx = s.cx * w;
        const cy = h * 0.185 + R;
        // Atmosphere glow around the limb.
        const atmo = ctx.createRadialGradient(cx, cy, R * 0.97, cx, cy, R * 1.14);
        atmo.addColorStop(0, rgba(p[5], 0.7));
        atmo.addColorStop(1, rgba(p[5], 0));
        ctx.fillStyle = atmo;
        ctx.fillRect(0, 0, w, h);
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, TAU);
        ctx.clip();
        ctx.fillStyle = vertical(ctx, cy - R, cy - R * 0.4, [p[3], p[4]]);
        ctx.fillRect(0, 0, w, h);
        // Latitude bands follow the curve of the planet.
        s.bands.forEach(([k, c, thick]) => {
          ctx.strokeStyle = rgba(mix(p[3], p[4], c), 0.35);
          ctx.lineWidth = thick * R * 0.5;
          ctx.beginPath();
          ctx.arc(cx, cy + R * 0.1, R * (0.86 - k * 0.3), Math.PI * 1.1, Math.PI * 1.9);
          ctx.stroke();
        });
        // Terminator: the far side falls into shadow.
        const term = ctx.createLinearGradient(cx - R * 0.4, cy - R, cx + R * 0.5, cy - R * 0.5);
        term.addColorStop(0, 'rgba(0,0,0,0)');
        term.addColorStop(1, 'rgba(0,0,0,0.6)');
        ctx.fillStyle = term;
        ctx.fillRect(0, 0, w, h);
        ctx.restore();
        ctx.strokeStyle = rgba(mix(p[5], '#ffffff', 0.4), 0.9);
        ctx.lineWidth = 4 * u;
        ctx.beginPath();
        ctx.arc(cx, cy, R, Math.PI * 1.15, Math.PI * 1.75);
        ctx.stroke();
      }
    ),

    // palette: [bgTop, bgBottom, ...blob colors]
    orb: layered(
      (r) => ({
        blobs: Array.from({ length: 6 }, (_, i) => [r(), r(), 0.3 + r() * 0.35, 2 + (i % 3)]),
        ox: 0.47 + r() * 0.06,
      }),
      (ctx, w, h, s, p) => drawOrbScene(ctx, w, h, s, p),
      (ctx, w, h, s, p) => {
        const u = w / 1000;
        const R = w * 0.38;
        const cx = s.ox * w;
        const cy = h * 0.36;
        // Contact shadow on the "floor" below the orb.
        ctx.save();
        ctx.translate(cx, cy + R * 1.25);
        ctx.scale(1, 0.14);
        const sh = ctx.createRadialGradient(0, 0, 0, 0, 0, R * 0.9);
        sh.addColorStop(0, 'rgba(0,0,0,0.28)');
        sh.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = sh;
        ctx.fillRect(-R, -R, R * 2, R * 2);
        ctx.restore();
        // Refraction: the scene behind, flipped and magnified through the glass.
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, TAU);
        ctx.clip();
        ctx.translate(cx, cy);
        ctx.scale(-1.45, -1.45);
        ctx.translate(-cx, -cy);
        drawOrbScene(ctx, w, h, s, p);
        ctx.restore();
        // Fresnel edge, highlights and rim.
        const edge = ctx.createRadialGradient(cx, cy, R * 0.55, cx, cy, R);
        edge.addColorStop(0, 'rgba(255,255,255,0)');
        edge.addColorStop(1, 'rgba(255,255,255,0.4)');
        ctx.fillStyle = edge;
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, TAU);
        ctx.fill();
        ctx.save();
        ctx.translate(cx - R * 0.36, cy - R * 0.46);
        ctx.rotate(-0.6);
        ctx.scale(1, 0.55);
        const spec = ctx.createRadialGradient(0, 0, 0, 0, 0, R * 0.3);
        spec.addColorStop(0, 'rgba(255,255,255,0.95)');
        spec.addColorStop(1, 'rgba(255,255,255,0)');
        ctx.fillStyle = spec;
        ctx.fillRect(-R, -R, R * 2, R * 2);
        ctx.restore();
        glow(ctx, cx + R * 0.45, cy + R * 0.5, R * 0.14, '#ffffff', 0.5);
        ctx.strokeStyle = 'rgba(255,255,255,0.55)';
        ctx.lineWidth = 2.5 * u;
        ctx.beginPath();
        ctx.arc(cx, cy, R - 1.25 * u, 0, TAU);
        ctx.stroke();
      }
    ),

    // palette: [skyTop, skyHorizon, sun, sea, palm]
    palm: layered(
      (r) => ({
        sx: 0.58 + r() * 0.12,
        streaks: Array.from({ length: 26 }, () => [r(), r(), r()]),
        fronds: Array.from({ length: 9 }, (_, i) => [i, r(), r()]),
        island: ridge(r, 33, 0.5),
      }),
      (ctx, w, h, s, p) => {
        const hz = h * 0.62;
        fill(ctx, w, h, vertical(ctx, 0, hz, [p[0], p[1]]));
        const sx = s.sx * w, sy = h * 0.53, sr = w * 0.15;
        glow(ctx, sx, sy, sr * 4, p[2], 0.5);
        ctx.fillStyle = p[2];
        ctx.beginPath();
        ctx.arc(sx, sy, sr, 0, TAU);
        ctx.fill();
        ctx.fillStyle = vertical(ctx, hz, h, [p[3], mix(p[3], '#000000', 0.45)]);
        ctx.fillRect(0, hz, w, h - hz);
        // Sun reflection: broken streaks narrowing toward the horizon.
        s.streaks.forEach(([a, b, c]) => {
          const y = hz + Math.pow(a, 1.6) * (h - hz) * 0.8;
          const k = (y - hz) / (h - hz);
          const len = sr * (0.4 + k * 2.4) * (0.4 + b * 0.6);
          ctx.fillStyle = rgba(p[2], 0.55 * (1 - k * 0.6));
          ctx.fillRect(sx - len / 2 + (c - 0.5) * sr * 0.6, y, len, Math.max(1, h * 0.003 * (0.5 + k)));
        });
        drawProfile(ctx, w, h, s.island, (v) => hz - v * h * 0.025, mix(p[4], p[1], 0.5), w * 0.62, w * 0.98, hz);
      },
      (ctx, w, h, s, p) => drawPalm(ctx, w, h, s, p[4])
    ),

    // palette: [bg, layer1, layer2, layer3, layer4, sun, trees]
    paper: layered(
      (r) => ({
        layers: Array.from({ length: 4 }, () => [r() * TAU, 0.6 + r() * 0.8, r() * TAU]),
        sunX: 0.62 + r() * 0.12,
        trees: [
          [0.43 + r() * 0.06, 0.168, 0.3],
          [0.16 + r() * 0.05, 0.34, 0.24],
          [0.76 + r() * 0.06, 0.3, 0.26],
          [0.95, 0.46, 0.2],
        ],
      }),
      (ctx, w, h, s, p) => {
        const u = w / 1000;
        fill(ctx, w, h, vertical(ctx, 0, h, [p[0], mix(p[0], p[1], 0.35)]));
        ctx.fillStyle = p[5];
        ctx.beginPath();
        ctx.arc(s.sunX * w, h * 0.3, w * 0.17, 0, TAU);
        ctx.fill();
        s.layers.forEach(([ph, f, ph2], i) => {
          const base = h * (0.46 + i * 0.12);
          paperLayer(ctx, w, h, u, p[1 + i], (x) => base + Math.sin(x * f * TAU + ph) * h * 0.025 + Math.sin(x * 3.1 * TAU + ph2) * h * 0.008);
        });
      },
      (ctx, w, h, s, p) => {
        const u = w / 1000;
        // Draw back to front: the tallest tree last, so it sits nearest.
        [...s.trees].sort((a, b) => b[1] - a[1]).forEach(([x, top, width], i) => {
          paperPine(ctx, w, h, u, x * w, top * h, width * w, mix(p[6], '#ffffff', 0.12 * (3 - i)));
        });
        // A paper ground strip ties the trees together.
        paperLayer(ctx, w, h, u, mix(p[6], '#000000', 0.2), (x) => h * 0.9 + Math.sin(x * 5 + 1) * h * 0.01);
      }
    ),
  };

  function drawProfile(ctx, w, h, pts, yOf, color, x0 = 0, x1 = w, baseY = h) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(x0, baseY);
    pts.forEach((v, i) => ctx.lineTo(x0 + (i / (pts.length - 1)) * (x1 - x0), yOf(v)));
    ctx.lineTo(x1, baseY);
    ctx.closePath();
    ctx.fill();
  }

  function drawOrbScene(ctx, w, h, s, p) {
    ctx.fillStyle = vertical(ctx, 0, h, [p[0], p[1]]);
    ctx.fillRect(-w, -h, w * 3, h * 3);
    s.blobs.forEach(([x, y, k, c]) => glow(ctx, x * w, y * h, k * w, p[c], 0.8));
  }

  // A pine cut from paper: stacked tiers, each casting a soft shadow.
  function paperPine(ctx, w, h, u, cx, top, width, color) {
    const tiers = 6;
    const bottom = h * 0.95;
    const tierH = (bottom - top) / (tiers + 1.2);
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.28)';
    ctx.shadowBlur = 24 * u;
    ctx.shadowOffsetY = 8 * u;
    ctx.fillStyle = mix(color, '#000000', 0.35);
    ctx.fillRect(cx - width * 0.05, top + tierH * tiers, width * 0.1, bottom - top);
    for (let k = 0; k < tiers; k++) {
      const y0 = top + k * tierH;
      const half = width * (0.22 + (k / (tiers - 1)) * 0.3);
      ctx.fillStyle = mix(color, '#000000', 0.05 * k);
      ctx.beginPath();
      ctx.moveTo(cx, y0);
      ctx.lineTo(cx + half, y0 + tierH * 1.7);
      ctx.quadraticCurveTo(cx, y0 + tierH * 1.35, cx - half, y0 + tierH * 1.7);
      ctx.closePath();
      ctx.fill();
    }
    ctx.restore();
  }

  function paperLayer(ctx, w, h, u, color, yOf) {
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.25)';
    ctx.shadowBlur = 28 * u;
    ctx.shadowOffsetY = -6 * u;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(0, h);
    for (let i = 0; i <= 60; i++) ctx.lineTo((i / 60) * w, yOf(i / 60));
    ctx.lineTo(w, h);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawPalm(ctx, w, h, s, color) {
    const u = w / 1000;
    const base = [w * 0.14, h * 1.02];
    const ctrl = [w * 0.04, h * 0.6];
    const crown = [w * 0.3, h * 0.235];
    const at = (t) => [
      (1 - t) * (1 - t) * base[0] + 2 * (1 - t) * t * ctrl[0] + t * t * crown[0],
      (1 - t) * (1 - t) * base[1] + 2 * (1 - t) * t * ctrl[1] + t * t * crown[1],
    ];
    ctx.fillStyle = color;
    ctx.strokeStyle = color;
    // Trunk: a tapering band with ring marks.
    const left = [];
    const right = [];
    for (let i = 0; i <= 40; i++) {
      const t = i / 40;
      const [x, y] = at(t);
      const [x2, y2] = at(Math.min(1, t + 0.01));
      const ang = Math.atan2(y2 - y, x2 - x) + Math.PI / 2;
      const half = w * (0.04 - t * 0.018);
      left.push([x + Math.cos(ang) * half, y + Math.sin(ang) * half]);
      right.push([x - Math.cos(ang) * half, y - Math.sin(ang) * half]);
    }
    ctx.beginPath();
    left.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    right.reverse().forEach(([x, y]) => ctx.lineTo(x, y));
    ctx.closePath();
    ctx.fill();
    // Fronds fan out from the crown and droop under their own weight. Each
    // is a filled outline whose zigzag edge suggests the leaflets.
    s.fronds.forEach(([i, a, b]) => {
      const spread = -Math.PI * 1.05 + (i / (s.fronds.length - 1)) * Math.PI * 1.2 + (a - 0.5) * 0.16;
      const len = w * (0.34 + b * 0.14);
      const droop = len * (0.3 + Math.abs(Math.cos(spread)) * 0.5);
      const end = [crown[0] + Math.cos(spread) * len, crown[1] + Math.sin(spread) * len * 0.7 + droop];
      const mid = [crown[0] + Math.cos(spread) * len * 0.55, crown[1] + Math.sin(spread) * len * 0.55 - len * 0.14];
      const pt = (t) => [
        (1 - t) * (1 - t) * crown[0] + 2 * (1 - t) * t * mid[0] + t * t * end[0],
        (1 - t) * (1 - t) * crown[1] + 2 * (1 - t) * t * mid[1] + t * t * end[1],
      ];
      const steps = 22;
      const sideA = [];
      const sideB = [];
      for (let k = 0; k <= steps; k++) {
        const t = k / steps;
        const [x, y] = pt(t);
        const [x2, y2] = pt(Math.min(1, t + 0.02));
        const dir = Math.atan2(y2 - y, x2 - x);
        const wide = len * 0.2 * Math.sin(Math.PI * Math.min(1, t * 1.05 + 0.02)) * (k % 2 ? 1 : 0.45);
        // Leaflets hang down, so both edges are pulled toward the ground.
        const hang = wide * 0.55;
        sideA.push([x + Math.cos(dir - 1.2) * wide, y + Math.sin(dir - 1.2) * wide + hang]);
        sideB.push([x + Math.cos(dir + 1.2) * wide, y + Math.sin(dir + 1.2) * wide + hang]);
      }
      ctx.beginPath();
      ctx.moveTo(crown[0], crown[1]);
      sideA.forEach(([x, y]) => ctx.lineTo(x, y));
      sideB.reverse().forEach(([x, y]) => ctx.lineTo(x, y));
      ctx.closePath();
      ctx.fill();
    });
    [[-0.012, 0.012], [0.014, 0.016], [0.002, 0.026]].forEach(([dx, dy]) => {
      ctx.beginPath();
      ctx.arc(crown[0] + dx * w, crown[1] + dy * h, w * 0.022, 0, TAU);
      ctx.fill();
    });
  }

  const SPATIAL = { spatial: true };
  Walls.register(GENS, [
    ['Lunar Peak', 'Spatial', 'peak', ['#0b1530', '#3b4b78', '#f4f1e6', '#ffe9c4', '#4a5578', '#1e2540'], SPATIAL],
    ['Planet Rise', 'Spatial', 'planet', ['#02020a', '#0f1033', '#7b3fe4', '#f6b47c', '#4a2a6a', '#7fd4ff'], SPATIAL],
    ['Glass Orb', 'Spatial', 'orb', ['#f3eefc', '#dfe8ff', '#ff9ec7', '#8fb8ff', '#ffd59e'], SPATIAL],
    ['Palm Sunset', 'Spatial', 'palm', ['#2a1b4a', '#ff8a5c', '#ffe08a', '#3a2a5e', '#140c22'], SPATIAL],
    ['Paper Pines', 'Spatial', 'paper', ['#fdf1e3', '#f6c7a5', '#ee9f86', '#d4747a', '#9c4f6e', '#ffd166', '#2f6b5e'], SPATIAL],
  ]);
})();
