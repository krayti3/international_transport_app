const CACHE_NAME = 'international-transport-v3';
const OFFLINE_URL = 'offline.html';

const SUPABASE_API_HOST = 'https://jgehdsmrmcpnvcnfrjai.supabase.co';

const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/offline.html',
  '/main.dart.js',
  '/flutter.js',
  '/canvaskit.js',
  '/canvaskit.wasm',
  '/manifest.json',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  if (url.origin === SUPABASE_API_HOST || url.host === 'jgehdsmrmcpnvcnfrjai.supabase.co') {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      const networkFetch = fetch(event.request).then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => cached);

      if (cached) {
        return cached;
      }

      return networkFetch.then((response) => {
        if (!response || response.status !== 200) {
          if (event.request.mode === 'navigate') {
            return caches.match(OFFLINE_URL);
          }
          return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
        }
        return response;
      });
    }),
  );
});
