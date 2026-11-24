/* Service worker de Estaciona: guarda la app en el celular para que abra rápido.
   Al publicar una versión nueva, cambia VERSION: la app muestra "Actualizar". */
const VERSION = 'est-2.14.52';
const ARCHIVOS = [
  './', 'index.html', 'manifest.webmanifest', 'css/app.css',
  'js/config.js', 'js/filtro.js', 'css/vendor/letras/inter.woff2', 'css/vendor/letras/roboto.woff2', 'css/vendor/letras/open-sans.woff2', 'css/vendor/letras/montserrat.woff2', 'css/vendor/letras/nunito.woff2', 'js/ui.js', 'css/vendor/bootstrap-utilities.min.css', 'js/seguro.js', 'js/vitrina.js', 'js/datos.js', 'js/carga.js', 'js/ayuda.js', 'js/est-motor.js', 'js/est-importador.js', 'js/est-links.js', 'js/estudio.js', 'js/qr.js', 'js/comprobante.js', 'js/modulos.js', 'js/premium.js', 'js/humano.js', 'js/verificar.js', 'js/pagos.js', 'js/respaldo.js', 'js/voz.js', 'js/fotos.js', 'js/auto.js', 'js/barra.js', 'css/tema.css', 'js/base.js', 'js/iconos.js', 'js/instalar.js', 'js/mapa.js', 'js/app.js', 'js/admin.js',
  'vendor/supabase.js', 'vendor/591.supabase.js', 'vendor/leaflet.js', 'vendor/leaflet.css', 'vendor/maplibre-gl.js', 'vendor/maplibre-gl.css', 'vendor/leaflet-maplibre-gl.js',
  'vendor/leaflet.markercluster.js', 'vendor/MarkerCluster.css', 'vendor/qrcode.js',
  'icons/icon-192.png', 'icons/icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(ARCHIVOS.map((f) => new Request(f, { cache: 'reload' })))));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((ks) => Promise.all(ks.filter((k) => k !== VERSION && k !== 'est-fotos').map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('message', (e) => { if (e.data === 'saltar') self.skipWaiting(); });

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Fotos públicas: primero la copia guardada (ahorra datos), máximo 300 fotos.
  if (/\/storage\/v1\/object\/public\/fotos\//.test(url.pathname)) {
    e.respondWith(caches.open('est-fotos').then(async (c) => {
      const hit = await c.match(req);
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok) {
        c.put(req, res.clone());
        c.keys().then((ks) => { if (ks.length > 300) ks.slice(0, ks.length - 300).forEach((k) => c.delete(k)); });
      }
      return res;
    }));
    return;
  }
  if (url.origin !== location.origin) return;
  e.respondWith(caches.open(VERSION).then(async (c) => {
    const hit = await c.match(req, { ignoreSearch: true });
    if (hit) return hit;
    try {
      const res = await fetch(req);
      if (res.ok && ARCHIVOS.some((f) => url.pathname.endsWith('/' + f.replace('./', '')))) c.put(req, res.clone());
      return res;
    } catch (err) {
      return (await c.match('index.html')) || Response.error();
    }
  }));
});

// Notificación push enviada por el servidor (llega aunque la app esté cerrada).
// G61 a 📲 Confirma al servidor que el aviso llegó (así deja de reenviarlo). Sin red: el servidor reintenta.
function cfxAck(e, d) {
  if (!d || !d.ack || !/^https:\/\//.test(d.ackUrl || '')) return;
  e.waitUntil(fetch(d.ackUrl, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: d.ackKey || '', Authorization: 'Bearer ' + (d.ackKey || '') }, body: JSON.stringify({ p_grupo: d.ack }) }).catch(() => {}));
}
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { title: e.data && e.data.text() }; }
  cfxAck(e, d);
  e.waitUntil(self.registration.showNotification(d.title || 'Estaciona', {
    body: d.body || '', icon: 'icons/icon-192.png', badge: 'icons/badge.png', tag: d.tag, data: { url: d.url || './' }, renotify: !!d.tag, vibrate: [200, 100, 200]
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const destino = new URL(e.notification.data && e.notification.data.url || './', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((ls) => {
    for (const c of ls) { if ('focus' in c) { c.navigate(destino).catch(() => {}); return c.focus(); } }
    return self.clients.openWindow(destino);
  }));
});
