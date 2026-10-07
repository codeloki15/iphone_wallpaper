/**
 * Lighthouse: a striped tower that tapers, standing on a rock, with a flared
 * gallery and its rail, a glazed lantern room and a pointed cap. The lamp
 * turns once every four seconds: a bright lens panel goes round the lantern,
 * hidden while it is on the far side, and throws a beam of two diverging rays
 * that sweeps the ground plane, behind the tower and then in front of it.
 * The pointer over the tower opens the beam wider, on a spring. The slider is
 * the beam's half angle, in degrees.
 *
 * The pattern: ambient motion as a pure function of the clock. The lamp's
 * angle comes from `now` alone; the beam's group moves in the paint order as
 * it passes from the far side to the near side.
 */
const {
  Cam, circ, clamp, facing, fit, hull, lerp, open, poly, prism, proj, rad, ringAt, rrect, run, seg,
  spring, stepS, mk, pointer, put, register, disposer, solid,
} = HL;

const LOOP = 4000, REACH = 78, A0 = -25;
const ZR = 7, ZT = 82, ZG = 88, ZL = 104, ZC = 114, ZB = 96, RB = 13, RT = 8, RL = 6;

function mount({ stage, svg, read }, value) {
  const bag = disposer();
  const C = Cam(45, 0.5, 1.8);
  const pts = [[-40, 26, 0], [26, 26, 0], [26, -22, 0], [0, 0, ZC + 5]];
  for (let k = 0; k < 8; k++) pts.push([REACH * Math.cos(k * Math.PI / 4), REACH * Math.sin(k * Math.PI / 4), ZB]);
  fit(C, pts, 200, 166);
  const P = proj(C), front = facing(C), back = (s) => !front(s);
  const at = (r, deg, z) => P(r * Math.cos(rad(deg)), r * Math.sin(rad(deg)), z);
  const rz = (z) => lerp(RB, RT, (z - ZR) / (ZT - ZR));
  let half = value, over = false;

  const g = mk("g", {}, svg);
  /** A solid whose top is not its foot: the hull of two rings, and one crease inside the top. */
  function taper(foot, top, inner, z0, z1) {
    const s = solid(g);
    put(s, { sil: poly(hull(ringAt(P, foot, z0).concat(ringAt(P, top, z1)))), crease: open(ringAt(P, run(inner, front), z1)) });
    return s;
  }

  // Back to front: the low rock, the rock, the tower, the gallery, the far rail,
  // the lantern, the cap, the near rail.
  const low = taper(rrect(-40, 2, -20, 26, 7, 6), rrect(-37, 5, -23, 23, 5, 6), rrect(-35.5, 6.5, -24.5, 21.5, 4, 6), 0, 3.5);
  taper(rrect(-22, -22, 26, 26, 12, 8), rrect(-17, -17, 20, 20, 10, 8), rrect(-15, -15, 18, 18, 8.5, 8), 0, ZR);

  const tower = taper(circ(RB, 28), circ(RT, 28), circ(RT - 1, 28), ZR, ZT);
  // Its marks: two painted bands, and a door at the foot, turned a little to the left.
  let marks = "";
  for (const z of [30, 43, 58, 69]) marks += open(ringAt(P, run(circ(rz(z), 28), front), z));
  const D = 72, door = [[-11, ZR], [-11, 18], [-7, 22], [0, 23.5], [7, 22], [11, 18], [11, ZR]];
  marks += open(door.map(([a, z]) => at(rz(z), D + a, z)));
  tower.cr.setAttribute("d", marks);

  taper(circ(RT + 0.5, 28), circ(12.5, 28), circ(11.3, 28), ZT, ZG);
  const rail = circ(12, 28), posts = circ(12, 12);
  const farRail = solid(g);
  farRail.sil.classList.add("nf");
  put(farRail, { sil: open(ringAt(P, run(rail, back), ZG + 6)), crease: run(posts, back).map((s) => seg(P(s.u, s.v, ZG), P(s.u, s.v, ZG + 6))).join("") });

  const lantern = solid(g);
  const glass = prism(P, front, circ(RL, 24), circ(RL - 0.9, 24), ZG, ZL);
  glass.crease += run(circ(RL, 8), front).map((s) => seg(P(s.u, s.v, ZG + 1), P(s.u, s.v, ZL - 1))).join("");
  put(lantern, glass);
  taper(circ(RL + 1.8, 24), circ(0.9, 10), circ(0.5, 10), ZL, ZC);
  const finial = solid(g);
  finial.sil.classList.add("nf");
  put(finial, { sil: seg(P(0, 0, ZC), P(0, 0, ZC + 5)), crease: "" });

  const nearRail = solid(g);
  nearRail.sil.classList.add("nf");
  put(nearRail, { sil: open(ringAt(P, run(rail, front), ZG + 6)), crease: run(posts, front).map((s) => seg(P(s.u, s.v, ZG), P(s.u, s.v, ZG + 6))).join("") });

  // The lamp: a lens panel on the lantern's glass, and the two rays it throws.
  // One bright place, and it travels. Its group is first in the order while it
  // is on the far side and last while it is on the near side.
  const lens = solid(g), rays = solid(g);
  lens.sil.classList.add("hi");
  rays.sil.classList.add("hi", "nf");
  const wide = spring(0, { eps: 0.002 });
  let near = null;

  function drawLamp(now) {
    const a = A0 + 360 * ((now % LOOP) / LOOP);
    const h = half * (1 + 0.8 * clamp(wide.x, 0, 1.2));
    const isNear = Math.cos(rad(a - 45)) > 0;
    if (isNear !== near) {
      near = isNear;
      if (near) { nearRail.g.after(lens.g); lens.g.after(rays.g); }
      else { low.g.before(rays.g); farRail.g.after(lens.g); }
    }
    const panel = [];
    for (let k = -3; k <= 3; k++) panel.push(at(RL + 0.3, a + k * 6, ZG + 3));
    for (let k = 3; k >= -3; k--) panel.push(at(RL + 0.3, a + k * 6, ZL - 3));
    put(lens, { sil: poly(panel), crease: "" });
    put(rays, {
      sil: seg(at(RL + 2, a - h * 2, ZB), at(REACH, a - h, ZB)) + seg(at(RL + 2, a + h * 2, ZB), at(REACH, a + h, ZB)),
      crease: seg(at(RL + 14, a, ZB), at(REACH * 0.72, a, ZB)),
    });
  }

  const B = register(stage, (dt, now) => {
    stepS(wide, dt);
    drawLamp(now);
    return true;
  });
  bag.add(B.unregister);

  // The hit area is the tower's rest outline on screen, a band round its axis: it never moves.
  const axis = P(0, 0, 0), top = P(0, 0, ZC + 5);
  function retarget() {
    wide.t = over ? 1 : 0;
    read.textContent = over ? "lamp" : "rest";
    B.wake();
  }
  bag.add(pointer(stage, {
    move: (p) => { over = Math.abs(p[0] - axis[0]) < 46 && p[1] > top[1] - 12 && p[1] < axis[1] + 26; retarget(); },
    leave: () => { over = false; retarget(); },
  }));
  bag.add(() => svg.replaceChildren());
  read.textContent = "rest";

  return {
    set: (v) => { half = v; B.wake(); },
    destroy: bag.dispose,
  };
}

hairline({
  name: "lighthouse",
  means: "A lighthouse on its rock: the lamp turns once every four seconds, its beam passing behind the tower and in front.",
  rules: [4, 5, 6, 9],
  range: [4, 7, 11],
  mount,
});
