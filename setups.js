/*
 * Home Screen setups. Layouts use the real iOS grid (4 columns, 6 rows)
 * and real widget sizes: small 2x2, medium 4x2, large 4x4. So each one can
 * be rebuilt on an iPhone with a widget app plus the theme's icons. Widgets
 * are drawn on canvas, which lets the theme pack include reference images.
 */
(function () {
  'use strict';

  const { mix } = Walls.util;
  const { FONT, spaced, timeWords, weekday, month } = Faces;

  // Items fill the grid in order. `labels: false` means iOS's Large icon
  // option, which hides app names.
  const LAYOUTS = {
    grid: {
      name: 'Grid',
      labels: true,
      items: [
        { widget: 'calendar', size: 'small' },
        'mail', 'calendar', 'photos', 'camera',
        'maps', 'weather', 'clock', 'notes',
        'store', 'settings', 'videocall', 'files',
        'wallet', 'health', 'chat', 'social',
      ],
    },
    minimal: {
      name: 'Minimal',
      labels: false,
      items: [
        { widget: 'day', size: 'large' },
        { widget: 'applist', size: 'medium' },
      ],
    },
    dial: {
      name: 'Dial',
      labels: false,
      items: [
        { widget: 'dial', size: 'medium' },
        'maps', 'weather', 'clock', 'notes',
        { widget: 'weather', size: 'small' },
        'camera', 'photos', 'mail', 'calendar',
        'store', 'settings', 'files', 'wallet',
      ],
    },
  };

  const SPAN = { small: [2, 2], medium: [4, 2], large: [4, 4] };
  // Reference image sizes (pixels on a 6.1-inch iPhone) for the theme pack.
  const PIXELS = { small: [474, 474], medium: [1014, 474], large: [1014, 1062] };
  const NAMES = {
    calendar: 'Calendar',
    weather: 'Weather',
    dial: 'Dial clock',
    day: 'Day headline',
    applist: 'App list',
  };
  const APPLIST = ['browser', 'social', 'store', 'messages', 'photos', 'settings'];
  // Transparent widgets sit straight on the wallpaper.
  const CLEAR = new Set(['day', 'applist']);

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  // Colors for a widget card, following the icon style and wallpaper.
  function palette(theme, style) {
    const dark = style === 'dark' || (style === 'color' && theme.darkWall);
    const accent = Theme.luminance(theme.accent) > 0.6 && !dark ? mix(theme.accent, '#000000', 0.45) : theme.accent;
    return {
      card: dark ? 'rgba(20,20,26,0.78)' : 'rgba(255,255,255,0.86)',
      ink: dark ? '#ffffff' : '#111114',
      muted: dark ? 'rgba(255,255,255,0.6)' : 'rgba(17,17,20,0.55)',
      accent,
      clear: theme.clock,
    };
  }

  function sentence(now) {
    return `It's ${now.getDate()} ${month(now)}, time now ${timeWords(now)}.`;
  }

  // "Satur–" / "day", like an editorial headline.
  function dayParts(now) {
    const name = weekday(now);
    return [`${name.replace(/day$/, '')}–`, 'day'];
  }

  function shadowText(ctx, on) {
    ctx.shadowColor = on ? 'rgba(0,0,0,0.55)' : 'transparent';
    ctx.shadowBlur = on ? ctx.canvas.width * 0.014 : 0;
  }

  const DRAW = {
    calendar(ctx, w, h, c, theme, style, now) {
      const pad = w * 0.12;
      ctx.fillStyle = c.accent;
      ctx.font = `700 ${w * 0.085}px ${FONT}`;
      ctx.textBaseline = 'top';
      spaced(ctx, weekday(now).toUpperCase(), pad, pad, w * 0.006);
      ctx.fillStyle = c.ink;
      ctx.font = `300 ${w * 0.36}px ${FONT}`;
      ctx.fillText(String(now.getDate()), pad - w * 0.015, pad + w * 0.1);
      ctx.fillStyle = c.muted;
      ctx.font = `500 ${w * 0.075}px ${FONT}`;
      ctx.textBaseline = 'bottom';
      ctx.fillText('No events today', pad, h - pad);
    },

    // Sample conditions: a widget app shows your real weather.
    weather(ctx, w, h, c) {
      const pad = w * 0.12;
      ctx.textBaseline = 'top';
      ctx.fillStyle = c.muted;
      ctx.font = `600 ${w * 0.075}px ${FONT}`;
      ctx.fillText('Today', pad, pad);
      ctx.fillStyle = c.ink;
      ctx.font = `300 ${w * 0.3}px ${FONT}`;
      ctx.fillText('24°', pad - w * 0.01, pad + w * 0.1);
      Theme.drawGlyph(ctx, 'weather', c.accent, w * 0.28, w - pad - w * 0.28, pad);
      ctx.textBaseline = 'bottom';
      ctx.fillStyle = c.ink;
      ctx.font = `600 ${w * 0.075}px ${FONT}`;
      ctx.fillText('Clear', pad, h - pad - w * 0.09);
      ctx.fillStyle = c.muted;
      ctx.font = `500 ${w * 0.07}px ${FONT}`;
      ctx.fillText('H 27°  L 18°', pad, h - pad);
    },

    dial(ctx, w, h, c, theme, style, now) {
      ctx.save();
      ctx.translate(w * 0.03, 0);
      Faces.drawDial(ctx, w * 0.97, h, c.ink, now, 58, false);
      ctx.restore();
    },

    day(ctx, w, h, c, theme, style, now) {
      const pad = w * 0.06;
      const [a, b] = dayParts(now);
      ctx.fillStyle = c.clear;
      shadowText(ctx, true);
      ctx.textBaseline = 'alphabetic';
      ctx.font = `600 ${w * 0.11}px ${FONT}`;
      ctx.fillText(a, pad, pad + w * 0.11);
      ctx.font = `200 ${w * 0.27}px ${FONT}`;
      ctx.fillText(b, pad - w * 0.01, pad + w * 0.36);
      ctx.font = `500 ${w * 0.042}px ${FONT}`;
      wrap(ctx, sentence(now), pad, pad + w * 0.47, w * 0.62, w * 0.056);
      Theme.drawGlyph(ctx, 'weather', c.clear, w * 0.085, pad, pad + w * 0.62);
      ctx.font = `500 ${w * 0.042}px ${FONT}`;
      ctx.fillText('Clear, 24°', pad + w * 0.11, pad + w * 0.68);
      // Music: a play button and a pill.
      shadowText(ctx, false);
      const y = pad + w * 0.79;
      const r = w * 0.045;
      ctx.beginPath();
      ctx.arc(pad + r, y, r, 0, Math.PI * 2);
      ctx.fillStyle = c.clear;
      ctx.fill();
      ctx.fillStyle = mix(c.clear, '#000000', 0.85);
      ctx.beginPath();
      ctx.moveTo(pad + r * 0.75, y - r * 0.45);
      ctx.lineTo(pad + r * 1.4, y);
      ctx.lineTo(pad + r * 0.75, y + r * 0.45);
      ctx.closePath();
      ctx.fill();
      roundRect(ctx, pad + r * 2.6, y - r, w * 0.2, r * 2, r);
      ctx.fillStyle = c.accent;
      ctx.fill();
      ctx.fillStyle = Theme.luminance(c.accent) > 0.5 ? '#111114' : '#ffffff';
      ctx.font = `600 ${w * 0.04}px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('Play', pad + r * 2.6 + w * 0.1, y + w * 0.002);
      ctx.textAlign = 'left';
    },

    applist(ctx, w, h, c, theme, style) {
      const pad = w * 0.06;
      const size = h * 0.2;
      const colW = (w - pad * 2) / 2;
      const rowH = (h - pad * 2) / 3;
      APPLIST.forEach((id, i) => {
        const col = Math.floor(i / 3);
        const row = i % 3;
        const x = pad + col * colW;
        const y = pad + row * rowH + (rowH - size) / 2;
        ctx.save();
        ctx.translate(x, y);
        roundRect(ctx, 0, 0, size, size, size * 0.23);
        ctx.clip();
        Theme.drawIcon(ctx, size, id, style, theme);
        ctx.restore();
        ctx.fillStyle = c.clear;
        shadowText(ctx, true);
        ctx.font = `500 ${h * 0.085}px ${FONT}`;
        ctx.textBaseline = 'middle';
        ctx.fillText(Theme.ICONS.find((icon) => icon.id === id).label, x + size + w * 0.03, y + size / 2);
        shadowText(ctx, false);
      });
    },
  };

  function wrap(ctx, text, x, y, maxW, lineH) {
    let line = '';
    for (const word of text.split(' ')) {
      const test = line ? `${line} ${word}` : word;
      if (ctx.measureText(test).width > maxW && line) {
        ctx.fillText(line, x, y);
        line = word;
        y += lineH;
      } else {
        line = test;
      }
    }
    ctx.fillText(line, x, y);
  }

  function drawWidget(ctx, w, h, kind, theme, style, now) {
    const c = palette(theme, style);
    ctx.clearRect(0, 0, w, h);
    if (!CLEAR.has(kind)) {
      roundRect(ctx, 0, 0, w, h, Math.min(w, h) * 0.14);
      ctx.fillStyle = c.card;
      ctx.fill();
    }
    ctx.save();
    DRAW[kind](ctx, w, h, c, theme, style, now);
    ctx.restore();
  }

  function widgetCanvas(kind, size, theme, style, now) {
    const [w, h] = PIXELS[size];
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    drawWidget(canvas.getContext('2d'), w, h, kind, theme, style, now);
    return canvas;
  }

  window.Setups = { LAYOUTS, SPAN, PIXELS, NAMES, CLEAR, drawWidget, widgetCanvas };
})();
