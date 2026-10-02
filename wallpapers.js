/*
 * Procedural wallpaper library.
 *
 * Every wallpaper is a generator + palette + seed. Generators draw in
 * coordinates relative to the canvas size, so the same wallpaper can be
 * rendered as a small thumbnail or at a device's full native resolution.
 */
(function (global) {
  'use strict';

  // ---------- helpers ----------

  function mulberry32(a) {
    return function () {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function hash(str) {
    let h = 2166136261;
    for (let i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return h >>> 0;
  }

  function hexToRgb(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function rgba(hex, a) {
    const [r, g, b] = hexToRgb(hex);
    return `rgba(${r},${g},${b},${a})`;
  }

  function mix(h1, h2, t) {
    const a = hexToRgb(h1);
    const b = hexToRgb(h2);
    return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * t).toString(16).padStart(2, '0')).join('');
  }

  // Sample a multi-stop palette at t in [0, 1].
  function sample(p, t) {
    t = Math.max(0, Math.min(1, t));
    const s = t * (p.length - 1);
    const i = Math.min(Math.floor(s), p.length - 2);
    return mix(p[i], p[i + 1], s - i);
  }

  function fill(ctx, w, h, style) {
    ctx.fillStyle = style;
    ctx.fillRect(0, 0, w, h);
  }

  function vertical(ctx, y0, y1, stops) {
    const g = ctx.createLinearGradient(0, y0, 0, y1);
    stops.forEach((c, i) => g.addColorStop(i / (stops.length - 1), c));
    return g;
  }

  // Film grain. Always called last so it doesn't shift the random sequence
  // used for shapes (which keeps thumbnails and downloads identical).
  function grain(ctx, w, h, r, amount) {
    const img = ctx.getImageData(0, 0, w, h);
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      const n = (r() - 0.5) * amount;
      d[i] += n;
      d[i + 1] += n;
      d[i + 2] += n;
    }
    ctx.putImageData(img, 0, 0);
  }

  // 1D midpoint displacement, used for mountain ridges and hills.
  function ridge(r, n, rough) {
    const a = new Array(n).fill(0);
    a[0] = r();
    a[n - 1] = r();
    let step = n - 1;
    let disp = 1;
    while (step > 1) {
      const half = step / 2;
      for (let i = half; i < n - 1; i += step) {
        a[i] = (a[i - half] + a[i + half]) / 2 + (r() - 0.5) * disp;
      }
      step = half;
      disp *= rough;
    }
    return a;
  }

  function drawRidge(ctx, w, h, pts, base, amp, color) {
    ctx.beginPath();
    ctx.moveTo(0, h);
    pts.forEach((v, j) => ctx.lineTo((j / (pts.length - 1)) * w, base - v * amp));
    ctx.lineTo(w, h);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
  }

  // ---------- generators: (ctx, w, h, rand, palette) ----------

  const GENS = {
    aurora(ctx, w, h, r, p) {
      fill(ctx, w, h, p[0]);
      for (let i = 0; i < 7; i++) {
        const x = r() * w;
        const y = r() * h;
        const rad = (0.45 + r() * 0.5) * h * 0.7;
        const c = p[1 + (i % (p.length - 1))];
        const g = ctx.createRadialGradient(x, y, 0, x, y, rad);
        g.addColorStop(0, rgba(c, 0.85));
        g.addColorStop(0.5, rgba(c, 0.35));
        g.addColorStop(1, rgba(c, 0));
        fill(ctx, w, h, g);
      }
      grain(ctx, w, h, r, 14);
    },

    linear(ctx, w, h, r, p) {
      const a = (r() - 0.5) * 0.6;
      const len = h / 2;
      const g = ctx.createLinearGradient(
        w / 2 - Math.sin(a) * len, h / 2 - Math.cos(a) * len,
        w / 2 + Math.sin(a) * len, h / 2 + Math.cos(a) * len
      );
      p.forEach((c, i) => g.addColorStop(i / (p.length - 1), c));
      fill(ctx, w, h, g);
      const gx = w * (0.2 + r() * 0.6);
      const gy = h * (0.2 + r() * 0.3);
      const glow = ctx.createRadialGradient(gx, gy, 0, gx, gy, w * 0.9);
      glow.addColorStop(0, 'rgba(255,255,255,0.18)');
      glow.addColorStop(1, 'rgba(255,255,255,0)');
      fill(ctx, w, h, glow);
      grain(ctx, w, h, r, 10);
    },

    // palette: [skyTop, skyBottom, waveFar, waveNear]
    waves(ctx, w, h, r, p) {
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
      const layers = 7;
      for (let i = 0; i < layers; i++) {
        const t = i / (layers - 1);
        const base = h * (0.38 + t * 0.55);
        const amp = h * (0.015 + r() * 0.025);
        const f1 = ((1 + r() * 2) * Math.PI * 2) / w;
        const f2 = ((2 + r() * 3) * Math.PI * 2) / w;
        const ph1 = r() * Math.PI * 2;
        const ph2 = r() * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(0, h);
        for (let s = 0; s <= 120; s++) {
          const x = (s / 120) * w;
          ctx.lineTo(x, base + Math.sin(x * f1 + ph1) * amp + Math.sin(x * f2 + ph2) * amp * 0.4);
        }
        ctx.lineTo(w, h);
        ctx.closePath();
        ctx.fillStyle = mix(p[2], p[3], t);
        ctx.fill();
      }
      grain(ctx, w, h, r, 8);
    },

    // palette: [skyTop, skyBottom, sun, ridgeFar, ridgeNear]
    mountains(ctx, w, h, r, p) {
      fill(ctx, w, h, vertical(ctx, 0, h * 0.7, [p[0], p[1]]));
      const sx = w * (0.25 + r() * 0.5);
      const sy = h * (0.3 + r() * 0.1);
      const sr = w * (0.12 + r() * 0.06);
      const glow = ctx.createRadialGradient(sx, sy, sr * 0.5, sx, sy, sr * 4);
      glow.addColorStop(0, rgba(p[2], 0.45));
      glow.addColorStop(1, rgba(p[2], 0));
      fill(ctx, w, h, glow);
      ctx.fillStyle = p[2];
      ctx.beginPath();
      ctx.arc(sx, sy, sr, 0, Math.PI * 2);
      ctx.fill();
      const ridges = 5;
      for (let i = 0; i < ridges; i++) {
        const t = i / (ridges - 1);
        drawRidge(ctx, w, h, ridge(r, 129, 0.55), h * (0.42 + t * 0.13), h * (0.12 - t * 0.05), mix(p[3], p[4], t));
      }
      grain(ctx, w, h, r, 8);
    },

    // palette: [skyTop, skyBottom, moon, hills]
    night(ctx, w, h, r, p) {
      const u = w / 1000;
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
      for (let i = 0; i < 600; i++) {
        const x = r() * w;
        const y = r() * h * 0.85;
        const s = (Math.pow(r(), 3) * 2.2 + 0.4) * u * 1.6;
        ctx.fillStyle = `rgba(255,255,255,${0.3 + r() * 0.7})`;
        ctx.beginPath();
        ctx.arc(x, y, s, 0, Math.PI * 2);
        ctx.fill();
      }
      const mx = w * (0.2 + r() * 0.6);
      const my = h * (0.12 + r() * 0.18);
      const mr = w * (0.07 + r() * 0.04);
      const glow = ctx.createRadialGradient(mx, my, mr, mx, my, mr * 5);
      glow.addColorStop(0, rgba(p[2], 0.35));
      glow.addColorStop(1, rgba(p[2], 0));
      fill(ctx, w, h, glow);
      ctx.fillStyle = p[2];
      ctx.beginPath();
      ctx.arc(mx, my, mr, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,0.07)';
      for (let i = 0; i < 5; i++) {
        const a = r() * Math.PI * 2;
        const d = r() * mr * 0.6;
        ctx.beginPath();
        ctx.arc(mx + Math.cos(a) * d, my + Math.sin(a) * d, mr * (0.1 + r() * 0.15), 0, Math.PI * 2);
        ctx.fill();
      }
      drawRidge(ctx, w, h, ridge(r, 65, 0.5), h * 0.82, h * 0.08, mix(p[3], p[1], 0.35));
      drawRidge(ctx, w, h, ridge(r, 65, 0.5), h * 0.9, h * 0.06, p[3]);
      grain(ctx, w, h, r, 6);
    },

    // palette: [background, ...ring colors]
    rings(ctx, w, h, r, p) {
      fill(ctx, w, h, p[0]);
      const cx = w * (0.3 + r() * 0.4);
      const cy = h * (0.55 + r() * 0.25);
      const n = p.length - 1;
      const count = 8;
      for (let i = count; i >= 1; i--) {
        ctx.fillStyle = p[1 + (i % n)];
        ctx.beginPath();
        ctx.arc(cx, cy, (h * 0.75 * i) / count, 0, Math.PI * 2);
        ctx.fill();
      }
      grain(ctx, w, h, r, 10);
    },

    lowpoly(ctx, w, h, r, p) {
      const cols = 7;
      const rows = Math.round((cols * h) / w);
      const cw = w / cols;
      const ch = h / rows;
      const pts = [];
      for (let y = 0; y <= rows; y++) {
        const row = [];
        for (let x = 0; x <= cols; x++) {
          const jx = x > 0 && x < cols ? (r() - 0.5) * cw * 0.8 : 0;
          const jy = y > 0 && y < rows ? (r() - 0.5) * ch * 0.8 : 0;
          row.push([x * cw + jx, y * ch + jy]);
        }
        pts.push(row);
      }
      ctx.lineJoin = 'round';
      ctx.lineWidth = 1.5;
      const tri = (a, b, c) => {
        const cx = (a[0] + b[0] + c[0]) / 3;
        const cy = (a[1] + b[1] + c[1]) / 3;
        let col = sample(p, (cx / w) * 0.35 + (cy / h) * 0.65);
        const j = r() - 0.5;
        col = j > 0 ? mix(col, '#ffffff', j * 0.18) : mix(col, '#000000', -j * 0.3);
        ctx.fillStyle = col;
        ctx.strokeStyle = col;
        ctx.beginPath();
        ctx.moveTo(a[0], a[1]);
        ctx.lineTo(b[0], b[1]);
        ctx.lineTo(c[0], c[1]);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      };
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const a = pts[y][x], b = pts[y][x + 1], c = pts[y + 1][x], d = pts[y + 1][x + 1];
          if (r() < 0.5) { tri(a, b, d); tri(a, d, c); } else { tri(a, b, c); tri(b, d, c); }
        }
      }
      grain(ctx, w, h, r, 6);
    },

    // palette: [background, ...shape colors]
    bauhaus(ctx, w, h, r, p) {
      fill(ctx, w, h, p[0]);
      const colors = p.slice(1);
      const pick = () => colors[Math.floor(r() * colors.length)];
      const cols = 3;
      const cell = w / cols;
      const rows = Math.ceil(h / cell);
      const oy = (h - rows * cell) / 2;
      const s = cell / 2;
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const x = col * cell;
          const y = oy + row * cell;
          const kind = Math.floor(r() * 6);
          const rot = Math.floor(r() * 4);
          let cellColor = null;
          if (r() < 0.35) {
            cellColor = pick();
            ctx.fillStyle = cellColor;
            ctx.fillRect(x, y, cell + 0.5, cell + 0.5);
          }
          let fg = pick();
          while (fg === cellColor && colors.length > 1) fg = pick();
          ctx.save();
          ctx.translate(x + s, y + s);
          ctx.rotate((rot * Math.PI) / 2);
          ctx.fillStyle = fg;
          ctx.beginPath();
          switch (kind) {
            case 0: ctx.arc(0, 0, s * 0.8, 0, Math.PI * 2); break;
            case 1: ctx.arc(0, s, s, Math.PI, Math.PI * 2); break;
            case 2: ctx.moveTo(-s, -s); ctx.arc(-s, -s, cell, 0, Math.PI / 2); break;
            case 3: ctx.moveTo(-s, s); ctx.lineTo(s, s); ctx.lineTo(-s, -s); break;
            case 4: for (let i = 0; i < 4; i++) ctx.rect(-s, -s + (i * cell) / 4, cell, cell / 8); break;
            default: ctx.arc(0, 0, s * 0.8, 0, Math.PI * 2); ctx.arc(0, 0, s * 0.4, 0, Math.PI * 2, true);
          }
          ctx.fill();
          ctx.restore();
        }
      }
      grain(ctx, w, h, r, 8);
    },

    // palette: [background, dotTop, dotBottom]
    dots(ctx, w, h, r, p) {
      fill(ctx, w, h, p[0]);
      const cols = 22;
      const sp = w / cols;
      const rows = Math.ceil(h / sp) + 1;
      const fx = w * r();
      const fy = h * (0.2 + r() * 0.6);
      const k = ((2 + r() * 2) * Math.PI * 2) / h;
      const ph = r() * Math.PI * 2;
      const maxD = Math.hypot(w, h);
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const px = (x + 0.5) * sp;
          const py = (y + 0.5) * sp;
          const d = Math.hypot(px - fx, py - fy);
          const v = (0.5 + 0.5 * Math.sin(d * k + ph)) * (1 - (d / maxD) * 0.7);
          const rad = sp * 0.48 * v;
          if (rad < sp * 0.04) continue;
          ctx.fillStyle = mix(p[1], p[2], py / h);
          ctx.beginPath();
          ctx.arc(px, py, rad, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      grain(ctx, w, h, r, 6);
    },

    // palette: [skyTop, skyBottom, sunTop, sunBottom, grid]
    synthwave(ctx, w, h, r, p) {
      const u = w / 1000;
      const hz = h * 0.6;
      const sky = vertical(ctx, 0, hz, [p[0], p[1]]);
      ctx.fillStyle = sky;
      ctx.fillRect(0, 0, w, hz);
      for (let i = 0; i < 150; i++) {
        const s = (0.5 + r() * 1.5) * u * 2;
        ctx.fillStyle = `rgba(255,255,255,${0.2 + r() * 0.6})`;
        ctx.fillRect(r() * w, r() * hz * 0.7, s, s);
      }
      const sr = w * 0.32;
      const sx = w / 2;
      const sy = hz - sr * 0.35;
      const glow = ctx.createRadialGradient(sx, sy, sr * 0.8, sx, sy, sr * 2.2);
      glow.addColorStop(0, rgba(p[3], 0.5));
      glow.addColorStop(1, rgba(p[3], 0));
      ctx.fillStyle = glow;
      ctx.fillRect(0, 0, w, hz);
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, 0, w, hz);
      ctx.clip();
      const sun = ctx.createLinearGradient(0, sy - sr, 0, sy + sr * 0.35);
      sun.addColorStop(0, p[2]);
      sun.addColorStop(1, p[3]);
      ctx.fillStyle = sun;
      ctx.beginPath();
      ctx.arc(sx, sy, sr, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = sky;
      for (let i = 0; i < 7; i++) {
        const t = i / 7;
        ctx.fillRect(sx - sr, sy - sr * 0.55 + t * sr * 0.9, sr * 2, sr * (0.015 + t * 0.05));
      }
      ctx.restore();
      ctx.fillStyle = vertical(ctx, hz, h, [mix(p[0], '#000000', 0.6), mix(p[0], '#000000', 0.2)]);
      ctx.fillRect(0, hz, w, h - hz);
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, hz, w, h - hz);
      ctx.clip();
      ctx.strokeStyle = p[4];
      ctx.lineWidth = 2.5 * u;
      ctx.shadowColor = p[4];
      ctx.shadowBlur = 14 * u;
      ctx.beginPath();
      for (let i = -14; i <= 14; i++) {
        ctx.moveTo(w / 2 + i * w * 0.04, hz);
        ctx.lineTo(w / 2 + i * w * 0.32, h);
      }
      for (let k = 1; k <= 14; k++) {
        const y = hz + (h - hz) * Math.pow(k / 14, 2.2);
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
      }
      ctx.stroke();
      ctx.restore();
      ctx.fillStyle = p[3];
      ctx.fillRect(0, hz - 1.5 * u, w, 3 * u);
      grain(ctx, w, h, r, 8);
    },

    // palette: [background, lineInner, lineOuter]
    contours(ctx, w, h, r, p) {
      const u = w / 1000;
      fill(ctx, w, h, p[0]);
      const cx = w * (0.1 + r() * 0.8);
      const cy = h * (0.15 + r() * 0.7);
      const harm = [];
      for (let j = 2; j <= 5; j++) {
        harm.push([j, (0.05 + r() * 0.08) / (j * 0.6), r() * Math.PI * 2, (r() - 0.5) * 0.6]);
      }
      const sp = 34 * u;
      const far = Math.max(
        Math.hypot(cx, cy), Math.hypot(w - cx, cy),
        Math.hypot(cx, h - cy), Math.hypot(w - cx, h - cy)
      );
      const n = Math.ceil((far * 1.4) / sp);
      ctx.lineJoin = 'round';
      for (let k = 1; k <= n; k++) {
        const base = k * sp;
        const drift = Math.log(k + 1) * 3;
        ctx.beginPath();
        for (let s = 0; s <= 180; s++) {
          const a = (s / 180) * Math.PI * 2;
          let m = 1;
          for (const [j, amp, ph, dr] of harm) m += amp * Math.sin(j * a + ph + dr * drift);
          const x = cx + Math.cos(a) * base * m;
          const y = cy + Math.sin(a) * base * m;
          if (s) ctx.lineTo(x, y); else ctx.moveTo(x, y);
        }
        ctx.closePath();
        ctx.strokeStyle = mix(p[1], p[2], Math.min(1, (k / n) * 1.3));
        ctx.lineWidth = (k % 5 === 0 ? 3.2 : 1.6) * u;
        ctx.stroke();
      }
      grain(ctx, w, h, r, 6);
    },

    // palette: [background, ...blob colors]
    blobs(ctx, w, h, r, p) {
      const u = w / 1000;
      const bg = ctx.createLinearGradient(0, 0, w, h);
      bg.addColorStop(0, p[0]);
      bg.addColorStop(1, mix(p[0], '#000000', 0.15));
      fill(ctx, w, h, bg);
      const cols = p.slice(1);
      const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
      for (let i = 0; i < 6; i++) {
        const cx = r() * w;
        const cy = r() * h;
        const rad = w * (0.22 + r() * 0.3);
        const rot = r() * Math.PI * 2;
        const n = 7;
        const pts = [];
        for (let j = 0; j < n; j++) {
          const a = rot + (j / n) * Math.PI * 2;
          const rr = rad * (0.75 + r() * 0.5);
          pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
        }
        const c = cols[i % cols.length];
        const g = ctx.createLinearGradient(cx - rad, cy - rad, cx + rad, cy + rad);
        g.addColorStop(0, mix(c, '#ffffff', 0.25));
        g.addColorStop(1, c);
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.25)';
        ctx.shadowBlur = 60 * u;
        ctx.shadowOffsetY = 24 * u;
        ctx.fillStyle = g;
        ctx.beginPath();
        const m0 = mid(pts[n - 1], pts[0]);
        ctx.moveTo(m0[0], m0[1]);
        for (let j = 0; j < n; j++) {
          const m = mid(pts[j], pts[(j + 1) % n]);
          ctx.quadraticCurveTo(pts[j][0], pts[j][1], m[0], m[1]);
        }
        ctx.fill();
        ctx.restore();
      }
      grain(ctx, w, h, r, 8);
    },
  };

  // ---------- catalogue ----------

  const CATALOGUE = [
    // Gradient
    ['Aurora', 'Gradient', 'aurora', ['#0b1026', '#3a86ff', '#8338ec', '#ff006e', '#00f5d4']],
    ['Peach Fizz', 'Gradient', 'aurora', ['#ffe5d9', '#ffb4a2', '#e5989b', '#ffcdb2', '#b5838d']],
    ['Lagoon', 'Gradient', 'aurora', ['#012a36', '#29b6f6', '#00e5a0', '#1de9b6', '#0277bd']],
    ['Cotton Candy', 'Gradient', 'aurora', ['#fde2ff', '#a0c4ff', '#ffc6ff', '#bdb2ff', '#caffbf']],
    ['Twilight', 'Gradient', 'linear', ['#0f0c29', '#302b63', '#ff6a88']],
    ['Citrus', 'Gradient', 'linear', ['#f7971e', '#ffd200', '#fff5c0']],
    ['Mint Haze', 'Gradient', 'linear', ['#d4fc79', '#96e6a1', '#4facfe']],
    // Nature
    ['Alpine Dawn', 'Nature', 'mountains', ['#fbc2a4', '#fde4cf', '#fff1e6', '#9a8c98', '#22223b']],
    ['Misty Peaks', 'Nature', 'mountains', ['#cfd8dc', '#eceff1', '#ffffff', '#90a4ae', '#263238']],
    ['Desert Dusk', 'Nature', 'mountains', ['#2b1055', '#f76b1c', '#ffd166', '#a4508b', '#2b1055']],
    ['Pacific', 'Nature', 'waves', ['#a1c4fd', '#c2e9fb', '#4f9dde', '#0a2a66']],
    ['Coral Sea', 'Nature', 'waves', ['#ffecd2', '#fcb69f', '#ff8c94', '#355c7d']],
    ['Starry Ridge', 'Nature', 'night', ['#020111', '#20124d', '#f5f3ce', '#0b0a1f']],
    ['Moonlit Hills', 'Nature', 'night', ['#0b132b', '#1c2541', '#e0e1dd', '#050a14']],
    // Abstract
    ['Ember Facets', 'Abstract', 'lowpoly', ['#1a0b2e', '#d7263d', '#f46036', '#fbb13c']],
    ['Glacier Facets', 'Abstract', 'lowpoly', ['#e0fbfc', '#98c1d9', '#3d5a80', '#293241']],
    ['Topo Sand', 'Abstract', 'contours', ['#efe6d8', '#b08968', '#7f5539']],
    ['Topo Neon', 'Abstract', 'contours', ['#0d1b2a', '#4cc9f0', '#7209b7']],
    ['Liquid Pop', 'Abstract', 'blobs', ['#ffd6e0', '#ff477e', '#7678ed', '#ffbe0b']],
    ['Liquid Ocean', 'Abstract', 'blobs', ['#03045e', '#0077b6', '#00b4d8', '#90e0ef']],
    // Minimal
    ['Sunset Rings', 'Minimal', 'rings', ['#fff4e6', '#ff9f1c', '#ffbf69', '#cb997e', '#e76f51']],
    ['Sage Rings', 'Minimal', 'rings', ['#f1f5ee', '#a3b18a', '#588157', '#dad7cd']],
    ['Bauhaus', 'Minimal', 'bauhaus', ['#f2ebdf', '#e63946', '#1d3557', '#f4a261', '#2a9d8f']],
    ['Bauhaus Pastel', 'Minimal', 'bauhaus', ['#fbf8f3', '#ffadad', '#a0c4ff', '#caffbf', '#fdffb6']],
    ['Halftone Blue', 'Minimal', 'dots', ['#f8f9fa', '#4361ee', '#4cc9f0']],
    ['Halftone Coral', 'Minimal', 'dots', ['#1b1b1e', '#ff6b6b', '#ffd93d']],
    // Dark
    ['Midnight Aurora', 'Dark', 'aurora', ['#000000', '#0d3b66', '#1b998b', '#5f0f40', '#2e294e']],
    ['Obsidian Waves', 'Dark', 'waves', ['#000000', '#111111', '#2b2d42', '#0b0b0f']],
    ['Dark Facets', 'Dark', 'lowpoly', ['#000000', '#141414', '#2d2d2d', '#0a0a0a']],
    ['Carbon Topo', 'Dark', 'contours', ['#0a0a0a', '#3a3a3a', '#6c6c6c']],
    ['Eclipse Rings', 'Dark', 'rings', ['#000000', '#111111', '#1e1e24', '#2a2a33', '#ff2e63']],
    // Retro
    ['Synthwave', 'Retro', 'synthwave', ['#0b0033', '#ff007f', '#ffe600', '#ff3cac', '#00f0ff']],
    ['Outrun Dawn', 'Retro', 'synthwave', ['#1a1033', '#f15bb5', '#fee440', '#f15bb5', '#9b5de5']],
    ['Vaporwave', 'Retro', 'synthwave', ['#2d0b4e', '#ff71ce', '#01cdfe', '#b967ff', '#05ffa1']],
  ];

  const list = CATALOGUE.map(([name, category, gen, palette]) => ({
    id: name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    name,
    category,
    gen,
    palette,
    seed: hash(name),
  }));

  const categories = ['All', ...new Set(list.map((w) => w.category))];

  // Render a wallpaper. `variant` > 0 produces a "remix" with a different seed.
  function render(ctx, w, h, wall, variant) {
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const rand = mulberry32(wall.seed + (variant || 0) * 7919);
    GENS[wall.gen](ctx, w, h, rand, wall.palette);
    ctx.restore();
  }

  global.Walls = { list, categories, render };
})(window);
