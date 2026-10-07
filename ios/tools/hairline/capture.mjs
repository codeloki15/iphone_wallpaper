#!/usr/bin/env node
/**
 * Records a Hairline figure's own motion, frame by frame, for a widget.
 *
 *   node capture.mjs figures/<name>.js --seconds 4 [--fps 8]
 *
 * A widget has no pointer, so what it shows is the figure left alone: the
 * motion its tick() makes by itself (rule 07's ambient motion). That motion
 * must repeat exactly every `--seconds` seconds, an even number that divides
 * an hour (2, 4, 6, 8, 10, 12 ...), because the widget plays one loop of it
 * over and over. Derive it from tick's `now`, never from a count of frames.
 *
 * The figure is built with the hairline-create skill's own build.mjs, opened
 * in a headless browser on a clock this script controls, run for two loops to
 * let its springs settle, and then every frame of one loop is read back as
 * plain SVG: each shape with the colors the page gave it. It writes
 *
 *   frames/<name>.json   the frames, read by tools/make_motion_fonts.py
 *   frames/<name>.png    every frame on one sheet, in the widget's colors
 *
 * and prints whether the loop closes (its last frame leads back into its
 * first) and whether anything a widget cannot show was used. It exits 1 when
 * the figure cannot be played as a widget.
 *
 * The browser is the one the skill's look.mjs uses: run look.mjs once first,
 * which installs playwright-core into its cache folder.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const skill = resolve(here, "../../../.claude/skills/hairline-create");

/** The widget's palette, given to the figure through Hairline's own custom properties. */
export const PALETTE = { plate: "#0c0d11", hi: "#ffffff", edge: "#b4b8c4", mid: "#6c7180", lo: "#353842" };

function fail(message) {
  console.error("capture: " + message);
  process.exit(2);
}

const args = process.argv.slice(2);
const source = args.find((a) => !a.startsWith("--"));
const option = (name, fallback) => {
  const i = args.indexOf("--" + name);
  return i < 0 ? fallback : Number(args[i + 1]);
};
const seconds = option("seconds", NaN), fps = option("fps", 8);
if (!source || !Number.isInteger(seconds)) fail("usage: node capture.mjs figures/<name>.js --seconds 4 [--fps 8]");
if (seconds % 2 || 3600 % seconds) fail(`--seconds must be even and divide 3600; ${seconds} does not.`);
if (!Number.isInteger(fps) || fps < 1 || fps > 15) fail("--fps must be a whole number from 1 to 15.");
if (!existsSync(join(skill, "build.mjs"))) fail(`the hairline-create skill is not at ${skill}. Install it: npx skills add lucasmarkes/hairline`);

const cache = process.env.HAIRLINE_LOOK_CACHE ?? join(homedir(), "Library/Caches/hairline-look");
let chromium;
try {
  chromium = createRequire(join(cache, "x.js"))("playwright-core").chromium;
} catch {
  fail(`no playwright-core in ${cache}. Run the skill's look.mjs once; it installs it.`);
}

const { assemble, nameOf } = await import(pathToFileURL(join(skill, "build.mjs")).href);
const figure = readFileSync(source, "utf8");
const name = nameOf(figure) ?? basename(source, ".js");
const out = join(here, "frames");
mkdirSync(out, { recursive: true });
const page_ = join(out, `.${name}.html`);
writeFileSync(page_, assemble(figure));

/*
 * A virtual clock, after the one in Hairline's own tests
 * (packages/hairline/test/parity/clock.js, MIT, Copyright (c) 2026 Lucas
 * Marques). The page's time stands at 0 from the start and moves only when
 * __advance is called: the frame queue is flushed with the new time, and CSS
 * transitions are seeked to it. Starting frozen matters: a frame the figure
 * asked the real browser for could not be driven from here.
 */
const CLOCK = `(() => {
  let now = 0, seq = 0, rafs = new Map();
  const timers = new Map(), started = new WeakMap();
  performance.now = () => now;
  window.requestAnimationFrame = (cb) => { const id = ++seq; rafs.set(id, cb); return id; };
  window.cancelAnimationFrame = (id) => { rafs.delete(id); };
  window.setTimeout = (cb, ms = 0, ...a) => { const id = ++seq; timers.set(id, { at: now + Math.max(0, ms), cb, a }); return id; };
  window.clearTimeout = (id) => { timers.delete(id); };
  function seek() {
    for (const an of document.getAnimations()) {
      if (!started.has(an)) { started.set(an, now); an.pause(); }
      const t = now - started.get(an), end = an.effect ? an.effect.getComputedTiming().endTime : 0;
      if (Number.isFinite(end) && t >= end) an.finish(); else an.currentTime = t;
    }
  }
  window.__advance = (ms) => {
    const target = now + ms;
    for (;;) {
      let next = null, id = 0;
      for (const [k, t] of timers) if (t.at <= target && (!next || t.at < next.at)) { next = t; id = k; }
      if (!next) break;
      now = next.at; timers.delete(id); next.cb(...next.a);
    }
    now = target;
    const due = rafs; rafs = new Map();
    for (const cb of due.values()) cb(now);
    seek();
  };
})();`;

/** Reads the drawing back as shapes with their colors resolved, in paint order, in viewBox units. */
const SNAP = `(() => {
  const svg = document.querySelector("#stage svg");
  const inverse = svg.getScreenCTM().inverse();
  const SHAPES = { path: ["d"], polygon: ["points"], polyline: ["points"], ellipse: ["cx", "cy", "rx", "ry"], circle: ["cx", "cy", "r"], line: ["x1", "y1", "x2", "y2"], rect: ["x", "y", "width", "height", "rx", "ry"] };
  const hex = (c) => {
    const m = /rgba?\\(([^)]+)\\)/.exec(c);
    if (!m) return null;
    const p = m[1].split(/[ ,/]+/).map(Number);
    if (p.length > 3 && p[3] === 0) return null;
    return "#" + p.slice(0, 3).map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");
  };
  const shapes = [], cannot = new Set();
  const walk = (el, opacity) => {
    const cs = getComputedStyle(el);
    if (cs.display === "none" || cs.visibility === "hidden") return;
    const tag = el.tagName.toLowerCase();
    if (el !== svg && (el.hasAttribute("mask") || el.hasAttribute("filter") || el.hasAttribute("clip-path"))) { cannot.add(tag + " with a mask, filter or clip-path (reflect and fade)"); return; }
    const o = opacity * Number(cs.opacity);
    if (o < 0.02) return;
    if (tag === "svg" || tag === "g") { for (const child of el.children) walk(child, o); return; }
    if (tag === "defs" || tag === "mask" || tag === "style") return;
    if (!SHAPES[tag]) { cannot.add("<" + tag + ">"); return; }
    const fill = cs.fill === "none" ? null : hex(cs.fill), stroke = cs.stroke === "none" ? null : hex(cs.stroke);
    if (!fill && !stroke) return;
    const shape = { tag };
    for (const a of SHAPES[tag]) if (el.hasAttribute(a)) shape[a] = el.getAttribute(a);
    if (tag === "path" && !shape.d) return;
    const m = inverse.multiply(el.getScreenCTM());
    if ([m.a - 1, m.b, m.c, m.d - 1, m.e, m.f].some((v) => Math.abs(v) > 1e-4)) shape.m = [m.a, m.b, m.c, m.d, m.e, m.f].map((v) => Math.round(v * 1000) / 1000);
    if (fill) shape.fill = fill;
    if (stroke) { shape.stroke = stroke; if (cs.strokeDasharray !== "none") shape.dash = true; }
    if (o < 0.99) shape.o = Math.round(o * 100) / 100;
    shapes.push(shape);
  };
  walk(svg, 1);
  const box = svg.getBBox();
  return { shapes, cannot: [...cannot], box: [box.x, box.y, box.x + box.width, box.y + box.height], read: document.querySelector("#read").textContent, error: document.querySelector("#error").hidden ? null : document.querySelector("#error").textContent };
})()`;

/** One shape as an SVG element with plain attributes: the only kind the widget's font can hold. */
export function element(s, strokeWidth) {
  const at = Object.entries(s).filter(([k]) => !["tag", "m", "fill", "stroke", "dash", "o"].includes(k)).map(([k, v]) => `${k}="${v}"`);
  if (s.m) at.push(`transform="matrix(${s.m.join(" ")})"`);
  at.push(`fill="${s.fill ?? "none"}"`);
  if (s.stroke) at.push(`stroke="${s.stroke}"`, `stroke-width="${strokeWidth}"`, 'stroke-linejoin="round"', 'stroke-linecap="round"');
  if (s.dash) at.push('stroke-dasharray="1 3"');
  if (s.o) at.push(`opacity="${s.o}"`);
  return `<${s.tag} ${at.join(" ")}/>`;
}

const browser = await chromium.launch({ channel: "chrome" }).catch(() => chromium.launch()).catch(() => null);
if (!browser) fail("no Chrome and no Chromium to open the figure in.");
const context = await browser.newContext({ viewport: { width: 900, height: 900 }, reducedMotion: "no-preference", colorScheme: "dark" });
await context.addInitScript({ content: CLOCK });
const page = await context.newPage();
const problems = [];
page.on("console", (m) => { if (["error", "warning"].includes(m.type())) problems.push("console: " + m.text()); });
page.on("pageerror", (e) => problems.push("page error: " + e.message));
await page.goto(pathToFileURL(page_).href + "?theme=dark");
await page.waitForFunction(() => window.hairline && window.hairline.figure, null, { timeout: 5000, polling: 50 }).catch(() => {});
await page.evaluate((palette) => {
  const stage = document.querySelector("#stage");
  for (const [key, value] of Object.entries(palette)) stage.style.setProperty("--hairline-" + key, value);
}, PALETTE);
// The figure's loop starts once the page says the stage is on screen, in real time.
await page.waitForTimeout(400);

const SUB = Math.ceil(1000 / fps / (1000 / 60));
const step = 1000 / fps / SUB;
const advance = (frames) => page.evaluate(([n, ms]) => { for (let i = 0; i < n; i++) window.__advance(ms); }, [frames * SUB, step]);
const count = seconds * fps;
await advance(count * 2);
const frames = [];
for (let k = 0; k <= count; k++) {
  frames.push(await page.evaluate(SNAP));
  await advance(1);
}
const still = await page.evaluate(() => !document.querySelector("#stage svg").children.length);
await page.close();

const lines = [];
let bad = false;
const first = frames[0];
if (first.error) { lines.push(`failed  the page reports: ${first.error}`); bad = true; }
for (const p of problems) { lines.push("failed  " + p); bad = true; }
if (still || !first.shapes.length) { lines.push("failed  nothing was drawn."); bad = true; }
const cannot = [...new Set(frames.flatMap((f) => f.cannot))];
if (cannot.length) { lines.push(`failed  a widget cannot show: ${cannot.join("; ")}. Draw it another way.`); bad = true; }

// Does anything move, and does the loop come round to where it began?
const key = (f) => JSON.stringify(f.shapes);
const numbers = (f) => (key(f).match(/-?\d+\.?\d*/g) ?? []).map(Number);
const distance = (a, b) => {
  const x = numbers(a), y = numbers(b);
  if (x.length !== y.length) return Infinity;
  let worst = 0;
  for (let i = 0; i < x.length; i++) worst = Math.max(worst, Math.abs(x[i] - y[i]));
  return worst;
};
const moving = frames.slice(1, count).filter((f, i) => key(f) !== key(frames[i])).length;
if (!moving) { lines.push("failed  nothing moves when the figure is left alone. A widget plays only what tick() does by itself."); bad = true; }
else lines.push(`motion  ${moving + 1} of ${count} frames differ from the one before.`);
const gap = distance(frames[count], frames[0]);
const stride = Math.max(...frames.slice(1, count).map((f, i) => distance(f, frames[i])).filter(Number.isFinite), 0);
if (gap > Math.max(0.6, stride * 0.25)) {
  lines.push(`failed  the loop does not close: after ${seconds} s the drawing is ${Number.isFinite(gap) ? gap.toFixed(1) + " units" : "a different set of shapes"} away from where it began (a frame moves ${stride.toFixed(1)}). Make every motion a function of now % ${seconds * 1000}.`);
  bad = true;
} else lines.push(`loop    closes: after ${seconds} s the drawing is back within ${gap.toFixed(2)} units of its first frame.`);
const box = frames.reduce((b, f) => [Math.min(b[0], f.box[0]), Math.min(b[1], f.box[1]), Math.max(b[2], f.box[2]), Math.max(b[3], f.box[3])], [1e9, 1e9, -1e9, -1e9]);
if (box[0] < 2 || box[1] < 2 || box[2] > 398 || box[3] > 318) { lines.push(`failed  the drawing leaves the 400 x 320 frame during the loop: it spans ${box.map((v) => v.toFixed(0)).join(", ")}.`); bad = true; }
else lines.push(`frame   the loop stays inside: ${box.map((v) => v.toFixed(0)).join(", ")} of 400 x 320.`);
const most = Math.max(...frames.map((f) => f.shapes.length));
const bytes = Math.max(...frames.slice(0, count).map((f) => f.shapes.map((s) => element(s, 1)).join("").length));
lines.push(`weight  ${most} shapes, ${(bytes / 1024).toFixed(1)} KB a frame at most.` + (bytes > 24 * 1024 ? " Heavy for a widget, which redraws it eight times a second: aim under 24 KB." : ""));
const hi = frames.slice(0, count).map((f) => f.shapes.filter((s) => s.stroke === PALETTE.hi || (s.fill === PALETTE.hi && !s.stroke)).length);
lines.push(`bright  ${Math.min(...hi)} to ${Math.max(...hi)} bright shapes a frame.`);

writeFileSync(join(out, `${name}.json`), JSON.stringify({ name, seconds, fps, palette: PALETTE, frames: frames.slice(0, count).map((f) => f.shapes) }));

// The sheet: every frame as the widget will draw it, small, with the first one large.
const draw = (f, w) => `<svg viewBox="0 0 400 320" width="${w}" height="${w * 0.8}" style="background:${PALETTE.plate}">${f.shapes.map((s) => element(s, 1.15)).join("")}</svg>`;
const cols = Math.min(8, fps);
const sheet = `<!doctype html><body style="margin:0;background:#1b1c22;font:11px ui-monospace,Menlo,monospace;color:#9a9daa"><div style="padding:14px;width:${cols * 204 + 4}px">
<div style="margin-bottom:8px">${name} · ${seconds} s at ${fps} frames a second · first frame at the size of a large widget, then every frame at 200 px</div>
<div style="display:flex;gap:12px;margin-bottom:12px">${draw(frames[0], 676)}<div style="display:flex;flex-direction:column;gap:6px"><span>medium widget</span>${draw(frames[0], 394)}</div></div>
<div style="display:grid;grid-template-columns:repeat(${cols},200px);gap:4px">${frames.slice(0, count).map((f, k) => `<div>${draw(f, 200)}<div>${(k / fps).toFixed(2)} s</div></div>`).join("")}</div></div></body>`;
const viewer = await context.newPage();
await viewer.setViewportSize({ width: cols * 204 + 32, height: 900 });
await viewer.setContent(sheet);
await viewer.screenshot({ path: join(out, `${name}.png`), fullPage: true });
await browser.close();

for (const line of lines) console.log(line);
console.log(`frames  ${join(out, name + ".json")}`);
console.log(`sheet   ${join(out, name + ".png")}`);
process.exit(bad ? 1 : 0);
