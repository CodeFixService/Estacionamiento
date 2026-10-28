/* Estaciona · panel del súper administrador. */
(function (g) {
  'use strict';
  const U = g.U, Api = g.Api;
  const { $, esc, clp, ico, toast, modal, cerrarModal, confirmar, avatar, nombreCon, imgMini, hace, fecha } = U;
  const V = $('vista');
  const TABS = [['resumen', 'Resumen'], ['verificaciones', 'Verificaciones'], ['denuncias', 'Denuncias'], ['pagos', 'Pagos'], ['usuarios', 'Usuarios'],
    ['estacionamientos', 'Estacionamientos'], ['keys', 'Keys'], ['avisos', 'Avisos'], ['ajustes', 'Ajustes']];
  const BD = 5; // versión de base de datos que espera esta app
  const mb = (b) => b >= 1073741824 ? (b / 1073741824).toFixed(2) + ' GB' : (b / 1048576).toFixed(1) + ' MB';

  // Base de datos: se actualiza sola cada 10 minutos (desde GitHub). Aquí solo se ve su estado.
  function cardBD(inst) {
    const al = inst === String(BD);
    return '<div class="card"><h3 style="margin-top:0">🗄️ Base de datos</h3><table class="tabla"><tr><td>Instalada</td><td><b>' + esc(inst) + '</b></td></tr>' +
      '<tr><td>La que espera la app</td><td>' + BD + '</td></tr></table>' +
      '<p class="small">' + (al ? '✅ Al día. Se actualiza sola cuando hay una versión nueva.' : '⏳ Se está actualizando sola (máximo 10 minutos, no borra datos).') + '</p></div>';
  }
  async function accionBD() { return false; }

  function marco(tab, pend) {
    V.innerHTML = '<div class="row between"><h1>Administración</h1><span class="chip-admin">ADMIN</span></div><div class="tabs">' +
      TABS.map((t) => '<a href="#/admin/' + t[0] + '" class="' + (t[0] === tab ? 'on' : '') + '">' + t[1] + (pend && pend[t[0]] ? ' <span class="pill bad" style="padding:0 6px">' + pend[t[0]] + '</span>' : '') + '</a>').join('') +
      '</div><div id="adC"><div class="spin"></div></div>';
    return $('adC');
  }
  let pendientes = null;
  const err = (C, e) => { C.innerHTML = '<div class="aviso bad">' + esc(e.message) + '</div>'; };

  async function vista(tab) {
    tab = tab || 'resumen';
    const C = marco(tab, pendientes);
    try { await (VISTAS[tab] || VISTAS.resumen)(C); U.ponerIconos(C); } catch (e) { err(C, e); }
    U.centrarSeg(V);
  }

  const VISTAS = {
    async resumen(C) {
      const r = await Api.rpc('admin_resumen');
      pendientes = { verificaciones: r.pend_verif, denuncias: r.pend_denuncias, pagos: r.pend_pagos };
      marco('resumen', pendientes); C = $('adC');
      const s = r.servidor, pDb = s.db / s.db_lim * 100, pSt = (s.fotos + s.privado) / s.st_lim * 100;
      const col = (p) => p > 85 ? 'bad' : p > 60 ? 'warn' : '';
      const sem = (p) => p > 85 ? '🔴 Casi lleno' : p > 60 ? '🟡 Atención' : '🟢 Bien';
      const maxR = Math.max(1, ...r.registros.map((x) => x.n));
      C.innerHTML = (String(r.version_bd) !== String(BD) ? '<div class="aviso bad">⚠️ La base de datos está en la versión ' + esc(r.version_bd || '1') + ' y la app espera la ' + BD + '.</div>' + cardBD(String(r.version_bd || '1')) : '') +
        ((r.pend_verif || r.pend_denuncias || r.pend_pagos) ? '<div class="aviso warn">' + [r.pend_verif && '<a href="#/admin/verificaciones">🪪 ' + r.pend_verif + ' verificación(es)</a>',
        r.pend_denuncias && '<a href="#/admin/denuncias">🚩 ' + r.pend_denuncias + ' denuncia(s)</a>', r.pend_pagos && '<a href="#/admin/pagos">💳 ' + r.pend_pagos + ' aviso(s) de pago</a>'].filter(Boolean).join(' · ') + ' por revisar</div>' : '') +
        ((r.devoluciones || []).length ? '<div class="sec-tit">💸 Devoluciones atrasadas</div><div class="card stack">' + r.devoluciones.map((d) =>
          '<div class="row between"><div class="grow small"><b>' + esc(d.dueno.nombre) + '</b> debe ' + clp(d.monto) + ' a ' + esc(d.arrendatario.nombre) +
          '<div class="muted">"' + esc(d.titulo) + '" · desde ' + fecha(d.desde) + '</div></div><button class="btn sec small" data-dev="' + d.dueno.id + '">' + ico('chat') + ' Escribir</button></div>').join('') + '</div>' : '') +
        '<div class="kpis" style="margin-top:12px">' + [['Usuarios', r.usuarios], ['Nuevos (7 días)', r.nuevos7], ['Activos (7 días)', r.activos7], ['Verificados', r.verificados],
          ['Premium pagados', r.premium], ['En prueba 7 días', r.prueba], ['Estacionamientos', r.estacionamientos], ['Disponibles', r.disponibles],
          ['Arriendos activos', r.arriendos_activos], ['Arriendos totales', r.arriendos_total], ['Ingresos del mes', clp(r.ingresos_mes)], ['Por vencer (7 días)', r.por_vencer],
          ['Reservas en revisión', r.reservas_revision], ['Keys sin usar', r.keys_libres], ['Suspendidos', r.suspendidos]]
          .map((k) => '<div class="kpi"><b>' + k[1] + '</b><small>' + k[0] + '</small></div>').join('') + '</div>' +
        '<div class="sec-tit">' + ico('server') + ' Estado del servidor (Supabase gratis)</div><div class="card">' +
        '<div class="row between small"><b>Base de datos</b><span>' + sem(pDb) + ' · ' + mb(s.db) + ' de ' + mb(s.db_lim) + '</span></div><div class="barra"><i class="' + col(pDb) + '" style="width:' + Math.max(1, pDb) + '%"></i></div>' +
        '<div class="row between small" style="margin-top:12px"><b>Fotos y archivos</b><span>' + sem(pSt) + ' · ' + mb(s.fotos + s.privado) + ' de ' + mb(s.st_lim) + '</span></div><div class="barra"><i class="' + col(pSt) + '" style="width:' + Math.max(1, pSt) + '%"></i></div>' +
        '<p class="small muted">' + s.archivos + ' archivos · ' + s.mensajes + ' mensajes guardados · ' + s.por_borrar + ' archivos por borrar. Los mensajes se borran solos a los 30 días y las fotos se guardan comprimidas (WebP).</p>' +
        '<button class="btn sec small" id="aLimpiar">🧹 Limpiar ahora</button>' +
        '<details style="margin-top:10px"><summary class="small">Tamaño por tabla</summary><table class="tabla">' + (r.tablas || []).map((t) => '<tr><td>' + esc(t.t) + '</td><td>' + t.n + ' filas</td><td>' + mb(t.b) + '</td></tr>').join('') + '</table></details></div>' +
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

    async pagos(C, estado) {
      estado = estado || 'pendiente';
      const r = await Api.rpc('admin_pagos', { p_estado: estado });
      C.innerHTML = '<div class="seg">' + [['pendiente', '🧾 Por revisar'], ['aprobado', '✅ Aprobados'], ['rechazado', '❌ Rechazados']].map((t) => '<button data-e="' + t[0] + '" class="' + (t[0] === estado ? 'on' : '') + '">' + t[1] + '</button>').join('') + '</div>' +
        (r.length ? r.map((p) => '<div class="card" style="margin-top:10px" data-id="' + p.id + '"><div class="row">' + avatar(p.usuario) + '<div class="grow"><b>' + esc(p.usuario.nombre) + '</b><div class="small muted">' + esc(p.email) + ' · ' + hace(p.creado) + '</div></div><div style="text-align:right"><b>' + clp(p.monto) + '</b><div>' + (p.periodo === 'anual' ? '<span class="pill gold">🗓️ Anual</span>' : '<span class="pill">📅 Mensual</span>') + '</div></div></div>' +
          (p.nota ? '<p class="small" style="background:var(--card2);padding:8px 10px;border-radius:10px">' + esc(p.nota) + '</p>' : '') +
          (p.comprobante ? '<img class="ver-img" data-priv="' + esc(p.comprobante) + '" alt="Comprobante" style="margin-top:8px"><a class="btn sec small" style="margin-top:6px" data-desc="' + esc(p.comprobante) + '">' + ico('download') + ' Descargar</a>' : '<p class="small muted">Sin comprobante (o ya se borró)</p>') +
          (p.motivo ? '<p class="small"><b>Motivo:</b> ' + esc(p.motivo) + '</p>' : '') +
          (estado === 'pendiente' ? '<div class="row" style="margin-top:10px"><button class="btn ok grow" data-ap="1">✅ Aprobar Premium</button><button class="btn line grow" data-ap="0">Rechazar</button></div>' : '') + '</div>').join('')
          : '<div class="vacio">💳<p>No hay pagos aquí</p></div>');
      C.querySelectorAll('[data-priv]').forEach(async (img) => { img.src = await U.urlPrivada(img.dataset.priv); img.onclick = () => window.open(img.src, '_blank'); });
      C.onclick = async (e) => {
        const t = e.target.closest('[data-e]'); if (t) { VISTAS.pagos(C, t.dataset.e).then(() => U.ponerIconos(C)); return; }
        const d = e.target.closest('[data-desc]');
        if (d) { const u = await U.urlPrivada(d.dataset.desc); const a = document.createElement('a'); a.href = u; a.download = 'comprobante'; a.target = '_blank'; a.click(); return; }
        const b = e.target.closest('[data-ap]'); if (!b) return;
        let motivo = null;
        if (b.dataset.ap === '0') { motivo = await U.pedirTexto('Motivo del rechazo', 'Ej: no encontré el pago en mi cuenta', 'Rechazar'); if (motivo == null) return; }
        try { await Api.rpc('admin_resolver_pago', { p_id: b.closest('[data-id]').dataset.id, p_aprobar: b.dataset.ap === '1', p_motivo: motivo }); Api.empujar(); toast('Listo'); vista('pagos'); } catch (er) { toast(er.message); }
      };
    },

    async usuarios(C) {
      C.innerHTML = '<div class="row"><input id="uQ" placeholder="Buscar por nombre, correo o RUT" class="grow"><select id="uF" style="width:auto"><option value="">Todos</option><option value="premium">Premium</option><option value="gratis">Gratis</option><option value="por_vencer">Por vencer (7 días)</option><option value="inactivos">Inactivos (30 días)</option>' +
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
      C.innerHTML = '<input id="eQ" placeholder="Buscar por título, comuna, dirección o dueño"><div id="eL"><div class="spin"></div></div><button class="btn line block" id="eMas" hidden style="margin-top:10px">Ver más</button>';
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

    async keys(C) {
      const r = await Api.rpc('admin_keys');
      C.innerHTML = '<div class="card"><h3>Crear keys Premium</h3><div class="grid3"><div><label>Duración</label><select id="kM"><option value="1">1 mes</option><option value="3">3 meses</option><option value="6">6 meses</option><option value="12">12 meses</option><option value="0">De por vida</option></select></div>' +
        '<div><label>Cantidad</label><input id="kN" type="number" min="1" max="50" value="1"></div><div><label>Nota</label><input id="kNota" placeholder="Ej: Juan"></div></div>' +
        '<button class="btn block" id="kCrear" style="margin-top:12px">' + ico('key') + ' Crear</button><div id="kNuevas"></div></div>' +
        '<div class="sec-tit">Keys creadas</div>' + (r.length ? '<div class="card pad0"><table class="tabla"><tr><th style="padding-left:12px">Key</th><th>Plan</th><th>Estado</th><th></th></tr>' +
          r.map((k) => '<tr><td style="padding-left:12px"><code class="key">' + esc(k.key) + '</code>' + (k.nota ? '<div class="small muted">' + esc(k.nota) + '</div>' : '') + '</td><td>' + (k.meses ? k.meses + ' m' : '∞') + '</td>' +
            '<td class="small">' + (k.revocada ? '<span class="pill bad">Anulada</span>' : k.canjeada ? '<span class="pill ok">Usada</span><div class="muted">' + esc(k.usuario || '') + '</div>' : '<span class="pill">Libre</span>') + '</td>' +
            '<td>' + (!k.canjeada && !k.revocada ? '<button class="btn sec small" data-wa="' + esc(k.key) + '">WhatsApp</button> <button class="btn line small" data-rev="' + esc(k.key) + '">Anular</button>' : '') + '</td></tr>').join('') + '</table></div>' : '<div class="vacio">Aún no creas keys</div>');
      const msj = (k) => '⭐ ¡Tu Premium de Estaciona está listo!\n\nKey: *' + k + '*\n\n1. Abre ' + U.enlace('#/premium') + '\n2. Pega la key en "¿Tienes una key?" y toca Activar.';
      $('kCrear').onclick = async () => {
        try {
          const ks = await Api.rpc('admin_crear_keys', { p_meses: +$('kM').value, p_cantidad: +$('kN').value || 1, p_nota: $('kNota').value });
          vista('keys').then(() => {
            $('kNuevas').innerHTML = '<div class="aviso" style="margin-top:12px"><b>Nuevas:</b><br>' + ks.map((k) => '<div class="row between" style="margin-top:6px"><code class="key">' + esc(k) + '</code><button class="btn sec small" data-wa="' + esc(k) + '">WhatsApp</button></div>').join('') + '</div>';
          });
        } catch (e) { toast(e.message); }
      };
      C.onclick = async (e) => {
        const wa = e.target.closest('[data-wa]');
        if (wa) { window.open('https://wa.me/?text=' + encodeURIComponent(msj(wa.dataset.wa)), '_blank'); return; }
        const rv = e.target.closest('[data-rev]');
        if (rv && await confirmar('¿Anular la key ' + rv.dataset.rev + '?', 'Anular', true)) { try { await Api.rpc('admin_revocar_key', { p_key: rv.dataset.rev }); vista('keys'); } catch (er) { toast(er.message); } }
      };
    },

    async avisos(C) {
      C.innerHTML = '<div class="card"><h3>Aviso a todos los usuarios</h3><p class="small muted">Llega a la campana de avisos y como notificación push a quienes la tengan activa.</p>' +
        '<label>Título</label><input id="avT" maxlength="80" placeholder="Ej: ¡Nuevos estacionamientos en Ñuñoa!"><label>Mensaje</label><textarea id="avC" maxlength="200"></textarea>' +
        '<button class="btn block" id="avOk" style="margin-top:12px">' + ico('send') + ' Enviar a todos</button></div>';
      $('avOk').onclick = async (e) => {
        if (!await confirmar('¿Enviar este aviso a todos los usuarios?', 'Enviar')) return;
        e.target.disabled = true;
        try { const n = await Api.rpc('admin_aviso', { p_titulo: $('avT').value, p_cuerpo: $('avC').value }); for (let i = 0; i < Math.ceil(n / 300); i++) await Api.funcion('push').catch(() => {}); toast('Enviado a ' + n + ' usuarios'); $('avT').value = $('avC').value = ''; }
        catch (er) { toast(er.message); } finally { e.target.disabled = false; }
      };
    },

    async ajustes(C, sub) {
      sub = sub || 'precios';
      const a = await Api.rpc('admin_config');
      const SUBS = [['precios', '💳 Precios y links'], ['planes', '⭐ Planes'], ['reglas', '⏱️ Reglas'], ['textos', '📝 Textos'], ['push', '🔔 Notificaciones'], ['mant', '🧹 Mantención']];
      const nav = '<div class="seg">' + SUBS.map((t) => '<button data-s="' + t[0] + '" class="' + (t[0] === sub ? 'on' : '') + '">' + t[1] + '</button>').join('') + '</div>';
      const ir = (s) => VISTAS.ajustes(C, s).then(() => { U.ponerIconos(C); U.centrarSeg(C); });
      let html = '';
      if (sub === 'precios') {
        const espacios = (lista, tipo) => (lista || []).map((s) => '<div class="card slotpago' + (s.activo ? ' on' : '') + '" data-slot="' + s.slot + '" data-tipo="' + tipo + '"><div class="row between"><b>Espacio ' + s.slot + '</b><label class="check" style="margin:0"><input type="radio" name="alAct-' + tipo + '"' + (s.activo ? ' checked' : '') + '> Activo</label></div>' +
          '<label>Precio (CLP)</label><input class="alM" type="number" inputmode="numeric" min="0" value="' + s.monto + '">' +
          '<label>Link de pago</label><input class="alU" type="url" placeholder="https://mpago.la/…" value="' + esc(s.url) + '">' +
          '<label>Texto (opcional)</label><input class="alT" maxlength="300" placeholder="Ej: Oferta de lanzamiento" value="' + esc(s.texto) + '">' +
          '<button class="btn block alOk" style="margin-top:10px">Guardar espacio ' + s.slot + '</button></div>').join('');
        html = '<p class="small muted">Links de pago del Premium (te pagan a ti). Cada plan tiene 2 espacios: el <b>activo</b> define el precio que ve todo el mundo.</p>' +
          '<div class="sec-tit">📅 Premium mensual · ' + ((a.planes || []).find((p) => p.codigo === 'premium') || {}).duracion_dias + ' días</div>' + espacios(a.links, 'premium') +
          '<div class="sec-tit">🗓️ Premium anual · ' + (a.reglas.dias_anual ?? 365) + ' días</div>' +
          (a.links_anual ? '<p class="small muted">Con precio 0 en el espacio activo, el plan anual no se muestra. Los días se cambian en <b>Reglas</b>.</p>' + espacios(a.links_anual, 'premium_anual')
            : '<div class="aviso warn">Actualiza la base de datos (Mantención) para activar el plan anual.</div>');
      } else if (sub === 'planes') {
        const etq = { publicar: 'Estacionamientos publicados', arrendar: 'Arriendos activos a la vez', fotos: 'Fotos por estacionamiento', favoritos: 'Favoritos (500 = ilimitado)',
          destacado: 'Pin dorado destacado', estadisticas: 'Estadísticas', alertas: 'Alerta de zona', color_libre: 'Color libre (RGB)', qr_color: 'QR con su color' };
        html = a.planes.map((p) => '<div class="card" data-plan="' + p.codigo + '"><h3 style="margin-top:0">' + (p.codigo === 'premium' ? '⭐ ' : '') + esc(p.nombre) + '</h3>' +
          '<div class="grid2"><div><label>Nombre</label><input class="plN" value="' + esc(p.nombre) + '"></div><div><label>Duración (días)</label><input class="plD" type="number" min="1" value="' + p.duracion_dias + '"></div></div>' +
          '<label>Descripción</label><input class="plDe" value="' + esc(p.descripcion) + '">' +
          '<div class="grid2">' + Object.keys(etq).map((k) => typeof p.limites[k] === 'boolean'
            ? '<label class="check"><input type="checkbox" data-k="' + k + '"' + (p.limites[k] ? ' checked' : '') + '> ' + etq[k] + '</label>'
            : '<div><label>' + etq[k] + '</label><input type="number" min="0" data-k="' + k + '" value="' + (p.limites[k] || 0) + '"></div>').join('') + '</div>' +
          '<label>Beneficios (uno por línea)</label><textarea class="plB">' + esc((p.beneficios || []).join('\n')) + '</textarea>' +
          '<button class="btn block plOk" style="margin-top:10px">Guardar plan</button></div>').join('');
      } else if (sub === 'reglas') {
        const etq = { minutos_pago: 'Minutos para pagar y subir el comprobante (reserva retenida)', minutos_devolucion: 'Minutos para cancelar con devolución',
          horas_cancelacion: 'Horas de anticipación para saldo a favor', dias_saldo: 'Días que dura el saldo a favor', dias_regalo: 'Días de Premium de regalo al crear una cuenta',
          dias_aviso_vencimiento: 'Días de aviso antes de que venza el Premium', dias_comprobantes: 'Días antes de borrar los comprobantes', dias_mensajes: 'Días antes de borrar los mensajes',
          mensajes_seguidos: 'Mensajes seguidos sin respuesta', mensajes_dia: 'Mensajes por día por persona',
          dias_devolucion: 'Días que tiene el dueño para devolver un pago (luego te avisa)', dias_anual: 'Días de Premium que entrega el pago anual' };
        html = '<div class="card">' + Object.keys(etq).map((k) => '<label>' + etq[k] + '</label><input type="number" min="0" data-r="' + k + '" value="' + (a.reglas[k] ?? '') + '">').join('') +
          '<button class="btn block" id="rgOk" style="margin-top:12px">Guardar reglas</button></div>';
      } else if (sub === 'textos') {
        const etq = { app_lema: 'Lema de la app', reserva_pago: 'Instrucciones de pago de la reserva ({minutos})', reserva_politica: 'Política de cancelación ({devolucion} {horas} {dias})',
          premium_titulo: 'Título de Premium', premium_texto: 'Texto de Premium', pago_instrucciones: 'Instrucciones para pagar Premium', bienvenida: 'Bienvenida', aviso_seguridad: 'Aviso de seguridad' };
        html = '<div class="card">' + Object.keys(etq).map((k) => '<label>' + etq[k] + '</label><textarea data-t="' + k + '">' + esc(a.textos[k] || '') + '</textarea>').join('') +
          '<button class="btn block" id="txOk" style="margin-top:12px">Guardar textos</button></div>';
      } else if (sub === 'push') {
        html = '<div class="card"><h3 style="margin-top:0">🔔 Notificaciones push</h3><p class="small muted">' + (a.vapid_public && a.push ? '✅ Claves configuradas.' : 'Genera las claves una sola vez para enviar notificaciones al celular.') + '</p>' +
          '<div class="row wrap"><button class="btn sec small" id="ajVapid">' + (a.vapid_public ? 'Regenerar claves' : 'Generar claves push') + '</button><button class="btn sec small" id="ajPing">Probar función "enviar"</button><button class="btn sec small" id="ajYo">Prueba: aviso solo a mí</button></div></div>';
      } else {
        html = '<div class="card"><h3 style="margin-top:0">🧹 Mantención</h3><p class="small muted">Borra mensajes y comprobantes viejos y fotos que ya no se usan, según las reglas.</p><button class="btn sec" id="mLimpiar">Limpiar ahora</button></div>' +
          '<div class="card" id="mVer"><h3 style="margin-top:0">🔄 Versiones de la app</h3><p class="small">Cargando…</p></div>' +
          cardBD(String((await Api.ajustes(true)).version_bd || '?'));
      }
      C.innerHTML = nav + html;
      if ($('mVer')) {
        let pub = '?';
        try { pub = String((await (await fetch('version.json?t=' + Date.now(), { cache: 'no-store' })).json()).version); } catch (e) { /* sin red */ }
        const lib = a.textos.version_liberada || '—', cfg = g.EST_CONFIG;
        $('mVer').innerHTML = '<h3 style="margin-top:0">🔄 Versiones de la app</h3><table class="tabla"><tr><td>Publicada (GitHub)</td><td><b>' + esc(pub) + '</b></td></tr>' +
          '<tr><td>La que usas tú</td><td>' + esc(cfg.VERSION) + '</td></tr><tr><td>Liberada a todos</td><td>' + esc(lib) + '</td></tr></table>' +
          '<p class="small muted">1) Actualiza la tuya y prueba. 2) Toca <b>Liberar</b>: a todos se les actualiza sola y les llega un aviso.</p>' +
          '<div class="row wrap"><button class="btn sec small" id="vMia">Actualizar la mía</button><button class="btn small" id="vLib"' + (pub === '?' || pub === lib ? ' disabled' : '') + '>🚀 Liberar v' + esc(pub) + ' a todos</button></div>';
        $('vMia').onclick = (e) => g.App.actualizarAhora(e.target);
        $('vLib').onclick = async () => {
          if (!await confirmar('¿Liberar la versión ' + pub + ' a todos y avisarles?', 'Liberar')) return;
          try {
            await Api.rpc('admin_guardar_textos', { p: { version_liberada: pub } });
            const n = await Api.rpc('admin_aviso', { p_titulo: '🔄 Nueva versión ' + pub, p_cuerpo: 'Abre Estaciona: se actualiza sola.' });
            for (let i = 0; i < Math.ceil(n / 300); i++) await Api.funcion('push').catch(() => {});
            toast('Versión ' + pub + ' liberada · aviso a ' + n + ' usuarios'); ir('mant');
          } catch (er) { toast(er.message); }
        };
      }
      C.onclick = async (e) => {
        const t = e.target.closest('[data-s]'); if (t) return ir(t.dataset.s);
        const al = e.target.closest('.alOk');
        if (al) {
          const c = al.closest('[data-slot]');
          const arg = { p_slot: +c.dataset.slot, p_monto: +c.querySelector('.alM').value || 0, p_url: c.querySelector('.alU').value, p_texto: c.querySelector('.alT').value, p_activo: c.querySelector('input[type=radio]').checked };
          if (c.dataset.tipo === 'premium_anual') arg.p_tipo = 'premium_anual';
          try { await Api.rpc('admin_guardar_link', arg); toast('Guardado'); ir('precios'); } catch (er) { toast(er.message); }
          return;
        }
        const pl = e.target.closest('.plOk');
        if (pl) {
          const c = pl.closest('[data-plan]'), lim = {};
          c.querySelectorAll('[data-k]').forEach((i) => { lim[i.dataset.k] = i.type === 'checkbox' ? i.checked : (+i.value || 0); });
          try {
            await Api.rpc('admin_guardar_plan', { p_codigo: c.dataset.plan, p_nombre: c.querySelector('.plN').value, p_descripcion: c.querySelector('.plDe').value, p_limites: lim,
              p_beneficios: c.querySelector('.plB').value.split('\n').map((x) => x.trim()).filter(Boolean), p_duracion: +c.querySelector('.plD').value || 30 });
            toast('Plan guardado'); ir('planes');
          } catch (er) { toast(er.message); }
          return;
        }
        if (e.target.id === 'rgOk') {
          const p = {}; C.querySelectorAll('[data-r]').forEach((i) => { if (i.value !== '') p[i.dataset.r] = +i.value; });
          try { await Api.rpc('admin_guardar_config', { p }); toast('Reglas guardadas'); } catch (er) { toast(er.message); }
          return;
        }
        if (e.target.id === 'txOk') {
          const p = {}; C.querySelectorAll('[data-t]').forEach((i) => { p[i.dataset.t] = i.value; });
          try { await Api.rpc('admin_guardar_textos', { p }); toast('Textos guardados'); } catch (er) { toast(er.message); }
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
