'use strict';
self.addEventListener('install', () => { self.skipWaiting(); });
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try { const k = await caches.keys(); await Promise.all(k.map(c => caches.delete(c))); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
    try {
      const cl = await self.clients.matchAll({ type: 'window' });
      cl.forEach(c => { if (c.url && 'navigate' in c) c.navigate(c.url); });
    } catch (e) {}
  })());
});
