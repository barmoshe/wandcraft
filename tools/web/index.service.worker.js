// Wandcraft no longer uses a service worker (decisions/0008). Older builds installed one
// that served the game cache-first, so a phone could keep playing a stale copy. This file
// sits at that worker's path: a phone that still has the old worker picks this up on its
// next launch, and it deletes the old caches, unregisters itself and reloads open pages
// once, so they load straight from the network from then on.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.filter((k) => k.startsWith('Wandcraft-sw-cache-')).map((k) => caches.delete(k)));
		await self.registration.unregister();
		const clients = await self.clients.matchAll({ type: 'window' });
		clients.forEach((c) => c.navigate(c.url));
	})());
});
