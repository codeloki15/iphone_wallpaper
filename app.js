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
  const HERO_PICKS = ['synthwave', 'aurora', 'alpine-dawn'];

  const $ = (s) => document.querySelector(s);
  const walls = Walls.list;

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
  };

  function draw(canvas, wall, w, h, variant) {
    canvas.width = w;
    canvas.height = h;
    Walls.render(canvas.getContext('2d'), w, h, wall, variant);
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
  const thumbObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const card = e.target;
        thumbObserver.unobserve(card);
        const wall = walls.find((w) => w.id === card.dataset.id);
        draw(card.querySelector('canvas'), wall, THUMB_W, THUMB_H, 0);
        card.classList.add('ready');
      });
    },
    { rootMargin: '400px 0px' }
  );

  function buildCards() {
    walls.forEach((wall) => {
      const card = document.createElement('article');
      card.className = 'card';
      card.dataset.id = wall.id;
      card.innerHTML = `
        <button type="button" class="thumb" aria-label="Preview ${wall.name}">
          <canvas width="${THUMB_W}" height="${THUMB_H}"></canvas>
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
      thumbObserver.observe(card);
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

  function buildHomeIcons() {
    const apps = $('#apps');
    for (let i = 0; i < 20; i++) apps.appendChild(document.createElement('span'));
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
    const d = state.device;
    $('#vName').textContent = wall.name + (state.variant ? ` · Remix ${state.variant}` : '');
    $('#vCategory').textContent = wall.category;
    $('#vRes').textContent = `${d.w} × ${d.h} px · exact native resolution`;
    screenEl.style.setProperty('--ar', `${d.w} / ${d.h}`);
    screenEl.classList.toggle('classic', d.h / d.w < 2);
    syncFavorites();
    updateClock();
    // Wait for layout so the canvas matches the on-screen size.
    requestAnimationFrame(() => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      const cw = Math.round(screenEl.clientWidth * dpr);
      const ch = Math.round((cw * d.h) / d.w);
      draw(phoneCanvas, wall, cw, ch, state.variant);
    });
  }

  function setMode(mode) {
    state.mode = mode;
    $('#lockOverlay').hidden = mode !== 'lock';
    $('#homeOverlay').hidden = mode !== 'home';
    document.querySelectorAll('.seg-btn').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.mode === mode));
    });
  }

  function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).replace(/\s?[AP]M$/i, '');
    $('#lockTime').textContent = time;
    $('#lockDate').textContent = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
    document.querySelectorAll('.mini-time').forEach((el) => { el.textContent = time; });
  }

  function slug(s) {
    return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  let savedUrl = null;

  // Renders at full resolution and shows the image so it can be saved with a
  // long-press (iOS) or right-click. A direct file download is also offered,
  // though sandboxed hosts may block it.
  function download() {
    const wall = state.visible[state.current];
    if (!wall) return;
    const d = state.device;
    const btn = $('#download');
    btn.disabled = true;
    btn.textContent = 'Rendering…';
    // Yield a frame so the button state paints before the heavy render.
    setTimeout(() => {
      const canvas = document.createElement('canvas');
      draw(canvas, wall, d.w, d.h, state.variant);
      canvas.toBlob((blob) => {
        btn.disabled = false;
        btn.textContent = 'Save wallpaper';
        if (!blob) return;
        closeSaver();
        savedUrl = URL.createObjectURL(blob);
        $('#saverImg').src = savedUrl;
        const link = $('#saverLink');
        if (link) {
          link.href = savedUrl;
          link.download = `${slug(wall.name)}${state.variant ? '-remix-' + state.variant : ''}-${d.w}x${d.h}.png`;
        }
        $('#saverInfo').textContent = `${$('#vName').textContent} · ${d.w} × ${d.h} px`;
        $('#saver').showModal();
        $('#saverClose').focus();
      }, 'image/png');
    }, 30);
  }

  function closeSaver() {
    if ($('#saver').open) $('#saver').close();
    if (savedUrl) {
      URL.revokeObjectURL(savedUrl);
      savedUrl = null;
    }
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
    $('#saver').addEventListener('click', (e) => { if (e.target === $('#saver')) closeSaver(); });
    $('#saver').addEventListener('close', closeSaver);
    document.querySelectorAll('.seg-btn').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));

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
  buildHomeIcons();
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
