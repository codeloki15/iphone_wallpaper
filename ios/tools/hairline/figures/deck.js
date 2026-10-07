/**
 * Deck: a record player. A plinth on feet, a platter with a record turning on
 * it by itself, one turn every two seconds, and a tone arm riding the groove
 * from its pivot, with a counterweight behind and a headshell in front. The
 * record's label is pressed off-centre, so it swings round the spindle and
 * shows the turn; it carries the bright stroke, and the arm sways a little
 * with it. The pointer cues the arm: it lifts and swings clear of the record
 * on a spring, and takes the bright. The slider is how far it swings, in
 * degrees.
 *
 * The pattern: ambient motion from the clock alone (the turn is a function of
 * `now`), and one spring for the pointer, tested on the plinth's top plane.
 */
const {
  Cam, circ, clamp, facing, fit, hull, poly, prism, proj, rad, ringAt, rings, rrect, seg, unproj,
  spring, stepS, flatDot, mk, place, pointer, put, register, disposer, solid,
} = HL;

const LOOP = 2000, X0 = -2, Y0 = -2, X1 = 128, Y1 = 98, TOP = 10;
const CX = 46, CY = 50, RZ = 15.5;          // the spindle, and the record's playing face
const PX = 106, PY = 18, LEN = 45.6;        // the arm's pivot, and its length to the stylus
const BASE = Math.atan2(54 - PY, 78 - PX);  // the arm's bearing with the stylus in the groove
const ECC = 6.5, LAB = 12;                    // how far off-centre the label is, and its radius

/** A circle of radius R round (cx, cy), as a ring. */
const ringC = (R, cx, cy, n) => circ(R, n || 40).map((s) => ({ ...s, u: s.u + cx, v: s.v + cy }));
/** A ring drawn in the arm's own frame, turned by a round the pivot. */
const turn = (ring, a) => {
  const c = Math.cos(a), s = Math.sin(a);
  return ring.map((q) => ({ ...q, u: PX + q.u * c - q.v * s, v: PY + q.u * s + q.v * c, nu: q.nu * c - q.nv * s, nv: q.nu * s + q.nv * c }));
};
/** A rounded bar in the arm's frame: [ring, inner]. */
const bar = (u0, v0, u1, v1, r, b) => [rrect(u0, v0, u1, v1, r, 4), rrect(u0 + b, v0 + b, u1 - b, v1 - b, r - b, 4)];

function mount({ stage, svg, read }, value) {
  const bag = disposer();
  const C = Cam(45, 0.5, 2);
  fit(C, [[X0, Y0, -5], [X1, Y1, -5], [X1, Y0, -5], [X0, Y1, -5], [116, 6, 28], [X0, Y0, TOP]], 200, 166);
  const P = proj(C), front = facing(C);
  let swing = value, over = false;
  const cue = spring(0, { eps: 0.002 });

  const g = mk("g", {}, svg);
  const cyl = (cx, cy, R, z0, z1, b, n) => {
    const el = solid(g);
    put(el, prism(P, front, ringC(R, cx, cy, n), ringC(R - b, cx, cy, n), z0, z1));
    return el;
  };

  // Back to front: the feet, the plinth over them, then what stands on it.
  cyl(X1 - 12, Y0 + 12, 6, -5, 0, 1.2, 16);
  cyl(X0 + 12, Y1 - 12, 6, -5, 0, 1.2, 16);
  cyl(X1 - 12, Y1 - 12, 6, -5, 0, 1.2, 16);
  const [pr, pi] = rings(X0, Y0, X1, Y1, 10, 2.2);
  put(solid(g), prism(P, front, pr, pi, 0, TOP));

  // The platter, and the record on it: a thin plate with two grooves.
  cyl(CX, CY, 39, TOP, 14, 1.4, 56);
  const rec = solid(g), disc = ringC(36, CX, CY, 56);
  put(rec, {
    sil: poly(hull(ringAt(P, disc, 14).concat(ringAt(P, disc, RZ)))),
    crease: poly(ringAt(P, ringC(30, CX, CY, 48), RZ)) + poly(ringAt(P, ringC(23.5, CX, CY, 40), RZ)),
  });

  // The label, pressed off-centre, with one dot printed near its edge; the spindle through it.
  const label = solid(g);
  label.sil.classList.add("hi");
  const mark = flatDot(g, C, 1.5, "dot");
  cyl(CX, CY, 1.9, RZ, 21, 0.6, 12);

  // The tone arm: a pivot post, a counterweight behind it, the tube, and the headshell.
  cyl(PX, PY, 5.5, TOP, 20, 1.2, 20);
  const weight = solid(g), tube = solid(g), head = solid(g);
  const wB = bar(-21, -5.5, -9, 5.5, 4.5, 1.2), tB = bar(-10, -1.5, LEN - 6, 1.5, 1.5, 0.5), hB = bar(LEN - 8, -4, LEN + 5, 4, 2, 1);

  // The controls, nearest the viewer: a start lever and a speed knob with its tick.
  const [lr, li] = rings(82, 85, 99, 92, 3, 1);
  put(solid(g), prism(P, front, lr, li, TOP, 12.5));
  const knob = prism(P, front, ringC(6.5, 113, 87, 20), ringC(5.2, 113, 87, 20), TOP, 15);
  knob.crease += seg(P(113, 87, 15), P(108.4, 90.4, 15));
  put(solid(g), knob);

  let armKey = NaN, lit = false;
  function drawArm(a, lift) {
    const key = Math.round(a * 2000) + Math.round(lift * 50) * 1e5;
    if (key === armKey) return;
    armKey = key;
    put(weight, prism(P, front, turn(wB[0], a), turn(wB[1], a), 15.5, 26.5));
    put(tube, prism(P, front, turn(tB[0], a), turn(tB[1], a), 20 + lift, 22.6 + lift));
    put(head, prism(P, front, turn(hB[0], a), turn(hB[1], a), 16.6 + lift, 22.6 + lift));
  }

  const B = register(stage, (dt, now) => {
    stepS(cue, dt);
    const c = clamp(cue.x, 0, 1);
    // The turn is the clock's alone: one revolution a loop, clockwise seen from above.
    const a = 2 * Math.PI * ((now % LOOP) / LOOP);
    const lx = CX + ECC * Math.cos(a), ly = CY + ECC * Math.sin(a);
    put(label, { sil: poly(ringAt(P, ringC(LAB, lx, ly, 28), RZ + 0.1)), crease: "" });
    place(mark, P(CX + (ECC + LAB - 4.5) * Math.cos(a), CY + (ECC + LAB - 4.5) * Math.sin(a), RZ + 0.1));
    // The stylus follows the off-centre groove out and back; cued, the arm lifts and swings clear.
    const sway = rad(1.8) * Math.cos(a - rad(7.1)) * (1 - c);
    drawArm(BASE - sway - rad(swing) * c, 6 * c);
    const now_lit = over;
    if (now_lit !== lit) {
      lit = now_lit;
      head.sil.classList.toggle("hi", lit);
      label.sil.classList.toggle("hi", !lit);
      mark.setAttribute("class", lit ? "dot m" : "dot");
    }
    return true;
  });
  bag.add(B.unregister);

  function retarget(on) {
    over = on;
    cue.t = on ? 1 : 0;
    read.textContent = on ? "cued" : "rest";
    B.wake();
  }
  read.textContent = "rest";

  bag.add(pointer(stage, {
    // Tested on the plinth's top plane, which never moves.
    move: (p) => { const w = unproj(C, p[0], p[1], TOP); retarget(w[0] >= X0 && w[0] <= X1 && w[1] >= Y0 && w[1] <= Y1); },
    leave: () => retarget(false),
  }));
  bag.add(() => svg.replaceChildren());

  return {
    set: (v) => { swing = v; B.wake(); },
    destroy: bag.dispose,
  };
}

hairline({
  name: "deck",
  means: "A record turns under its tone arm, the off-centre label showing the turn; the pointer cues the arm clear.",
  rules: [4, 5, 6, 9],
  range: [10, 20, 28],
  mount,
});
