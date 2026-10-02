/*
 * Live wallpapers: animated pseudo-3D scenes drawn with Canvas 2D.
 *
 * Each generator takes the usual (ctx, w, h, rand, palette) plus `t`, the
 * time in seconds. Scenes are deterministic for a given seed and time, and
 * loop seamlessly every PERIOD seconds. No grain: it is too slow per frame.
 */
(function () {
  'use strict';

  const { rgba, mix, vertical } = Walls.util;
  const TAU = Math.PI * 2;
  const PERIOD = 24;

  const phaseOf = (t) => ((t % PERIOD) / PERIOD) * TAU;
  const frac = (x) => x - Math.floor(x);

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

  const GENS = {
    // palette: [bgTop, bgBottom, ...orb colors]
    orbs(ctx, w, h, r, p, t) {
      const ph = phaseOf(t);
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
      const colors = p.slice(2);
      const orbs = [];
      for (let i = 0; i < 14; i++) {
        orbs.push({
          x: r(), y: r(), z: 0.35 + r() * 0.65,
          size: 0.08 + r() * 0.1,
          c: colors[i % colors.length],
          k1: 1 + Math.floor(r() * 2), k2: 1 + Math.floor(r() * 2),
          p1: r() * TAU, p2: r() * TAU,
        });
      }
      orbs.sort((a, b) => a.z - b.z);
      for (const o of orbs) {
        // Nearer orbs travel further, which reads as depth.
        const x = (o.x + Math.sin(ph * o.k1 + o.p1) * 0.06 * o.z) * w;
        const y = (o.y + Math.cos(ph * o.k2 + o.p2) * 0.05 * o.z) * h;
        const rad = o.size * o.z * w;
        const c = mix(p[1], o.c, 0.35 + o.z * 0.65);
        glow(ctx, x, y + rad * 0.3, rad * 2.2, c, 0.28 * o.z);
        const g = ctx.createRadialGradient(x - rad * 0.35, y - rad * 0.4, rad * 0.05, x, y, rad);
        g.addColorStop(0, mix(c, '#ffffff', 0.7));
        g.addColorStop(0.4, c);
        g.addColorStop(1, mix(c, '#000000', 0.45));
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(x, y, rad, 0, TAU);
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,0.22)';
        ctx.lineWidth = rad * 0.04;
        ctx.beginPath();
        ctx.arc(x, y, rad * 0.96, Math.PI * 1.05, Math.PI * 1.6);
        ctx.stroke();
      }
    },

    // palette: [bg, core glow, starA, starB]
    warp(ctx, w, h, r, p, t) {
      const u = w / 1000;
      const cx = w / 2;
      const cy = h * 0.45;
      fill(ctx, w, h, p[0]);
      glow(ctx, cx, cy, w * 0.9, p[1], 0.35);
      const f = w * 0.35;
      const loop = t / PERIOD;
      ctx.lineCap = 'round';
      for (let i = 0; i < 260; i++) {
        const a = r() * TAU;
        const rr = 0.15 + r() * 0.85;
        const speed = 1 + Math.floor(r() * 3);
        const z = 0.02 + frac(r() - loop * speed) * 0.98;
        const color = mix(p[2], p[3], r());
        const x3 = Math.cos(a) * rr;
        const y3 = Math.sin(a) * rr;
        const z0 = Math.min(1, z + 0.05);
        const fade = Math.pow(1 - z, 0.7);
        ctx.strokeStyle = rgba(color, fade);
        ctx.lineWidth = (0.8 + fade * 3.6) * u * 1.5;
        ctx.beginPath();
        ctx.moveTo(cx + (x3 * f) / z0, cy + (y3 * f) / z0);
        ctx.lineTo(cx + (x3 * f) / z, cy + (y3 * f) / z);
        ctx.stroke();
      }
    },

    // palette: [bgTop, bgBottom, near dots, far dots]
    dotsphere(ctx, w, h, r, p, t) {
      const ph = phaseOf(t);
      const u = w / 1000;
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
      const cx = w / 2;
      const cy = h * 0.47;
      const R = w * 0.62;
      glow(ctx, cx, cy, R * 1.9, p[2], 0.22);
      const tilt = 0.4 + r() * 0.2 + Math.sin(ph) * 0.12;
      const yaw = ph + r() * TAU;
      const n = 900;
      const pts = [];
      const golden = Math.PI * (3 - Math.sqrt(5));
      for (let i = 0; i < n; i++) {
        const y = 1 - (i / (n - 1)) * 2;
        const rad = Math.sqrt(1 - y * y);
        const a = i * golden;
        let x = Math.cos(a) * rad;
        let z = Math.sin(a) * rad;
        // Rotate around Y (spin), then X (tilt).
        const x1 = x * Math.cos(yaw) - z * Math.sin(yaw);
        const z1 = x * Math.sin(yaw) + z * Math.cos(yaw);
        const y2 = y * Math.cos(tilt) - z1 * Math.sin(tilt);
        const z2 = y * Math.sin(tilt) + z1 * Math.cos(tilt);
        pts.push([x1, y2, z2]);
      }
      pts.sort((a, b) => a[2] - b[2]);
      for (const [x, y, z] of pts) {
        const d = (z + 1) / 2;
        const persp = 1 / (1.6 - z * 0.45);
        ctx.fillStyle = rgba(mix(p[3], p[2], d), 0.2 + d * 0.8);
        ctx.beginPath();
        ctx.arc(cx + x * R * persp, cy + y * R * persp, (1.6 + d * 4) * u * 1.7, 0, TAU);
        ctx.fill();
      }
    },

    // palette: [skyTop, skyBottom, sun, line, ground]
    terrain(ctx, w, h, r, p, t) {
      const u = w / 1000;
      const hz = h * 0.5;
      fill(ctx, w, h, vertical(ctx, 0, hz, [p[0], p[1]]));
      const sunR = w * 0.26;
      glow(ctx, w / 2, hz - sunR * 0.2, sunR * 2.6, p[2], 0.45);
      ctx.fillStyle = vertical(ctx, hz - sunR * 1.2, hz, [p[2], p[1]]);
      ctx.beginPath();
      ctx.arc(w / 2, hz - sunR * 0.2, sunR, Math.PI, TAU);
      ctx.fill();
      ctx.fillStyle = p[4];
      ctx.fillRect(0, hz, w, h - hz);

      const rows = 34;
      const cols = 40;
      const F = h * 0.32;
      const camH = 1.1;
      const waves = [];
      for (let k = 0; k < 3; k++) {
        waves.push([1 + Math.floor(r() * 3), 0.6 + r() * 1.4, r() * TAU, 0.25 + r() * 0.35]);
      }
      // Heights repeat every `rows` world units, so the scroll loops cleanly.
      const height = (x, zw) => {
        let v = 0;
        for (const [kz, kx, ph, amp] of waves) v += Math.sin((zw / rows) * TAU * kz + x * kx + ph) * amp;
        return Math.max(0, v) * (0.3 + Math.min(1, Math.abs(x) / 3));
      };
      const s = (t / PERIOD) * rows;
      const shift = frac(s);
      const base = Math.floor(s);
      const project = (x, z, y) => [w / 2 + (x * F) / z, hz + ((camH - y) * F) / z];
      const rowPts = [];
      for (let i = rows; i >= 1; i--) {
        const z = 0.3 + (i - shift) * 0.55;
        const pts = [];
        for (let c = 0; c <= cols; c++) {
          const x = -7 + (c / cols) * 14;
          pts.push(project(x, z, height(x, i + base)));
        }
        rowPts.push([z, pts]);
      }
      ctx.lineJoin = 'round';
      for (let k = 0; k < rowPts.length - 1; k++) {
        const [zFar, far] = rowPts[k];
        const near = rowPts[k + 1][1];
        const fade = Math.max(0, 1 - zFar / 19);
        // Fill each strip so nearer hills hide the grid behind them.
        ctx.fillStyle = p[4];
        ctx.beginPath();
        far.forEach(([x, y], c) => (c ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
        for (let c = near.length - 1; c >= 0; c--) ctx.lineTo(near[c][0], near[c][1]);
        ctx.closePath();
        ctx.fill();
        ctx.beginPath();
        near.forEach(([x, y], c) => (c ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
        for (let c = 0; c <= cols; c++) {
          ctx.moveTo(far[c][0], far[c][1]);
          ctx.lineTo(near[c][0], near[c][1]);
        }
        ctx.strokeStyle = rgba(p[3], 0.18 * fade);
        ctx.lineWidth = 7 * u;
        ctx.stroke();
        ctx.strokeStyle = rgba(p[3], 0.25 + 0.75 * fade);
        ctx.lineWidth = 1.8 * u;
        ctx.stroke();
      }
    },

    // palette: [bg, ...ribbon colors]
    ribbons(ctx, w, h, r, p, t) {
      const ph = phaseOf(t);
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], mix(p[0], '#000000', 0.35)]));
      const colors = p.slice(1);
      const segs = 110;
      for (let i = 0; i < 4; i++) {
        const c = colors[i % colors.length];
        const bx = 0.18 + (i / 3) * 0.64 + (r() - 0.5) * 0.08;
        const amp = 0.12 + r() * 0.1;
        const freq = 0.8 + r() * 0.8;
        const twists = 1.2 + r() * 1.3;
        const off = r() * TAU;
        const k = 1 + Math.floor(r() * 2);
        const hw = w * (0.07 + r() * 0.04);
        let prev = null;
        for (let s = 0; s <= segs; s++) {
          const v = s / segs;
          const y = (-0.08 + v * 1.16) * h;
          const x = (bx + Math.sin(v * TAU * freq + ph * k + off) * amp) * w;
          const theta = v * twists * TAU + ph * k + off;
          const cos = Math.cos(theta);
          const lift = Math.sin(theta) * hw * 0.18;
          const cur = [x - hw * cos, y - lift, x + hw * cos, y + lift, cos];
          if (prev) {
            const facing = (prev[4] + cos) / 2;
            const light = Math.abs(facing);
            const shade = facing >= 0 ? mix(c, '#ffffff', light * 0.35) : mix(c, '#000000', 0.55 - light * 0.25);
            ctx.fillStyle = mix(mix(c, '#000000', 0.5), shade, 0.35 + light * 0.65);
            ctx.beginPath();
            ctx.moveTo(prev[0], prev[1]);
            ctx.lineTo(prev[2], prev[3]);
            ctx.lineTo(cur[2], cur[3]);
            ctx.lineTo(cur[0], cur[1]);
            ctx.closePath();
            ctx.fill();
            // Overdraw a hairline to hide seams between segments.
            ctx.strokeStyle = ctx.fillStyle;
            ctx.lineWidth = 1;
            ctx.stroke();
          }
          prev = cur;
        }
      }
    },

    // palette: [bgTop, bgBottom, colorA, colorB]
    cubes(ctx, w, h, r, p, t) {
      const ph = phaseOf(t);
      fill(ctx, w, h, vertical(ctx, 0, h, [p[0], p[1]]));
      glow(ctx, w * 0.5, h * 0.35, w * 1.1, p[2], 0.18);
      const light = normalize([-0.4, -0.7, -0.6]);
      const verts = [
        [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
        [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
      ];
      const faces = [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [4, 5, 1, 0], [3, 2, 6, 7]];
      const cubes = [];
      for (let i = 0; i < 10; i++) {
        cubes.push({
          // Stratify x so the cubes spread across the screen.
          x: 0.12 + ((i % 3) + r()) / 3 * 0.76, y: 0.06 + (i / 10) * 0.84 + r() * 0.06, z: 1.2 + r() * 2.4,
          size: 0.06 + r() * 0.06,
          ax: r() * TAU, ay: r() * TAU, kx: 1 + Math.floor(r() * 2), ky: 1 + Math.floor(r() * 2),
          bob: r() * TAU, c: mix(p[2], p[3], r()),
        });
      }
      cubes.sort((a, b) => b.z - a.z);
      for (const cube of cubes) {
        const rx = cube.ax + ph * cube.kx;
        const ry = cube.ay + ph * cube.ky;
        const cxs = cube.x * w;
        const cys = (cube.y + Math.sin(ph + cube.bob) * 0.02) * h;
        const scale = (cube.size * w) / (cube.z * 0.45);
        const pts = verts.map(([x, y, z]) => {
          const y1 = y * Math.cos(rx) - z * Math.sin(rx);
          const z1 = y * Math.sin(rx) + z * Math.cos(rx);
          const x2 = x * Math.cos(ry) + z1 * Math.sin(ry);
          const z2 = -x * Math.sin(ry) + z1 * Math.cos(ry);
          const persp = 1 / (1 + z2 * 0.12);
          return [cxs + x2 * scale * persp, cys + y1 * scale * persp, x2, y1, z2];
        });
        const depthFade = Math.min(1, 1.6 / cube.z);
        for (const f of faces) {
          const [a, b, c] = f.map((i) => pts[i]);
          // Back-face cull in screen space (the viewer looks down +z).
          if ((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) <= 0) continue;
          const n = normalize(cross(sub(b.slice(2), a.slice(2)), sub(c.slice(2), a.slice(2))));
          const lambert = Math.max(0, -(n[0] * light[0] + n[1] * light[1] + n[2] * light[2]));
          const shade = mix(mix(cube.c, '#000000', 0.6), mix(cube.c, '#ffffff', 0.25), 0.2 + lambert * 0.8);
          ctx.fillStyle = mix(p[1], shade, depthFade);
          ctx.beginPath();
          f.forEach((i, k) => (k ? ctx.lineTo(pts[i][0], pts[i][1]) : ctx.moveTo(pts[i][0], pts[i][1])));
          ctx.closePath();
          ctx.fill();
          ctx.strokeStyle = rgba('#ffffff', 0.12 * depthFade);
          ctx.lineWidth = Math.max(1, scale * 0.02);
          ctx.stroke();
        }
      }
    },
  };

  function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
  function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
  function normalize(v) { const l = Math.hypot(v[0], v[1], v[2]) || 1; return [v[0] / l, v[1] / l, v[2] / l]; }

  const LIVE = { live: true };
  Walls.register(GENS, [
    ['Glass Orbs', 'Live', 'orbs', ['#120b2e', '#2b1055', '#ff7ab6', '#7afcff', '#b18cff', '#ffd36e'], LIVE],
    ['Warp Speed', 'Live', 'warp', ['#03030b', '#3a2a8c', '#9ad8ff', '#ffffff'], LIVE],
    ['Dot Sphere', 'Live', 'dotsphere', ['#05101f', '#0b2440', '#7cf3ff', '#2b59c3'], LIVE],
    ['Neon Terrain', 'Live', 'terrain', ['#12002b', '#ff3d8b', '#ffd36e', '#00e5ff', '#07001a'], LIVE],
    ['Ribbons', 'Live', 'ribbons', ['#0d0b1f', '#ff5f6d', '#ffc371', '#7f7fd5', '#43e7c4'], LIVE],
    ['Cube Drift', 'Live', 'cubes', ['#0f1724', '#1d2b45', '#5ee7df', '#b490ca'], LIVE],
  ]);
})();
