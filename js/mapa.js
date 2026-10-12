/* Estaciona · mapa principal (público), filtros, lista, búsqueda y mapas chicos. */
(function (g) {
  'use strict';
  const { $, esc, corto, clp, ico, imgMini, toast, modal, cerrarModal } = g.U;
  const cfg = g.EST_CONFIG;
  let mapa, capa, grupo, datos = [], cargado = null, ultimaCarga = 0, yoMarca = null, iniciado = false;
  const F = { modalidad: '', max: 0, vehiculo: '', techado: false, acceso24: false, seguridad: false, carga: false };
  try { Object.assign(F, JSON.parse(localStorage.getItem('est:filtros')) || {}); } catch (e) { /* nada */ }

  // Mapa gratis y sin API key (OpenStreetMap). En modo oscuro se oscurece con un filtro.
  function teselas(m) {
    return L.tileLayer(cfg.TILES, { maxZoom: 19, attribution: cfg.ATRIBUCION, className: g.U.oscuro() ? 'tiles-oscuro' : '' }).addTo(m);
  }

  /* ---------- Geocodificación (OpenStreetMap / Nominatim) ---------- */
  async function buscar(q) {
    const u = 'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=6&countrycodes=cl&accept-language=es&viewbox=-71.0,-33.2,-70.4,-33.7&q=' + encodeURIComponent(q);
    const r = await fetch(u); if (!r.ok) throw new Error('Búsqueda no disponible');
    return (await r.json()).map((x) => ({ nombre: x.display_name, lat: +x.lat, lng: +x.lon }));
  }
  async function inverso(lat, lng) {
    try {
      const r = await fetch('https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&accept-language=es&lat=' + lat + '&lon=' + lng);
      const j = await r.json(); const a = j.address || {};
      const comuna = a.city || a.town || a.village || a.municipality || a.suburb || a.county || '';
      const calle = [a.road, a.house_number].filter(Boolean).join(' ');
      return { comuna, direccion: calle || (j.display_name || '').split(',').slice(0, 2).join(',') };
    } catch (e) { return { comuna: '', direccion: '' }; }
  }

  /* ---------- Precio para mostrar ---------- */
  function etiqueta(d) {
    const m = F.modalidad;
    if (m === 'hora' && d.ph) return corto(d.ph) + '/h';
    if (m === 'dia' && d.pd) return corto(d.pd) + '/día';
    if (m === 'mes' && d.pm) return corto(d.pm) + '/mes';
    if (d.pm) return corto(d.pm) + '/mes';
    if (d.pd) return corto(d.pd) + '/día';
    return corto(d.ph) + '/h';
  }
  function precioFiltro(d) {
    if (F.modalidad === 'hora') return d.ph; if (F.modalidad === 'dia') return d.pd; if (F.modalidad === 'mes') return d.pm;
    return d.pm || d.pd || d.ph;
  }
  function pasa(d) {
    if (F.modalidad === 'hora' && !d.ph) return false;
    if (F.modalidad === 'dia' && !d.pd) return false;
    if (F.modalidad === 'mes' && !d.pm) return false;
    if (F.max && precioFiltro(d) > F.max) return false;
    if (F.vehiculo === 'camioneta' && d.v !== 'camioneta') return false;
    if (F.vehiculo === 'auto' && d.v === 'moto') return false;
    if (F.techado && !d.t) return false;
    if (F.acceso24 && !d.h) return false;
    if (F.seguridad && !d.sg) return false;
    if (F.carga && !d.cg) return false;
    return true;
  }
  const caracs = (d) => [d.t && '🏠 Techado', d.h && '🕐 24 h', d.sg && '🛡️ Seguridad', d.cg && '⚡ Carga', d.v === 'moto' ? '🏍️ Moto' : d.v === 'camioneta' ? '🛻 Camioneta' : '🚗 Auto'].filter(Boolean);

  function popup(d) {
    return '<div class="pop">' + (d.f ? imgMini(d.f, '') : '') + '<div class="pop-c"><div class="pop-precio">' + esc(etiqueta(d)) + (d.d ? ' <span class="pill gold">PRO</span>' : '') + '</div>' +
      '<div class="muted small">' + esc(d.c || 'Santiago') + ' · ' + esc(caracs(d).slice(0, 3).join(' · ')) + '</div>' +
      '<a class="btn small block" style="margin-top:8px" href="#/e/' + d.id + '">Ver detalle</a></div></div>';
  }

  function pintar() {
    if (!grupo) return;
    grupo.clearLayers();
    const vis = datos.filter(pasa);
    vis.forEach((d) => {
      const m = L.marker([d.la, d.lo], {
        icon: L.divIcon({ className: 'pin-wrap', html: '<span class="pin' + (d.d ? ' prem' : '') + '">' + esc(etiqueta(d)) + '</span>', iconSize: [0, 0] }),
        zIndexOffset: d.d ? 1000 : 0
      });
      m.bindPopup(() => popup(d), { closeButton: false, offset: [0, -26] });
      grupo.addLayer(m);
    });
    $('mapaInfo').textContent = datos.length ? vis.length + ' disponible' + (vis.length === 1 ? '' : 's') + ' aquí' : '';
    if (!$('hojaLista').hidden) lista();
    const n = ['modalidad', 'max', 'vehiculo', 'techado', 'acceso24', 'seguridad', 'carga'].filter((k) => F[k]).length;
    $('bFiltros').classList.toggle('on', n > 0);
    chips();
  }

  async function cargar(forzar) {
    if (!mapa) return;
    const b = mapa.getBounds();
    if (!forzar && cargado && cargado.contains(b) && Date.now() - ultimaCarga < 90000) return pintar();
    const p = b.pad(0.35);
    try {
      const r = await g.Api.rpc('mapa', { p_s: p.getSouth(), p_w: p.getWest(), p_n: p.getNorth(), p_e: p.getEast() });
      datos = r || []; cargado = p; ultimaCarga = Date.now();
      pintar();
    } catch (e) { toast(e.message); }
  }

  function lista() {
    const c = mapa.getCenter();
    const vis = datos.filter(pasa).filter((d) => mapa.getBounds().contains([d.la, d.lo]))
      .map((d) => Object.assign({ dist: mapa.distance(c, [d.la, d.lo]) }, d))
      .sort((a, b) => (b.d - a.d) || (a.dist - b.dist));
    $('listaTit').textContent = vis.length + ' estacionamiento' + (vis.length === 1 ? '' : 's') + ' en esta zona';
    $('lista').innerHTML = vis.length ? vis.map((d) => '<a class="item" href="#/e/' + d.id + '">' + imgMini(d.f) +
      '<div class="grow"><b>' + esc(etiqueta(d)) + '</b>' + (d.d ? ' <span class="pill gold">PRO</span>' : '') +
      '<div class="small muted">' + esc(d.c || '') + ' · a ' + (d.dist < 1000 ? Math.round(d.dist) + ' m' : (d.dist / 1000).toFixed(1) + ' km') + '</div>' +
      '<div class="small">' + esc(caracs(d).join(' · ')) + '</div></div></a>').join('')
      : '<div class="vacio">' + ico('car') + '<p>No hay estacionamientos con estos filtros en esta zona.<br>Aleja el mapa o cambia los filtros.</p></div>';
  }

  function guardarF() { try { localStorage.setItem('est:filtros', JSON.stringify(F)); } catch (e) { /* nada */ } }
  function chips() {
    const op = [['modalidad', 'hora', 'Por hora'], ['modalidad', 'dia', 'Por día'], ['modalidad', 'mes', 'Mensual'],
      ['techado', true, '🏠 Techado'], ['acceso24', true, '🕐 24 h'], ['seguridad', true, '🛡️ Seguridad'], ['carga', true, '⚡ Carga']];
    $('chipsFiltro').innerHTML = op.map((o, i) => '<button type="button" data-k="' + i + '" class="' + (F[o[0]] === o[1] ? 'on' : '') + '">' + o[2] + '</button>').join('');
    $('chipsFiltro').onclick = (e) => {
      const b = e.target.closest('button'); if (!b) return;
      const o = op[+b.dataset.k];
      F[o[0]] = F[o[0]] === o[1] ? (o[0] === 'modalidad' ? '' : false) : o[1];
      guardarF(); pintar();
    };
  }
  function abrirFiltros() {
    const c = modal('<h2>Filtros</h2>' +
      '<label>¿Cómo quieres arrendar?</label><select id="fMod"><option value="">Cualquiera</option><option value="hora">Por hora</option><option value="dia">Por día</option><option value="mes">Mensual</option></select>' +
      '<label>Precio máximo</label><input id="fMax" type="number" inputmode="numeric" min="0" step="1000" placeholder="Sin límite">' +
      '<label>Vehículo</label><select id="fVeh"><option value="">Cualquiera</option><option value="moto">Moto</option><option value="auto">Auto</option><option value="camioneta">Camioneta / SUV grande</option></select>' +
      '<label class="check"><input type="checkbox" id="fT"> Techado</label><label class="check"><input type="checkbox" id="fH"> Acceso 24 horas</label>' +
      '<label class="check"><input type="checkbox" id="fS"> Con seguridad / conserjería</label><label class="check"><input type="checkbox" id="fC"> Carga para auto eléctrico</label>' +
      '<div class="row" style="margin-top:14px"><button class="btn sec grow" id="fLimpiar">Limpiar</button><button class="btn grow" id="fOk">Ver resultados</button></div>');
    c.querySelector('#fMod').value = F.modalidad; c.querySelector('#fMax').value = F.max || ''; c.querySelector('#fVeh').value = F.vehiculo;
    c.querySelector('#fT').checked = F.techado; c.querySelector('#fH').checked = F.acceso24; c.querySelector('#fS').checked = F.seguridad; c.querySelector('#fC').checked = F.carga;
    c.querySelector('#fLimpiar').onclick = () => { Object.assign(F, { modalidad: '', max: 0, vehiculo: '', techado: false, acceso24: false, seguridad: false, carga: false }); guardarF(); pintar(); cerrarModal(); };
    c.querySelector('#fOk').onclick = () => {
      Object.assign(F, { modalidad: c.querySelector('#fMod').value, max: +c.querySelector('#fMax').value || 0, vehiculo: c.querySelector('#fVeh').value,
        techado: c.querySelector('#fT').checked, acceso24: c.querySelector('#fH').checked, seguridad: c.querySelector('#fS').checked, carga: c.querySelector('#fC').checked });
      guardarF(); pintar(); cerrarModal();
    };
  }

  function cercaDeMi(silencioso) {
    if (!navigator.geolocation) { if (!silencioso) toast('Tu navegador no permite ubicación'); return; }
    navigator.geolocation.getCurrentPosition((p) => {
      const ll = [p.coords.latitude, p.coords.longitude];
      if (yoMarca) yoMarca.setLatLng(ll); else yoMarca = L.circleMarker(ll, { radius: 8, color: '#fff', weight: 3, fillColor: '#2563eb', fillOpacity: 1 }).addTo(mapa);
      mapa.setView(ll, 15);
    }, () => { if (!silencioso) toast('No pudimos obtener tu ubicación (revisa el permiso)'); }, { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 });
  }

  function iniciar() {
    if (iniciado) return;
    iniciado = true;
    let vista = null;
    try { vista = JSON.parse(sessionStorage.getItem('est:vista')); } catch (e) { /* nada */ }
    mapa = L.map('mapa', { zoomControl: false, attributionControl: true, minZoom: 5 }).setView(vista ? vista.c : cfg.CENTRO, vista ? vista.z : cfg.ZOOM);
    capa = teselas(mapa);
    grupo = L.markerClusterGroup({ maxClusterRadius: 45, showCoverageOnHover: false, spiderfyOnMaxZoom: true, disableClusteringAtZoom: 16 });
    mapa.addLayer(grupo);
    let t;
    mapa.on('moveend', () => {
      clearTimeout(t); t = setTimeout(() => cargar(false), 300);
      try { sessionStorage.setItem('est:vista', JSON.stringify({ c: mapa.getCenter(), z: mapa.getZoom() })); } catch (e) { /* nada */ }
    });
    matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => { mapa.removeLayer(capa); capa = teselas(mapa); });
    $('btnCerca').onclick = () => cercaDeMi(false);
    $('btnFiltros').onclick = abrirFiltros;
    $('btnLista').onclick = () => { $('hojaLista').hidden = false; lista(); };
    $('cerrarLista').onclick = () => { $('hojaLista').hidden = true; };
    let tb;
    $('qBuscar').addEventListener('input', () => {
      clearTimeout(tb);
      const q = $('qBuscar').value.trim();
      if (q.length < 3) { $('resBuscar').hidden = true; return; }
      tb = setTimeout(async () => {
        try {
          const r = await buscar(q);
          $('resBuscar').innerHTML = r.length ? r.map((x, i) => '<button type="button" data-i="' + i + '">' + esc(x.nombre) + '</button>').join('') : '<button type="button" disabled>Sin resultados</button>';
          $('resBuscar').hidden = false;
          $('resBuscar').onclick = (e) => {
            const b = e.target.closest('button[data-i]'); if (!b) return;
            const x = r[+b.dataset.i]; mapa.setView([x.lat, x.lng], 16); $('resBuscar').hidden = true; $('qBuscar').blur();
          };
        } catch (e) { /* sin red */ }
      }, 450);
    });
    $('fBuscar').onsubmit = (e) => { e.preventDefault(); const b = $('resBuscar').querySelector('button[data-i]'); if (b) b.click(); };
    chips();
    cargar(true);
    if (!vista && navigator.permissions) {
      navigator.permissions.query({ name: 'geolocation' }).then((p) => { if (p.state === 'granted') cercaDeMi(true); }).catch(() => {});
    }
  }

  /* ---------- Mapas chicos ---------- */
  function mini(el, lat, lng, exacta) {
    const m = L.map(el, { zoomControl: false, attributionControl: false, dragging: !L.Browser.mobile, scrollWheelZoom: false, tap: false }).setView([lat, lng], exacta ? 16 : 15);
    teselas(m);
    if (exacta) L.marker([lat, lng], { icon: L.divIcon({ className: 'pin-wrap', html: '<span class="pin sel">📍 Aquí</span>', iconSize: [0, 0] }) }).addTo(m);
    else L.circle([lat, lng], { radius: 250, color: '#2563eb', weight: 2, fillOpacity: 0.12 }).addTo(m);
    setTimeout(() => m.invalidateSize(), 150);
    return m;
  }
  // Mapa para marcar la ubicación al publicar: toca o arrastra el pin.
  function selector(el, lat, lng, alCambiar) {
    const ini = lat ? [lat, lng] : (mapa ? [mapa.getCenter().lat, mapa.getCenter().lng] : cfg.CENTRO);
    const m = L.map(el, { zoomControl: true, attributionControl: false, tap: false }).setView(ini, lat ? 17 : 13);
    teselas(m);
    let mk = null;
    const poner = (ll, avisar) => {
      if (!mk) {
        mk = L.marker(ll, { draggable: true, icon: L.divIcon({ className: 'pin-wrap', html: '<span class="pin sel">📍 Tu estacionamiento</span>', iconSize: [0, 0] }) }).addTo(m);
        mk.on('dragend', () => { const p = mk.getLatLng(); alCambiar(p.lat, p.lng); });
      } else mk.setLatLng(ll);
      if (avisar) alCambiar(ll[0], ll[1]);
    };
    if (lat) poner([lat, lng], false);
    m.on('click', (e) => poner([e.latlng.lat, e.latlng.lng], true));
    setTimeout(() => m.invalidateSize(), 150);
    return { mapa: m, mover(la, lo) { m.setView([la, lo], 17); poner([la, lo], true); } };
  }

  g.Mapa = {
    iniciar, buscar, inverso, mini, selector, caracs,
    refrescar() { if (mapa) { setTimeout(() => { mapa.invalidateSize(); cargar(false); }, 60); } },
    recargar() { if (mapa) cargar(true); }
  };
})(window);
