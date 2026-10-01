// VideoIQ Danmu: service worker.
// Required so Android Chrome can install the page as an app (and list it in the Share menu).
// It deliberately caches nothing: every visit loads the latest version from the network.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(fetch(e.request).catch(() =>
    new Response('<h3 style="font-family:sans-serif;color:#eee;background:#0d0f14;padding:24px">You\'re offline. Connect to the internet and try again.</h3>',
                 { headers: { 'Content-Type': 'text/html; charset=utf-8' } })));
});
