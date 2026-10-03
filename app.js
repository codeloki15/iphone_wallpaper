(function () {
  'use strict';

  // Native portrait resolutions, grouped by models that share a screen.
  const DEVICES = [
    { id: '1320x2868', name: 'iPhone 17 Pro Max · 16 Pro Max', w: 1320, h: 2868 },
    { id: '1206x2622', name: 'iPhone 17 · 17 Pro · 16 Pro', w: 1206, h: 2622 },
    { id: '1260x2736', name: 'iPhone Air', w: 1260, h: 2736 },
    { id: '1290x2796', name: 'iPhone 16 Plus · 15 Plus · 15 Pro Max · 14 Pro Max', w: 1290, h: 2796 },
    { id: '1179x2556', name: 'iPhone 16 · 15 · 15 Pro · 14 Pro', w: 1179, h: 2556 },
    { id: '1284x2778', name: 'iPhone 14 Plus · 13 Pro Max · 12 Pro Max', w: 1284, h: 2778 },
    { id: '1170x2532', name: 'iPhone 16e · 14 · 13 · 13 Pro · 12 · 12 Pro', w: 1170, h: 2532 },
    { id: '1080x2340', name: 'iPhone 13 mini · 12 mini', w: 1080, h: 2340 },
    { id: '1242x2688', name: 'iPhone 11 Pro Max · XS Max', w: 1242, h: 2688 },
    { id: '1125x2436', name: 'iPhone 11 Pro · XS · X', w: 1125, h: 2436 },
    { id: '828x1792', name: 'iPhone 11 · XR', w: 828, h: 1792 },
    { id: '750x1334', name: 'iPhone SE (2nd & 3rd gen) · 8', w: 750, h: 1334 },
  ];

  const THUMB_W = 360;
  const THUMB_H = Math.round((THUMB_W * 2556) / 1179);
  // Live thumbnails redraw every frame, so they use a smaller canvas.
  const LIVE_THUMB_W = 270;
  const LIVE_THUMB_H = Math.round((LIVE_THUMB_W * 2556) / 1179);
  const HERO_PICKS = ['synthwave', 'aurora', 'alpine-dawn'];

  const $ = (s) => document.querySelector(s);
  const walls = Walls.list;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const clockStart = performance.now();
  const seconds = () => (performance.now() - clockStart) / 1000;

  // localStorage can be unavailable (private mode, blocked storage).
  const store = {
    get(key, fallback) {
      try {
        const v = localStorage.getItem(key);
        return v ? JSON.parse(v) : fallback;
      } catch (e) {
        return fallback;
      }
    },
    set(key, value) {
      try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* ignore */ }
    },
  };

  function detectDevice() {
    const dpr = window.devicePixelRatio || 1;
    const w = Math.round(Math.min(screen.width, screen.height) * dpr);
    const h = Math.round(Math.max(screen.width, screen.height) * dpr);
    return DEVICES.find((d) => d.w === w && d.h === h);
  }

  const state = {
    category: 'All',
    query: '',
    favorites: new Set(store.get('pw:favs', [])),
    device: DEVICES.find((d) => d.id === store.get('pw:device')) || detectDevice() || DEVICES[1],
    visible: walls.slice(),
    current: -1,
    variant: 0,
    mode: 'lock',
    iconStyle: ['color', 'light', 'dark', 'mono'].includes(store.get('pw:iconStyle')) ? store.get('pw:iconStyle') : 'color',
    lockWidgets: store.get('pw:lockWidgets', false) === true,
    signature: typeof store.get('pw:signature') === 'string' ? store.get('pw:signature') : '',
    face: Faces.STYLES.includes(store.get('pw:face')) ? store.get('pw:face') : 'classic',
    layout: Setups.LAYOUTS[store.get('pw:layout')] ? store.get('pw:layout') : 'grid',
    t: 0,
  };

  // Resizing a canvas reallocates it, so only do it when the size changes.
  function draw(canvas, wall, w, h, variant, t = 0) {
    if (canvas.width !== w) canvas.width = w;
    if (canvas.height !== h) canvas.height = h;
    Walls.render(canvas.getContext('2d'), w, h, wall, variant, t);
  }

  const heartSvg =
    '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>';

  // ---------- hero ----------

  function buildHero() {
    const host = $('#heroPhones');
    HERO_PICKS.forEach((id) => {
      const wall = walls.find((w) => w.id === id);
      const phone = document.createElement('div');
      phone.className = 'mini-phone';
      phone.innerHTML = '<div class="mini-screen"><canvas></canvas><div class="mini-island"></div><div class="mini-time"></div></div>';
      host.appendChild(phone);
      draw(phone.querySelector('canvas'), wall, 300, Math.round((300 * 2556) / 1179), 0);
    });
  }

  // ---------- gallery ----------

  const cards = new Map();
  const wallOf = new WeakMap();

  // Draws one depth layer of a spatial wall (the front is transparent).
  function drawLayer(canvas, wall, w, h, variant, layer) {
    if (canvas.width !== w) canvas.width = w;
    if (canvas.height !== h) canvas.height = h;
    Walls.render(canvas.getContext('2d'), w, h, wall, variant, 0, layer);
  }

  function drawThumb(card, t) {
    const wall = wallOf.get(card);
    const canvas = card.querySelector('canvas');
    if (wall.live) {
      draw(canvas, wall, LIVE_THUMB_W, LIVE_THUMB_H, 0, t);
    } else if (wall.spatial) {
      // Two canvases, so hovering can shift them at different depths.
      drawLayer(canvas, wall, THUMB_W, THUMB_H, 0, 'back');
      drawLayer(card.querySelector('.spatial-front'), wall, THUMB_W, THUMB_H, 0, 'front');
    } else {
      draw(canvas, wall, THUMB_W, THUMB_H, 0);
    }
  }

  const thumbObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const card = e.target;
        thumbObserver.unobserve(card);
        drawThumb(card, seconds());
        card.classList.add('ready');
      });
    },
    { rootMargin: '400px 0px' }
  );

  // Live cards animate at ~30fps, only while on screen and the viewer is closed.
  const liveVisible = new Set();
  let thumbLoop = 0;
  let lastThumbFrame = 0;
  const liveObserver = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) liveVisible.add(e.target);
      else liveVisible.delete(e.target);
    });
    startThumbLoop();
  });

  function startThumbLoop() {
    if (thumbLoop || !liveVisible.size || reduceMotion.matches || viewer.open) return;
    thumbLoop = requestAnimationFrame(tickThumbs);
  }

  function tickThumbs(ts) {
    thumbLoop = 0;
    if (!liveVisible.size || reduceMotion.matches || viewer.open) return;
    if (ts - lastThumbFrame >= 33) {
      lastThumbFrame = ts;
      const t = seconds();
      liveVisible.forEach((card) => { if (card.isConnected) drawThumb(card, t); });
    }
    thumbLoop = requestAnimationFrame(tickThumbs);
  }

  function buildCards() {
    walls.forEach((wall) => {
      const card = document.createElement('article');
      card.className = 'card';
      card.dataset.id = wall.id;
      card.innerHTML = `
        <button type="button" class="thumb${wall.spatial ? ' spatial' : ''}" aria-label="Preview ${wall.name}${wall.live ? ' (live)' : ''}${wall.spatial ? ' (spatial)' : ''}">
          <canvas width="${THUMB_W}" height="${THUMB_H}"></canvas>
          ${wall.spatial ? `<canvas class="spatial-front" width="${THUMB_W}" height="${THUMB_H}"></canvas>` : ''}
          ${wall.live ? '<span class="live-badge" aria-hidden="true">Live</span>' : ''}
          ${wall.spatial ? '<span class="spatial-badge" aria-hidden="true">Spatial</span>' : ''}
        </button>
        <div class="meta">
          <div>
            <h3>${wall.name}</h3>
            <p>${wall.category}</p>
          </div>
          <button type="button" class="fav-btn" aria-label="Favorite ${wall.name}" aria-pressed="false">${heartSvg}</button>
        </div>`;
      card.querySelector('.thumb').addEventListener('click', () => openViewer(state.visible.indexOf(wall)));
      card.querySelector('.fav-btn').addEventListener('click', () => toggleFavorite(wall));
      cards.set(wall.id, card);
      wallOf.set(card, wall);
      thumbObserver.observe(card);
      if (wall.live) liveObserver.observe(card);
    });
    syncFavorites();
  }

  function buildChips() {
    const host = $('#chips');
    [...Walls.categories, 'Favorites'].forEach((cat) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'chip';
      b.textContent = cat;
      b.setAttribute('role', 'tab');
      b.addEventListener('click', () => {
        state.category = cat;
        renderGrid();
      });
      host.appendChild(b);
    });
  }

  function renderGrid() {
    const q = state.query.trim().toLowerCase();
    state.visible = walls.filter((w) => {
      if (state.category === 'Favorites' && !state.favorites.has(w.id)) return false;
      if (state.category !== 'All' && state.category !== 'Favorites' && w.category !== state.category) return false;
      return !q || w.name.toLowerCase().includes(q) || w.category.toLowerCase().includes(q);
    });
    const grid = $('#grid');
    grid.replaceChildren(...state.visible.map((w) => cards.get(w.id)));
    $('#empty').hidden = state.visible.length > 0;
    $('#empty').textContent =
      state.category === 'Favorites' && !q
        ? 'No favorites yet. Tap the heart on any wallpaper to save it here.'
        : 'No wallpapers match your search.';
    document.querySelectorAll('.chip').forEach((c) => {
      c.setAttribute('aria-selected', String(c.textContent === state.category));
    });
  }

  function toggleFavorite(wall) {
    if (state.favorites.has(wall.id)) state.favorites.delete(wall.id);
    else state.favorites.add(wall.id);
    store.set('pw:favs', [...state.favorites]);
    syncFavorites();
    if (state.category === 'Favorites') renderGrid();
  }

  function syncFavorites() {
    cards.forEach((card, id) => {
      card.querySelector('.fav-btn').setAttribute('aria-pressed', String(state.favorites.has(id)));
    });
    const wall = state.visible[state.current];
    if (wall) {
      const on = state.favorites.has(wall.id);
      $('#fav').setAttribute('aria-pressed', String(on));
      $('#fav span').textContent = on ? 'Saved' : 'Favorite';
    }
  }

  // ---------- viewer ----------

  const viewer = $('#viewer');
  const screenEl = $('#screen');
  const phoneCanvas = $('#phoneCanvas');
  const phoneFront = $('#phoneFront');

  function buildDeviceSelect() {
    const sel = $('#model');
    DEVICES.forEach((d) => {
      const o = document.createElement('option');
      o.value = d.id;
      o.textContent = d.name;
      sel.appendChild(o);
    });
    sel.value = state.device.id;
    sel.addEventListener('change', () => {
      state.device = DEVICES.find((d) => d.id === sel.value);
      store.set('pw:device', state.device.id);
      updateViewer();
    });
  }

  // ---------- matching theme ----------

  // The preview Home Screen follows the chosen setup (see setups.js); the
  // dock always holds the first four icons.
  const DOCK = Theme.ICONS.slice(0, 4);
  const iconCache = new Map();
  let currentTheme = null;

  function buildHome() {
    const layout = Setups.LAYOUTS[state.layout];
    const apps = $('#apps');
    apps.replaceChildren();
    $('#homeOverlay').classList.toggle('no-labels', !layout.labels);
    layout.items.forEach((item) => {
      if (item === null) {
        apps.appendChild(document.createElement('div'));
        return;
      }
      if (typeof item === 'string') {
        const icon = Theme.ICONS.find((i) => i.id === item);
        const app = document.createElement('div');
        app.className = 'app';
        app.innerHTML = `<span class="app-icon" data-icon="${icon.id}"></span><span class="app-label">${icon.label}</span>`;
        apps.appendChild(app);
        return;
      }
      const [cols, rows] = Setups.SPAN[item.size];
      const widget = document.createElement('div');
      widget.className = Setups.CLEAR.has(item.widget) ? 'widget' : 'widget widget-card';
      widget.dataset.widget = item.widget;
      widget.style.gridColumn = `span ${cols}`;
      widget.style.gridRow = `span ${rows}`;
      widget.innerHTML = '<canvas></canvas>';
      apps.appendChild(widget);
    });
    if (!$('#dock').children.length) {
      DOCK.forEach((icon) => {
        const span = document.createElement('span');
        span.className = 'app-icon';
        span.dataset.icon = icon.id;
        $('#dock').appendChild(span);
      });
    }
  }

  function iconUrl(iconId, style, theme, key) {
    const k = `${key}|${style}|${iconId}`;
    if (!iconCache.has(k)) iconCache.set(k, Theme.iconCanvas(128, iconId, style, theme).toDataURL());
    return iconCache.get(k);
  }

  // Widgets are canvases sized to their grid cell, so they wait for layout.
  function drawWidgets() {
    if (!currentTheme) return;
    const now = new Date();
    const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
    document.querySelectorAll('#homeOverlay .widget').forEach((el) => {
      const canvas = el.querySelector('canvas');
      const w = Math.round(el.clientWidth * dpr);
      const h = Math.round(el.clientHeight * dpr);
      if (!w || !h) return;
      if (canvas.width !== w) canvas.width = w;
      if (canvas.height !== h) canvas.height = h;
      Setups.drawWidget(canvas.getContext('2d'), w, h, el.dataset.widget, currentTheme, state.iconStyle, now);
    });
  }

  function renderFace() {
    const classic = state.face === 'classic';
    $('#lockDate').hidden = !classic;
    $('#lockTime').hidden = !classic;
    $('#lockFace').hidden = classic;
    if (!classic) Faces.render($('#lockFace'), state.face, new Date());
    renderLockWidgets();
  }

  // Lock Screen widgets sit under the Classic clock, as on iOS: a music
  // waveform and a handwritten signature.
  function renderLockWidgets() {
    const show = state.lockWidgets && state.face === 'classic';
    $('#lockWidgets').hidden = !show;
    if (!show) return;
    const wall = state.visible[state.current];
    const script = $('#lwScript');
    script.textContent = state.signature || (wall ? wall.name : 'Pocket Walls');
    // Shrink long signatures to fit their widget instead of cutting them off.
    script.style.fontSize = '';
    let size = parseFloat(getComputedStyle(script).fontSize);
    const min = size * 0.5;
    while (script.scrollWidth > script.clientWidth + 1 && size > min) {
      size *= 0.92;
      script.style.fontSize = `${size}px`;
    }
    $('#lwSub').textContent = new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    const canvas = $('#lwWave');
    const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
    const w = Math.round(canvas.clientWidth * dpr);
    const h = Math.round(canvas.clientHeight * dpr);
    if (!w || !h) return;
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    // Bars from a seed, so each wallpaper keeps the same waveform.
    const rand = Walls.util.mulberry32(wall ? wall.seed : 7);
    const bars = 46;
    const bw = w / bars;
    ctx.fillStyle = getComputedStyle($('#lockWidgets')).color;
    for (let i = 0; i < bars; i++) {
      const env = Math.sin((i / bars) * Math.PI) * 0.6 + 0.4;
      const bh = Math.max(h * 0.08, h * env * (0.25 + rand() * 0.75));
      ctx.globalAlpha = 0.55 + rand() * 0.45;
      ctx.fillRect(i * bw + bw * 0.2, (h - bh) / 2, bw * 0.6, bh);
    }
  }

  // ---------- complete looks ----------

  const LOOKS = [
    { name: 'Black Vision', wall: 'torn-mono', iconStyle: 'mono', face: 'classic', lockWidgets: true, layout: 'diagonal', signature: 'Black Vision' },
    { name: 'Terracotta Day', wall: 'torn-terracotta', iconStyle: 'color', face: 'vertical', lockWidgets: false, layout: 'minimal' },
    { name: 'Doodle Split', wall: 'doodle-panel', iconStyle: 'mono', face: 'vertical', lockWidgets: false, layout: 'dial' },
    { name: 'Rose Words', wall: 'silk-rose', iconStyle: 'light', face: 'words', lockWidgets: false, layout: 'minimal' },
    { name: 'Graphite Dial', wall: 'torn-graphite', iconStyle: 'dark', face: 'dial', lockWidgets: false, layout: 'dial' },
    { name: 'Lunar Depth', wall: 'lunar-peak', iconStyle: 'dark', face: 'classic', lockWidgets: true, layout: 'grid', signature: 'Moonlight' },
  ];
  const FACE_NAMES = { classic: 'Classic', dial: 'Dial', vertical: 'Vertical', words: 'Words' };

  function buildLooks() {
    const row = $('#looksRow');
    LOOKS.forEach((look) => {
      const wall = walls.find((w) => w.id === look.wall);
      if (!wall) return;
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'look';
      card.innerHTML = `
        <canvas width="${LIVE_THUMB_W}" height="${LIVE_THUMB_H}"></canvas>
        <span class="look-meta">
          <strong>${look.name}</strong>
          <span>${look.iconStyle[0].toUpperCase() + look.iconStyle.slice(1)} icons · ${FACE_NAMES[look.face]} clock · ${Setups.LAYOUTS[look.layout].name}</span>
        </span>`;
      card.addEventListener('click', () => applyLook(look));
      row.appendChild(card);
      draw(card.querySelector('canvas'), wall, LIVE_THUMB_W, LIVE_THUMB_H, 0);
    });
  }

  function applyLook(look) {
    state.category = 'All';
    state.query = '';
    $('#search').value = '';
    renderGrid();
    state.lockWidgets = look.lockWidgets;
    store.set('pw:lockWidgets', look.lockWidgets);
    $('#lockWidgetsToggle').checked = look.lockWidgets;
    if (look.signature !== undefined) {
      state.signature = look.signature;
      store.set('pw:signature', look.signature);
      $('#sigInput').value = look.signature;
    }
    setIconStyle(look.iconStyle);
    setFace(look.face);
    openViewer(state.visible.findIndex((w) => w.id === look.wall));
    setLayout(look.layout);
  }

  // Re-themes everything in the preview that follows the wallpaper: icons,
  // widgets, clock color, swatches and the color codes in the guide.
  function applyTheme(wall) {
    const theme = Theme.fromWall(wall, state.bgLum);
    currentTheme = theme;
    const key = wall.palette.join('');
    document.querySelectorAll('#homeOverlay .app-icon').forEach((el) => {
      el.style.backgroundImage = `url(${iconUrl(el.dataset.icon, state.iconStyle, theme, key)})`;
    });
    $('#lockOverlay').style.setProperty('--clock', theme.clock);
    requestAnimationFrame(() => {
      drawWidgets();
      renderFace();
    });
    const swatches = [['Accent', theme.accent], ['Second', theme.second], ['Clock', theme.clock]];
    $('#swatches').replaceChildren(...swatches.map(([label, hex]) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'swatch';
      b.dataset.hex = hex;
      b.innerHTML = `<span class="chip-color" style="background:${hex}"></span><span class="sw-label">${label}</span><span class="sw-hex">${hex}</span>`;
      return b;
    }));
    document.querySelectorAll('#guide .hex').forEach((el) => {
      const hex = theme[el.dataset.key];
      el.innerHTML = `<span class="chip-color" style="background:${hex}"></span>${hex}`;
    });
    syncGuideSetup();
  }

  // The Setup tab of the guide names the current layout's widgets.
  function syncGuideSetup() {
    const layout = Setups.LAYOUTS[state.layout];
    const widgets = layout.items.filter((item) => item && typeof item === 'object');
    $('#guideWidgets').textContent = widgets.length
      ? widgets.map((item) => `a ${item.size} "${Setups.NAMES[item.widget]}" widget`).join(' and ')
      : 'the widgets';
    $('#guideLabels').textContent = layout.labels
      ? `The ${layout.name} layout uses normal icons with names, so no change is needed.`
      : `The ${layout.name} layout uses big icons without names: touch and hold the Home Screen, tap Edit → Customize, then choose Large.`;
  }

  function setFace(face) {
    state.face = face;
    store.set('pw:face', face);
    document.querySelectorAll('.seg-btn[data-face]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.face === face));
    });
    setMode('lock');
    requestAnimationFrame(renderFace);
  }

  function setLayout(layout) {
    state.layout = layout;
    store.set('pw:layout', layout);
    document.querySelectorAll('.seg-btn[data-layout]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.layout === layout));
    });
    buildHome();
    const wall = state.visible[state.current];
    if (wall) applyTheme(wall);
    setMode('home');
  }

  function setIconStyle(style) {
    state.iconStyle = style;
    store.set('pw:iconStyle', style);
    document.querySelectorAll('.seg-btn[data-style]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.style === style));
    });
    const wall = state.visible[state.current];
    if (wall) applyTheme(wall);
    // Icons only show on the Home Screen, so switch to it.
    setMode('home');
  }

  async function copyHex(button) {
    const hex = button.dataset.hex;
    const label = button.querySelector('.sw-hex');
    try {
      await navigator.clipboard.writeText(hex);
      label.textContent = 'Copied';
    } catch (e) {
      // Clipboard refused: select the code so it can be copied by hand.
      const range = document.createRange();
      range.selectNodeContents(label);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
      return;
    }
    setTimeout(() => { label.textContent = hex; }, 1200);
  }

  async function downloadPack() {
    const wall = state.visible[state.current];
    if (!wall) return;
    const btn = $('#packBtn');
    const status = (text) => { $('#packStatus').textContent = text; };
    btn.disabled = true;
    btn.textContent = 'Building…';
    status('');
    try {
      const layout = Setups.LAYOUTS[state.layout];
      const theme = Theme.fromWall(wall, state.bgLum);
      const now = new Date();
      const widgets = layout.items.filter((item) => item && typeof item === 'object');
      const blob = await Theme.buildPack({
        wall,
        variant: state.variant,
        t: wall.live ? state.t : 0,
        device: state.device,
        style: state.iconStyle,
        bgLum: state.bgLum,
        extras: widgets.map((item) => ({
          name: `widgets/${item.size}-${item.widget}.png`,
          canvas: Setups.widgetCanvas(item.widget, item.size, theme, state.iconStyle, now),
        })),
        notes: [
          `HOME SCREEN SETUP: ${layout.name}`,
          layout.labels
            ? '1. Keep normal icons with names.'
            : '1. Touch and hold the Home Screen > Edit > Customize > Large (big icons, no names).',
          `2. In a widget app that lets you design widgets, recreate ${widgets.map((item) => `the ${item.size} ${Setups.NAMES[item.widget]} widget`).join(' and ')}`,
          '   using the images in the widgets folder. Use a transparent background where the image has no card.',
          '3. Touch and hold the Home Screen > Edit > Add Widget, pick your widget app and size, then choose your design.',
          '4. Drag your apps into place. Since iOS 18 you can leave empty spaces.',
          '',
          'LOCK SCREEN CLOCK',
          `iOS doesn't allow custom clock faces. In Customize, tap the time and pick a font and the color ${theme.clock}.`,
        ],
      });
      const filename = `${slug(wall.name)}${state.variant ? '-remix-' + state.variant : ''}-theme.zip`;
      if (await saveWithViewer(blob, filename, status, 'Saved. Open How to apply for the next steps.')) return;
      if (inClaudeViewer) {
        status("Saving files isn't available here. Open the site in Safari to download the pack.");
        return;
      }
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 10000);
      status('Downloaded. Open How to apply for the next steps.');
    } catch (e) {
      status('The pack could not be built. Try again, or pick a smaller iPhone model.');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Theme pack';
    }
  }

  function setGuideTab(tab) {
    document.querySelectorAll('.seg-btn[data-tab]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.tab === tab));
    });
    $('#guideQuick').hidden = tab !== 'quick';
    $('#guideIcons').hidden = tab !== 'icons';
    $('#guideIconsNote').hidden = tab !== 'icons';
    $('#guideSetup').hidden = tab !== 'setup';
  }

  function openViewer(index) {
    if (index < 0) return;
    state.current = index;
    state.variant = 0;
    if (!viewer.open) viewer.showModal();
    updateViewer();
  }

  function step(delta) {
    const n = state.visible.length;
    if (!n) return;
    state.current = (state.current + delta + n) % n;
    state.variant = 0;
    updateViewer();
  }

  function updateViewer() {
    const wall = state.visible[state.current];
    if (!wall) return;
    if (wall.id + state.variant !== state.sampledFor) {
      state.sampledFor = wall.id + state.variant;
      state.bgLum = undefined;
    }
    const d = state.device;
    $('#vName').textContent = wall.name + (state.variant ? ` · Remix ${state.variant}` : '');
    $('#vCategory').textContent = wall.category;
    // Live and spatial walls show a badge instead of the plain category label.
    $('#vCategory').hidden = !!(wall.live || wall.spatial);
    $('#vLive').hidden = !wall.live;
    $('#vSpatial').hidden = !wall.spatial;
    $('#liveNote').hidden = !wall.live;
    $('#spatialNote').hidden = !wall.spatial;
    $('#vRes').textContent = `${d.w} × ${d.h} px · exact native resolution`;
    screenEl.style.setProperty('--ar', `${d.w} / ${d.h}`);
    screenEl.classList.toggle('classic', d.h / d.w < 2);
    syncFavorites();
    updateClock();
    applyTheme(wall);
    // Wait for layout so the canvas matches the on-screen size.
    requestAnimationFrame(() => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      const cw = Math.round(screenEl.clientWidth * dpr);
      const ch = Math.round((cw * d.h) / d.w);
      renderPhone(wall, cw, ch);
    });
  }

  let viewerLoop = 0;

  function stopViewerLoop() {
    cancelAnimationFrame(viewerLoop);
    viewerLoop = 0;
  }

  // Static walls draw once; live walls animate while the viewer is open.
  // Under reduced motion a live wall shows its first frame.
  // Average brightness behind the clock and top widgets (upper left two
  // thirds of the screen), so text colors contrast with what's really there.
  function sampleBackground(wall) {
    try {
      const w = phoneCanvas.width;
      const h = phoneCanvas.height;
      const data = phoneCanvas.getContext('2d').getImageData(Math.round(w * 0.05), Math.round(h * 0.07), Math.round(w * 0.6), Math.round(h * 0.36)).data;
      let sum = 0;
      let n = 0;
      for (let i = 0; i < data.length; i += 4 * 37) {
        sum += Theme.luminance('#' + [data[i], data[i + 1], data[i + 2]].map((v) => v.toString(16).padStart(2, '0')).join(''));
        n++;
      }
      const lum = n ? sum / n : undefined;
      if (lum !== undefined && (state.bgLum === undefined || Math.abs(lum - state.bgLum) > 0.01)) {
        state.bgLum = lum;
        applyTheme(wall);
      }
    } catch (e) {
      // Reading pixels can fail in unusual contexts; keep the palette guess.
    }
  }

  function renderPhone(wall, cw, ch) {
    stopViewerLoop();
    // Spatial walls split into two layers with the clock between them.
    phoneFront.hidden = !wall.spatial;
    if (wall.spatial) {
      state.t = 0;
      drawLayer(phoneCanvas, wall, cw, ch, state.variant, 'back');
      drawLayer(phoneFront, wall, cw, ch, state.variant, 'front');
      sampleBackground(wall);
      return;
    }
    if (!wall.live || reduceMotion.matches) {
      state.t = 0;
      draw(phoneCanvas, wall, cw, ch, state.variant, 0);
      sampleBackground(wall);
      return;
    }
    const tick = () => {
      state.t = seconds();
      draw(phoneCanvas, wall, cw, ch, state.variant, state.t);
      viewerLoop = requestAnimationFrame(tick);
    };
    tick();
    sampleBackground(wall);
  }

  function setMode(mode) {
    state.mode = mode;
    $('#lockOverlay').hidden = mode !== 'lock';
    $('#homeOverlay').hidden = mode !== 'home';
    document.querySelectorAll('.seg-btn[data-mode]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.mode === mode));
    });
    requestAnimationFrame(() => (mode === 'home' ? drawWidgets() : renderFace()));
  }

  function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).replace(/\s?[AP]M$/i, '');
    $('#lockTime').textContent = time;
    $('#lockDate').textContent = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
    document.querySelectorAll('.mini-time').forEach((el) => { el.textContent = time; });
    if (viewer.open) {
      if (state.mode === 'lock' && state.face !== 'classic') renderFace();
      if (state.mode === 'home') drawWidgets();
    }
  }

  function slug(s) {
    return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  let savedUrl = null;
  let savedBlob = null;
  let savedName = '';

  // Inside the Claude artifact viewer, files must go through its `downloads`
  // capability. Elsewhere `window.claude` is absent and a normal link is used.
  const inClaudeViewer = !!(window.claude && typeof window.claude.use === 'function');
  const downloadsReady = inClaudeViewer
    ? window.claude.use('downloads').catch(() => null)
    : Promise.resolve(null);

  function setStatus(text) {
    $('#dlStatus').textContent = text;
  }

  // Returns true if the file was handed to the viewer's save prompt.
  async function saveWithViewer(blob, filename, status = setStatus, savedText = 'Saved. Set it in Settings → Wallpaper.') {
    const downloads = await downloadsReady;
    if (!downloads) return false;
    try {
      await downloads.save({ filename, data: blob });
      status(savedText);
    } catch (err) {
      const code = err && err.code;
      if (code === 'declined') status('');
      else if (code === 'rate_limited') status('A save prompt is already open.');
      else return false;
    }
    return true;
  }

  // Renders at full resolution, then offers the file. If no save prompt is
  // available, shows the image so it can be saved with a long-press (iOS) or
  // right-click, plus a direct download link.
  function download() {
    const wall = state.visible[state.current];
    if (!wall) return;
    const d = state.device;
    const btn = $('#download');
    btn.disabled = true;
    btn.textContent = 'Rendering…';
    setStatus('');
    // A live wall is saved as the frame on screen right now.
    const t = wall.live ? state.t : 0;
    // Yield a frame so the button state paints before the heavy render.
    setTimeout(() => {
      const canvas = document.createElement('canvas');
      draw(canvas, wall, d.w, d.h, state.variant, t);
      canvas.toBlob(async (blob) => {
        btn.disabled = false;
        btn.textContent = 'Download wallpaper';
        if (!blob) return;
        const filename = `${slug(wall.name)}${state.variant ? '-remix-' + state.variant : ''}-${d.w}x${d.h}.png`;
        if (await saveWithViewer(blob, filename)) return;
        showSaver(blob, filename, `${$('#vName').textContent} · ${d.w} × ${d.h} px`);
      }, 'image/png');
    }, 30);
  }

  function showSaver(blob, filename, info) {
    closeSaver();
    savedBlob = blob;
    savedName = filename;
    savedUrl = URL.createObjectURL(blob);
    $('#saverImg').src = savedUrl;
    const link = $('#saverLink');
    link.href = savedUrl;
    link.download = filename;
    // In the Claude viewer a plain link can't download, so hide it.
    downloadsReady.then((downloads) => { link.hidden = inClaudeViewer && !downloads; });
    $('#saverInfo').textContent = info;
    $('#saver').showModal();
    $('#saverClose').focus();
  }

  function closeSaver() {
    if ($('#saver').open) $('#saver').close();
    if (savedUrl) {
      URL.revokeObjectURL(savedUrl);
      savedUrl = null;
    }
    savedBlob = null;
  }

  function bindViewer() {
    $('#close').addEventListener('click', () => viewer.close());
    $('#prev').addEventListener('click', () => step(-1));
    $('#next').addEventListener('click', () => step(1));
    $('#remix').addEventListener('click', () => {
      state.variant += 1;
      updateViewer();
    });
    $('#fav').addEventListener('click', () => {
      const wall = state.visible[state.current];
      if (wall) toggleFavorite(wall);
    });
    $('#download').addEventListener('click', download);
    $('#saverClose').addEventListener('click', closeSaver);
    $('#saverLink').addEventListener('click', async (e) => {
      if (!inClaudeViewer || !savedBlob) return;
      e.preventDefault();
      await saveWithViewer(savedBlob, savedName);
    });
    $('#saver').addEventListener('click', (e) => { if (e.target === $('#saver')) closeSaver(); });
    $('#saver').addEventListener('close', closeSaver);
    document.querySelectorAll('.seg-btn[data-mode]').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
    document.querySelectorAll('.seg-btn[data-style]').forEach((b) => b.addEventListener('click', () => setIconStyle(b.dataset.style)));
    document.querySelectorAll('.seg-btn[data-face]').forEach((b) => b.addEventListener('click', () => setFace(b.dataset.face)));
    document.querySelectorAll('.seg-btn[data-layout]').forEach((b) => b.addEventListener('click', () => setLayout(b.dataset.layout)));
    $('#lockWidgetsToggle').addEventListener('change', (e) => {
      state.lockWidgets = e.target.checked;
      store.set('pw:lockWidgets', state.lockWidgets);
      if (state.lockWidgets && state.face !== 'classic') setFace('classic');
      else setMode('lock');
      requestAnimationFrame(renderLockWidgets);
    });
    $('#sigInput').addEventListener('input', (e) => {
      state.signature = e.target.value.trim();
      store.set('pw:signature', state.signature);
      renderLockWidgets();
    });
    $('#swatches').addEventListener('click', (e) => {
      const b = e.target.closest('.swatch');
      if (b) copyHex(b);
    });
    $('#packBtn').addEventListener('click', downloadPack);
    const guide = $('#guide');
    $('#guideBtn').addEventListener('click', () => guide.showModal());
    $('#guideClose').addEventListener('click', () => guide.close());
    guide.addEventListener('click', (e) => { if (e.target === guide) guide.close(); });
    document.querySelectorAll('.seg-btn[data-tab]').forEach((b) => b.addEventListener('click', () => setGuideTab(b.dataset.tab)));

    viewer.addEventListener('close', () => {
      stopViewerLoop();
      startThumbLoop();
    });
    reduceMotion.addEventListener('change', () => {
      startThumbLoop();
      if (viewer.open) updateViewer();
    });

    // Close when clicking the backdrop.
    viewer.addEventListener('click', (e) => {
      if (e.target === viewer) viewer.close();
    });
    viewer.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'SELECT') return;
      if (e.key === 'ArrowLeft') step(-1);
      if (e.key === 'ArrowRight') step(1);
    });

    let touchX = null;
    screenEl.addEventListener('touchstart', (e) => { touchX = e.touches[0].clientX; }, { passive: true });
    screenEl.addEventListener('touchend', (e) => {
      if (touchX === null) return;
      const dx = e.changedTouches[0].clientX - touchX;
      touchX = null;
      if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
    });

    let resizeTimer;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => { if (viewer.open) updateViewer(); }, 150);
    });
  }

  // ---------- init ----------

  buildHero();
  buildChips();
  buildCards();
  buildDeviceSelect();
  buildHome();
  buildLooks();
  $('#lockWidgetsToggle').checked = state.lockWidgets;
  $('#sigInput').value = state.signature;
  setIconStyle(state.iconStyle);
  setFace(state.face);
  setLayout(state.layout);
  bindViewer();
  setMode('lock');
  renderGrid();
  updateClock();
  setInterval(updateClock, 15000);

  $('#search').addEventListener('input', (e) => {
    state.query = e.target.value;
    renderGrid();
  });

  $('#surprise').addEventListener('click', () => {
    state.category = 'All';
    state.query = '';
    $('#search').value = '';
    renderGrid();
    openViewer(Math.floor(Math.random() * state.visible.length));
  });
})();
