/* Estaciona · utilidades compartidas: servidor, sesión, fotos comprimidas, íconos, QR, modales. */
(function (g) {
  'use strict';
  const cfg = g.EST_CONFIG;
  const sb = g.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, storageKey: 'est-auth', detectSessionInUrl: true }
  });

  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const clp = (n) => '$' + Math.round(Number(n || 0)).toLocaleString('es-CL');
  const corto = (n) => n >= 1e6 ? '$' + (n / 1e6).toFixed(n % 1e6 ? 1 : 0) + 'M' : n >= 1e4 ? '$' + Math.round(n / 1e3) + 'k' : clp(n);

  function hace(f) {
    const s = (Date.now() - new Date(f)) / 1000;
    if (s < 60) return 'ahora';
    if (s < 3600) return 'hace ' + Math.floor(s / 60) + ' min';
    if (s < 86400) return 'hace ' + Math.floor(s / 3600) + ' h';
    if (s < 604800) return 'hace ' + Math.floor(s / 86400) + ' d';
    return new Date(f).toLocaleDateString('es-CL', { day: 'numeric', month: 'short' });
  }
  const fecha = (f) => f ? new Date(f).toLocaleDateString('es-CL', { day: 'numeric', month: 'short', year: 'numeric' }) : '';
  const hora = (f) => new Date(f).toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' });
  const fh = (f) => f ? new Date(f).toLocaleString('es-CL', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '';
  // "quedan 12:34" hasta una fecha (para la reserva retenida).
  function quedan(f) {
    const s = Math.max(0, Math.floor((new Date(f) - Date.now()) / 1000));
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  }

  /* ---------- Íconos (estilo Lucide, ISC) ---------- */
  const I = {
    map: '<path d="M14.1 6.3 9.9 4.2a2 2 0 0 0-1.8 0L3.6 6.5A1 1 0 0 0 3 7.4v12a1 1 0 0 0 1.4.9l3.7-1.9a2 2 0 0 1 1.8 0l4.2 2.1a2 2 0 0 0 1.8 0l4.5-2.3a1 1 0 0 0 .6-.9v-12a1 1 0 0 0-1.4-.9l-3.7 1.9a2 2 0 0 1-1.8 0z"/><path d="M15 6v15M9 3v15"/>',
    car: '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    chat: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
    user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.9 1.9 0 0 0 3.4 0"/>',
    search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    sliders: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    locate: '<path d="M2 12h3M19 12h3M12 2v3M12 19v3"/><circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    shield: '<path d="M20 13c0 5-3.5 7.5-7.7 9a1 1 0 0 1-.7 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    star: '<path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z"/>',
    heart: '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>',
    flag: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7"/>',
    qr: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3"/>',
    edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
    trash: '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    send: '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    ban: '<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>',
    crown: '<path d="m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7zM5 20h14"/>',
    roof: '<path d="m3 10 9-7 9 7"/><path d="M5 9v11h14V9"/>',
    clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    cam: '<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>',
    bolt: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>',
    eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    share: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.6 13.5 6.8 4M15.4 6.5l-6.8 4"/>',
    help: '<circle cx="12" cy="12" r="10"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/>',
    logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
    pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
    server: '<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><path d="M6 6h.01M6 18h.01"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>'
  };
  const ico = (n, extra) => '<span class="ico' + (extra ? ' ' + extra : '') + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (I[n] || '') + '</svg></span>';
  function ponerIconos(raiz) {
    (raiz || document).querySelectorAll('[data-i]').forEach((e) => { e.outerHTML = ico(e.dataset.i); });
  }
  const sello = '<span class="sello" title="Identidad verificada"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 1l2.6 2.1 3.3-.4 1 3.2 2.9 1.7-1 3.2 1 3.2-2.9 1.7-1 3.2-3.3-.4L12 23l-2.6-2.1-3.3.4-1-3.2L2.2 16.4l1-3.2-1-3.2L5.1 8.3l1-3.2 3.3.4z"/><path d="m8 12 3 3 5-6" stroke="#fff" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg></span>';

  /* ---------- Toast y modales ---------- */
  let tt;
  function toast(m) { const t = $('toast'); t.textContent = m; t.classList.add('on'); clearTimeout(tt); tt = setTimeout(() => t.classList.remove('on'), 2800); }
  let alCerrar = null;
  function modal(html, onClose) {
    $('modalCuerpo').innerHTML = html; ponerIconos($('modalCuerpo'));
    $('modal').hidden = false; alCerrar = onClose || null;
    document.body.style.overflow = 'hidden';
    return $('modalCuerpo');
  }
  function cerrarModal() {
    if ($('modal').hidden) return;
    $('modal').hidden = true; $('modalCuerpo').innerHTML = ''; document.body.style.overflow = '';
    const f = alCerrar; alCerrar = null; if (f) f();
  }
  document.addEventListener('DOMContentLoaded', () => {
    $('modal').addEventListener('click', (e) => { if (e.target.id === 'modal' || e.target.closest('.modal-x')) cerrarModal(); });
  });
  function confirmar(texto, okTxt, peligro) {
    return new Promise((res) => {
      const c = modal('<h2>' + esc(texto) + '</h2><div class="row" style="margin-top:18px"><button class="btn sec grow" data-no>Cancelar</button><button class="btn grow ' + (peligro ? 'bad' : '') + '" data-si>' + esc(okTxt || 'Aceptar') + '</button></div>', () => res(false));
      c.querySelector('[data-no]').onclick = () => cerrarModal();
      c.querySelector('[data-si]').onclick = () => { alCerrar = null; cerrarModal(); res(true); };
    });
  }
  function pedirTexto(titulo, ph, okTxt, valor) {
    return new Promise((res) => {
      const c = modal('<h2>' + esc(titulo) + '</h2><textarea id="ptxt" placeholder="' + esc(ph || '') + '">' + esc(valor || '') + '</textarea><button class="btn block" style="margin-top:12px" id="pok">' + esc(okTxt || 'Aceptar') + '</button>', () => res(null));
      c.querySelector('#pok').onclick = () => { const v = c.querySelector('#ptxt').value; alCerrar = null; cerrarModal(); res(v); };
    });
  }

  /* ---------- Servidor ---------- */
  function amable(e) {
    const m = String((e && (e.message || e.error_description)) || e || 'Error');
    if (/Invalid login credentials/i.test(m)) return 'Correo o contraseña incorrectos';
    if (/User already registered|already been registered/i.test(m)) return 'Ese correo ya tiene cuenta. Inicia sesión.';
    if (/Password should be at least/i.test(m)) return 'La contraseña debe tener al menos 6 caracteres';
    if (/Email not confirmed/i.test(m)) return 'Falta confirmar el correo (avísale al administrador)';
    if (/rate limit|too many/i.test(m)) return 'Demasiados intentos. Espera unos minutos.';
    if (/Failed to fetch|NetworkError|Load failed|fetch/i.test(m)) return 'Sin conexión. Revisa tu internet.';
    if (/JWT|jwt expired/i.test(m)) return 'Tu sesión expiró. Vuelve a ingresar.';
    if (/permission denied/i.test(m)) return 'No tienes permiso para esto';
    return m.replace(/^\w*Error:\s*/, '');
  }
  async function rpc(nombre, args) {
    const { data, error } = await sb.rpc(nombre, args || {});
    if (error) throw new Error(amable(error));
    return data;
  }
  // Pide a la función "enviar" que mande los push pendientes (sin esperar).
  let ultimoEmpuje = 0;
  function empujar() {
    if (Date.now() - ultimoEmpuje < 1500) return;
    ultimoEmpuje = Date.now();
    sb.functions.invoke('enviar', { body: { accion: 'push' } }).catch(() => {});
  }
  async function funcion(accion, extra) {
    const { data, error } = await sb.functions.invoke('enviar', { body: Object.assign({ accion }, extra || {}) });
    if (error) {
      let st = 0; try { st = error.context && error.context.status; } catch (e) { /* nada */ }
      if (error.name === 'FunctionsFetchError' || st === 404) throw new Error('La función "enviar" no está instalada en Supabase (guía, paso 4)');
      if (st === 401) throw new Error('En Supabase apaga "Verify JWT" de la función "enviar"');
      throw new Error(amable(error));
    }
    if (data && data.ok === false) throw new Error(data.error || 'Error');
    return data;
  }

  /* ---------- Fotos: compresión fuerte en el celular antes de subir ---------- */
  function cargarImagen(file) {
    return new Promise((ok, mal) => {
      const img = new Image();
      img.onload = () => ok(img);
      img.onerror = () => mal(new Error('No se pudo leer la imagen'));
      img.src = URL.createObjectURL(file);
    });
  }
  async function comprimir(file, lado, calidad, cuadrado) {
    const img = await cargarImagen(file);
    let sw = img.naturalWidth, sh = img.naturalHeight, sx = 0, sy = 0;
    if (cuadrado) { const m = Math.min(sw, sh); sx = (sw - m) / 2; sy = (sh - m) / 2; sw = sh = m; }
    const k = Math.min(1, lado / Math.max(sw, sh));
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(sw * k)); c.height = Math.max(1, Math.round(sh * k));
    const ctx = c.getContext('2d');
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height);
    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, c.width, c.height);
    URL.revokeObjectURL(img.src);
    const blob = (t, q) => new Promise((ok) => c.toBlob(ok, t, q));
    let b = await blob('image/webp', calidad);
    if (!b || b.type !== 'image/webp') b = await blob('image/jpeg', calidad); // iPhone antiguo
    return b;
  }
  const rnd = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  // Sube una foto. Si "conMini", sube además una miniatura (para el mapa y listas).
  // Calidad de fotos según su uso: viene del núcleo (fotos.js); estos valores son el respaldo.
  const FOTO = (k) => (g.CFX_FOTO && g.CFX_FOTO[k]) || { comprobante: { lado: 1000, calidad: 0.6, kb: 110 }, documento: { lado: 1400, calidad: 0.72, kb: 300 }, vitrina: { lado: 1080, calidad: 0.8, kb: 220 }, portada: { lado: 1280, calidad: 0.8, kb: 300 }, perfil: { lado: 400, calidad: 0.8, kb: 45 }, logo: { lado: 256, calidad: 0.85, kb: 30 } }[k];
  async function subirFoto(file, bucket, opt) {
    opt = opt || {};
    const uid = Api.uid();
    const b = await comprimir(file, opt.lado || 1280, opt.calidad || 0.72, opt.cuadrado);
    const ext = b.type === 'image/webp' ? 'webp' : 'jpg';
    const base = uid + '/' + rnd();
    const ruta = base + '.' + ext;
    const up = (r, blob) => sb.storage.from(bucket).upload(r, blob, { contentType: blob.type, cacheControl: '31536000', upsert: false });
    let { error } = await up(ruta, b);
    if (error) throw new Error('No se pudo subir la foto: ' + amable(error));
    if (opt.conMini) {
      const m = await comprimir(file, 400, 0.6);
      await up(base + '_t.' + (m.type === 'image/webp' ? 'webp' : 'jpg'), m);
    }
    return ruta;
  }
  const urlFoto = (ruta) => ruta ? cfg.SUPABASE_URL + '/storage/v1/object/public/fotos/' + ruta.split('/').map(encodeURIComponent).join('/') : '';
  const urlMini = (ruta) => ruta ? urlFoto(ruta.replace(/\.(webp|jpg)$/, '_t.$1')) : '';
  async function urlPrivada(ruta) {
    if (!ruta) return '';
    const { data } = await sb.storage.from('privado').createSignedUrl(ruta, 600);
    return data ? data.signedUrl : '';
  }
  // <img> de miniatura que vuelve a la foto completa si la miniatura no existe.
  const imgMini = (ruta, cls) => ruta ? '<img class="' + (cls || 'thumb') + '" loading="lazy" src="' + esc(urlMini(ruta)) + '" data-full="' + esc(urlFoto(ruta)) + '" onerror="if(this.dataset.full&&this.src!==this.dataset.full){this.src=this.dataset.full}" alt="">' : '<div class="' + (cls || 'thumb') + '"></div>';

  function avatar(p, cls) {
    p = p || {};
    const inicial = (p.nombre || '?').trim().charAt(0).toUpperCase() || '?';
    const dentro = p.avatar ? '<img src="' + esc(urlFoto(p.avatar)) + '" alt="" loading="lazy">' : esc(p.icono || inicial);
    return '<span class="av ' + (cls || '') + (p.premium ? ' prem' : '') + '" style="--c:' + esc(/^#[0-9a-f]{6}$/i.test(p.color || '') ? p.color : '#2563eb') + '">' + dentro + '</span>';
  }
  const nombreCon = (p) => esc(p.nombre || 'Usuario') + (p.verificado ? ' ' + sello : '') + (p.premium && !p.admin ? ' <span class="pill gold" style="padding:1px 6px">PRO</span>' : '') + (p.admin ? ' <span class="pill brand" style="padding:1px 6px">Soporte</span>' : '');
  const estrellas = (n) => n ? '<span class="estrellas">★</span> ' + Number(n).toFixed(1) : '<span class="muted small">Sin calificaciones</span>';

  /* ---------- RUT ---------- */
  function rutDv(cuerpo) {
    let s = 0, m = 2;
    for (let i = cuerpo.length - 1; i >= 0; i--) { s += +cuerpo[i] * m; m = m === 7 ? 2 : m + 1; }
    const r = 11 - (s % 11);
    return r === 11 ? '0' : r === 10 ? 'K' : String(r);
  }
  function rutValido(r) {
    const c = String(r || '').replace(/[^0-9kK]/g, '').toUpperCase();
    if (c.length < 8 || c.length > 9 || !/^\d+$/.test(c.slice(0, -1))) return false;
    return rutDv(c.slice(0, -1)) === c.slice(-1);
  }
  function rutFormato(r) {
    const c = String(r || '').replace(/[^0-9kK]/g, '').toUpperCase().slice(0, 9);
    if (c.length < 2) return c;
    return c.slice(0, -1).replace(/\B(?=(\d{3})+(?!\d))/g, '.') + '-' + c.slice(-1);
  }

  /* ---------- QR ---------- */
  function qrCanvas(texto, color, px) {
    const q = g.qrcode(0, 'M'); q.addData(texto); q.make();
    const n = q.getModuleCount(), m = 2, k = Math.max(4, Math.floor((px || 480) / (n + 2 * m)));
    const c = document.createElement('canvas');
    c.width = c.height = k * (n + 2 * m);
    const x = c.getContext('2d');
    x.fillStyle = '#fff'; x.fillRect(0, 0, c.width, c.height); x.fillStyle = color || '#000';
    for (let r = 0; r < n; r++) for (let j = 0; j < n; j++) if (q.isDark(r, j)) x.fillRect((j + m) * k, (r + m) * k, k, k);
    return c;
  }
  const enlace = (hash) => location.origin + location.pathname + hash;
  async function compartir(titulo, texto, url) {
    if (navigator.share) { try { await navigator.share({ title: titulo, text: texto, url }); return; } catch (e) { if (e.name === 'AbortError') return; } }
    try { await navigator.clipboard.writeText(url); toast('Enlace copiado'); } catch (e) { prompt('Copia el enlace:', url); }
  }
  function mostrarQR(titulo, sub, url, color) {
    const c = modal('<div class="center"><h2>' + esc(titulo) + '</h2><p class="muted">' + esc(sub || '') + '</p><div class="qr-caja" id="qrC"></div>' +
      '<p class="small muted" style="word-break:break-all">' + esc(url) + '</p><div class="row"><button class="btn sec grow" id="qrDesc">' + ico('download') + ' Descargar</button>' +
      '<button class="btn grow" id="qrComp">' + ico('share') + ' Compartir</button></div></div>');
    const cv = qrCanvas(url, color, 600);
    c.querySelector('#qrC').appendChild(cv);
    c.querySelector('#qrDesc').onclick = () => { const a = document.createElement('a'); a.href = cv.toDataURL('image/png'); a.download = 'estaciona-qr.png'; a.click(); };
    c.querySelector('#qrComp').onclick = () => compartir(titulo, sub || titulo, url);
  }

  /* ---------- Tema (color del perfil y claro/oscuro) ---------- */
  function tinta(hex) {
    const n = parseInt(hex.slice(1), 16);
    return (0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255 > 0.62 ? '#0f172a' : '#ffffff';
  }
  function aplicarColor(c) {
    if (!/^#[0-9a-f]{6}$/i.test(c || '')) c = '#2563eb';
    const r = document.documentElement.style;
    r.setProperty('--brand', c); r.setProperty('--brand-ink', tinta(c));
    document.querySelector('meta[name=theme-color]').content = c;
    try { localStorage.setItem('est:color', c); } catch (e) { /* sin espacio */ }
  }
  function aplicarTema(t) {
    if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t; else delete document.documentElement.dataset.theme;
    try { if (t) localStorage.setItem('est:tema', t); else localStorage.removeItem('est:tema'); } catch (e) { /* nada */ }
  }
  const oscuro = () => document.documentElement.dataset.theme === 'dark' ||
    (!document.documentElement.dataset.theme && matchMedia('(prefers-color-scheme: dark)').matches);

  /* ---------- Sesión ---------- */
  let cuenta = null;
  try { cuenta = JSON.parse(localStorage.getItem('est:cuenta')); } catch (e) { cuenta = null; }
  const Api = {
    sb, rpc, funcion, empujar,
    get cuenta() { return cuenta; },
    uid: () => cuenta && cuenta.id,
    logueado: () => !!cuenta,
    premium: () => !!(cuenta && cuenta.premium),
    admin: () => !!(cuenta && cuenta.admin),
    // Funciones del plan actual (editable por el admin en Ajustes → Planes).
    puede: (k) => !!(cuenta && (cuenta.admin || (cuenta.plan && cuenta.plan[k]))),
    _aj: null,
    async ajustes(forzar) {
      if (this._aj && !forzar) return this._aj;
      try { this._aj = await rpc('ajustes_publicos') || {}; try { localStorage.setItem('est:aj', JSON.stringify(this._aj)); } catch (e) { /* nada */ } }
      catch (e) { try { this._aj = JSON.parse(localStorage.getItem('est:aj')) || {}; } catch (e2) { this._aj = {}; } }
      return this._aj;
    },
    // Texto editable con variables {minutos}, {devolucion}, {horas}, {dias}.
    texto(clave, def) {
      const aj = this._aj || {}, r = aj.reglas || {};
      return String(((aj.textos || {})[clave]) || def || '').replace(/\{minutos\}/g, r.minutos_pago).replace(/\{devolucion\}/g, r.minutos_devolucion)
        .replace(/\{horas\}/g, r.horas_cancelacion).replace(/\{dias\}/g, r.dias_saldo);
    },
    async refrescar() {
      const { data } = await sb.auth.getSession();
      if (!data.session) { this.guardar(null); return null; }
      try { this.guardar(await rpc('mi_cuenta')); }
      catch (e) { if (!/conexión/.test(e.message)) this.guardar(null); }
      return cuenta;
    },
    guardar(c) {
      cuenta = c || null;
      try { if (c) localStorage.setItem('est:cuenta', JSON.stringify(c)); else localStorage.removeItem('est:cuenta'); } catch (e) { /* nada */ }
      if (c) aplicarColor(c.color);
      // Núcleo (ayuda.js): cabecera común [campana][FREE/PRO][foto], menú de la cuenta, ayuda y sensación Premium.
      if (c) {
        window.CFX_AYUDA_PEND = Object.assign(window.CFX_AYUDA_PEND || {}, { rpc, app: 'estaciona', admin: !!c.admin, premium: !!c.premium && c.plan_origen !== 'prueba', id: c.id, hasta: c.premium_hasta,
          nombre: c.nombre, email: c.email, foto: c.avatar ? urlFoto(c.avatar) : null, quitar: '#btnAdmin, #miniAv', cuenta: '#/mas/cuenta', panel: c.admin ? '#/admin' : null,
          salir: async () => { await Api.salir(); location.hash = '#/'; location.reload(); } });
        if (window.CFX_AYUDA) window.CFX_AYUDA.iniciar(window.CFX_AYUDA_PEND);
      }
      document.dispatchEvent(new CustomEvent('cuenta'));
    },
    async ingresar(email, clave) {
      const { error } = await sb.auth.signInWithPassword({ email: email.trim().toLowerCase(), password: clave });
      if (error) throw new Error(amable(error));
      return this.refrescar();
    },
    async registrar(nombre, email, clave) {
      const { data, error } = await sb.auth.signUp({
        email: email.trim().toLowerCase(), password: clave,
        options: { data: { nombre: nombre.trim(), acepta: 'si' }, emailRedirectTo: location.origin + location.pathname }
      });
      if (error) throw new Error(amable(error));
      if (!data.session) throw new Error('Falta apagar "Confirm email" en Supabase (guía, paso 2)');
      return this.refrescar();
    },
    async salir() {
      try { await quitarPushLocal(); } catch (e) { /* nada */ }
      try { await sb.auth.signOut(); } catch (e) { /* sin red */ }
      this.guardar(null);
    }
  };

  /* ---------- Push ---------- */
  const b64 = (s) => { const p = '='.repeat((4 - s.length % 4) % 4); const r = atob((s + p).replace(/-/g, '+').replace(/_/g, '/')); return Uint8Array.from(r, (c) => c.charCodeAt(0)); };
  const pushOk = () => 'serviceWorker' in navigator && 'PushManager' in g && 'Notification' in g;
  async function activarPush() {
    if (!pushOk()) throw new Error(/iPhone|iPad/.test(navigator.userAgent) ? 'En iPhone primero instala la app (Compartir → Agregar a inicio) y ábrela desde ahí' : 'Este navegador no permite notificaciones');
    const aj = await rpc('ajustes_publicos');
    if (!aj || !aj.vapid_public) throw new Error('El administrador aún no activa las notificaciones');
    if (await Notification.requestPermission() !== 'granted') throw new Error('Permiso de notificaciones denegado');
    const reg = await navigator.serviceWorker.ready;
    const key = b64(aj.vapid_public);
    let sub = await reg.pushManager.getSubscription();
    if (sub) {
      const k = sub.options && sub.options.applicationServerKey ? new Uint8Array(sub.options.applicationServerKey) : null;
      if (!k || k.length !== key.length || k.some((v, i) => v !== key[i])) { await sub.unsubscribe(); sub = null; }
    }
    if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key });
    const j = sub.toJSON();
    await rpc('guardar_push', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth });
  }
  async function pushActivo() {
    if (!pushOk() || Notification.permission !== 'granted') return false;
    const reg = await navigator.serviceWorker.getRegistration();
    return !!(reg && await reg.pushManager.getSubscription());
  }
  async function quitarPushLocal() {
    if (!pushOk()) return;
    const reg = await navigator.serviceWorker.getRegistration();
    const sub = reg && await reg.pushManager.getSubscription();
    if (sub) { await rpc('quitar_push', { p_endpoint: sub.endpoint }).catch(() => {}); }
  }
  // Al iniciar sesión en un celular con push activo, queda a nombre de esta cuenta.
  async function sincronizarPush() {
    try {
      if (!(await pushActivo())) return;
      const reg = await navigator.serviceWorker.getRegistration();
      const j = (await reg.pushManager.getSubscription()).toJSON();
      await rpc('guardar_push', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth });
    } catch (e) { /* nada */ }
  }

  // Deja visible la pestaña activa de una barra deslizable (.seg / .tabs) sin mover la página.
  function centrarSeg(raiz) {
    (raiz || document).querySelectorAll('.seg, .tabs').forEach((bar) => {
      const on = bar.querySelector('.on'); if (!on) return;
      bar.scrollLeft = Math.max(0, on.offsetLeft - bar.offsetLeft - (bar.clientWidth - on.offsetWidth) / 2);
    });
  }
  g.U = {
    $, esc, clp, corto, hace, fecha, hora, fh, quedan, centrarSeg, ico, ponerIconos, sello, toast, modal, cerrarModal, confirmar, pedirTexto, amable,
    subirFoto, FOTO, urlFoto, urlMini, urlPrivada, imgMini, avatar, nombreCon, estrellas, rutValido, rutFormato, qrCanvas, mostrarQR,
    enlace, compartir, aplicarColor, aplicarTema, oscuro, activarPush, pushActivo, pushOk, sincronizarPush
  };
  g.Api = Api;
})(window);
