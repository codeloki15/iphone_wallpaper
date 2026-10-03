/*
 * Matching themes. Every wallpaper's palette yields a small theme: an accent
 * color, a second color and a clock color, plus a 24-icon set drawn in one
 * of three styles. Icons are drawn as full squares, because iOS rounds the
 * corners of Home Screen icons itself. Also builds the downloadable .zip.
 */
(function () {
  'use strict';

  const { mix, hexToRgb } = Walls.util;

  // ---------- color ----------

  function hsl(hex) {
    const [r, g, b] = hexToRgb(hex).map((v) => v / 255);
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const l = (max + min) / 2;
    if (max === min) return { h: 0, s: 0, l };
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h;
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    return { h: h / 6, s, l };
  }

  function luminance(hex) {
    const [r, g, b] = hexToRgb(hex).map((v) => {
      const c = v / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  const hueGap = (a, b) => Math.min(Math.abs(a - b), 1 - Math.abs(a - b));

  // The accent is the most vivid mid-tone color in the palette; the second
  // color is the next vivid one with a clearly different hue.
  function fromWall(wall) {
    const cols = [...new Set(wall.palette)];
    const scored = cols
      .map((c) => {
        const { h, s, l } = hsl(c);
        return { c, h, score: s * Math.max(0, 1 - Math.abs(l - 0.55) * 1.4) };
      })
      .sort((a, b) => b.score - a.score);
    const accent = scored[0].c;
    const second = (scored.find((x) => x !== scored[0] && hueGap(x.h, scored[0].h) > 0.06 && x.score > 0.08) || scored[1] || scored[0]).c;
    const avg = cols.reduce((sum, c) => sum + luminance(c), 0) / cols.length;
    const darkWall = avg < 0.4;
    return {
      accent,
      second,
      clock: darkWall ? mix(accent, '#ffffff', 0.78) : mix(accent, '#000000', 0.55),
      darkWall,
    };
  }

  function styleColors(style, theme) {
    const { accent, second } = theme;
    if (style === 'light') {
      return {
        bg: [mix(accent, '#ffffff', 0.9), mix(second, '#ffffff', 0.8)],
        glyph: luminance(accent) > 0.35 ? mix(accent, '#000000', 0.5) : accent,
        sheen: 0.35,
      };
    }
    if (style === 'dark') {
      return {
        bg: ['#18181d', mix(accent, '#000000', 0.78)],
        glyph: luminance(accent) < 0.2 ? mix(accent, '#ffffff', 0.6) : mix(accent, '#ffffff', 0.15),
        sheen: 0.08,
      };
    }
    const top = mix(accent, '#ffffff', 0.08);
    return {
      bg: [top, mix(second, accent, 0.25)],
      glyph: luminance(mix(top, second, 0.5)) > 0.55 ? mix(accent, '#000000', 0.62) : '#ffffff',
      sheen: 0.18,
    };
  }

  // ---------- icons ----------
  // Glyphs are drawn on a 24-unit grid: SVG path data (`d`), circles, or a
  // custom function. `fill: true` fills instead of stroking.

  const circle = (x, y, r, fill) => ({ circle: [x, y, r], fill });

  const GLYPHS = {
    phone: [{ d: 'M7.2 3.8l2.3-.3 1.6 4.1-1.9 1.5a11.5 11.5 0 0 0 5.7 5.7l1.5-1.9 4.1 1.6-.3 2.3a2.2 2.2 0 0 1-2.4 1.9C10.6 18.2 5.8 13.4 5.3 6.2a2.2 2.2 0 0 1 1.9-2.4z', fill: true }],
    messages: [{ d: 'M12 4c5 0 9 3.1 9 7s-4 7-9 7c-1 0-2-.1-2.9-.4L5 19.5l1.2-3.4C4.2 14.8 3 13 3 11c0-3.9 4-7 9-7z', fill: true }],
    browser: [circle(12, 12, 9), { d: 'M15.8 8.2l-2.4 5.2-5.2 2.4 2.4-5.2z', fill: true }],
    music: [{ d: 'M9 17.5V6l10-2v11.5' }, circle(6.5, 17.5, 2.5, true), circle(16.5, 15.5, 2.5, true)],
    mail: [{ d: 'M5 6h14a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 18H5a1.5 1.5 0 0 1-1.5-1.5v-9A1.5 1.5 0 0 1 5 6z' }, { d: 'M4 7.2l8 5.8 8-5.8' }],
    calendar: [{ d: 'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v12A1.5 1.5 0 0 1 19 20H5a1.5 1.5 0 0 1-1.5-1.5v-12A1.5 1.5 0 0 1 5 5z' }, { d: 'M3.5 9.5h17M8 3v4M16 3v4' }, { custom: 'day' }],
    photos: [{ d: 'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5v-11A1.5 1.5 0 0 1 5 5z' }, { d: 'M3.8 16l4.7-4.5 3.5 3.5 2.5-2.5 5.5 5' }, circle(15.5, 9.5, 1.6, true)],
    camera: [{ d: 'M4.5 8h2.8l1.6-2.5h6.2L16.7 8h2.8A1.5 1.5 0 0 1 21 9.5v8a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-8A1.5 1.5 0 0 1 4.5 8z' }, circle(12, 13.3, 3.4)],
    maps: [{ d: 'M12 21s-6.5-5.9-6.5-11a6.5 6.5 0 0 1 13 0c0 5.1-6.5 11-6.5 11z' }, circle(12, 10, 2.3)],
    weather: [circle(8.5, 8, 3), { d: 'M8.5 2.3v1.2M2.8 8H4M4.5 4l.9.9M12.5 4l-.9.9' }, { d: 'M7.5 19h9.5a4 4 0 0 0 .6-7.95A5.5 5.5 0 0 0 7.1 12.6 3.2 3.2 0 0 0 7.5 19z', fill: true }],
    clock: [circle(12, 12, 9), { d: 'M12 7v5.2l3.4 2' }],
    notes: [{ d: 'M6 3.5h12A1.5 1.5 0 0 1 19.5 5v14a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 19V5A1.5 1.5 0 0 1 6 3.5z' }, { d: 'M8 9h8M8 12.5h8M8 16h5' }],
    store: [{ d: 'M5.5 8.5h13l-1.1 11a1.5 1.5 0 0 1-1.5 1.4H8.1a1.5 1.5 0 0 1-1.5-1.4z' }, { d: 'M9 8.5V7a3 3 0 0 1 6 0v1.5' }],
    settings: [{ custom: 'gear' }],
    videocall: [{ d: 'M4.5 7h9A1.5 1.5 0 0 1 15 8.5v7a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 3 15.5v-7A1.5 1.5 0 0 1 4.5 7z' }, { d: 'M15 10.5l5.5-3v9l-5.5-3z', fill: true }],
    files: [{ d: 'M3.5 7A1.5 1.5 0 0 1 5 5.5h4.2l2 2.2H19a1.5 1.5 0 0 1 1.5 1.5v8.8a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 18z' }],
    wallet: [{ d: 'M4.5 6.5h15A1.5 1.5 0 0 1 21 8v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17V8a1.5 1.5 0 0 1 1.5-1.5z' }, { d: 'M3 10.5h18M15 14.5h3' }],
    health: [{ d: 'M12 20s-7.5-4.6-7.5-10.2A4.2 4.2 0 0 1 12 7.3a4.2 4.2 0 0 1 7.5 2.5C19.5 15.4 12 20 12 20z', fill: true }],
    audio: [{ d: 'M12 3.5a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0v-5a3 3 0 0 1 3-3z', fill: true }, { d: 'M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5v3' }],
    calculator: [{ d: 'M7 3.5h10A1.5 1.5 0 0 1 18.5 5v14a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z' }, { d: 'M8.5 7.2h7' }, { custom: 'keys' }],
    chat: [{ d: 'M12 3.5a8.5 8.5 0 0 0-7.4 12.7L3.5 20.5l4.4-1.1A8.5 8.5 0 1 0 12 3.5z' }, circle(8.5, 12, 1.1, true), circle(12, 12, 1.1, true), circle(15.5, 12, 1.1, true)],
    social: [{ d: 'M7.5 3.5h9a4 4 0 0 1 4 4v9a4 4 0 0 1-4 4h-9a4 4 0 0 1-4-4v-9a4 4 0 0 1 4-4z' }, circle(12, 12, 3.8), circle(17, 7, 1, true)],
    video: [{ d: 'M5 5.5h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z' }, { d: 'M10 9l5 3-5 3z', fill: true }],
    fitness: [{ custom: 'rings' }],
  };

  const CUSTOM = {
    // Today's date on the calendar page.
    day(ctx) {
      ctx.font = '700 8px -apple-system, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(String(new Date().getDate()), 12, 15.2);
    },
    gear(ctx) {
      ctx.save();
      ctx.translate(12, 12);
      for (let i = 0; i < 8; i++) {
        ctx.rotate(Math.PI / 4);
        ctx.fillRect(-1.6, -9.6, 3.2, 3.6);
      }
      ctx.restore();
      ctx.beginPath();
      ctx.arc(12, 12, 6.6, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(12, 12, 2.6, 0, Math.PI * 2);
      ctx.stroke();
    },
    keys(ctx) {
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) {
          ctx.beginPath();
          ctx.arc(9 + c * 3, 11 + r * 3, 0.95, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    },
    rings(ctx) {
      [[8.8, 0.85], [6.1, 0.7], [3.4, 0.55]].forEach(([r, part]) => {
        ctx.beginPath();
        ctx.arc(12, 12, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * part);
        ctx.stroke();
      });
    },
  };

  // Dock first, then the Home Screen grid in reading order. Third-party apps
  // get generic names; you choose which app each icon goes on.
  const ICONS = [
    ['phone', 'Phone'], ['messages', 'Messages'], ['browser', 'Browser'], ['music', 'Music'],
    ['mail', 'Mail'], ['calendar', 'Calendar'], ['photos', 'Photos'], ['camera', 'Camera'],
    ['maps', 'Maps'], ['weather', 'Weather'], ['clock', 'Clock'], ['notes', 'Notes'],
    ['store', 'Store'], ['settings', 'Settings'], ['videocall', 'Video Call'], ['files', 'Files'],
    ['wallet', 'Wallet'], ['health', 'Health'], ['chat', 'Chat'], ['social', 'Social'],
    ['video', 'Video'], ['audio', 'Audio'], ['calculator', 'Calculator'], ['fitness', 'Fitness'],
  ].map(([id, label]) => ({ id, label }));

  function drawIcon(ctx, size, iconId, style, theme) {
    const c = styleColors(style, theme);
    const bg = ctx.createLinearGradient(0, 0, size, size);
    bg.addColorStop(0, c.bg[0]);
    bg.addColorStop(1, c.bg[1]);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, size, size);
    const sheen = ctx.createLinearGradient(0, 0, 0, size * 0.6);
    sheen.addColorStop(0, `rgba(255,255,255,${c.sheen})`);
    sheen.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = sheen;
    ctx.fillRect(0, 0, size, size);
    const k = (size * 0.56) / 24;
    ctx.save();
    ctx.translate(size / 2 - 12 * k, size / 2 - 12 * k);
    ctx.scale(k, k);
    ctx.fillStyle = c.glyph;
    ctx.strokeStyle = c.glyph;
    ctx.lineWidth = 1.9;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (const op of GLYPHS[iconId]) {
      if (op.custom) {
        CUSTOM[op.custom](ctx);
      } else if (op.circle) {
        ctx.beginPath();
        ctx.arc(op.circle[0], op.circle[1], op.circle[2], 0, Math.PI * 2);
        if (op.fill) ctx.fill();
        else ctx.stroke();
      } else {
        const path = new Path2D(op.d);
        if (op.fill) ctx.fill(path);
        else ctx.stroke(path);
      }
    }
    ctx.restore();
  }

  function iconCanvas(size, iconId, style, theme) {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    drawIcon(canvas.getContext('2d'), size, iconId, style, theme);
    return canvas;
  }

  // ---------- zip (stored, no compression: PNGs are already compressed) ----------

  const CRC_TABLE = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  function crc32(bytes) {
    let c = 0xffffffff;
    for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  }

  // files: [{ name, data: Uint8Array }] -> Blob
  function zip(files) {
    const enc = new TextEncoder();
    const now = new Date();
    const time = (now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1);
    const date = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    const parts = [];
    const central = [];
    let offset = 0;
    for (const f of files) {
      const name = enc.encode(f.name);
      const crc = crc32(f.data);
      const size = f.data.length;
      const local = new DataView(new ArrayBuffer(30));
      local.setUint32(0, 0x04034b50, true);
      local.setUint16(4, 20, true);
      local.setUint16(6, 0x0800, true); // UTF-8 names
      local.setUint16(10, time, true);
      local.setUint16(12, date, true);
      local.setUint32(14, crc, true);
      local.setUint32(18, size, true);
      local.setUint32(22, size, true);
      local.setUint16(26, name.length, true);
      parts.push(new Uint8Array(local.buffer), name, f.data);
      const entry = new DataView(new ArrayBuffer(46));
      entry.setUint32(0, 0x02014b50, true);
      entry.setUint16(4, 20, true);
      entry.setUint16(6, 20, true);
      entry.setUint16(8, 0x0800, true);
      entry.setUint16(12, time, true);
      entry.setUint16(14, date, true);
      entry.setUint32(16, crc, true);
      entry.setUint32(20, size, true);
      entry.setUint32(24, size, true);
      entry.setUint16(28, name.length, true);
      entry.setUint32(42, offset, true);
      central.push(new Uint8Array(entry.buffer), name);
      offset += 30 + name.length + size;
    }
    const centralSize = central.reduce((sum, a) => sum + a.length, 0);
    const end = new DataView(new ArrayBuffer(22));
    end.setUint32(0, 0x06054b50, true);
    end.setUint16(8, files.length, true);
    end.setUint16(10, files.length, true);
    end.setUint32(12, centralSize, true);
    end.setUint32(16, offset, true);
    return new Blob([...parts, ...central, new Uint8Array(end.buffer)], { type: 'application/zip' });
  }

  function canvasBytes(canvas) {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (!blob) reject(new Error('Could not encode image'));
        else blob.arrayBuffer().then((buf) => resolve(new Uint8Array(buf)), reject);
      }, 'image/png');
    });
  }

  function guideText(wall, theme, style, device) {
    return [
      `${wall.name} theme`,
      `Accent ${theme.accent} · Second ${theme.second} · Clock ${theme.clock} · Icon style: ${style}`,
      '',
      'QUICK THEME (about 2 minutes)',
      '1. Save wallpaper.png to Photos (open it, then Share > Save Image).',
      '2. Settings > Wallpaper > Add New Wallpaper > Photos. Pick it, tap Add, then Set as Wallpaper Pair.',
      `3. Touch and hold the Lock Screen > Customize > Lock Screen. Tap the time and set the color to ${theme.clock}`,
      '   (tap the color wheel, open the Sliders tab and type the hex code).',
      '4. iOS 18 or later: touch and hold an empty spot on the Home Screen > Edit > Customize > Tinted.',
      `   Pick ${theme.accent} with the color picker, or match it with the sliders.`,
      '',
      'CUSTOM ICONS (Shortcuts app, about a minute per app)',
      '1. Unzip this pack in the Files app (tap the .zip).',
      '2. Optional: in the icons folder, tap ... > Select, select all, then Share > Save Images, so the icons are in Photos.',
      '3. Open Shortcuts, tap +, tap Add Action, search for "Open App" and add it. Tap App and choose the app.',
      '4. Tap the menu by the shortcut name at the top and choose Add to Home Screen.',
      '5. Tap the icon, choose Choose Photo or Choose File, pick the matching icon, type the app name, then tap Add.',
      '6. Repeat for each app. To hide an original icon: touch and hold it > Remove App > Remove from Home Screen.',
      '   The app stays in the App Library.',
      '',
      'Opening an app from a shortcut can briefly show a Shortcuts banner. That is how iOS handles custom icons.',
      '',
      `Wallpaper size: ${device.w} x ${device.h} px (${device.name}).`,
      'Icons are 512 x 512 px squares; iOS rounds the corners itself.',
    ].join('\n');
  }

  // Builds the theme pack: wallpaper, 24 icons and a text guide.
  async function buildPack({ wall, variant, t, device, style }) {
    const theme = fromWall(wall);
    const root = `${wall.id}-theme/`;
    const files = [];
    const paper = document.createElement('canvas');
    paper.width = device.w;
    paper.height = device.h;
    Walls.render(paper.getContext('2d'), device.w, device.h, wall, variant, t);
    files.push({ name: `${root}wallpaper.png`, data: await canvasBytes(paper) });
    for (const icon of ICONS) {
      const name = icon.label.toLowerCase().replace(/[^a-z0-9]+/g, '-');
      files.push({ name: `${root}icons/${name}.png`, data: await canvasBytes(iconCanvas(512, icon.id, style, theme)) });
    }
    files.push({ name: `${root}How to apply.txt`, data: new TextEncoder().encode(guideText(wall, theme, style, device)) });
    return zip(files);
  }

  window.Theme = { fromWall, ICONS, drawIcon, iconCanvas, buildPack, luminance };
})();
