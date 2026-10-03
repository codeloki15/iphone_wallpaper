/*
 * Art wallpapers: physical-looking compositions. Torn paper (one sheet
 * ripped away to show another, with the white paper core along the tear),
 * folded silk (satin petals fanning from a corner) and doodle sticker-bombs.
 */
(function () {
  'use strict';

  const { mix, vertical, grain, ridge } = Walls.util;

  const GENS = {
    // palette: [left sheet, right sheet, paper core]
    torn(ctx, w, h, r, p) {
      tear(ctx, w, h, r, p, false);
    },

    // The same tear running corner to corner: dark above, paper below.
    // palette: [top sheet, bottom sheet, paper core]
    tornDiagonal(ctx, w, h, r, p) {
      tear(ctx, w, h, r, p, true);
    },

    // A sticker-bomb of hand-drawn doodles. With a 4th color, a solid panel
    // covers the left side to hold a clock, like a split-screen setup.
    // palette: [background, ink, fill, (panel)]
    doodle(ctx, w, h, r, p) {
      drawDoodles(ctx, w, h, r, p);
      grain(ctx, w, h, r, 8);
    },

    // palette: [background, ...petal colors]
    silk(ctx, w, h, r, p) {
      const u = w / 1000;
      const bg = ctx.createRadialGradient(w * 0.3, h * 0.25, 0, w * 0.3, h * 0.25, h);
      bg.addColorStop(0, mix(p[0], p[1], 0.18));
      bg.addColorStop(1, p[0]);
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, w, h);
      // Ribbons fan out from a hub just off the left edge and sweep across.
      const hx = -w * (0.08 + r() * 0.06);
      const hy = h * (0.3 + r() * 0.08);
      const colors = p.slice(1);
      const count = 9;
      const petals = [];
      for (let i = 0; i < count; i++) {
        const t = i / (count - 1);
        petals.push({
          ang: -0.5 + t * 1.45 + (r() - 0.5) * 0.1,
          len: h * (0.62 + r() * 0.3) * (1 - Math.abs(t - 0.4) * 0.45),
          wid: 0.26 + r() * 0.1,
          twist: r() < 0.25 ? -1 : 1,
          c: colors[i % colors.length],
        });
      }
      // Longest petals first, so the shorter ones fold over them.
      petals.sort((a, b) => b.len - a.len);
      for (const pt of petals) {
        const dx = Math.cos(pt.ang);
        const dy = Math.sin(pt.ang);
        const px = -dy;
        const py = dx;
        const L = pt.len;
        const W = L * pt.wid;
        const at = (a, b) => [hx + dx * L * a + px * W * b * pt.twist, hy + dy * L * a + py * W * b * pt.twist];
        const tip = at(1, 0.7);
        const shape = new Path2D();
        shape.moveTo(hx, hy);
        shape.bezierCurveTo(...at(0.3, 1.7), ...at(0.72, 1.5), ...tip);
        shape.bezierCurveTo(...at(0.8, -0.1), ...at(0.32, -0.75), hx, hy);
        // A gradient across the petal reads as a satin fold.
        const [mx, my] = at(0.55, 0.1);
        const fold = ctx.createLinearGradient(mx - px * W * pt.twist, my - py * W * pt.twist, mx + px * W * pt.twist, my + py * W * pt.twist);
        fold.addColorStop(0, mix(pt.c, '#000000', 0.6));
        fold.addColorStop(0.4, pt.c);
        fold.addColorStop(0.58, mix(pt.c, '#ffffff', 0.42));
        fold.addColorStop(0.72, pt.c);
        fold.addColorStop(1, mix(pt.c, '#000000', 0.45));
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.5)';
        ctx.shadowBlur = 60 * u;
        ctx.shadowOffsetY = 20 * u;
        ctx.fillStyle = fold;
        ctx.fill(shape);
        ctx.restore();
        ctx.strokeStyle = `rgba(255,255,255,0.18)`;
        ctx.lineWidth = 1.5 * u;
        ctx.stroke(shape);
      }
      grain(ctx, w, h, r, 9);
    },
  };


  // One sheet torn away to reveal another. Points run along the tear and
  // are pushed sideways by noise; `nl` points toward the revealed sheet.
  function tear(ctx, w, h, r, p, diagonal) {
    const u = w / 1000;
    const n = 257;
    const coarse = ridge(r, n, 0.62);
    const fine = ridge(r, n, 0.85);
    const fiber = ridge(r, n, 0.9);
    let a;
    let b;
    let amp;
    if (diagonal) {
      a = [-w * 0.06, h * (0.7 + r() * 0.06)];
      b = [w * 1.06, h * (0.3 + r() * 0.06)];
      amp = h * 0.06;
    } else {
      const edgeX = w * (0.5 + (r() - 0.5) * 0.08);
      a = [edgeX, -h * 0.02];
      b = [edgeX, h * 1.02];
      amp = w * 0.3;
    }
    const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const dx = (b[0] - a[0]) / len;
    const dy = (b[1] - a[1]) / len;
    const nl = diagonal ? [-dy, dx] : [dy, -dx];
    const pts = coarse.map((v, i) => {
      const t = i / (n - 1);
      const off = (v - 0.5) * amp + (fine[i] - 0.5) * w * 0.035;
      return [a[0] + (b[0] - a[0]) * t + nl[0] * off, a[1] + (b[1] - a[1]) * t + nl[1] * off];
    });
    // The exposed core is widest where the tear wanders furthest.
    const core = pts.map(([x, y], i) => {
      const k = w * (0.016 + Math.abs(fiber[i] - 0.5) * 0.07);
      return [x + nl[0] * k, y + nl[1] * k];
    });

    ctx.fillStyle = vertical(ctx, 0, h, [mix(p[1], '#ffffff', 0.1), mix(p[1], '#000000', 0.06)]);
    ctx.fillRect(0, 0, w, h);

    // Core strip, casting a soft shadow on the revealed sheet.
    const strip = new Path2D();
    pts.forEach(([x, y], i) => (i ? strip.lineTo(x, y) : strip.moveTo(x, y)));
    for (let i = core.length - 1; i >= 0; i--) strip.lineTo(core[i][0], core[i][1]);
    strip.closePath();
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.32)';
    ctx.shadowBlur = 36 * u;
    ctx.shadowOffsetX = nl[0] * 12 * u;
    ctx.shadowOffsetY = nl[1] * 12 * u;
    ctx.fillStyle = vertical(ctx, 0, h, [p[2], mix(p[2], p[1], 0.25)]);
    ctx.fill(strip);
    ctx.restore();

    // Torn fibres: short strands across the core.
    ctx.save();
    ctx.clip(strip);
    ctx.lineCap = 'round';
    for (let i = 0; i < 520; i++) {
      const k = Math.floor(r() * (n - 1));
      const t = r();
      const x = pts[k][0] + (core[k][0] - pts[k][0]) * t;
      const y = pts[k][1] + (core[k][1] - pts[k][1]) * t;
      ctx.strokeStyle = r() < 0.5 ? 'rgba(255,255,255,0.5)' : `rgba(0,0,0,${0.05 + r() * 0.06})`;
      ctx.lineWidth = (0.6 + r() * 1.4) * u;
      const sx = (r() - 0.3) * 18 * u;
      const sy = (r() - 0.5) * 10 * u;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + nl[0] * sx - nl[1] * sy, y + nl[1] * sx + nl[0] * sy);
      ctx.stroke();
    }
    ctx.restore();

    // The torn sheet on top, with a slight lip of shadow along its edge.
    const sheet = new Path2D();
    pts.forEach(([x, y], i) => (i ? sheet.lineTo(x, y) : sheet.moveTo(x, y)));
    const corners = diagonal
      ? [[w * 1.1, -h * 0.1], [-w * 0.1, -h * 0.1]]
      : [[-w * 0.1, h * 1.05], [-w * 0.1, -h * 0.05]];
    corners.forEach(([x, y]) => sheet.lineTo(x, y));
    sheet.closePath();
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.28)';
    ctx.shadowBlur = 10 * u;
    ctx.shadowOffsetX = nl[0] * 3 * u;
    ctx.shadowOffsetY = nl[1] * 3 * u;
    ctx.fillStyle = vertical(ctx, 0, h, [mix(p[0], '#ffffff', 0.06), mix(p[0], '#000000', 0.12)]);
    ctx.fill(sheet);
    ctx.restore();
    ctx.save();
    ctx.clip(sheet);
    const mx = (a[0] + b[0]) / 2;
    const my = (a[1] + b[1]) / 2;
    const lip = ctx.createLinearGradient(mx - nl[0] * w * 0.25, my - nl[1] * w * 0.25, mx + nl[0] * w * 0.05, my + nl[1] * w * 0.05);
    lip.addColorStop(0, 'rgba(0,0,0,0)');
    lip.addColorStop(1, 'rgba(0,0,0,0.12)');
    ctx.fillStyle = lip;
    ctx.fillRect(0, 0, w, h);
    ctx.restore();
    grain(ctx, w, h, r, 12);
  }

  // ---------- doodles ----------

  const TAU = Math.PI * 2;

  function star(ctx, spikes, outer, inner) {
    ctx.beginPath();
    for (let i = 0; i < spikes * 2; i++) {
      const rad = i % 2 ? inner : outer;
      const ang = (i / (spikes * 2)) * TAU - Math.PI / 2;
      ctx.lineTo(Math.cos(ang) * rad, Math.sin(ang) * rad);
    }
    ctx.closePath();
  }

  function rounded(ctx, x, y, w, h, rad) {
    ctx.beginPath();
    ctx.moveTo(x + rad, y);
    ctx.arcTo(x + w, y, x + w, y + h, rad);
    ctx.arcTo(x + w, y + h, x, y + h, rad);
    ctx.arcTo(x, y + h, x, y, rad);
    ctx.arcTo(x, y, x + w, y, rad);
    ctx.closePath();
  }

  // Each sticker draws around (0, 0) within a radius of about 1 unit.
  // fillStroke() fills with the paper color and outlines in ink.
  const STICKERS = {
    bolt(ctx, fs) {
      ctx.beginPath();
      [[0.15, -1], [-0.45, 0.1], [-0.02, 0.1], [-0.2, 1], [0.48, -0.2], [0.05, -0.2], [0.3, -1]].forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      ctx.closePath();
      fs();
    },
    dice(ctx, fs, ink) {
      rounded(ctx, -0.8, -0.8, 1.6, 1.6, 0.3);
      fs();
      ctx.fillStyle = ink;
      [[-0.4, -0.4], [0, 0], [0.4, 0.4], [0.4, -0.4], [-0.4, 0.4]].forEach(([x, y]) => {
        ctx.beginPath();
        ctx.arc(x, y, 0.13, 0, TAU);
        ctx.fill();
      });
    },
    star(ctx, fs) {
      star(ctx, 5, 1, 0.45);
      fs();
    },
    smiley(ctx, fs, ink) {
      ctx.beginPath();
      ctx.arc(0, 0, 0.9, 0, TAU);
      fs();
      ctx.fillStyle = ink;
      [-0.3, 0.3].forEach((x) => {
        ctx.beginPath();
        ctx.ellipse(x, -0.2, 0.1, 0.18, 0, 0, TAU);
        ctx.fill();
      });
      ctx.beginPath();
      ctx.arc(0, 0.05, 0.5, 0.2 * Math.PI, 0.8 * Math.PI);
      ctx.stroke();
    },
    eye(ctx, fs, ink) {
      ctx.beginPath();
      ctx.moveTo(0, -1);
      ctx.lineTo(0.95, 0.75);
      ctx.lineTo(-0.95, 0.75);
      ctx.closePath();
      fs();
      ctx.beginPath();
      ctx.moveTo(-0.45, 0.25);
      ctx.quadraticCurveTo(0, -0.15, 0.45, 0.25);
      ctx.quadraticCurveTo(0, 0.6, -0.45, 0.25);
      ctx.stroke();
      ctx.fillStyle = ink;
      ctx.beginPath();
      ctx.arc(0, 0.25, 0.14, 0, TAU);
      ctx.fill();
    },
    shades(ctx, fs, ink) {
      [-0.5, 0.5].forEach((x) => {
        rounded(ctx, x - 0.42, -0.3, 0.84, 0.62, 0.22);
        fs();
      });
      ctx.beginPath();
      ctx.moveTo(-0.08, -0.1);
      ctx.quadraticCurveTo(0, -0.22, 0.08, -0.1);
      ctx.stroke();
      ctx.strokeStyle = ink;
      [-0.5, 0.5].forEach((x) => {
        ctx.beginPath();
        ctx.moveTo(x - 0.2, 0.2);
        ctx.lineTo(x + 0.05, -0.2);
        ctx.moveTo(x - 0.02, 0.22);
        ctx.lineTo(x + 0.2, -0.12);
        ctx.stroke();
      });
    },
    pizza(ctx, fs, ink) {
      ctx.beginPath();
      ctx.moveTo(0, 1);
      ctx.lineTo(-0.75, -0.6);
      ctx.quadraticCurveTo(0, -1.05, 0.75, -0.6);
      ctx.closePath();
      fs();
      ctx.beginPath();
      ctx.moveTo(-0.62, -0.38);
      ctx.quadraticCurveTo(0, -0.8, 0.62, -0.38);
      ctx.stroke();
      ctx.fillStyle = ink;
      [[-0.2, -0.2], [0.22, -0.1], [0, 0.35]].forEach(([x, y]) => {
        ctx.beginPath();
        ctx.arc(x, y, 0.14, 0, TAU);
        ctx.fill();
      });
    },
    coin(ctx, fs) {
      ctx.beginPath();
      ctx.arc(0, 0, 0.85, 0, TAU);
      fs();
      ctx.beginPath();
      ctx.arc(0, 0, 0.6, 0, TAU);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, -0.38);
      ctx.lineTo(0, 0.38);
      ctx.moveTo(0.2, -0.2);
      ctx.quadraticCurveTo(0, -0.32, -0.2, -0.15);
      ctx.quadraticCurveTo(0.22, 0.05, 0.2, 0.2);
      ctx.quadraticCurveTo(0, 0.34, -0.2, 0.2);
      ctx.stroke();
    },
    heart(ctx, fs) {
      ctx.beginPath();
      ctx.moveTo(0, 0.85);
      ctx.bezierCurveTo(-1.2, 0, -0.7, -1, 0, -0.4);
      ctx.bezierCurveTo(0.7, -1, 1.2, 0, 0, 0.85);
      fs();
    },
    bubble(ctx, fs, ink) {
      ctx.beginPath();
      ctx.ellipse(0, -0.1, 0.95, 0.7, 0, 0, TAU);
      fs();
      ctx.beginPath();
      ctx.moveTo(-0.3, 0.5);
      ctx.lineTo(-0.55, 0.95);
      ctx.lineTo(0.05, 0.58);
      ctx.stroke();
      ctx.fillStyle = ink;
      [-0.35, 0, 0.35].forEach((x) => {
        ctx.beginPath();
        ctx.arc(x, -0.1, 0.09, 0, TAU);
        ctx.fill();
      });
    },
    hand(ctx, fs) {
      // A pointing hand: palm plus an outstretched finger.
      rounded(ctx, -0.8, -0.35, 0.95, 0.9, 0.3);
      fs();
      rounded(ctx, 0.05, -0.32, 0.95, 0.3, 0.15);
      fs();
      [0.05, 0.25].forEach((y) => {
        rounded(ctx, -0.05, y, 0.42, 0.22, 0.11);
        fs();
      });
    },
  };

  function drawDoodles(ctx, w, h, r, p) {
    const u = w / 1000;
    ctx.fillStyle = p[0];
    ctx.fillRect(0, 0, w, h);
    // Halftone dots behind everything.
    ctx.fillStyle = mix(p[0], p[1], 0.25);
    const step = 26 * u;
    for (let y = 0; y < h; y += step) {
      for (let x = (y / step) % 2 ? step / 2 : 0; x < w; x += step) {
        ctx.beginPath();
        ctx.arc(x, y, 2.4 * u, 0, TAU);
        ctx.fill();
      }
    }
    const kinds = Object.keys(STICKERS);
    const cell = w / 3.1;
    const cols = Math.ceil(w / cell) + 1;
    const rows = Math.ceil(h / cell) + 1;
    const items = [];
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        items.push({
          x: (col + (row % 2) * 0.5 + (r() - 0.5) * 0.5) * cell,
          y: (row + (r() - 0.5) * 0.5) * cell,
          size: cell * (0.44 + r() * 0.18),
          rot: (r() - 0.5) * 1.4,
          kind: kinds[Math.floor(r() * kinds.length)],
          shade: r(),
        });
      }
    }
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    for (const it of items) {
      ctx.save();
      ctx.translate(it.x, it.y);
      ctx.rotate(it.rot);
      ctx.scale(it.size, it.size);
      ctx.lineWidth = (7 * u) / it.size;
      ctx.strokeStyle = p[1];
      const fillColor = mix(p[2], p[0], it.shade * 0.35);
      const fs = () => {
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.35)';
        ctx.shadowBlur = 10 * u;
        ctx.shadowOffsetY = 5 * u;
        ctx.fillStyle = fillColor;
        ctx.fill();
        ctx.restore();
        ctx.stroke();
      };
      STICKERS[it.kind](ctx, fs, p[1]);
      ctx.restore();
    }
    if (p[3]) {
      // The clock panel, with a hard edge and a soft shadow on the doodles.
      const pw = w * 0.62;
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,0.5)';
      ctx.shadowBlur = 40 * u;
      ctx.shadowOffsetX = 10 * u;
      ctx.fillStyle = vertical(ctx, 0, h, [mix(p[3], '#ffffff', 0.05), p[3]]);
      ctx.fillRect(0, 0, pw, h);
      ctx.restore();
    }
  }

  Walls.register(GENS, [
    ['Torn Terracotta', 'Art', 'torn', ['#8f5b3c', '#e6bf9e', '#f7ebdd']],
    ['Torn Sage', 'Art', 'torn', ['#5c7762', '#e0e6d6', '#f6f3ea']],
    ['Torn Midnight', 'Art', 'torn', ['#1d2842', '#c7d1e4', '#eef1f7']],
    ['Silk Rose', 'Art', 'silk', ['#16090f', '#e46a8c', '#f5a9bc', '#b0365a']],
    ['Silk Emerald', 'Art', 'silk', ['#04120d', '#1fa37a', '#82e3c4', '#0c6a4f']],
    ['Silk Amber', 'Art', 'silk', ['#120a03', '#e3992b', '#ffd38a', '#a2570b']],
    ['Torn Mono', 'Art', 'tornDiagonal', ['#0b0b0d', '#ebe8ee', '#ffffff']],
    ['Torn Graphite', 'Art', 'tornDiagonal', ['#131315', '#4c4a51', '#76737c']],
    ['Doodle Noir', 'Art', 'doodle', ['#2a2a2d', '#0e0e10', '#d9d9de']],
    ['Doodle Panel', 'Art', 'doodle', ['#2a2a2d', '#0e0e10', '#d9d9de', '#29292c']],
    ['Doodle Pop', 'Art', 'doodle', ['#ffd23f', '#1b1b1f', '#ffffff']],
  ]);
})();
