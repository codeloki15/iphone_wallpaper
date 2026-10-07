/**
 * Cradle: a Newton's cradle. Two rails on four legs over a plinth, and five
 * balls in a touching row, each hung from both rails on a V of threads. The
 * ball at one end swings out and back, clicks, and the ball at the other end
 * takes its turn: one click a second, for ever. The ball in the air takes the
 * bright stroke, so the bright place crosses the row with each click. The
 * pointer holds the cradle: the swing shrinks while it is over the figure, on
 * a spring. The slider is the swing, in degrees.
 *
 * The pattern: ambient motion that is a function of the clock alone and
 * repeats every two seconds; the pointer only scales it.
 */
const {
  Cam, facing, fit, poly, open, seg, prism, proj, rings, rad, spring, stepS,
  mk, pointer, put, register, disposer, solid,
} = HL;

const NB = 5, R = 9, GAP = 18, W = 16, H = 68, LEN = 46, LEGX = 88, BAR = 2.5, PB = 5, LOOP = 2000, HELD = 0.3;

function mount({ stage, svg, read }, value) {
  const bag = disposer();
  const C = Cam(45, 0.5, 1.55);
  const far = (NB - 1) / 2 * GAP + LEN * Math.sin(rad(40)) + R;
  fit(C, [[-96, -25, -PB], [96, 25, -PB], [96, -25, -PB], [-96, 25, -PB], [-92, -W, H + 4], [92, -W, H + 4], [92, W, H + 4],
    [-far, 0, H - LEN], [far, 0, H - LEN]], 200, 166);
  const P = proj(C), front = facing(C);
  const o = P(0, 0, 0), S = (P(1, -1, 0)[0] - o[0]) / Math.SQRT2;
  let A = value;
  const amp = spring(1, { eps: 0.002 });

  const g = mk("g", {}, svg);
  const box = (x0, y0, x1, y1, r, b, z0, z1) => {
    const [ring, inner] = rings(x0, y0, x1, y1, r, b);
    put(solid(g), prism(P, front, ring, inner, z0, z1));
  };
  /** One side of the frame: two legs, then the rail that lies on them. */
  const side = (y) => {
    box(-LEGX - BAR, y - BAR, -LEGX + BAR, y + BAR, 1.4, 0.7, 0, H);
    box(LEGX - BAR, y - BAR, LEGX + BAR, y + BAR, 1.4, 0.7, 0, H);
    box(-LEGX - BAR - 2, y - BAR, LEGX + BAR + 2, y + BAR, 1.8, 0.7, H, H + 4);
  };

  // Back to front: the plinth, the far side of the frame, the balls from the
  // far end of the row to the near one, the near side of the frame.
  box(-96, -25, 96, 25, 9, 2.2, -PB, 0);
  side(-W);
  const balls = [];
  for (let i = 0; i < NB; i++) {
    balls.push({ x: (i - (NB - 1) / 2) * GAP, ball: solid(g), thread: solid(g), drawn: NaN, paths: null });
  }
  side(W);
  // The one bright stroke: a copy of the ball in the air, laid over it. It moves
  // from end to end with the click, so exactly one ball is bright on every frame.
  const glow = solid(g);
  glow.sil.classList.add("hi");
  let lit = null, shown = null;

  /** A ball hanging at angle a (degrees) from the vertical: a circle, a glint, and its two threads. */
  function drawBall(b, a) {
    a = Math.round(a * 20) / 20;
    if (a === b.drawn) return;
    b.drawn = a;
    const s = Math.sin(rad(a)), c = Math.cos(rad(a));
    const ctr = P(b.x + LEN * s, 0, H - LEN * c);
    const top = P(b.x + (LEN - R) * s, 0, H - (LEN - R) * c);
    const rim = [], glint = [];
    for (let k = 0; k < 30; k++) {
      const t = (k / 30) * 2 * Math.PI;
      rim.push([ctr[0] + R * S * Math.cos(t), ctr[1] + R * S * Math.sin(t)]);
    }
    for (let k = 0; k <= 6; k++) {
      const t = rad(195 + k * 11);
      glint.push([ctr[0] + R * S * 0.62 * Math.cos(t), ctr[1] + R * S * 0.62 * Math.sin(t)]);
    }
    b.paths = { sil: poly(rim), crease: open(glint) };
    put(b.ball, b.paths);
    put(b.thread, { sil: seg(top, P(b.x, -W + BAR, H)) + seg(top, P(b.x, W - BAR, H)), crease: "" });
  }

  function frame(now) {
    const ph = (now % LOOP) / LOOP, a = A * amp.x;
    // Half a pendulum's period each: out and back on a sine, slowest at the top.
    const left = ph < 0.5 ? -a * Math.sin(2 * Math.PI * ph) : 0;
    const right = ph < 0.5 ? 0 : a * Math.sin(2 * Math.PI * (ph - 0.5));
    balls.forEach((b, i) => drawBall(b, i === 0 ? left : i === NB - 1 ? right : 0));
    const air = balls[ph < 0.5 ? 0 : NB - 1];
    if (air !== lit) { lit = air; air.ball.g.after(glow.g); }
    if (air.paths !== shown) { shown = air.paths; put(glow, shown); }
  }
  frame(0);
  const B = register(stage, (dt, now) => { stepS(amp, dt); frame(now); return true; });
  bag.add(B.unregister);

  // The whole cradle answers: any pointer over the stage holds it.
  bag.add(pointer(stage, {
    move: () => { amp.t = HELD; read.textContent = "held"; B.wake(); },
    leave: () => { amp.t = 1; read.textContent = "rest"; B.wake(); },
  }));
  read.textContent = "rest";
  bag.add(() => svg.replaceChildren());

  return {
    set: (v) => { A = v; B.wake(); },
    destroy: bag.dispose,
  };
}

hairline({
  name: "cradle",
  means: "A Newton's cradle clicks once a second, the end balls swinging in turn; the pointer holds it.",
  rules: [4, 5, 6, 7],
  range: [20, 30, 40],
  mount,
});
