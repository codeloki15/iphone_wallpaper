/*
 * Spinning 3D iPhone for the hero, built from three.js core primitives.
 * The screen cycles through wallpapers under a live lock-screen clock.
 * Drag to spin it; a click opens the wallpaper on screen. If three.js or
 * WebGL is unavailable, the 2D mockups from app.js stay in place.
 */
(function () {
  'use strict';

  const host = document.getElementById('heroPhones');
  if (!host || !window.THREE || !window.Walls) return;
  const T = window.THREE;

  let renderer;
  try {
    renderer = new T.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'low-power' });
  } catch (e) {
    return;
  }

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const TAU = Math.PI * 2;
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const ease = (x) => 1 - Math.pow(1 - x, 3);

  // Phone size in centimetres (a 6.3-inch Pro-class phone).
  const W = 7.15;
  const H = 14.76;
  const D = 0.825;
  const R = 1.15;

  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = T.sRGBEncoding;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.setClearColor(0x000000, 0);

  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(28, 1, 1, 200);

  // ---------- environment & lights ----------

  // A painted studio (gradient sky plus soft boxes) gives the metal
  // something to reflect without loading an HDR file.
  function studio() {
    const c = document.createElement('canvas');
    c.width = 512;
    c.height = 256;
    const g = c.getContext('2d');
    const sky = g.createLinearGradient(0, 0, 0, 256);
    sky.addColorStop(0, '#ffffff');
    sky.addColorStop(0.45, '#9da3ad');
    sky.addColorStop(1, '#16171c');
    g.fillStyle = sky;
    g.fillRect(0, 0, 512, 256);
    g.fillStyle = 'rgba(255,255,255,0.95)';
    g.fillRect(50, 60, 80, 46);
    g.fillRect(290, 40, 140, 34);
    g.fillRect(200, 130, 36, 70);
    const tex = new T.CanvasTexture(c);
    tex.mapping = T.EquirectangularReflectionMapping;
    tex.encoding = T.sRGBEncoding;
    const pmrem = new T.PMREMGenerator(renderer);
    const env = pmrem.fromEquirectangular(tex).texture;
    tex.dispose();
    pmrem.dispose();
    return env;
  }
  scene.environment = studio();
  scene.add(new T.HemisphereLight(0xffffff, 0x30323a, 0.55));
  const key = new T.DirectionalLight(0xffffff, 1.3);
  key.position.set(4, 7, 9);
  scene.add(key);
  const rim = new T.DirectionalLight(0x9fb8ff, 0.9);
  rim.position.set(-7, 3, -6);
  scene.add(rim);

  // ---------- geometry helpers ----------

  function roundedRect(w, h, r) {
    const s = new T.Shape();
    const x = -w / 2;
    const y = -h / 2;
    s.moveTo(x + r, y);
    s.lineTo(x + w - r, y);
    s.absarc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
    s.lineTo(x + w, y + h - r);
    s.absarc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
    s.lineTo(x + r, y + h);
    s.absarc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
    s.lineTo(x, y + r);
    s.absarc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false);
    return s;
  }

  // A flat rounded rectangle whose UVs run 0..1 across its bounds.
  function flatRounded(w, h, r) {
    const geo = new T.ShapeGeometry(roundedRect(w, h, r), 24);
    const pos = geo.attributes.position;
    const uv = geo.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / w + 0.5, pos.getY(i) / h + 0.5);
    return geo;
  }

  function disc(radius, depth, material) {
    const m = new T.Mesh(new T.CylinderGeometry(radius, radius, depth, 40), material);
    m.rotation.x = Math.PI / 2;
    return m;
  }

  // ---------- materials ----------

  const frameMat = new T.MeshStandardMaterial({ color: 0xa7a39b, metalness: 0.9, roughness: 0.3 });
  const capMat = new T.MeshStandardMaterial({ color: 0x050506, metalness: 0, roughness: 0.08 });
  const backMat = new T.MeshStandardMaterial({ color: 0x8d8a84, metalness: 0.15, roughness: 0.55 });
  const plateauMat = new T.MeshStandardMaterial({ color: 0x8d8a84, metalness: 0.2, roughness: 0.28 });
  const lensMat = new T.MeshStandardMaterial({ color: 0x07080c, metalness: 0.3, roughness: 0.05 });
  const lensCoreMat = new T.MeshBasicMaterial({ color: 0x1b2a4a });
  const flashMat = new T.MeshStandardMaterial({ color: 0xf1e6cc, metalness: 0, roughness: 0.4 });
  const controlMat = new T.MeshStandardMaterial({ color: 0x5f5c57, metalness: 0.6, roughness: 0.2 });

  // ---------- phone ----------

  const phone = new T.Group();
  scene.add(phone);

  const bevel = 0.14;
  const bodyGeo = new T.ExtrudeGeometry(roundedRect(W - bevel * 2, H - bevel * 2, R - bevel), {
    depth: D - bevel * 2,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 5,
    curveSegments: 28,
  });
  bodyGeo.translate(0, 0, -(D - bevel * 2) / 2);
  // Group 0 is the front/back caps, group 1 the sides and bevels.
  phone.add(new T.Mesh(bodyGeo, [capMat, frameMat]));

  const back = new T.Mesh(flatRounded(W - 0.3, H - 0.3, R - 0.15), backMat);
  back.rotation.y = Math.PI;
  back.position.z = -D / 2 - 0.002;
  phone.add(back);

  // Screen texture: wallpaper, clock, bezel and Dynamic Island.
  const SW = 640;
  const SH = 1336;
  const BEZEL = 18;
  const screenCanvas = document.createElement('canvas');
  screenCanvas.width = SW;
  screenCanvas.height = SH;
  const sg = screenCanvas.getContext('2d');
  const screenTex = new T.CanvasTexture(screenCanvas);
  screenTex.encoding = T.sRGBEncoding;
  screenTex.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy());

  const screen = new T.Mesh(
    flatRounded(W - 0.16, H - 0.16, R - 0.08),
    new T.MeshBasicMaterial({ map: screenTex, toneMapped: false })
  );
  screen.position.z = D / 2 + 0.003;
  phone.add(screen);

  // A faint reflective layer so the glass catches the studio light.
  const sheen = new T.Mesh(
    flatRounded(W - 0.16, H - 0.16, R - 0.08),
    new T.MeshStandardMaterial({ color: 0x000000, metalness: 0, roughness: 0.04, transparent: true, opacity: 0.16, depthWrite: false })
  );
  sheen.position.z = D / 2 + 0.006;
  phone.add(sheen);

  // Camera plateau and lenses. Seen from the back, the plateau sits top left,
  // which is +x in the phone's own coordinates.
  const plateauDepth = 0.06;
  const plateauBevel = 0.04;
  const plateauGeo = new T.ExtrudeGeometry(roundedRect(3.45, 3.45, 0.9), {
    depth: plateauDepth,
    bevelEnabled: true,
    bevelThickness: plateauBevel,
    bevelSize: plateauBevel,
    bevelSegments: 3,
    curveSegments: 20,
  });
  plateauGeo.translate(0, 0, -(plateauDepth + plateauBevel));
  const pcx = W / 2 - 0.32 - 1.75;
  const pcy = H / 2 - 0.32 - 1.75;
  const plateau = new T.Mesh(plateauGeo, plateauMat);
  plateau.position.set(pcx, pcy, -D / 2);
  phone.add(plateau);

  const lensZ = -D / 2 - plateauDepth - plateauBevel * 2 - 0.07;
  [[0.78, 0.78], [0.78, -0.78], [-0.74, 0]].forEach(([dx, dy]) => {
    const ring = disc(0.66, 0.14, frameMat);
    ring.position.set(pcx + dx, pcy + dy, lensZ);
    const glass = disc(0.5, 0.16, lensMat);
    glass.position.set(pcx + dx, pcy + dy, lensZ - 0.01);
    const core = disc(0.16, 0.17, lensCoreMat);
    core.position.set(pcx + dx, pcy + dy, lensZ - 0.012);
    phone.add(ring, glass, core);
  });
  const flash = disc(0.2, 0.06, flashMat);
  flash.position.set(pcx - 0.74, pcy + 1.0, lensZ + 0.04);
  const lidar = disc(0.17, 0.06, lensMat);
  lidar.position.set(pcx - 0.74, pcy - 1.0, lensZ + 0.04);
  phone.add(flash, lidar);

  // Side buttons: action and volume on the left, power and camera control on the right.
  const buttons = [
    [-1, 4.25, 0.55, frameMat],
    [-1, 3.05, 1.05, frameMat],
    [-1, 1.8, 1.05, frameMat],
    [1, 2.6, 1.7, frameMat],
    [1, -1.75, 0.95, controlMat],
  ];
  buttons.forEach(([side, y, len, mat]) => {
    const b = new T.Mesh(new T.BoxGeometry(0.1, len, 0.34), mat);
    b.position.set(side * (W / 2 + 0.02), y, 0);
    phone.add(b);
  });

  // Soft contact shadow.
  const shadowCanvas = document.createElement('canvas');
  shadowCanvas.width = shadowCanvas.height = 128;
  const shg = shadowCanvas.getContext('2d');
  const grad = shg.createRadialGradient(64, 64, 0, 64, 64, 64);
  grad.addColorStop(0, 'rgba(0,0,0,0.5)');
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  shg.fillStyle = grad;
  shg.fillRect(0, 0, 128, 128);
  const shadowMat = new T.MeshBasicMaterial({ map: new T.CanvasTexture(shadowCanvas), transparent: true, depthWrite: false, toneMapped: false });
  const shadow = new T.Mesh(new T.PlaneGeometry(W * 1.7, W * 0.55), shadowMat);
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.y = -H / 2 - 0.9;
  scene.add(shadow);

  // ---------- screen content ----------

  const PICKS = ['synthwave', 'glass-orbs', 'aurora', 'alpine-dawn', 'neon-terrain', 'liquid-pop'];
  const picks = PICKS.map((id) => Walls.list.find((w) => w.id === id)).filter(Boolean);
  const SLIDE = 4;
  const FADE = 0.8;
  const WW = SW - BEZEL * 2;
  const WH = SH - BEZEL * 2;
  const stills = new Map();
  const liveCanvas = document.createElement('canvas');
  liveCanvas.width = WW;
  liveCanvas.height = WH;
  const FONT = '-apple-system, "SF Pro Rounded", "SF Pro Display", system-ui, sans-serif';

  function wallImage(wall, t) {
    if (wall.live) {
      Walls.render(liveCanvas.getContext('2d'), WW, WH, wall, 0, t);
      return liveCanvas;
    }
    let c = stills.get(wall.id);
    if (!c) {
      c = document.createElement('canvas');
      c.width = WW;
      c.height = WH;
      Walls.render(c.getContext('2d'), WW, WH, wall, 0);
      stills.set(wall.id, c);
    }
    return c;
  }

  function roundRectPath(g, x, y, w, h, r) {
    g.beginPath();
    g.moveTo(x + r, y);
    g.arcTo(x + w, y, x + w, y + h, r);
    g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r);
    g.arcTo(x, y, x + w, y, r);
    g.closePath();
  }

  let clockText = '';
  let dateText = '';

  function drawScreen(current, next, fade, t) {
    sg.fillStyle = '#000';
    sg.fillRect(0, 0, SW, SH);
    sg.save();
    roundRectPath(sg, BEZEL, BEZEL, WW, WH, 76);
    sg.clip();
    sg.drawImage(wallImage(current, t), BEZEL, BEZEL);
    if (fade > 0) {
      sg.globalAlpha = fade;
      sg.drawImage(wallImage(next, t), BEZEL, BEZEL);
      sg.globalAlpha = 1;
    }
    sg.fillStyle = '#fff';
    sg.textAlign = 'center';
    sg.shadowColor = 'rgba(0,0,0,0.25)';
    sg.shadowBlur = 18;
    sg.font = `600 34px ${FONT}`;
    sg.fillText(dateText, SW / 2, 222);
    sg.font = `700 172px ${FONT}`;
    sg.fillText(clockText, SW / 2, 392);
    sg.shadowBlur = 0;
    sg.fillStyle = 'rgba(255,255,255,0.85)';
    roundRectPath(sg, SW / 2 - 70, SH - BEZEL - 22, 140, 8, 4);
    sg.fill();
    sg.restore();
    sg.fillStyle = '#000';
    roundRectPath(sg, SW / 2 - 98, BEZEL + 22, 196, 56, 28);
    sg.fill();
    screenTex.needsUpdate = true;
  }

  function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).replace(/\s?[AP]M$/i, '');
    const date = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
    const changed = time !== clockText || date !== dateText;
    clockText = time;
    dateText = date;
    return changed;
  }

  // ---------- motion ----------

  let autoT = 0;     // advances only while the phone moves on its own
  let screenT = 0;   // drives the slideshow
  // The entrance runs on wall-clock time so slow devices don't drag it out.
  let introStart = reduce.matches ? -Infinity : performance.now();
  let userYaw = 0;
  let userPitch = 0;
  let velYaw = 0;
  let dragging = false;
  let releasedAt = -Infinity;
  let lastDrawn = -1;
  let lastClockCheck = 0;

  // Mostly a gentle sway that keeps the screen in view, then every
  // 18 seconds a full turn to show off the back.
  function autoYaw(t) {
    const c = t % 18;
    if (c < 13) return 0.5 * Math.sin((c / 13) * TAU);
    const k = (c - 13) / 5;
    return TAU * (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
  }

  function currentSlide() {
    const n = picks.length;
    const i = Math.floor(screenT / SLIDE) % n;
    const fade = clamp(((screenT % SLIDE) - (SLIDE - FADE)) / FADE, 0, 1);
    return { current: picks[i], next: picks[(i + 1) % n], fade, index: i };
  }

  // ---------- input ----------

  const canvas = renderer.domElement;
  canvas.className = 'hero-3d';
  let down = null;

  canvas.addEventListener('pointerdown', (e) => {
    down = { x: e.clientX, y: e.clientY, lastX: e.clientX, lastY: e.clientY, time: performance.now(), moved: 0 };
    dragging = true;
    velYaw = 0;
    canvas.setPointerCapture(e.pointerId);
    canvas.classList.add('dragging');
  });

  canvas.addEventListener('pointermove', (e) => {
    if (!down) return;
    const dx = e.clientX - down.lastX;
    const dy = e.clientY - down.lastY;
    down.lastX = e.clientX;
    down.lastY = e.clientY;
    down.moved += Math.abs(dx) + Math.abs(dy);
    userYaw += dx * 0.012;
    userPitch = clamp(userPitch + dy * 0.006, -0.5, 0.5);
    velYaw = dx * 0.012;
  });

  function endDrag(e, cancelled) {
    if (!down) return;
    const click = !cancelled && down.moved < 6 && performance.now() - down.time < 500;
    down = null;
    dragging = false;
    releasedAt = performance.now();
    canvas.classList.remove('dragging');
    if (canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
    if (click) openOnScreenWall();
  }
  canvas.addEventListener('pointerup', (e) => endDrag(e, false));
  canvas.addEventListener('pointercancel', (e) => endDrag(e, true));

  // Opens the wallpaper showing on the phone by clicking its gallery card,
  // which is only possible while that card is in the current filter.
  function openOnScreenWall() {
    const { current, next, fade } = currentSlide();
    const wall = fade > 0.5 ? next : current;
    const thumb = document.querySelector(`.card[data-id="${wall.id}"] .thumb`);
    if (thumb) thumb.click();
  }

  // ---------- render loop ----------

  // Frame the phone plus its shadow (y from about -8.3 to +7.5).
  function fit() {
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    const half = Math.tan((camera.fov * Math.PI) / 360);
    const distH = (H + 1.3) / 0.94 / 2 / half;
    const distW = (W * 1.35) / 2 / half / camera.aspect;
    camera.position.set(0, 0.1, Math.max(distH, distW));
    camera.lookAt(0, -0.4, 0);
    camera.updateProjectionMatrix();
  }

  let raf = 0;
  let last = 0;
  let onScreen = false;
  let lastLiveDraw = 0;
  // If frames are slow (an old phone, software rendering), drop to 1x pixels.
  let slowFrames = 0;
  let sampledFrames = 0;

  function tick(now) {
    raf = requestAnimationFrame(tick);
    const dt = Math.min(0.05, last ? (now - last) / 1000 : 0);
    if (last && renderer.getPixelRatio() > 1 && sampledFrames < 120) {
      sampledFrames++;
      if (now - last > 40) slowFrames++;
      if (slowFrames > 30) {
        renderer.setPixelRatio(1);
        fit();
      }
    }
    last = now;
    const still = reduce.matches;

    if (!dragging && !still) {
      autoT += dt;
      screenT += dt;
    }

    // Inertia, then drift back to the nearest front-facing angle.
    if (!dragging) {
      userYaw += velYaw;
      velYaw *= Math.pow(0.92, dt * 60);
      if (now - releasedAt > 1500 && Math.abs(velYaw) < 0.002) {
        const k = 1 - Math.pow(0.97, dt * 60);
        userYaw += (Math.round(userYaw / TAU) * TAU - userYaw) * k;
        userPitch += (0 - userPitch) * k;
      }
    }

    const intro = ease(clamp((now - introStart) / 1200, 0, 1));
    const bob = still ? 0 : Math.sin(autoT * 0.9) * 0.12;
    phone.rotation.y = (still ? 0 : autoYaw(autoT)) + userYaw - (1 - intro) * 1.4;
    phone.rotation.x = (still ? 0.04 : 0.06 + Math.sin(autoT * 0.5) * 0.04) + userPitch;
    phone.position.y = bob - (1 - intro) * 4;
    shadowMat.opacity = (0.75 - bob * 1.2) * intro;

    // Redraw the screen only when something on it changed.
    const { current, next, fade, index } = currentSlide();
    let dirty = false;
    if (now - lastClockCheck > 1000) {
      lastClockCheck = now;
      dirty = updateClock();
    }
    const slideKey = index + fade;
    const liveShowing = current.live || (fade > 0 && next.live);
    // Live wallpapers redraw at 30fps to limit texture uploads.
    if (slideKey !== lastDrawn || (liveShowing && !still && now - lastLiveDraw > 33)) dirty = true;
    if (dirty) {
      lastDrawn = slideKey;
      lastLiveDraw = now;
      drawScreen(current, next, fade, still ? 0 : screenT);
    }

    renderer.render(scene, camera);
  }

  function start() {
    if (raf || !onScreen || document.hidden) return;
    last = 0;
    raf = requestAnimationFrame(tick);
  }

  function stop() {
    cancelAnimationFrame(raf);
    raf = 0;
  }

  // ---------- mount ----------

  host.appendChild(canvas);
  fit();
  updateClock();
  drawScreen(picks[0], picks[1 % picks.length], 0, 0);
  lastDrawn = 0;
  renderer.render(scene, camera);
  host.classList.add('has-3d');

  new ResizeObserver(fit).observe(host);
  new IntersectionObserver(([entry]) => {
    onScreen = entry.isIntersecting;
    if (onScreen) start();
    else stop();
  }).observe(host);
  document.addEventListener('visibilitychange', () => (document.hidden ? stop() : start()));
  reduce.addEventListener('change', () => { introStart = -Infinity; });

  canvas.addEventListener('webglcontextlost', (e) => {
    e.preventDefault();
    stop();
    host.classList.remove('has-3d');
  });
})();
