/*
 * Offline support for the installed app. Pages and assets are served from
 * the cache straight away and refreshed in the background (stale while
 * revalidate), so the app opens offline and picks up updates on the next
 * launch. Bump VERSION to drop old caches.
 */
const VERSION = 'pocket-walls-v1';
const CORE = [
  './',
  'index.html',
  'manifest.webmanifest',
  'icons/apple-touch-icon.png',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'styles.css',
  'live.css',
  'spatial.css',
  'theme.css',
  'setups.css',
  'tilt.css',
  'hero3d.css',
  'wallpapers.js',
  'live.js',
  'spatial.js',
  'art.js',
  'theme.js',
  'faces.js',
  'setups.js',
  'app.js',
  'tilt.js',
  'hero3d.js',
];
const THREE = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION)
      .then((cache) => cache.addAll(CORE).then(() => cache.add(THREE).catch(() => {})))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== location.origin && request.url !== THREE) return;
  event.respondWith(
    caches.open(VERSION).then((cache) =>
      cache.match(request, { ignoreSearch: true }).then((cached) => {
        const fresh = fetch(request)
          .then((res) => {
            if (res.ok) cache.put(request, res.clone());
            return res;
          })
          .catch(() => cached);
        return cached || fresh;
      })
    )
  );
});
