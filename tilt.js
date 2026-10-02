/*
 * 3D tilt and depth. Gallery cards tilt toward the mouse with a moving
 * glare. In the viewer the phone tilts with the pointer (or finger), and
 * the lock screen floats above the wallpaper like iOS's perspective effect.
 * Everything is driven through CSS variables; tilt.css does the transforms.
 */
(function () {
  'use strict';

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  const fine = window.matchMedia('(hover: hover) and (pointer: fine)');
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

  // ---------- gallery cards ----------

  const grid = document.getElementById('grid');
  const CARD_MAX = 10;
  let card = null;
  let cardEvent = null;
  let cardFrame = 0;

  function releaseCard() {
    if (!card) return;
    card.classList.remove('tilting');
    ['--rx', '--ry', '--gx', '--gy', '--px', '--py'].forEach((p) => card.style.removeProperty(p));
    card = null;
  }

  function paintCard() {
    cardFrame = 0;
    if (!card || !cardEvent) return;
    const r = card.getBoundingClientRect();
    const nx = clamp((cardEvent.clientX - r.left) / r.width, 0, 1);
    const ny = clamp((cardEvent.clientY - r.top) / r.height, 0, 1);
    card.style.setProperty('--rx', `${((0.5 - ny) * 2 * CARD_MAX).toFixed(2)}deg`);
    card.style.setProperty('--ry', `${((nx - 0.5) * 2 * CARD_MAX).toFixed(2)}deg`);
    card.style.setProperty('--gx', `${(nx * 100).toFixed(1)}%`);
    card.style.setProperty('--gy', `${(ny * 100).toFixed(1)}%`);
    // -1..1 offsets for layered (spatial) thumbnails.
    card.style.setProperty('--px', ((nx - 0.5) * 2).toFixed(3));
    card.style.setProperty('--py', ((ny - 0.5) * 2).toFixed(3));
  }

  grid.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse' || reduce.matches || !fine.matches) return;
    const thumb = e.target.closest('.thumb');
    if (thumb !== card) {
      releaseCard();
      card = thumb;
      if (card) card.classList.add('tilting');
    }
    if (!card) return;
    cardEvent = e;
    if (!cardFrame) cardFrame = requestAnimationFrame(paintCard);
  });
  grid.addEventListener('pointerleave', releaseCard);

  // ---------- viewer phone ----------

  const viewer = document.getElementById('viewer');
  const phone = document.getElementById('phone');
  const screenEl = document.getElementById('screen');
  const PHONE_MAX = 12;
  const IDLE_AFTER = 1800;
  const target = { x: 0, y: 0 };
  const cur = { x: 0, y: 0 };
  let loop = 0;
  let lastInput = -Infinity;
  let lastFrame = 0;

  function aim(x, y) {
    target.x = clamp(x, -1, 1);
    target.y = clamp(y, -1, 1);
    lastInput = performance.now();
  }

  function apply() {
    phone.style.setProperty('--tilt-x', `${(-cur.y * PHONE_MAX).toFixed(2)}deg`);
    phone.style.setProperty('--tilt-y', `${(cur.x * PHONE_MAX).toFixed(2)}deg`);
    screenEl.style.setProperty('--par-x', cur.x.toFixed(3));
    screenEl.style.setProperty('--par-y', cur.y.toFixed(3));
  }

  function reset() {
    cancelAnimationFrame(loop);
    loop = 0;
    target.x = target.y = cur.x = cur.y = 0;
    screenEl.classList.remove('depth');
    ['--tilt-x', '--tilt-y'].forEach((p) => phone.style.removeProperty(p));
    ['--par-x', '--par-y'].forEach((p) => screenEl.style.removeProperty(p));
  }

  function frame(now) {
    loop = 0;
    if (!viewer.open || reduce.matches) {
      reset();
      return;
    }
    // With no input for a moment, the phone sways gently on its own.
    if (now - lastInput > IDLE_AFTER) {
      const s = now / 1000;
      target.x = Math.sin(s * 0.55) * 0.3;
      target.y = Math.sin(s * 0.4 + 1) * 0.18;
    }
    const dt = Math.min(64, now - (lastFrame || now));
    lastFrame = now;
    const k = 1 - Math.pow(0.86, dt / 16.7);
    cur.x += (target.x - cur.x) * k;
    cur.y += (target.y - cur.y) * k;
    apply();
    loop = requestAnimationFrame(frame);
  }

  function start() {
    if (loop || !viewer.open || reduce.matches) return;
    screenEl.classList.add('depth');
    lastFrame = 0;
    loop = requestAnimationFrame(frame);
  }

  // The viewer is a <dialog>; watch its `open` attribute to start and stop.
  new MutationObserver(() => (viewer.open ? start() : reset())).observe(viewer, {
    attributes: true,
    attributeFilter: ['open'],
  });
  reduce.addEventListener('change', () => (reduce.matches ? reset() : start()));

  viewer.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    const r = phone.getBoundingClientRect();
    const reach = Math.max(r.width, r.height) * 0.75;
    aim((e.clientX - (r.left + r.width / 2)) / reach, (e.clientY - (r.top + r.height / 2)) / reach);
  });
  viewer.addEventListener('pointerleave', () => aim(0, 0));

  // On touch, follow the finger during a press. Listeners are passive, so
  // scrolling and the swipe-to-change-wallpaper gesture keep working.
  let touchStart = null;
  screenEl.addEventListener('touchstart', (e) => {
    const t = e.touches[0];
    touchStart = [t.clientX, t.clientY];
  }, { passive: true });
  screenEl.addEventListener('touchmove', (e) => {
    if (!touchStart) return;
    const t = e.touches[0];
    const half = screenEl.clientWidth / 2;
    aim((t.clientX - touchStart[0]) / half, (t.clientY - touchStart[1]) / half);
  }, { passive: true });
  const endTouch = () => {
    touchStart = null;
    aim(0, 0);
  };
  screenEl.addEventListener('touchend', endTouch, { passive: true });
  screenEl.addEventListener('touchcancel', endTouch, { passive: true });
})();
