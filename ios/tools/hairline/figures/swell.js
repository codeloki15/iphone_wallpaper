/**
 * Swell: a tray of 36 pillars with a wave rolling across it, corner to
 * corner, by itself. The pillars on the crest take the bright stroke, so a
 * bright band travels with the wave. The pointer presses the water flat: the
 * pillars near it sink toward the floor, the nearest most, each on its own
 * spring. The slider is how far the calm reaches, in cells.
 *
 * The pattern: a continuous field under ambient motion. The wave is a
 * function of the clock alone and repeats every four seconds; the pointer
 * only scales it, and is tested on the ground plane, which never moves.
 */
const {
  Cam, clamp, facing, fit, prism, proj, rings, unproj, spring, stepS,
  mk, pointer, put, register, disposer, solid,
} = HL;

const N = 6, CELL = 17, FOOT = 13, LOW = 5, HIGH = 44, EXT = N * CELL, PB = 5, LOOP = 4000;

/** How much of the wave is left u radii from the pointer: none under it, all of it past the edge. */
const calm = (u) => (u >= 1 ? 1 : u <= 0.3 ? 0.06 : 0.06 + ((u - 0.3) / 0.7) ** 2 * 0.94);

function mount({ stage, svg, read }, value) {
  const bag = disposer();
  const C = Cam(45, 0.5, 1.7);
  fit(C, [[-6, -6, -PB], [EXT + 6, EXT + 6, -PB], [EXT + 6, -6, -PB], [-6, EXT + 6, -PB], [0, 0, HIGH], [EXT, EXT, HIGH * 0.4]], 200, 166);
  const P = proj(C), front = facing(C);
  let R = value * CELL, over = null;

  const g = mk("g", {}, svg), cols = [];
  const [pr, pi] = rings(-6, -6, EXT + 6, EXT + 6, 9, 2.2);
  put(solid(g), prism(P, front, pr, pi, -PB, 0));
  // Diagonal by diagonal from the far corner, so appending is painting back to front.
  for (let s = 0; s <= 2 * (N - 1); s++) for (let i = 0; i < N; i++) {
    const j = s - i;
    if (j < 0 || j >= N) continue;
    const x0 = i * CELL + (CELL - FOOT) / 2, y0 = j * CELL + (CELL - FOOT) / 2;
    const [ring, inner] = rings(x0, y0, x0 + FOOT, y0 + FOOT, 3, 1);
    cols.push({ i, j, ring, inner, keep: spring(1, { eps: 0.002 }), el: solid(g), drawn: NaN, lit: false });
  }

  /** The wave at a pillar, 0 to 1: one long swell along the diagonal and a small cross ripple at twice its pace. */
  function wave(c, now) {
    const t = (now % LOOP) / LOOP;
    const a = Math.sin(2 * Math.PI * (t - (c.i + c.j) / 9));
    const b = Math.sin(2 * Math.PI * (2 * t - (c.i - c.j) / 5));
    return clamp(0.5 + 0.42 * a + 0.08 * b, 0, 1);
  }

  const B = register(stage, (dt, now) => {
    for (const c of cols) {
      stepS(c.keep, dt);
      const w = wave(c, now) * clamp(c.keep.x, 0, 1);
      const h = Math.round((LOW + (HIGH - LOW) * w) * 10) / 10;
      if (h !== c.drawn) {
        c.drawn = h;
        put(c.el, prism(P, front, c.ring, c.inner, 0, h));
      }
      const lit = w > 0.82;
      if (lit !== c.lit) { c.lit = lit; c.el.sil.classList.toggle("hi", lit); }
    }
    return true;
  });
  bag.add(B.unregister);

  function retarget() {
    for (const c of cols) {
      if (!over) { c.keep.t = 1; continue; }
      const dx = (c.i + 0.5) * CELL - over[0], dy = (c.j + 0.5) * CELL - over[1];
      c.keep.t = calm(Math.hypot(dx, dy) / R);
    }
    if (over) {
      const i = clamp(Math.floor(over[0] / CELL), 0, N - 1), j = clamp(Math.floor(over[1] / CELL), 0, N - 1);
      read.textContent = `calm ${i}·${j}`;
    } else read.textContent = "rest";
    B.wake();
  }

  bag.add(pointer(stage, {
    move: (p) => { over = unproj(C, p[0], p[1], 0); retarget(); },
    leave: () => { over = null; retarget(); },
  }));
  bag.add(() => svg.replaceChildren());

  return {
    set: (v) => { R = v * CELL; if (over) retarget(); },
    destroy: bag.dispose,
  };
}

hairline({
  name: "swell",
  means: "A wave rolls across a tray of pillars; the pointer presses the water flat around it.",
  rules: [1, 3, 5, 7],
  range: [1.6, 2.8, 4.5],
  mount,
});
