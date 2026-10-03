/*
 * Art wallpapers: physical-looking compositions. Torn paper (one sheet
 * ripped away to show another, with the white paper core along the tear)
 * and folded silk (satin petals fanning from a corner).
 */
(function () {
  'use strict';

  const { mix, vertical, grain, ridge } = Walls.util;

  const GENS = {
    // palette: [left sheet, right sheet, paper core]
    torn(ctx, w, h, r, p) {
      const u = w / 1000;
      const n = 257;
      const coarse = ridge(r, n, 0.62);
      const fine = ridge(r, n, 0.85);
      const fiber = ridge(r, n, 0.9);
      const edgeX = w * (0.5 + (r() - 0.5) * 0.08);
      const pts = coarse.map((v, i) => [edgeX + (v - 0.5) * w * 0.3 + (fine[i] - 0.5) * w * 0.035, -h * 0.02 + (i / (n - 1)) * h * 1.04]);
      // The exposed core is widest where the tear wanders furthest.
      const core = pts.map(([x, y], i) => [x + w * (0.016 + Math.abs(fiber[i] - 0.5) * 0.07), y]);

      ctx.fillStyle = vertical(ctx, 0, h, [mix(p[1], '#ffffff', 0.1), mix(p[1], '#000000', 0.06)]);
      ctx.fillRect(0, 0, w, h);

      // Core strip, casting a soft shadow on the right-hand sheet.
      const strip = new Path2D();
      pts.forEach(([x, y], i) => (i ? strip.lineTo(x, y) : strip.moveTo(x, y)));
      for (let i = core.length - 1; i >= 0; i--) strip.lineTo(core[i][0], core[i][1]);
      strip.closePath();
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,0.32)';
      ctx.shadowBlur = 36 * u;
      ctx.shadowOffsetX = 12 * u;
      ctx.fillStyle = vertical(ctx, 0, h, [p[2], mix(p[2], p[1], 0.25)]);
      ctx.fill(strip);
      ctx.restore();

      // Torn fibres: short strands across the core.
      ctx.save();
      ctx.clip(strip);
      ctx.lineCap = 'round';
      for (let i = 0; i < 520; i++) {
        const k = Math.floor(r() * (n - 1));
        const [x0, y0] = pts[k];
        const x1 = core[k][0];
        const x = x0 + (x1 - x0) * r();
        ctx.strokeStyle = r() < 0.5 ? 'rgba(255,255,255,0.5)' : `rgba(0,0,0,${0.05 + r() * 0.06})`;
        ctx.lineWidth = (0.6 + r() * 1.4) * u;
        ctx.beginPath();
        ctx.moveTo(x, y0);
        ctx.lineTo(x + (r() - 0.3) * 18 * u, y0 + (r() - 0.5) * 10 * u);
        ctx.stroke();
      }
      ctx.restore();

      // Left sheet on top, with a slight lip of shadow along its edge.
      const left = new Path2D();
      left.moveTo(-w * 0.1, -h * 0.05);
      pts.forEach(([x, y]) => left.lineTo(x, y));
      left.lineTo(-w * 0.1, h * 1.05);
      left.closePath();
      ctx.save();
      ctx.shadowColor = 'rgba(0,0,0,0.28)';
      ctx.shadowBlur = 10 * u;
      ctx.shadowOffsetX = 3 * u;
      ctx.fillStyle = vertical(ctx, 0, h, [mix(p[0], '#ffffff', 0.06), mix(p[0], '#000000', 0.12)]);
      ctx.fill(left);
      ctx.restore();
      ctx.save();
      ctx.clip(left);
      const lip = ctx.createLinearGradient(edgeX - w * 0.2, 0, edgeX + w * 0.1, 0);
      lip.addColorStop(0, 'rgba(0,0,0,0)');
      lip.addColorStop(1, 'rgba(0,0,0,0.12)');
      ctx.fillStyle = lip;
      ctx.fillRect(0, 0, w, h);
      ctx.restore();
      grain(ctx, w, h, r, 12);
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

  Walls.register(GENS, [
    ['Torn Terracotta', 'Art', 'torn', ['#8f5b3c', '#e6bf9e', '#f7ebdd']],
    ['Torn Sage', 'Art', 'torn', ['#5c7762', '#e0e6d6', '#f6f3ea']],
    ['Torn Midnight', 'Art', 'torn', ['#1d2842', '#c7d1e4', '#eef1f7']],
    ['Silk Rose', 'Art', 'silk', ['#16090f', '#e46a8c', '#f5a9bc', '#b0365a']],
    ['Silk Emerald', 'Art', 'silk', ['#04120d', '#1fa37a', '#82e3c4', '#0c6a4f']],
    ['Silk Amber', 'Art', 'silk', ['#120a03', '#e3992b', '#ffd38a', '#a2570b']],
  ]);
})();
