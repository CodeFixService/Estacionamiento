/* Estaciona · panel del súper administrador: verificaciones, denuncias, usuarios, estacionamientos y ajustes propios.
   Precios, planes, textos, keys, avisos a todos, pagos Premium y versiones se manejan en el Centro de Mando. */
(function (g) {
  'use strict';
  const U = g.U, Api = g.Api;
  const { $, esc, clp, ico, toast, modal, cerrarModal, confirmar, avatar, nombreCon, imgMini, hace, fecha } = U;
  const V = $('vista');
  const BD = g.EST_CONFIG.BD; // una sola fuente: js/config.js
  const mb = (b) => b >= 1073741824 ? (b / 1073741824).toFixed(2) + ' GB' : (b / 1048576).toFixed(1) + ' MB';

  // Base de datos: se actualiza sola cada 10 minutos (desde GitHub). Aquí solo se ve su estado.
  function cardBD(inst) {
    const al = Number(inst) >= BD; // más nueva que la app también está bien (la app es la que se pone al día)
    return '<div class="card"><h3 style="margin-top:0">🗄️ Base de datos</h3><table class="tabla"><tr><td>Instalada</td><td><b>' + esc(inst) + '</b></td></tr>' +
      '<tr><td>La que espera la app</td><td>' + BD + '</td></tr></table>' +
      '<p class="small">' + (al ? '✅ Al día. Se actualiza sola cuando hay una versión nueva.' : '⏳ Se está actualizando sola (máximo 10 minutos, no borra datos).') + '</p></div>';
  }
  async function accionBD() { return false; }

  // Sin pestañas arriba (la barra de abajo es del admin). Verificaciones y Denuncias se abren desde el Resumen, con ← para volver.
  function marco(tab) {
    const sub = { verificaciones: '🪪 Verificaciones', denuncias: '🚩 Denuncias' }[tab];
    V.innerHTML = (sub ? '<div class="row" style="align-items:center;gap:8px;margin-bottom:12px"><a class="icon-btn" href="#/admin/resumen" aria-label="Volver" data-sin-atras>' + ico('back') + '</a><h2 style="margin:0">' + sub + '</h2></div>' : '') +
      '<div id="adC"><div class="spin"></div></div>';
    return $('adC');
  }

  let pendientes = null;
  const err = (C, e) => { C.innerHTML = '<div class="aviso bad">' + esc(e.message) + '</div>'; };

  async function vista(tab) {
    tab = tab || 'resumen';
    const C = marco(tab);
    try { await (VISTAS[tab] || VISTAS.resumen)(C); U.ponerIconos(C); } catch (e) { err(C, e); }
    U.centrarSeg(V);
  }

  const VISTAS = {
    async resumen(C) {
      const r = await Api.rpc('admin_resumen');
      pendientes = { verificaciones: r.pend_verif, denuncias: r.pend_denuncias };
      C = $('adC');
      const maxR = Math.max(1, ...r.registros.map((x) => x.n));
      C.innerHTML = (Number(r.version_bd || 1) < BD ? '<div class="aviso bad">⚠️ La base de datos está en la versión ' + esc(r.version_bd || '1') + ' y la app espera la ' + BD + '.</div>' + cardBD(String(r.version_bd || '1')) : '') +
        '<div class="cfx-grilla"><a class="op" href="#/admin/verificaciones"><span style="font-size:24px">🪪</span>Verificaciones' + (r.pend_verif ? '<i class="badge on">' + r.pend_verif + '</i>' : '') + '<small class="muted">Identidades por revisar</small></a>' +
        '<a class="op" href="#/admin/denuncias"><span style="font-size:24px">🚩</span>Denuncias' + (r.pend_denuncias ? '<i class="badge on">' + r.pend_denuncias + '</i>' : '') + '<small class="muted">Reportes de usuarios</small></a></div>' +
        ((r.devoluciones || []).length ? '<div class="sec-tit">💸 Devoluciones atrasadas</div><div class="card stack">' + r.devoluciones.map((d) =>
          '<div class="row between"><div class="grow small"><b>' + esc(d.dueno.nombre) + '</b> debe ' + clp(d.monto) + ' a ' + esc(d.arrendatario.nombre) +
          '<div class="muted">"' + esc(d.titulo) + '" · desde ' + fecha(d.desde) + '</div></div><button class="btn sec small" data-dev="' + d.dueno.id + '">' + ico('chat') + ' Escribir</button></div>').join('') + '</div>' : '') +
        '<div class="kpis" style="margin-top:12px">' + [['Usuarios', r.usuarios], ['Nuevos (7 días)', r.nuevos7], ['Activos (7 días)', r.activos7], ['Verificados', r.verificados],
          ['Estacionamientos', r.estacionamientos], ['Disponibles', r.disponibles], ['Arriendos activos', r.arriendos_activos], ['Arriendos totales', r.arriendos_total],
          ['Reservas en revisión', r.reservas_revision], ['Suspendidos', r.suspendidos]]
          .map((k) => '<div class="kpi"><b>' + k[1] + '</b><small>' + k[0] + '</small></div>').join('') + '</div>' +
        // El uso del servidor se ve en el Centro de Mando → Resumen (carrusel de servidores); aquí solo la limpieza.
        '<div class="sec-tit">🧹 Limpieza</div><div class="card"><p class="small muted" style="margin-top:0">Los mensajes se borran solos a los 30 días y las fotos se guardan comprimidas. También puedes limpiar ahora:</p>' +
        '<button class="btn sec small" id="aLimpiar">🧹 Limpiar ahora</button></div>' +
        '<div class="sec-tit">Registros últimos 14 días</div><div class="card"><div class="barras">' + r.registros.map((x) => '<div title="' + esc(x.d) + ': ' + x.n + '" style="height:' + (x.n / maxR * 100) + '%"></div>').join('') + '</div></div>' +
        '<div class="sec-tit">Comunas con más estacionamientos</div><div class="card">' + (r.comunas.length ? r.comunas.map((c) => '<div class="row between"><span>' + esc(c.c) + '</span><b>' + c.n + '</b></div>').join('') : '<span class="muted">Aún no hay</span>') + '</div>' +
        '<div class="sec-tit">Compartir la app</div><div class="card center"><div class="qr-caja" id="aQR"></div><p class="small" style="word-break:break-all">' + esc(U.enlace('')) + '</p>' +
        '<div class="row"><button class="btn sec grow" id="aWA">Enviar por WhatsApp</button><button class="btn grow" id="aComp">' + ico('share') + ' Compartir</button></div></div>';
      $('aQR').appendChild(U.qrCanvas(U.enlace(''), '#0b1020', 480));
      ['bdCop', 'bdAbrir'].forEach((id) => { if ($(id)) $(id).onclick = (e) => accionBD(e.currentTarget); });
      C.querySelectorAll('[data-dev]').forEach((b) => { b.onclick = async () => { try { location.hash = '#/chat/' + await Api.rpc('abrir_conversacion', { p_con: b.dataset.dev }); } catch (e) { toast(e.message); } }; });
      const inv = '🅿️ Te invito a *Estaciona*: arrienda o publica estacionamientos en Santiago con personas verificadas.\n\n1. Abre: ' + U.enlace('') + '\n2. Toca "Instalar" (iPhone: Compartir → Agregar a inicio)\n3. Crea tu cuenta y tienes 7 días Premium gratis 🎁';
      $('aWA').onclick = () => window.open('https://wa.me/?text=' + encodeURIComponent(inv), '_blank');
      $('aComp').onclick = () => U.compartir('Estaciona', inv, U.enlace(''));
      $('aLimpiar').onclick = async (e) => {
        e.target.disabled = true; e.target.textContent = 'Limpiando…';
        try { const x = await Api.funcion('limpiar'); toast('Listo: ' + (x.borrados || 0) + ' archivos borrados'); vista('resumen'); }
        catch (er) { toast(er.message); e.target.disabled = false; e.target.textContent = '🧹 Limpiar ahora'; }
      };
    },

    async verificaciones(C) {
      const r = await Api.rpc('admin_verificaciones');
      if (!r.length) { C.innerHTML = '<div class="vacio">' + ico('shield') + '<p>No hay verificaciones pendientes 🎉</p></div>'; return; }
      C.innerHTML = '<p class="small muted">Revisa que el RUT y la foto coincidan con la selfie. Confirma en el Registro Civil que el documento esté <b>vigente</b>. Al aprobar o rechazar, las fotos se borran.</p>' +
        r.map((v) => '<div class="card" style="margin-top:12px" data-u="' + v.usuario + '"><div class="row between"><div><b>' + esc(v.nombre) + '</b><div class="small muted">' + esc(v.email) + ' · ' + hace(v.enviada) + '</div></div></div>' +
          '<div class="grid2" style="margin-top:10px"><div><div class="small muted">RUT</div><div class="row"><code class="key">' + esc(U.rutFormato(v.rut)) + '</code><button class="btn sec small" data-copiar="' + esc(U.rutFormato(v.rut)) + '">Copiar</button></div></div>' +
          '<div><div class="small muted">N° documento</div><div class="row"><code class="key">' + esc(v.serie) + '</code><button class="btn sec small" data-copiar="' + esc(v.serie) + '">Copiar</button></div></div></div>' +
          '<a class="btn line small block" style="margin-top:10px" target="_blank" rel="noopener" href="https://portal.sidiv.registrocivil.cl/usuarios-portal/pages/DocumentRequestStatus.xhtml">🔎 Consultar vigencia en el Registro Civil</a>' +
          '<div class="grid3" style="margin-top:10px">' + [['frente', 'Frente'], ['reverso', 'Reverso'], ['selfie', 'Selfie']].map((f) => '<div><div class="small muted">' + f[1] + '</div><img class="ver-img" data-priv="' + esc(v[f[0]] || '') + '" alt="' + f[1] + '"></div>').join('') + '</div>' +
          '<div class="row" style="margin-top:12px"><button class="btn ok grow" data-ap="1">' + ico('check') + ' Aprobar</button><button class="btn bad grow" data-ap="0">Rechazar</button></div></div>').join('');
      C.querySelectorAll('[data-priv]').forEach(async (img) => { img.src = await U.urlPrivada(img.dataset.priv); img.onclick = () => window.open(img.src, '_blank'); });
      C.onclick = async (e) => {
        const cp = e.target.closest('[data-copiar]');
        if (cp) { try { await navigator.clipboard.writeText(cp.dataset.copiar); toast('Copiado'); } catch (er) { /* nada */ } return; }
        const b = e.target.closest('[data-ap]'); if (!b) return;
        const uid = b.closest('[data-u]').dataset.u, ok = b.dataset.ap === '1';
        let motivo = null;
        if (!ok) { motivo = await U.pedirTexto('Motivo del rechazo', 'Ej: La foto de la cédula está borrosa / el RUT no coincide', 'Rechazar'); if (motivo == null) return; }
        try { await Api.rpc('admin_resolver_verificacion', { p_id: uid, p_aprobar: ok, p_motivo: motivo }); Api.empujar(); toast(ok ? 'Aprobada ✅' : 'Rechazada'); vista('verificaciones'); } catch (er) { toast(er.message); }
      };
    },

    async denuncias(C, estado) {
      estado = estado || 'abierta';
      const r = await Api.rpc('admin_denuncias', { p_estado: estado });
      C.innerHTML = '<div class="tabs"><button data-e="abierta" class="' + (estado === 'abierta' ? 'on' : '') + '">Abiertas</button><button data-e="resuelta" class="' + (estado === 'resuelta' ? 'on' : '') + '">Resueltas</button><button data-e="descartada" class="' + (estado === 'descartada' ? 'on' : '') + '">Descartadas</button></div>' +
        (r.length ? r.map((d) => '<div class="card" style="margin-top:12px" data-id="' + d.id + '"><div class="row between"><span class="pill bad">' + esc(d.motivo) + '</span><span class="small muted">' + hace(d.creado) + '</span></div>' +
          '<p style="white-space:pre-line">' + esc(d.detalle) + '</p>' +
          '<div class="grid2 small"><div><div class="muted">Denuncia</div><a href="#/u/' + d.autor.id + '">' + esc(d.autor.nombre) + '</a></div><div><div class="muted">Denunciado (' + d.previas + ' denuncia' + (d.previas === 1 ? '' : 's') + ')</div>' +
          (d.denunciado ? '<a href="#/u/' + d.denunciado.id + '">' + esc(d.denunciado.nombre) + '</a>' : '—') + '</div></div>' +
          '<div class="small muted" style="margin-top:8px">Sobre: ' + esc(d.tipo) + (d.tipo === 'estacionamiento' ? ' · <a href="#/e/' + d.objetivo + '">ver</a>' : '') + (d.tipo === 'conversacion' ? ' · <a href="#" data-conv="' + d.objetivo + '">leer conversación</a>' : '') + '</div>' +
          '<div class="small muted" style="margin-top:8px">Evidencia:</div><img class="ver-img" data-priv="' + esc(d.evidencia) + '" alt="Evidencia">' +
          (d.resolucion ? '<p class="small"><b>Resolución:</b> ' + esc(d.resolucion) + '</p>' : '') +
          (estado === 'abierta' ? '<div class="row wrap" style="margin-top:12px"><button class="btn bad small" data-ac="suspender">Suspender al denunciado</button>' + (d.tipo === 'estacionamiento' ? '<button class="btn sec small" data-ac="ocultar">Ocultar estacionamiento</button>' : '') +
            '<button class="btn ok small" data-ac="resolver">Marcar resuelta</button><button class="btn line small" data-ac="descartar">Descartar</button></div>' : '') + '</div>').join('')
          : '<div class="vacio">' + ico('flag') + '<p>No hay denuncias ' + (estado === 'abierta' ? 'abiertas 🎉' : 'aquí') + '</p></div>');
      C.querySelectorAll('[data-priv]').forEach(async (img) => { img.src = await U.urlPrivada(img.dataset.priv); img.onclick = () => window.open(img.src, '_blank'); });
      C.onclick = async (e) => {
        const t = e.target.closest('[data-e]'); if (t) { VISTAS.denuncias(C, t.dataset.e).then(() => U.ponerIconos(C)); return; }
        const cv = e.target.closest('[data-conv]');
        if (cv) {
          e.preventDefault();
          try {
            const x = await Api.rpc('admin_conversacion', { p_conv: cv.dataset.conv });
            modal('<h2>Conversación denunciada</h2><p class="small muted">' + esc(x.a.nombre) + ' ↔ ' + esc(x.b.nombre) + '</p><div class="chat-msjs" style="max-height:60vh">' +
              (x.mensajes.length ? x.mensajes.map((m) => '<div class="burbuja' + (m.autor === x.a.id ? '' : ' mio') + '"><b class="small">' + esc(m.autor === x.a.id ? x.a.nombre : x.b.nombre) + '</b><br>' + esc(m.texto) + '<time>' + fecha(m.fecha) + ' ' + U.hora(m.fecha) + '</time></div>').join('') : '<p class="muted">Sin mensajes (se borran a los 30 días)</p>') + '</div>');
          } catch (er) { toast(er.message); }
          return;
        }
        const b = e.target.closest('[data-ac]'); if (!b) return;
        const id = b.closest('[data-id]').dataset.id, ac = b.dataset.ac;
        if (ac === 'suspender' && !await confirmar('¿Suspender la cuenta denunciada?', 'Suspender', true)) return;
        const nota = ac === 'descartar' ? null : await U.pedirTexto('Nota de resolución (opcional)', 'Ej: Se suspendió por intento de estafa', 'Guardar');
        if (nota === null && ac !== 'descartar') return;
        try { await Api.rpc('admin_resolver_denuncia', { p_id: id, p_accion: ac, p_nota: nota }); Api.empujar(); toast('Listo'); VISTAS.denuncias(C, 'abierta').then(() => U.ponerIconos(C)); } catch (er) { toast(er.message); }
      };
    },

    async usuarios(C) {
      C.innerHTML = '<div class="row"><input id="uQ" placeholder="Nombre o RUT" class="grow"><select id="uF" style="width:auto"><option value="">Todos</option><option value="premium">Premium</option><option value="gratis">Gratis</option><option value="por_vencer">Por vencer (7 días)</option><option value="inactivos">Inactivos (30 días)</option>' +
        '<option value="verificados">Verificados</option><option value="sin_verificar">Sin verificar</option><option value="suspendidos">Suspendidos</option></select></div><div id="uL"><div class="spin"></div></div><button class="btn line block" id="uMas" hidden style="margin-top:10px">Ver más</button>';
      let off = 0, t;
      const cargar = async (mas) => {
        off = mas ? off + 50 : 0;
        const r = await Api.rpc('admin_usuarios', { p_q: $('uQ').value, p_filtro: $('uF').value, p_off: off });
        const html = r.map((u) => '<div class="card" style="margin-top:10px" data-id="' + u.id + '" data-n="' + esc(u.nombre) + '"><div class="row">' + avatar(u) + '<div class="grow"><b>' + nombreCon(u) + '</b>' + (u.suspendido ? ' <span class="pill bad">Suspendido</span>' : '') +
          '<div class="small muted ell">' + esc(u.email) + (u.rut && u.rut[0] !== 'X' ? ' · RUT ' + esc(U.rutFormato(u.rut)) : '') + '</div>' +
          '<div class="small">' + (u.admin ? 'Administrador' : u.premium ? '⭐ ' + (u.plan_origen === 'prueba' ? 'Prueba' : 'Premium') + (u.premium_hasta && !/infinity/i.test(String(u.premium_hasta)) ? ' hasta ' + fecha(u.premium_hasta) : ' de por vida') : 'Gratis') +
          ' · ' + u.publicados + ' publicados' + (u.denuncias ? ' · <b style="color:var(--bad)">' + u.denuncias + ' denuncias</b>' : '') + ' · registro ' + fecha(u.creado) + '</div></div></div>' +
          (u.admin ? '' : '<div class="row wrap" style="margin-top:10px"><select data-prem class="grow" style="width:auto"><option value="">⭐ Premium…</option><option value="7">+7 días</option><option value="30">+30 días</option><option value="90">+90 días</option><option value="365">+365 días</option><option value="0">De por vida</option><option value="-1">Quitar Premium</option></select>' +
            '<button class="btn sec small" data-a="chat">' + ico('chat') + '</button><a class="btn sec small" href="#/u/' + u.id + '">' + ico('eye') + '</a>' +
            '<button class="btn ' + (u.suspendido ? 'ok' : 'sec') + ' small" data-a="susp" data-s="' + (u.suspendido ? 0 : 1) + '">' + (u.suspendido ? 'Reactivar' : 'Suspender') + '</button>' +
            '<button class="btn line small" data-a="borrar" style="color:var(--bad)">' + ico('trash') + '</button></div>') + '</div>').join('');
        if (mas) $('uL').insertAdjacentHTML('beforeend', html); else $('uL').innerHTML = html || '<div class="vacio">Sin resultados</div>';
        $('uMas').hidden = r.length < 50;
        U.ponerIconos($('uL'));
      };
      $('uQ').oninput = () => { clearTimeout(t); t = setTimeout(() => cargar(false).catch((e) => toast(e.message)), 350); };
      $('uF').onchange = () => cargar(false).catch((e) => toast(e.message));
      $('uMas').onclick = () => cargar(true).catch((e) => toast(e.message));
      $('uL').onchange = async (e) => {
        const s = e.target.closest('[data-prem]'); if (!s || s.value === '') return;
        const card = s.closest('[data-id]');
        try { await Api.rpc('admin_premium', { p_id: card.dataset.id, p_dias: +s.value }); Api.empujar(); toast('Plan actualizado'); cargar(false); } catch (er) { toast(er.message); }
      };
      $('uL').onclick = async (e) => {
        const b = e.target.closest('[data-a]'); if (!b) return;
        const card = b.closest('[data-id]'), id = card.dataset.id, n = card.dataset.n;
        try {
          if (b.dataset.a === 'chat') { location.hash = '#/chat/' + await Api.rpc('abrir_conversacion', { p_con: id }); return; }
          if (b.dataset.a === 'susp') {
            const si = b.dataset.s === '1';
            if (si && !await confirmar('¿Suspender a ' + n + '? No podrá publicar, arrendar ni chatear.', 'Suspender', true)) return;
            await Api.rpc('admin_suspender', { p_id: id, p_si: si }); toast(si ? 'Suspendido' : 'Reactivado');
          }
          if (b.dataset.a === 'borrar') {
            if (!await confirmar('¿Eliminar la cuenta de ' + n + '? Se borran su perfil, estacionamientos, fotos y mensajes. No se puede deshacer.', 'Eliminar', true)) return;
            await Api.funcion('eliminar_usuario', { id }); toast('Cuenta eliminada');
          }
          cargar(false);
        } catch (er) { toast(er.message); }
      };
      await cargar(false);
    },

    async estacionamientos(C) {
      C.innerHTML = '<div class="row" style="gap:8px;margin-bottom:10px"><a class="btn line grow" href="#/">🗺️ Ver mapa</a><a class="btn grow" href="#/publicar">＋ Agregar</a></div><input id="eQ" style="margin-bottom:14px" placeholder="Buscar lugar, comuna o dueño"><div id="eL"><div class="spin"></div></div><button class="btn line block" id="eMas" hidden style="margin-top:10px">Ver más</button>';
      let off = 0, t;
      const cargar = async (mas) => {
        off = mas ? off + 50 : 0;
        const r = await Api.rpc('admin_estacionamientos', { p_q: $('eQ').value, p_off: off });
        const html = r.map((e) => '<div class="card" style="margin-top:10px" data-id="' + e.id + '"><a class="row" href="#/e/' + e.id + '" style="color:var(--ink)">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b>' +
          '<div class="small muted">' + esc(e.direccion) + (e.comuna ? ', ' + esc(e.comuna) : '') + '</div><div class="small">' + esc(g.App.precioTxt(e)) + ' · ' + e.vistas + ' visitas</div>' +
          '<div class="small">Dueño: ' + esc(e.dueno) + ' · ' + fecha(e.creado) + ' · <span class="pill ' + g.App.ESTADO_EST[e.estado][0] + '">' + g.App.ESTADO_EST[e.estado][1] + '</span></div></div></a>' +
          '<div class="row" style="margin-top:10px"><button class="btn sec small grow" data-a="' + (e.estado === 'oculto' ? 'mostrar' : 'ocultar') + '">' + (e.estado === 'oculto' ? 'Volver a mostrar' : 'Ocultar del mapa') + '</button>' +
          '<button class="btn line small" data-a="borrar" style="color:var(--bad)">' + ico('trash') + ' Eliminar</button></div></div>').join('');
        if (mas) $('eL').insertAdjacentHTML('beforeend', html); else $('eL').innerHTML = html || '<div class="vacio">Sin resultados</div>';
        $('eMas').hidden = r.length < 50;
        U.ponerIconos($('eL'));
      };
      $('eQ').oninput = () => { clearTimeout(t); t = setTimeout(() => cargar(false).catch((e) => toast(e.message)), 350); };
      $('eMas').onclick = () => cargar(true).catch((e) => toast(e.message));
      $('eL').onclick = async (ev) => {
        const b = ev.target.closest('[data-a]'); if (!b) return;
        const id = b.closest('[data-id]').dataset.id;
        try {
          if (b.dataset.a === 'borrar') { if (!await confirmar('¿Eliminar este estacionamiento y sus fotos?', 'Eliminar', true)) return; await Api.rpc('borrar_estacionamiento', { p_id: id }); Api.empujar(); }
          else await Api.rpc('admin_ocultar', { p_id: id, p_ocultar: b.dataset.a === 'ocultar' });
          toast('Listo'); g.Mapa.recargar(); cargar(false);
        } catch (er) { toast(er.message); }
      };
      await cargar(false);
    },

    // Ajustes en cuadrícula (núcleo): solo lo propio de Estaciona.
    async ajustes(C) {
      const a = await Api.rpc('admin_config');
      C.innerHTML = '';  // sin el spinner de carga debajo de la cuadrícula
      window.CFX_AJUSTES.montar(C, [
        { k: 'reglas', ico: '⏱️', t: 'Reglas', d: 'Pagos, devoluciones y mensajes', abrir: (z) => VISTAS.seccion(z, 'reglas', a) },
        { k: 'push', ico: '🔔', t: 'Notificaciones', d: 'Claves push y función "enviar"', abrir: (z) => VISTAS.seccion(z, 'push', a) },
        { k: 'mant', ico: '🧹', t: 'Mantención', d: 'Limpieza y base de datos', abrir: (z) => VISTAS.seccion(z, 'mant', a) },
        { k: 'cuenta', ico: '👤', t: 'Mi cuenta', d: 'Foto, nombre y clave', abrir: (z) => g.App.vCuenta(z) },
        { k: 'registro', ico: '📜', t: 'Registro de cambios', d: 'Lo que se hizo en el panel', abrir: (z) => window.CFX_AJUSTES.registro(z, (f, x) => Api.rpc(f, x), { lista: true }) }
      ], { arriba: '<p class="small muted" style="margin:0 0 10px">Precios, planes, textos, keys, avisos a todos, pagos Premium y versiones se manejan en el Centro de Mando.</p>' });
    },
    async seccion(C, sub, a) {
      const ir = (x) => VISTAS.seccion(C, x, a).then(() => U.ponerIconos(C));
      let html = '';
      if (sub === 'reglas') {
        const etq = { minutos_pago: 'Minutos para pagar y subir el comprobante (reserva retenida)', minutos_devolucion: 'Minutos para cancelar con devolución',
          horas_cancelacion: 'Horas de anticipación para saldo a favor', dias_saldo: 'Días que dura el saldo a favor', dias_regalo: 'Días de Premium de regalo al crear una cuenta',
          dias_aviso_vencimiento: 'Días de aviso antes de que venza el Premium', dias_comprobantes: 'Días antes de borrar los comprobantes', dias_mensajes: 'Días antes de borrar los mensajes',
          mensajes_seguidos: 'Mensajes seguidos sin respuesta', mensajes_dia: 'Mensajes por día por persona',
          dias_devolucion: 'Días que tiene el dueño para devolver un pago (luego te avisa)', dias_anual: 'Días de Premium que entrega el pago anual' };
        html = '<div class="card">' + Object.keys(etq).map((k) => '<label>' + etq[k] + '</label><input type="number" min="0" data-r="' + k + '" value="' + (a.reglas[k] ?? '') + '">').join('') +
          '<button class="btn block" id="rgOk" style="margin-top:12px">Guardar reglas</button></div>';
      } else if (sub === 'push') {
        html = '<div class="card"><h3 style="margin-top:0">🔔 Notificaciones push</h3><p class="small muted">' + (a.vapid_public && a.push ? '✅ Claves configuradas.' : 'Genera las claves una sola vez para enviar notificaciones al celular.') + '</p>' +
          '<div class="row wrap"><button class="btn sec small" id="ajVapid">' + (a.vapid_public ? 'Regenerar claves' : 'Generar claves push') + '</button><button class="btn sec small" id="ajPing">Probar función "enviar"</button><button class="btn sec small" id="ajYo">Prueba: aviso solo a mí</button></div></div>';
      } else {
        html = '<div class="card"><p class="small muted">Borra mensajes y comprobantes viejos y fotos que ya no se usan, según las reglas.</p><button class="btn sec" id="mLimpiar">🧹 Limpiar ahora</button></div>' +
          cardBD(String((await Api.ajustes(true)).version_bd || '?'));
      }
      C.innerHTML = html;
      C.onclick = async (e) => {
        if (e.target.id === 'rgOk') {
          const p = {}; C.querySelectorAll('[data-r]').forEach((i) => { if (i.value !== '') p[i.dataset.r] = +i.value; });
          try { await Api.rpc('admin_guardar_config', { p }); toast('Reglas guardadas'); } catch (er) { toast(er.message); }
          return;
        }
        if (await accionBD(e.target)) return;
        if (e.target.id === 'mLimpiar') {
          e.target.disabled = true;
          try { const x = await Api.funcion('limpiar'); toast('Listo: ' + (x.borrados || 0) + ' archivos borrados'); } catch (er) { toast(er.message); }
          e.target.disabled = false; return;
        }
        if (e.target.id === 'ajVapid') {
          if (a.vapid_public && !await confirmar('Si regeneras las claves, cada persona deberá activar de nuevo las notificaciones. ¿Seguir?', 'Regenerar', true)) return;
          try {
            const k = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
            const raw = new Uint8Array(await crypto.subtle.exportKey('raw', k.publicKey));
            const pub = btoa(String.fromCharCode(...raw)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
            const priv = (await crypto.subtle.exportKey('jwk', k.privateKey)).d;
            await Api.rpc('admin_guardar_ajustes', { p: { vapid_public: pub, vapid_private: priv } });
            toast('Claves creadas. Activa las notificaciones en Más → Mi cuenta.'); ir('push');
          } catch (er) { toast(er.message); }
          return;
        }
        if (e.target.id === 'ajPing') { try { const r = await Api.funcion('ping'); toast('✅ Función "enviar" v' + r.version + (r.servicio ? ' lista' : ' sin clave de servidor')); } catch (er) { toast(er.message); } return; }
        if (e.target.id === 'ajYo') {
          try { await U.activarPush(); await Api.rpc('admin_prueba_push'); const r = await Api.funcion('push'); toast('Push enviados: ' + (r.enviados || 0) + (r.error ? ' · ' + r.error : '')); } catch (er) { toast(er.message); }
        }
      };
    }
  };

  g.Admin = { vista };
})(window);
