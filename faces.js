/*
 * Clock faces for the Lock Screen preview: Classic (the iOS default look),
 * Dial (minutes and seconds on curved scales, current minute in a pill),
 * Vertical (a sideways clock along the left edge) and Words (the time as a
 * sentence). The dial is drawn on canvas so setups.js can reuse it as a
 * Home Screen widget.
 */
(function () {
  'use strict';

  const ONES = ['twelve', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
    'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty'];

  function minuteWords(m) {
    if (m === 0) return "o'clock";
    if (m < 10) return `oh ${ONES[m]}`;
    if (m < 20) return ONES[m];
    return TENS[Math.floor(m / 10)] + (m % 10 ? ` ${ONES[m % 10]}` : '');
  }

  // "ten forty", "nine oh five", "seven o'clock"
  function timeWords(now) {
    return `${ONES[now.getHours() % 12]} ${minuteWords(now.getMinutes())}`;
  }

  function period(now) {
    const h = now.getHours();
    if (h < 5) return 'at night';
    if (h < 12) return 'in the morning';
    if (h < 17) return 'in the afternoon';
    if (h < 21) return 'in the evening';
    return 'at night';
  }

  const pad = (n) => String(n).padStart(2, '0');
  const hour12 = (now) => now.getHours() % 12 || 12;
  const weekday = (now) => now.toLocaleDateString('en-US', { weekday: 'long' });
  const month = (now) => now.toLocaleDateString('en-US', { month: 'long' });

  // Canvas letter-spacing support is uneven, so space characters by hand.
  function spaced(ctx, text, x, y, spacing, align = 'left') {
    const widths = [...text].map((ch) => ctx.measureText(ch).width);
    const total = widths.reduce((a, b) => a + b, 0) + spacing * (text.length - 1);
    let cx = align === 'right' ? x - total : align === 'center' ? x - total / 2 : x;
    const prev = ctx.textAlign;
    ctx.textAlign = 'left';
    [...text].forEach((ch, i) => {
      ctx.fillText(ch, cx, y);
      cx += widths[i] + spacing;
    });
    ctx.textAlign = prev;
  }

  const FONT = '-apple-system, "SF Pro Display", system-ui, sans-serif';

  // The dial: hour on the left, the minute scale curving around it with the
  // current minute in a pill at three o'clock, an outer seconds scale, and
  // the date to the right. Scales rotate so "now" is always horizontal.
  // `maxDeg` is how far the scales reach above and below three o'clock;
  // `seconds: false` drops the outer scale so a small widget can go bigger.
  function drawDial(ctx, w, h, color, now, maxDeg = 74, seconds = true) {
    const MAX = (maxDeg * Math.PI) / 180;
    // Fit the outer scale to the height and keep room for the date.
    const reach = seconds ? 39 : 28;
    const k = Math.min(w / (reach + 43), (h * 0.47) / (reach * Math.sin(MAX)));
    const cx = k * 14;
    const cy = h / 2;
    const Rm = k * 22;
    const Rs = k * 34;
    const STEP = (3.2 * Math.PI) / 180;
    const fade = (a) => Math.pow(Math.max(0, 1 - Math.abs(a) / MAX), 0.7);
    const m = now.getMinutes();
    const s = now.getSeconds();
    ctx.save();
    ctx.fillStyle = color;
    ctx.strokeStyle = color;
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';

    ctx.font = `300 ${k * 13}px ${FONT}`;
    ctx.fillText(pad(hour12(now)), cx, cy + k * 0.6);

    // value -> angle, upward for larger values; wraps around the hour.
    const angleOf = (v, current) => -((((v - current) % 60) + 90) % 60 - 30) * STEP;
    const ring = (current, radius, labelInset, labelSize, tickIn, tickOut, skip) => {
      for (let v = 0; v < 60; v++) {
        const a = angleOf(v, current);
        if (Math.abs(a) > MAX) continue;
        const alpha = fade(a);
        const major = v % 5 === 0;
        const delta = Math.abs((((v - current) % 60) + 90) % 60 - 30);
        // The pill covers the current minute's tick.
        if (skip && delta <= 1) continue;
        ctx.globalAlpha = alpha * (major ? 0.9 : 0.45);
        ctx.lineWidth = k * (major ? 0.45 : 0.3);
        const r0 = radius + tickIn;
        const r1 = radius + (major ? tickOut : tickOut * 0.6);
        ctx.beginPath();
        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
        ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
        ctx.stroke();
        // Labels right next to the pill would collide with it.
        if (major && !(skip && delta <= 3)) {
          ctx.globalAlpha = alpha;
          ctx.font = `500 ${labelSize}px ${FONT}`;
          const rl = radius - labelInset;
          ctx.fillText(pad(v), cx + Math.cos(a) * rl, cy + Math.sin(a) * rl);
        }
      }
    };
    ring(m, Rm, 0, k * 3.4, k * 3.6, k * 5.6, true);
    if (seconds) ring(s, Rs, 0, k * 2.5, k * 2.4, k * 4.2, false);

    // The current minute, in a pill at three o'clock.
    ctx.globalAlpha = 1;
    const pw = k * 11;
    const ph = k * 6.2;
    const px = cx + Rm - pw * 0.32;
    ctx.lineWidth = k * 0.5;
    ctx.beginPath();
    ctx.moveTo(px + ph / 2, cy - ph / 2);
    ctx.arcTo(px + pw, cy - ph / 2, px + pw, cy + ph / 2, ph / 2);
    ctx.arcTo(px + pw, cy + ph / 2, px, cy + ph / 2, ph / 2);
    ctx.arcTo(px, cy + ph / 2, px, cy - ph / 2, ph / 2);
    ctx.arcTo(px, cy - ph / 2, px + pw, cy - ph / 2, ph / 2);
    ctx.closePath();
    ctx.stroke();
    ctx.font = `500 ${k * 4.2}px ${FONT}`;
    ctx.fillText(pad(m), px + pw * 0.42, cy + k * 0.2);

    // Date block to the right of the dial.
    const dx = cx + (seconds ? Rs : Rm + k * 6) + k * 7;
    ctx.textAlign = 'left';
    ctx.font = `500 ${k * 2.4}px ${FONT}`;
    ctx.globalAlpha = 0.85;
    spaced(ctx, `${now.getDate()} ${month(now).slice(0, 3).toUpperCase()} ${now.getFullYear()}`, dx, cy - k * 2, k * 0.55);
    ctx.globalAlpha = 1;
    ctx.font = `700 ${k * 2.6}px ${FONT}`;
    spaced(ctx, weekday(now).toUpperCase(), dx, cy + k * 2.2, k * 0.5);
    ctx.restore();
  }

  // Fills the Lock Screen face container for the given style.
  function render(container, style, now) {
    if (style === 'dial') {
      let canvas = container.querySelector('canvas');
      if (!canvas) {
        container.innerHTML = '<canvas class="face-dial"></canvas>';
        canvas = container.querySelector('canvas');
      }
      const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      const w = Math.round(canvas.clientWidth * dpr);
      const h = Math.round(canvas.clientHeight * dpr);
      if (!w || !h) return;
      if (canvas.width !== w) canvas.width = w;
      if (canvas.height !== h) canvas.height = h;
      const ctx = canvas.getContext('2d');
      ctx.clearRect(0, 0, w, h);
      drawDial(ctx, w, h, getComputedStyle(container).color, now);
      return;
    }
    if (style === 'vertical') {
      container.innerHTML = `
        <div class="face-vertical">
          <span class="fv-date">${now.getDate()} ${month(now).toUpperCase()}</span>
          <span class="fv-hour">${hour12(now)}</span>
          <span class="fv-side"><span class="fv-min">${pad(now.getMinutes())}</span><span class="fv-day">${weekday(now).slice(0, 3).toUpperCase()}</span></span>
        </div>`;
      return;
    }
    if (style === 'words') {
      const [h, ...rest] = timeWords(now).split(' ');
      container.innerHTML = `
        <div class="face-words">
          <span class="fw-date">${weekday(now).toUpperCase()} · ${now.getDate()} ${month(now).toUpperCase()}</span>
          <span class="fw-line">It's ${h}</span>
          <span class="fw-line fw-light">${rest.join(' ')}</span>
          <span class="fw-small">${period(now)}</span>
        </div>`;
    }
  }

  window.Faces = { STYLES: ['classic', 'dial', 'vertical', 'words'], render, drawDial, timeWords, weekday, month, spaced, FONT };
})();
