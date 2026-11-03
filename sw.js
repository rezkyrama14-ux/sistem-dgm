// Service worker: aplikasi tetap bisa dibuka tanpa internet.
// Naikkan angka versi setiap kali index.html diubah agar pengguna mendapat versi baru.
const CACHE = "pusat-kendali-v1";
const ASSETS = ["./", "./index.html", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png", "./icons/maskable-512.png", "./icons/favicon-32.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;
  // Halaman utama: coba internet dulu (supaya dapat versi terbaru), kalau offline pakai cache.
  if (req.mode === "navigate" || req.url.endsWith("/index.html")) {
    e.respondWith(
      fetch(req).then((res) => { const copy = res.clone(); caches.open(CACHE).then((c) => c.put("./index.html", copy)); return res; })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }
  // File lain: cache dulu, lalu internet.
  e.respondWith(caches.match(req).then((hit) => hit || fetch(req)));
});
