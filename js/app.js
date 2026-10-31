/* Estaciona · pantallas de la app (rutas con #). */
(function (g) {
  'use strict';
  const U = g.U, Api = g.Api, cfg = g.EST_CONFIG;
  const { $, esc, clp, ico, toast, modal, cerrarModal, confirmar, avatar, nombreCon, estrellas, imgMini, urlFoto, hace, fecha, hora, fh, quedan } = U;
  const V = $('vista');
  let rutaActual = '', pollChat = null, ajustes = null;
  const COLORES_GRATIS = [['Azul', '#2563eb'], ['Negro', '#0f172a'], ['Verde', '#16a34a'], ['Rojo', '#dc2626'], ['Violeta', '#7c3aed'], ['Naranja', '#ea580c']];
  const ICONOS = ['🚗', '🏍️', '🛻', '🚙', '🚕', '🅿️', '😎', '⭐', '🔑', '🏠', '🐶', '⚽'];
  const MODAL = { hora: 'Por hora', dia: 'Por día', mes: 'Mensual' };
  const ESTADO_ARR = { pendiente: ['warn', 'Pendiente'], por_pagar: ['warn', '💳 Esperando pago'], en_revision: ['brand', '🧾 En revisión'],
    aceptado: ['ok', '✅ Confirmada'], rechazado: ['bad', 'Rechazada'], cancelado: ['', 'Cancelada'], finalizado: ['brand', 'Finalizada'], expirado: ['', '⌛ Vencida'] };
  const PAGO = { devolver: ['bad', '💸 Por devolver'], devuelto: ['ok', 'Devuelto'], saldo: ['brand', '💰 Saldo a favor'], perdido: ['', 'Sin devolución'], aplicado: ['', 'Saldo usado'] };
  const ESTADO_EST = { disponible: ['ok', 'Disponible'], ocupado: ['warn', 'Ocupado'], pausado: ['', 'Pausado'], oculto: ['bad', 'Oculto por el admin'] };

  async function ajustesPub() {
    if (ajustes) return ajustes;
    try { ajustes = await Api.rpc('ajustes_publicos') || {}; } catch (e) { ajustes = {}; }
    return ajustes;
  }
  const precioTxt = (e) => [e.ph && clp(e.ph) + '/h', e.pd && clp(e.pd) + '/día', e.pm && clp(e.pm) + '/mes'].filter(Boolean).join(' · ');
  const volver = (txt) => '<button class="btn line small" onclick="history.length>1?history.back():location.hash=\'#/\'" style="margin-bottom:12px">' + ico('back') + ' ' + esc(txt || 'Volver') + '</button>';
  const cargando = () => { V.innerHTML = '<div class="spin"></div>'; };
  const pill = (par) => '<span class="pill ' + par[0] + '">' + esc(par[1]) + '</span>';

  // Errores con salida: Premium → planes; verificación → verificar.
  function fallo(e) {
    const m = (e && e.message) || String(e);
    if (/Premium/i.test(m)) {
      const c = modal('<div class="center"><div style="font-size:44px">⭐</div><h2>Función Premium</h2><p>' + esc(m) + '</p><a class="btn gold block" href="#/premium">Ver Premium</a></div>');
      c.querySelector('a').onclick = cerrarModal;
    } else if (/verifica tu identidad/i.test(m)) {
      const c = modal('<div class="center"><div style="font-size:44px">🪪</div><h2>Verifica tu identidad</h2><p>Para cuidar a la comunidad, solo las personas verificadas pueden publicar, arrendar y chatear. Toma 2 minutos.</p><a class="btn block" href="#/verificar">Verificar ahora</a></div>');
      c.querySelector('a').onclick = cerrarModal;
    } else toast(m);
  }

  /* ======================= Sesión ======================= */
  function vLogin(motivo, tab) {
    const c = modal('<div class="center" style="margin-bottom:6px"><span class="logo-p" style="margin:0 auto 8px;width:52px;height:52px;font-size:30px;border-radius:16px">P</span>' +
      '<h2>' + esc(motivo || 'Bienvenido a Estaciona') + '</h2><p class="muted small">Arrienda o publica estacionamientos con personas verificadas.</p></div>' +
      '<div class="tabs" style="justify-content:center"><button data-t="in">Ingresar</button><button data-t="up">Crear cuenta</button></div>' +
      '<form id="fIn"><label>Correo</label><input type="email" id="lEmail" autocomplete="email" required><label>Contraseña</label><input type="password" id="lClave" autocomplete="current-password" required minlength="6">' +
      '<button class="btn block" style="margin-top:16px">Ingresar</button><p class="center small"><a href="#" id="lOlvide">¿Olvidaste tu contraseña?</a></p></form>' +
      '<form id="fUp" hidden><label>Tu nombre</label><input id="rNombre" autocomplete="name" required minlength="2" maxlength="60" placeholder="Ej: Camila Rojas">' +
      '<label>Correo</label><input type="email" id="rEmail" autocomplete="email" required><label>Contraseña (mínimo 6)</label><input type="password" id="rClave" autocomplete="new-password" required minlength="6">' +
      '<label class="check"><input type="checkbox" id="rAcepto" required> <span>Acepto los <a href="#/legal" target="_blank">términos y la política de privacidad</a>.</span></label>' +
      '<div class="aviso small">🎁 Tu primer pago te da <b>30 días de Premium</b>.</div>' +
      '<button class="btn block" style="margin-top:14px">Crear mi cuenta</button></form>');
    const tabs = c.querySelectorAll('.tabs button');
    const ir = (t) => { tabs.forEach((b) => b.classList.toggle('on', b.dataset.t === t)); c.querySelector('#fIn').hidden = t !== 'in'; c.querySelector('#fUp').hidden = t !== 'up'; };
    tabs.forEach((b) => { b.onclick = () => ir(b.dataset.t); });
    ir(tab || 'up');
    c.querySelector('#fIn').onsubmit = async (e) => {
      e.preventDefault(); const b = e.target.querySelector('button'); b.disabled = true;
      try { await Api.ingresar(c.querySelector('#lEmail').value, c.querySelector('#lClave').value); cerrarModal(); toast('¡Hola de nuevo! 👋'); despuesDeIngresar(); }
      catch (err) { toast(err.message); } finally { b.disabled = false; }
    };
    c.querySelector('#fUp').onsubmit = async (e) => {
      e.preventDefault(); const b = e.target.querySelector('button'); b.disabled = true;
      try { await Api.registrar(c.querySelector('#rNombre').value, c.querySelector('#rEmail').value, c.querySelector('#rClave').value); cerrarModal(); toast('¡Cuenta creada! 🎁'); despuesDeIngresar(true); }
      catch (err) { toast(err.message); } finally { b.disabled = false; }
    };
    c.querySelector('#lOlvide').onclick = async (e) => {
      e.preventDefault();
      const email = c.querySelector('#lEmail').value.trim();
      if (!email) { toast('Escribe tu correo arriba'); return; }
      const { error } = await Api.sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname });
      toast(error ? U.amable(error) : 'Te enviamos un correo para crear una contraseña nueva');
    };
  }
  let destino = '';
  function despuesDeIngresar(nuevo) {
    U.sincronizarPush(); contadores();
    const d = destino; destino = '';
    if (nuevo && !/^#\/e\//.test(d)) { location.hash = '#/verificar'; return; }
    if (d && d !== location.hash) location.hash = d; else router();
  }
  function pedirLogin(motivo) { vLogin(motivo || 'Crea tu cuenta para continuar', 'up'); }

  /* ======================= Detalle de estacionamiento (público) ======================= */
  async function vDetalle(id) {
    cargando();
    let d;
    try { d = await Api.rpc('estacionamiento_detalle', { p_id: id }); } catch (e) { V.innerHTML = volver() + '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    const est = ESTADO_EST[d.estado] || ['', d.estado];
    const fotos = (d.fotos || []).map((f) => '<img src="' + esc(urlFoto(f)) + '" alt="Foto del estacionamiento" loading="lazy">').join('');
    const precios = [['hora', d.ph], ['dia', d.pd], ['mes', d.pm]].filter((p) => p[1])
      .map((p) => '<div class="precio"><b>' + clp(p[1]) + '</b><small>' + MODAL[p[0]] + '</small></div>').join('');
    const arr = d.mi_arriendo;
    const reservable = d.estado === 'disponible' && (d.reservable ?? d.visible) !== false;
    const ocup = (d.ocupado || []).slice(0, 6);
    V.innerHTML = volver('Mapa') + '<div class="galeria">' + (fotos || '<img alt="">') + '</div>' +
      '<div class="row between" style="margin-top:14px"><h1 class="grow">' + esc(d.titulo) + '</h1>' + (d.estado !== 'disponible' ? pill(est) : '') + '</div>' +
      '<div class="precios">' + precios + '</div>' +
      '<div class="carac">' + g.Mapa.caracs({ t: d.techado, h: d.acceso24, sg: d.seguridad, cg: d.carga, v: d.vehiculo }).map((x) => '<span class="pill">' + esc(x) + '</span>').join('') + '</div>' +
      (d.descripcion ? '<p style="margin-top:12px;white-space:pre-line">' + esc(d.descripcion) + '</p>' : '') +
      (d.mio && !d.visible ? '<div class="aviso warn" style="margin-top:12px">⚠️ Este estacionamiento <b>no se ve en el mapa</b> porque superas el límite de tu plan. <a href="#/premium">Hazte Premium</a>.</div>' : '') +
      '<div class="sec-tit">Ubicación exacta</div><div class="card"><b>📍 ' + esc(d.direccion) + '</b>' + (d.comuna ? '<div class="small muted">' + esc(d.comuna) + '</div>' : '') +
      '<div class="mini-mapa" id="mm" style="margin-top:10px"></div>' +
      '<div class="row" style="margin-top:10px"><a class="btn small sec" target="_blank" rel="noopener" href="https://www.google.com/maps/dir/?api=1&destination=' + d.lat + ',' + d.lng + '">🧭 Cómo llegar</a></div></div>' +
      (ocup.length ? '<div class="sec-tit">Horarios ya reservados</div><div class="card small">' + ocup.map((o) => '<div>⛔ ' + esc(fh(o.inicio)) + ' → ' + esc(fh(o.fin)) + '</div>').join('') + '</div>' : '') +
      '<div class="sec-tit">Publicado por</div>' + (d.logueado ? '<a class="item" href="#/u/' + d.dueno.id + '">' : '<div class="item">') + avatar(d.dueno) + '<div class="grow"><b>' + nombreCon(d.dueno) + '</b><div class="small">' + estrellas(d.dueno.calif) +
      (d.dueno.calif_n ? ' <span class="muted">(' + d.dueno.calif_n + ')</span>' : '') + ' · <span class="muted">desde ' + fecha(d.dueno.desde) + '</span></div></div>' + (d.logueado ? '</a>' : '</div>') +
      (!d.mio && !arr && d.estado === 'disponible' && !reservable ? '<div class="aviso warn" style="margin-top:12px">⏸️ Este estacionamiento no está recibiendo reservas por ahora. Puedes escribirle al dueño.</div>' : '') +
      (arr ? '<a class="aviso" style="display:block;margin-top:12px;color:var(--ink)" href="#/r/' + arr.id + '">Tu reserva: ' + pill(ESTADO_ARR[arr.estado] || ['', arr.estado]) + ' · Ver →</a>' : '') +
      (d.mio ? '<div class="sec-tit">Tu estacionamiento</div><div class="card"><div class="row between"><span>Estado</span><select id="dEstado" style="width:auto"' + (d.estado === 'oculto' ? ' disabled' : '') + '>' +
        ['disponible', 'ocupado', 'pausado'].map((s) => '<option value="' + s + '"' + (d.estado === s ? ' selected' : '') + '>' + ESTADO_EST[s][1] + '</option>').join('') + '</select></div>' +
        '<p class="small muted" style="margin:8px 0 0">' + ico('eye') + ' ' + (Api.puede('estadisticas') ? (d.vistas || 0) + ' visitas' : 'Estadísticas: <a href="#/premium">Premium</a>') + '</p></div>' : '') +
      '<p class="small muted" style="margin-top:14px">🔒 ' + esc(Api.texto('aviso_seguridad', 'Si algo parece estafa, denúncialo con evidencia.')) + '</p>' +
      '<div class="acciones">' + (d.mio
        ? '<a class="btn grow" href="#/editar/' + d.id + '">' + ico('edit') + ' Editar</a><button class="btn sec" id="dQR" aria-label="QR">' + ico('qr') + '</button>'
        : (!arr && reservable ? '<button class="btn grow" id="dSol">📅 Reservar</button>' : '') +
          '<button class="btn sec' + (arr || !reservable ? ' grow' : '') + '" id="dChat">' + ico('chat') + (arr || !reservable ? ' Contactar' : '') + '</button>' +
          '<button class="btn sec" id="dFav" aria-label="Favorito" style="' + (d.favorito ? 'color:#e11d48' : '') + '">' + ico('heart') + '</button>' +
          '<button class="btn sec" id="dQR" aria-label="QR">' + ico('qr') + '</button>' + (d.logueado ? '<button class="btn sec" id="dDen" aria-label="Denunciar">' + ico('flag') + '</button>' : '')) + '</div>';
    U.ponerIconos(V);
    g.Mapa.mini($('mm'), d.lat, d.lng, true);
    const url = U.enlace('#/e/' + d.id);
    $('dQR').onclick = () => U.mostrarQR(d.titulo, 'Escanea para ver este estacionamiento en Estaciona', url, Api.puede('qr_color') ? Api.cuenta.color : '#000');
    if (d.mio) {
      $('dEstado').onchange = async (e) => { try { await Api.rpc('estado_estacionamiento', { p_id: d.id, p_estado: e.target.value }); toast('Estado actualizado'); g.Mapa.recargar(); } catch (er) { fallo(er); } };
      return;
    }
    const conSesion = (fn, motivo) => () => (Api.logueado() ? fn() : (destino = '#/e/' + d.id, pedirLogin(motivo)));
    if ($('dSol')) $('dSol').onclick = conSesion(() => reservar(d), 'Crea tu cuenta para reservar');
    $('dChat').onclick = conSesion(() => contactar(d.dueno.id), 'Crea tu cuenta para contactar al dueño');
    $('dFav').onclick = conSesion(async () => {
      try { const si = await Api.rpc('favorito', { p_id: d.id }); $('dFav').style.color = si ? '#e11d48' : ''; toast(si ? 'Guardado en favoritos ❤️' : 'Quitado de favoritos'); }
      catch (e) { fallo(e); }
    }, 'Crea tu cuenta para guardar favoritos');
    if ($('dDen')) $('dDen').onclick = () => denunciar('estacionamiento', d.id, d.titulo);
  }

  // Reservar: modalidad, desde cuándo y por cuánto tiempo. Queda apartado mientras se paga.
  async function reservar(d) {
    await Api.ajustes();
    const ops = [['hora', d.ph, 'horas', 24], ['dia', d.pd, 'días', 31], ['mes', d.pm, 'meses', 12]].filter((x) => x[1]);
    const ahora = new Date(); ahora.setMinutes(0, 0, 0); ahora.setHours(ahora.getHours() + 1);
    const local = (dt) => { const x = new Date(dt); x.setMinutes(x.getMinutes() - x.getTimezoneOffset()); return x.toISOString().slice(0, 16); };
    const mins = (Api._aj.reglas || {}).minutos_pago || 30;
    const c = modal('<h2>📅 Reservar</h2><p class="muted small">' + esc(d.titulo) + '</p>' +
      '<label>¿Cómo quieres arrendar?</label><div class="seg" id="rMod">' + ops.map((o, i) => '<button type="button" data-m="' + o[0] + '" class="' + (i === 0 ? 'on' : '') + '">' + MODAL[o[0]] + '<br><b>' + clp(o[1]) + '</b></button>').join('') + '</div>' +
      '<div class="grid2"><div><label>Desde</label><input type="datetime-local" id="rIni" value="' + local(ahora) + '" min="' + local(new Date()) + '"></div>' +
      '<div><label id="rCantL">Cantidad</label><input type="number" id="rCant" inputmode="numeric" min="1" value="1"></div></div>' +
      '<div class="card" style="margin-top:12px"><div class="row between"><span>Total</span><b id="rTot" style="font-size:20px"></b></div><div class="small muted" id="rHasta"></div></div>' +
      '<label>Mensaje para el dueño (opcional)</label><textarea id="rNota" maxlength="300" placeholder="Ej: auto mediano, llego a las 8:00"></textarea>' +
      '<p class="small muted">⏳ Al reservar, el estacionamiento queda <b>apartado ' + mins + ' minutos</b> para que pagues y subas el comprobante.</p>' +
      '<button class="btn block" id="rOk">Reservar y pagar</button>');
    let mod = ops[0];
    const calc = () => {
      const n = Math.max(1, Math.min(mod[3], +c.querySelector('#rCant').value || 1));
      c.querySelector('#rCantL').textContent = 'Cantidad de ' + mod[2] + ' (máx. ' + mod[3] + ')';
      c.querySelector('#rTot').textContent = clp(mod[1] * n);
      const ini = new Date(c.querySelector('#rIni').value);
      if (!isNaN(ini)) {
        const fin = new Date(ini);
        if (mod[0] === 'hora') fin.setHours(fin.getHours() + n); else if (mod[0] === 'dia') fin.setDate(fin.getDate() + n); else fin.setMonth(fin.getMonth() + n);
        c.querySelector('#rHasta').textContent = 'Hasta ' + fh(fin);
      }
    };
    c.querySelector('#rMod').onclick = (e) => {
      const b = e.target.closest('[data-m]'); if (!b) return;
      c.querySelectorAll('#rMod button').forEach((x) => x.classList.toggle('on', x === b));
      mod = ops.find((o) => o[0] === b.dataset.m); calc();
    };
    c.querySelector('#rCant').oninput = calc; c.querySelector('#rIni').oninput = calc; calc();
    c.querySelector('#rOk').onclick = async (e) => {
      const ini = new Date(c.querySelector('#rIni').value);
      if (isNaN(ini)) { toast('Elige la fecha y hora'); return; }
      e.target.disabled = true;
      try {
        const id = await Api.rpc('solicitar_arriendo', { p_id: d.id, p_modalidad: mod[0], p_inicio: ini.toISOString(),
          p_cantidad: Math.max(1, +c.querySelector('#rCant').value || 1), p_nota: c.querySelector('#rNota').value });
        Api.empujar(); cerrarModal(); toast('¡Reservado! Ahora paga y sube el comprobante'); location.hash = '#/r/' + id; Api.refrescar();
      } catch (er) { e.target.disabled = false; cerrarModal(); fallo(er); }
    };
  }

  /* ======================= Una reserva ======================= */
  async function vReserva(id) {
    cargando();
    await Api.ajustes();
    let x;
    try { x = (await Api.rpc('mis_arriendos')).find((r) => r.id === id); } catch (e) { V.innerHTML = volver() + '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    if (!x) { V.innerHTML = volver() + '<div class="vacio">Reserva no encontrada</div>'; return; }
    const dueno = x.soy_dueno, e = x.est, o = x.otro, r = Api._aj.reglas || {};
    const pagado = x.monto_pagar + x.saldo_aplicado;
    const b = [];
    if (!dueno && x.estado === 'por_pagar') {
      b.push('<div class="aviso warn" style="margin-top:12px">⏳ Apartado por <b id="rReloj">' + quedan(x.expira_at) + '</b> minutos. ' + esc(Api.texto('reserva_pago', '')) + '</div>' +
        (x.pago && x.pago.url ? '<a class="btn block gold" style="margin-top:10px" target="_blank" rel="noopener" href="' + esc(x.pago.url) + '">💳 Pagar ' + clp(x.monto_pagar) + '</a>' + (x.pago.texto ? '<p class="small muted">' + esc(x.pago.texto) + '</p>' : '')
          : '<p class="small">El dueño aún no configura su link de pago: coordina el pago por el chat y sube el comprobante.</p>') +
        '<label>Foto del comprobante</label><input type="file" id="rComp" accept="image/*"><button class="btn block" id="rSubir" style="margin-top:10px">📤 Subir comprobante</button>');
    }
    if (!dueno && x.estado === 'en_revision') b.push('<div class="aviso" style="margin-top:12px">🧾 El dueño está revisando tu comprobante. Te avisaremos apenas responda.</div>');
    if (dueno && ['en_revision', 'pendiente'].includes(x.estado)) {
      b.push('<div class="card" style="margin-top:12px"><b>🧾 Comprobante</b>' + (x.comprobante ? '<img class="ver-img" id="rImg" alt="Comprobante" style="margin-top:8px">' : '<p class="small muted">Sin comprobante (se usó saldo a favor o es una solicitud antigua).</p>') +
        '<div class="row" style="margin-top:10px"><button class="btn ok grow" id="rAprobar">✅ Aprobar</button><button class="btn bad grow" id="rRechazar">Rechazar</button></div></div>');
    }
    if (dueno && x.estado === 'por_pagar') b.push('<div class="aviso warn" style="margin-top:12px">⏳ Esperando que pague. Se libera sola en <b id="rReloj">' + quedan(x.expira_at) + '</b> min si no sube el comprobante.</div>');
    if (x.pago_estado === 'devolver') b.push('<div class="aviso bad" style="margin-top:12px">💸 Hay que devolver ' + clp(pagado) + '.' + (dueno ? ' <button class="btn small" id="rDevuelto" style="margin-left:6px">Marcar devuelto</button>' : ' El dueño debe devolvértelo.') + '</div>');
    if (x.pago_estado === 'saldo') b.push('<div class="aviso" style="margin-top:12px">💰 Saldo a favor de ' + clp(x.saldo_monto) + ' con este dueño hasta el ' + fecha(x.saldo_hasta) + '. Se descuenta solo en tu próxima reserva con él.</div>');
    if (x.motivo) b.push('<p class="small"><b>Motivo:</b> ' + esc(x.motivo) + '</p>');
    const acc = [];
    if (['pendiente', 'por_pagar', 'en_revision', 'aceptado'].includes(x.estado)) acc.push('<button class="btn line grow" id="rCancelar">Cancelar reserva</button>');
    if (x.estado === 'aceptado') acc.push('<button class="btn grow" id="rFin">Finalizar</button>');
    if (x.estado === 'finalizado' && !x.calificado) acc.push('<button class="btn gold grow" id="rCalif">⭐ Calificar</button>');
    V.innerHTML = volver('Reservas') +
      '<div class="card"><div class="row">' + imgMini(e.foto, 'thumb sm') + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">📍 ' + esc(e.direccion) + (e.comuna ? ', ' + esc(e.comuna) : '') + '</div></div></div>' +
      '<div class="row" style="margin-top:10px"><a class="btn small sec" href="#/e/' + e.id + '">Ver ficha</a><a class="btn small sec" target="_blank" rel="noopener" href="https://www.google.com/maps/dir/?api=1&destination=' + e.lat + ',' + e.lng + '">🧭 Cómo llegar</a></div></div>' +
      '<div class="card"><div class="row between"><b>' + (dueno ? 'Reserva recibida' : 'Tu reserva') + '</b>' + pill(ESTADO_ARR[x.estado] || ['', x.estado]) + '</div>' +
      '<table class="tabla" style="margin-top:8px"><tr><td>Desde</td><td>' + esc(fh(x.inicio)) + '</td></tr><tr><td>Hasta</td><td>' + esc(fh(x.fin)) + '</td></tr>' +
      '<tr><td>Modalidad</td><td>' + MODAL[x.modalidad] + ' × ' + x.cantidad + '</td></tr><tr><td>Total</td><td><b>' + clp(x.total) + '</b></td></tr>' +
      (x.saldo_aplicado ? '<tr><td>Saldo a favor usado</td><td>−' + clp(x.saldo_aplicado) + '</td></tr>' : '') +
      '<tr><td>' + (x.monto_pagar < x.total - x.saldo_aplicado ? 'Abono para confirmar' : 'A pagar') + '</td><td><b>' + clp(x.monto_pagar) + '</b></td></tr></table>' +
      (x.nota ? '<p class="small" style="background:var(--card2);padding:8px 10px;border-radius:10px">“' + esc(x.nota) + '”</p>' : '') + b.join('') + '</div>' +
      '<div class="card"><a class="row" href="#/u/' + o.id + '" style="color:var(--ink)">' + avatar(o) + '<div class="grow"><b>' + nombreCon(o) + '</b><div class="small">' + estrellas(o.calif) + '</div></div></a>' +
      '<div class="row" style="margin-top:10px"><button class="btn sec grow" id="rChat">' + ico('chat') + ' Chat</button>' +
      (x.whatsapp ? '<a class="btn sec grow" target="_blank" rel="noopener" href="https://wa.me/' + esc(x.whatsapp.replace(/\D/g, '')) + '">📲 WhatsApp</a>' : '') + '</div></div>' +
      (!dueno && ['por_pagar', 'en_revision', 'aceptado'].includes(x.estado) ? '<p class="small muted">' + esc(Api.texto('reserva_politica', '')) + '</p>' : '') +
      (acc.length ? '<div class="row">' + acc.join('') + '</div>' : '');
    U.ponerIconos(V);
    if ($('rImg')) U.urlPrivada(x.comprobante).then((u) => { $('rImg').src = u; $('rImg').onclick = () => window.open(u, '_blank'); });
    const recargar = () => { Api.empujar(); contadores(); vReserva(id); };
    const hacer = async (fn, msg) => { try { await fn(); if (msg) toast(msg); recargar(); } catch (er) { fallo(er); } };
    $('rChat').onclick = () => contactar(o.id);
    if ($('rReloj')) pollChat = setInterval(() => {
      if (!$('rReloj')) return;
      $('rReloj').textContent = quedan(x.expira_at);
      if (new Date(x.expira_at) < Date.now()) { clearInterval(pollChat); vReserva(id); }
    }, 1000);
    if ($('rSubir')) $('rSubir').onclick = async (ev) => {
      const f = $('rComp').files[0]; if (!f) { toast('Elige la foto del comprobante'); return; }
      ev.target.disabled = true; ev.target.textContent = 'Subiendo…';
      try { const ruta = await U.subirFoto(f, 'privado', U.FOTO('comprobante')); await Api.rpc('subir_comprobante', { p_id: id, p_ruta: ruta }); toast('¡Comprobante enviado! 🧾'); recargar(); }
      catch (er) { ev.target.disabled = false; ev.target.textContent = '📤 Subir comprobante'; fallo(er); }
    };
    if ($('rAprobar')) $('rAprobar').onclick = () => hacer(() => Api.rpc('responder_arriendo', { p_id: id, p_aceptar: true, p_motivo: null }), 'Reserva confirmada ✅');
    if ($('rRechazar')) $('rRechazar').onclick = async () => {
      const m = await U.pedirTexto('Motivo del rechazo', 'Ej: no recibí el pago / el comprobante no corresponde', 'Rechazar');
      if (m != null) hacer(() => Api.rpc('responder_arriendo', { p_id: id, p_aceptar: false, p_motivo: m }), 'Reserva rechazada');
    };
    if ($('rDevuelto')) $('rDevuelto').onclick = () => hacer(() => Api.rpc('cerrar_arriendo', { p_id: id, p_accion: 'devuelto' }), 'Marcado como devuelto');
    if ($('rFin')) $('rFin').onclick = async () => { if (await confirmar('¿Marcar este arriendo como finalizado?', 'Finalizar')) hacer(() => Api.rpc('cerrar_arriendo', { p_id: id, p_accion: 'finalizar' }), 'Finalizado. ¡Califica! ⭐'); };
    if ($('rCalif')) $('rCalif').onclick = () => calificar(id, o.nombre, () => vReserva(id));
    if ($('rCancelar')) $('rCancelar').onclick = async () => {
      let txt = '¿Cancelar esta reserva?';
      if (!dueno && ['en_revision', 'aceptado'].includes(x.estado) && pagado > 0) {
        const min = (Date.now() - new Date(x.creado)) / 60000, hrs = (new Date(x.inicio) - Date.now()) / 3600000;
        txt += min <= r.minutos_devolucion ? ' Se te devuelve lo pagado.' : hrs >= r.horas_cancelacion ? ' Lo pagado queda como saldo a favor.' : ' Con tan poca anticipación pierdes lo pagado.';
      } else if (dueno && pagado > 0 && ['en_revision', 'aceptado'].includes(x.estado)) txt += ' Deberás devolver lo pagado.';
      if (await confirmar(txt, 'Sí, cancelar', true)) hacer(() => Api.rpc('cerrar_arriendo', { p_id: id, p_accion: 'cancelar' }), 'Reserva cancelada');
    };
  }

  /* ======================= Reservas (dueño y arrendatario) ======================= */
  const FILTROS = [['revisar', '🧾 Por revisar'], ['proximas', '📅 Próximas'], ['pagando', '⏳ Esperando pago'], ['devolver', '💸 Por devolver'], ['mias', '🚗 Mis arriendos'], ['historial', '📚 Historial']];
  const ACTIVAS = ['pendiente', 'por_pagar', 'en_revision', 'aceptado'];
  function filtrar(l, f) {
    if (f === 'revisar') return l.filter((x) => x.soy_dueno && ['en_revision', 'pendiente'].includes(x.estado));
    if (f === 'proximas') return l.filter((x) => x.estado === 'aceptado').sort((a, b) => new Date(a.inicio) - new Date(b.inicio));
    if (f === 'pagando') return l.filter((x) => x.estado === 'por_pagar');
    if (f === 'devolver') return l.filter((x) => x.pago_estado === 'devolver');
    if (f === 'mias') return l.filter((x) => !x.soy_dueno && ACTIVAS.includes(x.estado));
    return l.filter((x) => !ACTIVAS.includes(x.estado));
  }
  function tarjetaArriendo(x) {
    return '<a class="card" style="display:block;margin-top:10px;color:var(--ink)" href="#/r/' + x.id + '"><div class="row">' + imgMini(x.est.foto, 'thumb sm') +
      '<div class="grow"><b class="ell" style="display:block">' + esc(x.est.titulo) + '</b><div class="small muted">' + esc(fh(x.inicio)) + ' · ' + MODAL[x.modalidad] + ' × ' + x.cantidad + '</div>' +
      '<div class="small">' + (x.soy_dueno ? '👤 ' + esc(x.otro.nombre) : '🅿️ ' + esc(x.otro.nombre)) + ' · ' + clp(x.total) + '</div></div>' +
      '<div style="text-align:right">' + pill(ESTADO_ARR[x.estado] || ['', x.estado]) + (PAGO[x.pago_estado] ? '<div style="margin-top:4px">' + pill(PAGO[x.pago_estado]) + '</div>' : '') + '</div></div></a>';
  }
  async function vReservas(f) {
    V.innerHTML = '<h1>Reservas</h1><div id="rsC"><div class="spin"></div></div>';
    let l, p;
    try { [l, p] = await Promise.all([Api.rpc('mis_arriendos'), Api.rpc('panel')]); } catch (e) { $('rsC').innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    f = f || (p.revisar ? 'revisar' : filtrar(l, 'mias').length ? 'mias' : 'proximas');
    // Quien solo arrienda ve solo "verifica tu identidad"; WhatsApp, link de pago y publicar son de quien publica. El admin no ve nada.
    const dueno = !!(Api.cuenta && Api.cuenta.uso && Api.cuenta.uso.publicados > 0);
    const falta = Api.admin() ? [] : [p.falta.verificar && ['#/verificar', '🪪 Verifica tu identidad'], dueno && p.falta.whatsapp && ['#/mas/perfil', '📲 Agrega tu WhatsApp'],
      dueno && p.falta.link && ['#/mas/links', '💳 Configura tu link de pago']].filter(Boolean);
    const lista = filtrar(l, f);
    $('rsC').innerHTML = '<div class="kpis">' + [['revisar', '🧾 Por revisar', p.revisar], ['proximas', '📅 Hoy', p.hoy], ['pagando', '⏳ Esperando pago', p.pagando], ['devolver', '💸 Por devolver', p.devolver]]
      .map((k) => '<a class="kpi" href="#/reservas/' + k[0] + '" style="color:var(--ink)"><b>' + k[2] + '</b><small class="t">' + k[1] + '</small></a>').join('') + '</div>' +
      (falta.length ? '<div class="card" style="margin-top:12px"><b>✅ Lo que te falta configurar</b>' + falta.map((x) => '<a class="row" style="margin-top:8px" href="' + x[0] + '">' + x[1] + ' →</a>').join('') + '</div>' : '') +
      '<div class="seg" style="margin-top:14px">' + FILTROS.map((t) => '<a href="#/reservas/' + t[0] + '" class="' + (t[0] === f ? 'on' : '') + '">' + t[1] + ' <small>' + filtrar(l, t[0]).length + '</small></a>').join('') + '</div>' +
      (lista.length ? lista.map(tarjetaArriendo).join('') : '<div class="vacio">' + ico('car') + '<p>' + (f === 'mias' ? 'Aún no arriendas. Busca en el mapa y reserva.' : 'Nada por aquí.') + '</p>' + (f === 'mias' ? '<a class="btn" href="#/">Ir al mapa</a>' : '') + '</div>');
    U.ponerIconos($('rsC'));
    U.centrarSeg($('rsC'));
    pedirCalificacion(l);
  }
  // Un arriendo que terminó (solo o a mano) pide calificar una vez, al abrir Reservas.
  function pedirCalificacion(l) {
    const x = l.find((r) => r.estado === 'finalizado' && !r.calificado && Date.now() - new Date(r.fin) < 14 * 864e5);
    if (!x) return;
    const k = 'est:calif:' + x.id;
    try { if (localStorage.getItem(k)) return; localStorage.setItem(k, '1'); } catch (e) { return; }
    calificar(x.id, x.otro.nombre, () => vReservas());
  }
  async function contactar(uid) {
    try { const id = await Api.rpc('abrir_conversacion', { p_con: uid }); location.hash = '#/chat/' + id; } catch (e) { fallo(e); }
  }

  /* ======================= Denuncias (con evidencia obligatoria) ======================= */
  function denunciar(tipo, objetivo, nombre) {
    const c = modal('<h2>' + ico('flag') + ' Denunciar</h2><p class="muted small">' + esc(nombre || '') + '</p>' +
      '<label>Motivo</label><select id="dMot">' + ['Estafa o intento de estafa', 'Suplantación / datos falsos', 'El estacionamiento no existe o no corresponde', 'Cobro indebido', 'Acoso o lenguaje ofensivo', 'Otro'].map((m) => '<option>' + m + '</option>').join('') + '</select>' +
      '<label>¿Qué pasó?</label><textarea id="dDet" maxlength="800" placeholder="Cuenta con detalle lo que ocurrió, fechas y montos si corresponde."></textarea>' +
      '<label>Evidencia (obligatoria)</label><input type="file" id="dEv" accept="image/*"><div class="hint">Pantallazo de la conversación, comprobante o foto. Solo la ve el administrador.</div>' +
      '<label class="check"><input type="checkbox" id="dDecl"> <span class="small">Declaro que la información es verdadera. Una denuncia falsa puede significar la suspensión de mi cuenta.</span></label>' +
      '<button class="btn bad block" id="dOk">Enviar denuncia</button>');
    c.querySelector('#dOk').onclick = async (e) => {
      const f = c.querySelector('#dEv').files[0];
      if (!f) { toast('Adjunta una evidencia'); return; }
      if (!c.querySelector('#dDecl').checked) { toast('Marca la declaración'); return; }
      e.target.disabled = true; e.target.textContent = 'Enviando…';
      try {
        const ev = await U.subirFoto(f, 'privado', { lado: 1600, calidad: 0.75 });
        await Api.rpc('denunciar', { p_tipo: tipo, p_objetivo: objetivo, p_motivo: c.querySelector('#dMot').value, p_detalle: c.querySelector('#dDet').value, p_evidencia: ev });
        Api.empujar(); cerrarModal(); toast('Denuncia enviada. El administrador la revisará 🙏');
      } catch (er) { e.target.disabled = false; e.target.textContent = 'Enviar denuncia'; toast(er.message); }
    };
  }

  /* ======================= Perfil público ======================= */
  async function vPerfil(id) {
    cargando();
    let p;
    try { p = await Api.rpc('perfil_publico', { p_id: id }); } catch (e) { V.innerHTML = volver() + '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    const mio = id === Api.uid();
    V.innerHTML = volver() + '<div class="card center">' + '<div style="display:flex;justify-content:center">' + avatar(p, 'lg') + '</div>' +
      '<h1 style="margin-top:10px">' + nombreCon(p) + '</h1><div class="muted small">' + esc(p.comuna || '') + (p.comuna ? ' · ' : '') + 'En Estaciona desde ' + fecha(p.desde) + '</div>' +
      '<div style="margin:8px 0">' + estrellas(p.calif) + (p.calif_n ? ' <span class="muted small">(' + p.calif_n + ' opiniones)</span>' : '') + '</div>' +
      (p.bio ? '<p>' + esc(p.bio) + '</p>' : '') + (p.verificado ? '<span class="pill ok">' + ico('shield') + ' Identidad verificada</span>' : '<span class="pill warn">Sin verificar</span>') +
      '<div class="row" style="margin-top:14px;justify-content:center">' + (mio ? '<a class="btn" href="#/mas/perfil">Editar mi perfil</a>'
        : '<button class="btn" id="pChat">' + ico('chat') + ' Contactar</button><button class="btn sec" id="pBlq">' + ico('ban') + ' ' + (p.bloqueado ? 'Desbloquear' : 'Bloquear') + '</button><button class="btn sec" id="pDen" aria-label="Denunciar">' + ico('flag') + '</button>') +
      '<button class="btn sec" id="pQR" aria-label="QR">' + ico('qr') + '</button></div></div>' +
      '<div class="sec-tit">Estacionamientos (' + p.estacionamientos.length + ')</div>' +
      (p.estacionamientos.length ? p.estacionamientos.map((e) => '<a class="item" href="#/e/' + e.id + '">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div></div></a>').join('') : '<div class="vacio">Aún no publica estacionamientos</div>');
    U.ponerIconos(V);
    $('pQR').onclick = () => U.mostrarQR(p.nombre, 'Perfil en Estaciona', U.enlace('#/u/' + p.id), p.premium ? p.color : '#000');
    if (mio) return;
    $('pChat').onclick = () => contactar(p.id);
    $('pDen').onclick = () => denunciar('usuario', p.id, p.nombre);
    $('pBlq').onclick = async () => {
      if (!p.bloqueado && !await confirmar('¿Bloquear a ' + p.nombre + '? No podrán escribirse ni arrendarse entre ustedes.', 'Bloquear', true)) return;
      try { await Api.rpc('bloquear', { p_usuario: p.id, p_si: !p.bloqueado }); toast(p.bloqueado ? 'Desbloqueado' : 'Bloqueado'); vPerfil(id); } catch (e) { fallo(e); }
    };
  }

  /* ======================= Publicar / editar ======================= */
  async function vPublicar(id) {
    cargando();
    await Api.refrescar();
    const a = Api.cuenta;
    if (!a.verificado) {
      V.innerHTML = '<h1>Publicar estacionamiento</h1><div class="card center"><div style="font-size:48px">🪪</div><h2>Primero verifica tu identidad</h2>' +
        '<p class="muted">Para evitar estafas, solo las personas verificadas pueden publicar. ' + (a.verif_estado === 'pendiente' ? '<b>Tu verificación está en revisión.</b>' : 'Toma 2 minutos.') + '</p>' +
        (a.verif_estado === 'pendiente' ? '' : '<a class="btn block" href="#/verificar">Verificar ahora</a>') + '</div>';
      return;
    }
    // Núcleo (pagos.js): cuenta nueva que aún no hace su primer pago → lo pide antes de publicar el primero.
    if (!id && !a.admin && !a.uso.publicados && window.CFX_PAGOS) {
      const ex = await CFX_PAGOS.revisar({ rpc: (f, x) => Api.rpc(f, x), comoNegocio: true, salirTexto: 'Volver', salir: () => { location.hash = '#/'; } });
      if (ex && ex.debe_inicio) { V.innerHTML = '<h1>Publicar estacionamiento</h1><div class="card center"><div style="font-size:48px">🚀</div><h2>Activa tu cuenta para publicar</h2>' +
        '<p class="muted">Con tu primer pago publicas y tienes Premium por ' + ((ex.config.negocio || {}).inicio_dias || 30) + ' días.</p><button class="btn block" id="pubAct">Activar</button></div>';
        $('pubAct').onclick = () => CFX_PAGOS.abrir({ rpc: (f, x) => Api.rpc(f, x), comoNegocio: true, salirTexto: 'Volver', salir: () => { location.hash = '#/'; } }); return; }
    }
    let e = { fotos: [], vehiculo: 'auto' };
    if (id) {
      cargando();
      try { e = await Api.rpc('estacionamiento_detalle', { p_id: id }); } catch (er) { V.innerHTML = '<div class="vacio">' + esc(er.message) + '</div>'; return; }
      if (!e.mio) { location.hash = '#/e/' + id; return; }
    } else if (a.uso.publicados >= a.lim.publicar) {
      V.innerHTML = '<h1>Publicar estacionamiento</h1><div class="card center"><div style="font-size:48px">⭐</div><h2>Llegaste al límite de tu plan</h2>' +
        '<p class="muted">Con el plan Gratis puedes publicar ' + a.lim.publicar + ' estacionamiento. Con <b>Premium</b> publicas más, con pin dorado destacado y estadísticas.</p>' +
        '<a class="btn gold block" href="#/premium">Hazte Premium</a><a class="btn line block" style="margin-top:8px" href="#/mis/publicados">Ver mis estacionamientos</a></div>';
      return;
    }
    const st = { lat: id ? e.lat : null, lng: id ? e.lng : null, fotos: (e.fotos || []).map((r) => ({ ruta: r })) };
    const lim = a.lim.fotos;
    V.innerHTML = volver() + '<h1>' + (id ? 'Editar estacionamiento' : 'Publicar estacionamiento') + '</h1>' +
      '<form id="fPub"><div class="sec-tit">Fotos (hasta ' + lim + ')</div><div class="fotos-ed" id="pFotos"></div>' +
      (lim < 8 ? '<div class="hint">⭐ Con Premium puedes subir hasta 8 fotos.</div>' : '') + '<input type="file" id="pFile" accept="image/*" multiple hidden>' +
      '<label>Título</label><input id="pTit" maxlength="60" required placeholder="Ej: Estacionamiento techado cerca del metro Los Leones" value="' + esc(e.titulo || '') + '">' +
      '<label>Descripción</label><textarea id="pDesc" maxlength="600" placeholder="Medidas, cómo se accede, horarios, reglas del edificio…">' + esc(e.descripcion || '') + '</textarea>' +
      '<div class="sec-tit">Ubicación</div><div class="row"><input id="pBus" placeholder="Busca la dirección" class="grow"><button type="button" class="btn sec" id="pBusB">' + ico('search') + '</button></div>' +
      '<div class="resultados-busqueda" id="pRes" hidden></div>' +
      '<p class="hint">Toca el mapa o arrastra el pin hasta la entrada exacta. En el mapa público se muestra una ubicación aproximada.</p>' +
      '<div class="mini-mapa alto" id="pMapa"></div><button type="button" class="btn line small" id="pYo" style="margin-top:8px">' + ico('locate') + ' Usar mi ubicación</button>' +
      '<label>Dirección exacta (solo la ve quien arrienda)</label><input id="pDir" maxlength="140" required placeholder="Calle, número, depto/torre" value="' + esc(e.direccion || '') + '">' +
      '<label>Comuna</label><input id="pCom" maxlength="40" placeholder="Ej: Providencia" value="' + esc(e.comuna || '') + '">' +
      '<div class="sec-tit">Precios (deja vacío lo que no ofreces)</div><div class="grid3">' +
      '<div><label>Por hora</label><input id="pPh" type="number" inputmode="numeric" min="0" step="100" value="' + (e.ph || '') + '"></div>' +
      '<div><label>Por día</label><input id="pPd" type="number" inputmode="numeric" min="0" step="500" value="' + (e.pd || '') + '"></div>' +
      '<div><label>Mensual</label><input id="pPm" type="number" inputmode="numeric" min="0" step="1000" value="' + (e.pm || '') + '"></div></div>' +
      '<div class="sec-tit">Características</div><label>Vehículo máximo</label><select id="pVeh"><option value="moto">Moto</option><option value="auto">Auto</option><option value="camioneta">Camioneta / SUV grande</option></select>' +
      '<label class="check"><input type="checkbox" id="pT"' + (e.techado ? ' checked' : '') + '> 🏠 Techado</label><label class="check"><input type="checkbox" id="pH"' + (e.acceso24 ? ' checked' : '') + '> 🕐 Acceso 24 horas</label>' +
      '<label class="check"><input type="checkbox" id="pS"' + (e.seguridad ? ' checked' : '') + '> 🛡️ Seguridad / conserjería</label><label class="check"><input type="checkbox" id="pC"' + (e.carga ? ' checked' : '') + '> ⚡ Carga para auto eléctrico</label>' +
      (id ? '' : '<label class="check"><input type="checkbox" id="pDecl" required> <span class="small">Declaro que el estacionamiento es mío o tengo autorización para arrendarlo, y que la información es verdadera.</span></label>') +
      '<button class="btn block" id="pOk" style="margin-top:16px">' + (id ? 'Guardar cambios' : 'Publicar') + '</button>' +
      (id ? '<button type="button" class="btn line block" id="pDel" style="margin-top:8px;color:var(--bad)">' + ico('trash') + ' Eliminar estacionamiento</button>' : '') + '</form>';
    U.ponerIconos(V);
    $('pVeh').value = e.vehiculo || 'auto';
    const pintarFotos = () => {
      $('pFotos').innerHTML = st.fotos.map((f, i) => '<div class="foto-ed"><img src="' + esc(f.url || U.urlMini(f.ruta)) + '" onerror="this.src=\'' + esc(f.ruta ? urlFoto(f.ruta) : '') + '\'" alt=""><button type="button" data-q="' + i + '" aria-label="Quitar">✕</button></div>').join('') +
        (st.fotos.length < lim ? '<div class="foto-ed foto-mas" id="pMas">' + ico('cam') + '<br>Agregar foto</div>' : '');
      U.ponerIconos($('pFotos'));
    };
    pintarFotos();
    $('pFotos').onclick = (ev) => {
      const q = ev.target.closest('[data-q]');
      if (q) { st.fotos.splice(+q.dataset.q, 1); pintarFotos(); return; }
      if (ev.target.closest('#pMas')) $('pFile').click();
    };
    $('pFile').onchange = () => {
      [...$('pFile').files].slice(0, lim - st.fotos.length).forEach((f) => st.fotos.push({ file: f, url: URL.createObjectURL(f) }));
      $('pFile').value = ''; pintarFotos();
    };
    const sel = g.Mapa.selector($('pMapa'), st.lat, st.lng, async (la, lo) => {
      st.lat = la; st.lng = lo;
      const r = await g.Mapa.inverso(la, lo);
      if (r.comuna) $('pCom').value = r.comuna;
      if (!$('pDir').value && r.direccion) $('pDir').value = r.direccion;
    });
    $('pYo').onclick = () => navigator.geolocation && navigator.geolocation.getCurrentPosition((p) => sel.mover(p.coords.latitude, p.coords.longitude), () => toast('No pudimos obtener tu ubicación'), { enableHighAccuracy: true });
    const buscarDir = async () => {
      const q = $('pBus').value.trim(); if (q.length < 3) return;
      try {
        const r = await g.Mapa.buscar(q);
        $('pRes').innerHTML = r.length ? r.map((x, i) => '<button type="button" data-i="' + i + '">' + esc(x.nombre) + '</button>').join('') : '<button type="button" disabled>Sin resultados</button>';
        $('pRes').hidden = false;
        $('pRes').onclick = (ev) => { const b = ev.target.closest('button[data-i]'); if (!b) return; const x = r[+b.dataset.i]; sel.mover(x.lat, x.lng); $('pRes').hidden = true; };
      } catch (er) { toast(er.message); }
    };
    $('pBusB').onclick = buscarDir;
    $('pBus').onkeydown = (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); buscarDir(); } };
    if ($('pDel')) $('pDel').onclick = async () => {
      if (!await confirmar('¿Eliminar este estacionamiento? También se borran sus fotos.', 'Eliminar', true)) return;
      try { await Api.rpc('borrar_estacionamiento', { p_id: id }); Api.empujar(); toast('Eliminado'); await Api.refrescar(); g.Mapa.recargar(); location.hash = '#/mis/publicados'; } catch (er) { fallo(er); }
    };
    $('fPub').onsubmit = async (ev) => {
      ev.preventDefault();
      if (!st.fotos.length) { toast('Sube al menos una foto'); return; }
      if (st.lat == null) { toast('Marca la ubicación en el mapa'); return; }
      if (!+$('pPh').value && !+$('pPd').value && !+$('pPm').value) { toast('Pon al menos un precio'); return; }
      const b = $('pOk'); b.disabled = true;
      try {
        const rutas = [];
        for (let i = 0; i < st.fotos.length; i++) {
          const f = st.fotos[i];
          if (f.ruta) { rutas.push(f.ruta); continue; }
          b.textContent = 'Subiendo foto ' + (i + 1) + ' de ' + st.fotos.length + '…';
          f.ruta = await U.subirFoto(f.file, 'fotos', Object.assign({}, U.FOTO('vitrina'), { conMini: true }));
          rutas.push(f.ruta);
        }
        b.textContent = 'Guardando…';
        const nid = await Api.rpc('guardar_estacionamiento', { p: {
          id: id || null, titulo: $('pTit').value, descripcion: $('pDesc').value, direccion: $('pDir').value, comuna: $('pCom').value,
          lat: st.lat, lng: st.lng, precio_hora: +$('pPh').value || 0, precio_dia: +$('pPd').value || 0, precio_mes: +$('pPm').value || 0,
          vehiculo: $('pVeh').value, techado: $('pT').checked, acceso24: $('pH').checked, seguridad: $('pS').checked, carga: $('pC').checked, fotos: rutas
        } });
        Api.empujar(); await Api.refrescar(); g.Mapa.recargar();
        toast(id ? 'Cambios guardados' : '¡Publicado! Ya aparece en el mapa 🎉');
        location.hash = '#/e/' + nid;
      } catch (er) { fallo(er); b.disabled = false; b.textContent = id ? 'Guardar cambios' : 'Publicar'; }
    };
  }

  /* ======================= Más (perfil, estacionamientos, links, plan…) ======================= */
  const SUBS = [['perfil', '👤 Perfil'], ['estacionamientos', '🚗 Mis estacionamientos'], ['links', '💳 Links de pago'], ['favoritos', '❤️ Favoritos'],
    ['plan', '⭐ Plan'], ['estadisticas', '📊 Estadísticas'], ['cuenta', '⚙️ Mi cuenta']];
  async function vMas(sub) {
    // El admin solo administra: de Más solo usa Mi cuenta (lo demás es de usuarios); el resto va a sus Ajustes.
    if (Api.admin() && sub !== 'cuenta') { location.replace('#/admin/ajustes'); return; }
    if (!sub) {  // Más: menú en cuadrícula; cada opción abre su sección (con la tira de secciones arriba)
      // Igual que BiciTaller: tarjetas con íconos de línea (los pone iconos.js), sin título; cada sección se abre sola con ← para volver.
      V.innerHTML = '<div class="cfx-grilla">' + SUBS.filter((t) => !(t[0] === 'plan' && Api.admin())).map((t) => '<a class="op" href="#/mas/' + t[0] + '">' + t[1].replace(/^(\S+)\s/, '<span style="font-size:24px">$1</span>') + '</a>').join('') + '</div>';
      return;
    }
    if (sub === 'plan' && Api.admin()) sub = 'cuenta';
    const st = SUBS.find((t) => t[0] === sub) || ['', 'Más'];
    V.innerHTML = '<div class="row" style="align-items:center;gap:8px;margin-bottom:12px"><a class="icon-btn" href="#/mas" aria-label="Volver" data-sin-atras>' + ico('back') + '</a><h2 style="margin:0">' + esc(st[1]) + '</h2></div><div id="masC"><div class="spin"></div></div>';
    U.ponerIconos(V);
    const T = $('masC');
    try {
      if (sub === 'perfil') return vEditarPerfil(T);
      if (sub === 'cuenta') return vCuenta(T);
      if (sub === 'plan') return vPremium(T);
      if (sub === 'links') return vLinks(T);
      if (sub === 'estadisticas') return vEstadisticas(T);
      if (sub === 'favoritos') return vFavoritos(T);
      return vPublicados(T);
    } catch (e) { T.innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; }
  }

  async function vPublicados(T) {
    const a = Api.cuenta, r = await Api.rpc('mis_estacionamientos');
    T.innerHTML = '<div class="row between"><span class="muted small">Usas ' + r.length + ' de ' + a.lim.publicar + ' publicaciones</span><a class="btn small" href="#/publicar">' + ico('plus') + ' Publicar</a></div>' +
      '<div class="barra"><i style="width:' + Math.min(100, r.length / Math.max(1, a.lim.publicar) * 100) + '%"></i></div>' +
      (!Api.puede('destacado') ? '<a class="aviso" style="display:block;margin:10px 0;color:var(--ink)" href="#/premium">⭐ <b>Premium:</b> publica más, pin dorado destacado y estadísticas.</a>' : '') +
      (r.length ? r.map((e) => '<div class="card" style="margin-top:10px"><a class="row" href="#/e/' + e.id + '" style="color:var(--ink)">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div>' +
          '<div style="margin-top:4px">' + pill(ESTADO_EST[e.estado]) + (!e.visible ? ' <span class="pill warn">No visible: supera tu plan</span>' : '') + '</div></div></a>' +
          (e.stats ? '<div class="row small muted" style="margin-top:8px;gap:14px">' + ico('eye') + ' ' + e.stats.vistas + ' visitas · ❤️ ' + e.stats.favoritos + ' · 📩 ' + e.stats.solicitudes + ' reservas</div>'
            : '<div class="small muted" style="margin-top:8px">📊 Estadísticas: <a href="#/premium">solo Premium</a></div>') +
          '<div class="row" style="margin-top:10px"><select data-est="' + e.id + '" class="grow"' + (e.estado === 'oculto' ? ' disabled' : '') + '>' + ['disponible', 'ocupado', 'pausado'].map((s) => '<option value="' + s + '"' + (e.estado === s ? ' selected' : '') + '>' + ESTADO_EST[s][1] + '</option>').join('') + '</select>' +
          '<a class="btn sec small" href="#/editar/' + e.id + '">' + ico('edit') + ' Editar</a></div></div>').join('')
        : '<div class="vacio">' + ico('car') + '<p>¿Tienes un estacionamiento sin usar? Publícalo y gana plata extra.</p><a class="btn" href="#/publicar">Publicar ahora</a></div>');
    U.ponerIconos(T);
    T.onchange = async (ev) => {
      const s = ev.target.closest('[data-est]'); if (!s) return;
      try { await Api.rpc('estado_estacionamiento', { p_id: s.dataset.est, p_estado: s.value }); toast('Estado actualizado'); g.Mapa.recargar(); } catch (er) { fallo(er); }
    };
  }

  async function vFavoritos(T) {
    const r = await Api.rpc('mis_favoritos'), a = Api.cuenta;
    T.innerHTML = '<p class="muted small">' + r.length + ' de ' + (a.lim.favoritos >= 500 ? 'ilimitados' : a.lim.favoritos) + ' favoritos</p>' +
      (r.length ? r.map((e) => '<a class="item" href="#/e/' + e.id + '">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div></div>' + (e.estado !== 'disponible' ? pill(ESTADO_EST[e.estado]) : '') + '</a>').join('')
        : '<div class="vacio">' + ico('heart') + '<p>Guarda estacionamientos con ❤️ para encontrarlos rápido.</p></div>');
    U.ponerIconos(T);
  }

  // 2 espacios de link de pago, uno activo. Lo que pagan tus arrendatarios llega directo a ti.
  async function vLinks(T) {
    const l = await Api.rpc('mis_links');
    T.innerHTML = '<div class="card"><b>💳 Tus links de pago</b><p class="small muted" style="margin:6px 0 0">Tus arrendatarios pagan con el link <b>activo</b> y suben el comprobante; tú apruebas. ' +
      'Tienes 2 espacios (por ejemplo Mercado Pago y transferencia) y eliges cuál se usa. Si pones un <b>abono</b>, se cobra solo eso para confirmar y el resto se paga al llegar. Solo tú ves estos datos.</p></div>' +
      l.map((s) => '<div class="card slotpago' + (s.activo ? ' on' : '') + '" data-slot="' + s.slot + '"><div class="row between"><b>Espacio ' + s.slot + '</b>' +
        '<label class="check" style="margin:0"><input type="radio" name="lkAct"' + (s.activo ? ' checked' : '') + '> Activo</label></div>' +
        '<label>Link de pago (Mercado Pago u otro)</label><input class="lkUrl" type="url" placeholder="https://mpago.la/…" value="' + esc(s.url) + '">' +
        '<label>Abono fijo para confirmar (opcional, $)</label><input class="lkMonto" type="number" inputmode="numeric" min="0" step="500" placeholder="Vacío = paga el total" value="' + (s.monto || '') + '">' +
        '<label>Texto o datos de transferencia (opcional)</label><textarea class="lkTxt" maxlength="300" placeholder="Ej: Banco Estado, cuenta RUT 12.345.678-9">' + esc(s.texto) + '</textarea>' +
        '<button class="btn block lkOk" style="margin-top:10px">Guardar espacio ' + s.slot + '</button></div>').join('');
    T.onclick = async (ev) => {
      const b = ev.target.closest('.lkOk'); if (!b) return;
      const c = b.closest('[data-slot]');
      try {
        await Api.rpc('guardar_link', { p_slot: +c.dataset.slot, p_monto: +c.querySelector('.lkMonto').value || 0, p_url: c.querySelector('.lkUrl').value,
          p_texto: c.querySelector('.lkTxt').value, p_activo: c.querySelector('input[type=radio]').checked });
        toast('Guardado'); Api.refrescar(); vLinks(T);
      } catch (er) { fallo(er); }
    };
  }

  async function vEstadisticas(T) {
    if (!Api.puede('estadisticas')) {
      T.innerHTML = '<div class="card center"><div style="font-size:44px">📊</div><h2>Estadísticas Premium</h2><p class="muted">Visitas, reservas e ingresos por mes de tus estacionamientos.</p><a class="btn gold" href="#/premium">Ver Premium</a></div>';
      return;
    }
    const s = await Api.rpc('mis_estadisticas');
    const max = Math.max(1, ...s.meses.map((m) => m.ingresos));
    T.innerHTML = '<div class="kpis">' + [['Visitas', s.vistas], ['Favoritos', s.favoritos], ['Reservas (6 meses)', s.meses.reduce((t, m) => t + m.reservas, 0)], ['Canceladas', s.canceladas]]
      .map((k) => '<div class="kpi"><b>' + k[1] + '</b><small>' + k[0] + '</small></div>').join('') + '</div>' +
      '<div class="card" style="margin-top:12px"><b>Ingresos por mes</b><div class="barras" style="margin-top:12px">' + s.meses.map((m) => '<div title="' + esc(m.mes) + ': ' + clp(m.ingresos) + '" style="height:' + Math.max(2, m.ingresos / max * 100) + '%"></div>').join('') + '</div>' +
      '<div class="row between small muted">' + s.meses.map((m) => '<span>' + esc(m.mes) + '</span>').join('') + '</div>' +
      '<table class="tabla" style="margin-top:10px">' + s.meses.map((m) => '<tr><td>' + esc(m.mes) + '</td><td>' + m.reservas + ' reservas</td><td><b>' + clp(m.ingresos) + '</b></td></tr>').join('') + '</table></div>';
  }
  function calificar(id, nombre, tab) {
    let n = 5;
    const c = modal('<div class="center"><h2>¿Cómo te fue con ' + esc(nombre) + '?</h2><div id="cEst" style="font-size:40px;letter-spacing:6px;cursor:pointer;color:var(--gold)">★★★★★</div></div>' +
      '<label>Comentario (opcional)</label><textarea id="cCom" maxlength="200" placeholder="Cuenta tu experiencia"></textarea><button class="btn block" style="margin-top:12px" id="cOk">Enviar calificación</button>');
    const pintar = () => { c.querySelector('#cEst').innerHTML = '★'.repeat(n) + '<span style="color:var(--line)">' + '★'.repeat(5 - n) + '</span>'; };
    c.querySelector('#cEst').onclick = (e) => { const r = e.currentTarget.getBoundingClientRect(); n = Math.min(5, Math.max(1, Math.ceil((e.clientX - r.left) / r.width * 5))); pintar(); };
    c.querySelector('#cOk').onclick = async () => {
      try { await Api.rpc('calificar', { p_arriendo: id, p_estrellas: n, p_comentario: c.querySelector('#cCom').value }); cerrarModal(); toast('¡Gracias por calificar!'); if (typeof tab === 'function') tab(); else vReservas(); } catch (e) { toast(e.message); }
    };
  }

  /* ======================= Chat ======================= */
  async function vChats() {
    V.innerHTML = '<h1>Chat</h1><div id="chC"><div class="spin"></div></div>';
    try {
      const r = await Api.rpc('mis_conversaciones');
      $('chC').innerHTML = (!Api.admin() ? '<button class="item" id="chSop" style="width:100%;text-align:left;cursor:pointer;font:inherit"><span class="av" style="--c:#0b1020">🛟</span><div class="grow"><b>Soporte Estaciona</b><div class="small muted">¿Algún problema? Escríbenos aquí</div></div></button><div class="sec-tit">Conversaciones</div>' : '') +
        (r.length ? r.map((c) => '<a class="item" href="#/chat/' + c.id + '">' + avatar(c.otro) + '<div class="grow"><div class="row between"><b class="ell">' + nombreCon(c.otro) + '</b><span class="small muted">' + hace(c.ultimo) + '</span></div>' +
            '<div class="row between"><span class="small muted ell">' + (c.mio ? 'Tú: ' : '') + esc(c.texto || '') + '</span>' + (c.no_leidos ? '<span class="pill" style="background:var(--brand);color:var(--brand-ink)">' + c.no_leidos + '</span>' : '') + '</div></div></a>').join('')
          : '<div class="vacio">' + ico('chat') + '<p>Aún no tienes conversaciones. Escribe a un dueño desde un estacionamiento.</p></div>');
      U.ponerIconos($('chC'));
      if ($('chSop')) $('chSop').onclick = async () => { try { location.hash = '#/chat/' + await Api.rpc('soporte'); } catch (e) { fallo(e); } };
    } catch (e) { $('chC').innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; }
  }
  async function vConversacion(id) {
    cargando();
    let ultimo = 0, info, lista = [];
    try { info = await Api.rpc('leer_mensajes', { p_conv: id, p_desde: 0 }); } catch (e) { V.innerHTML = volver() + '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    const o = info.otro;
    V.innerHTML = '<div class="chat"><div class="chat-cab"><a class="icon-btn" href="#/chat" aria-label="Volver">' + ico('back') + '</a><a href="#/u/' + o.id + '" class="row grow" style="color:var(--ink)">' + avatar(o, 'xs') + '<b class="ell">' + nombreCon(o) + '</b></a>' +
      '<button class="icon-btn" id="cBorrar" aria-label="Borrar conversación">' + ico('trash') + '</button>' +
      (o.admin ? '' : '<button class="icon-btn" id="cBlq" aria-label="Bloquear">' + ico('ban') + '</button><button class="icon-btn" id="cDen" aria-label="Denunciar">' + ico('flag') + '</button>') + '</div>' +
      '<div class="chat-msjs" id="cMsjs"><p class="small muted center">🔒 Nunca pagues antes de ver el estacionamiento. Si algo parece estafa, denúncialo con evidencia.<br>Máximo 3 mensajes seguidos: luego espera la respuesta.</p></div>' +
      '<div id="cAviso"></div><form class="chat-pie" id="cForm"><textarea id="cTxt" maxlength="500" rows="1" placeholder="Escribe un mensaje…"></textarea><button class="btn" aria-label="Enviar">' + ico('send') + '</button></form></div>';
    const M = $('cMsjs');
    const estadoPie = () => {
      let seguidos = 0;
      for (let i = lista.length - 1; i >= 0 && lista[i].mio; i--) seguidos++;
      const bloq = info.bloqueado || info.me_bloqueo;
      $('cForm').hidden = bloq;
      $('cAviso').innerHTML = info.bloqueado ? '<div class="aviso warn small">Bloqueaste a esta persona. <a href="#" id="cDesb">Desbloquear</a></div>'
        : info.me_bloqueo ? '<div class="aviso warn small">No puedes escribir a esta persona.</div>'
          : (!Api.admin() && seguidos >= 3 ? '<div class="chat-limite">Enviaste 3 mensajes seguidos. Espera la respuesta para escribir de nuevo.</div>'
            : (!Api.admin() && seguidos > 0 ? '<div class="chat-limite">Puedes enviar ' + (3 - seguidos) + ' mensaje' + (3 - seguidos === 1 ? '' : 's') + ' más antes de la respuesta.</div>' : ''));
      if ($('cDesb')) $('cDesb').onclick = async (e) => { e.preventDefault(); await Api.rpc('bloquear', { p_usuario: o.id, p_si: false }); info.bloqueado = false; estadoPie(); };
    };
    const agregar = (ms) => {
      if (!ms.length) return;
      const abajo = M.scrollHeight - M.scrollTop - M.clientHeight < 80;
      M.insertAdjacentHTML('beforeend', ms.map((m) => '<div class="burbuja' + (m.mio ? ' mio' : '') + '">' + esc(m.texto) + '<time>' + hora(m.fecha) + (m.mio ? (m.visto ? ' ✓✓' : ' ✓') : '') + '</time></div>').join(''));
      lista = lista.concat(ms); ultimo = ms[ms.length - 1].id;
      if (abajo || ms.some((m) => m.mio)) M.scrollTop = M.scrollHeight;
      estadoPie();
    };
    agregar(info.mensajes); M.scrollTop = M.scrollHeight; estadoPie(); contadores();
    $('cTxt').oninput = (e) => { e.target.style.height = 'auto'; e.target.style.height = Math.min(120, e.target.scrollHeight) + 'px'; };
    $('cTxt').onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey && !('ontouchstart' in window)) { e.preventDefault(); $('cForm').requestSubmit(); } };
    $('cForm').onsubmit = async (e) => {
      e.preventDefault();
      const t = $('cTxt').value.trim(); if (!t) return;
      const b = e.target.querySelector('button'); b.disabled = true;
      try {
        await Api.rpc('enviar_mensaje', { p_conv: id, p_texto: t });
        $('cTxt').value = ''; $('cTxt').style.height = '';
        Api.empujar(); await refrescar();
      } catch (er) { fallo(er); } finally { b.disabled = false; }
    };
    $('cBorrar').onclick = async () => {
      if (!await confirmar('¿Borrar toda la conversación con ' + o.nombre + '? Se borra para los dos. Los mensajes también se borran solos a los 30 días.', 'Borrar', true)) return;
      try { await Api.rpc('borrar_conversacion', { p_conv: id }); toast('Conversación borrada'); location.hash = '#/chat'; } catch (e) { fallo(e); }
    };
    if ($('cBlq')) {
      $('cBlq').onclick = async () => {
        if (info.bloqueado) return;
        if (!await confirmar('¿Bloquear a ' + o.nombre + '? No podrán escribirse ni arrendarse entre ustedes.', 'Bloquear', true)) return;
        try { await Api.rpc('bloquear', { p_usuario: o.id, p_si: true }); info.bloqueado = true; estadoPie(); toast('Bloqueado'); } catch (e) { fallo(e); }
      };
      $('cDen').onclick = () => denunciar('conversacion', id, 'Conversación con ' + o.nombre);
    }
    // Revisa mensajes nuevos cada 5 s mientras el chat esté abierto (y con la app a la vista).
    async function refrescar() {
      const r = await Api.rpc('leer_mensajes', { p_conv: id, p_desde: ultimo });
      info.bloqueado = r.bloqueado; info.me_bloqueo = r.me_bloqueo;
      // Actualiza los ✓✓ de mis mensajes que la otra persona ya vio.
      const mios = lista.filter((x) => x.mio);
      M.querySelectorAll('.burbuja.mio time').forEach((tm, i) => {
        const mm = mios[i];
        if (mm && !mm.visto && r.visto_hasta && mm.id <= r.visto_hasta) { mm.visto = true; tm.textContent = hora(mm.fecha) + ' ✓✓'; }
      });
      agregar(r.mensajes);
    }
    pollChat = setInterval(() => { if (!document.hidden) refrescar().catch(() => {}); }, 5000);
  }

  /* ======================= Cuenta ======================= */
  function planTxt(a) {
    if (a.admin) return '<span class="pill brand">Administrador</span>';
    if (!a.premium) return '<span class="pill">Plan Gratis</span>';
    if (a.premium_hasta && /infinity/i.test(String(a.premium_hasta))) return '<span class="pill gold">⭐ Premium de por vida</span>';
    const dias = Math.max(0, Math.ceil((new Date(a.premium_hasta) - Date.now()) / 864e5));
    return '<span class="pill gold">⭐ ' + (a.plan_origen === 'prueba' ? 'Prueba Premium' : 'Premium') + ' · ' + (dias <= 1 ? 'último día' : dias + ' días') + '</span>';
  }
  async function vCuenta(T) {
    T = T || V;
    await Api.refrescar();
    const a = Api.cuenta; if (!a) { router(); return; }
    const ver = a.verificado ? '<span class="pill ok">' + ico('shield') + ' Verificado</span>'
      : a.verif_estado === 'pendiente' ? '<span class="pill warn">🕐 Verificación en revisión</span>'
        : '<a class="pill bad" href="#/verificar">Sin verificar · Verificar ahora</a>';
    const miLink = U.enlace('#/u/' + a.id), miColor = Api.puede('qr_color') ? a.color : '#000';
    T.innerHTML = '<div class="card"><div class="row">' + avatar(a, 'lg') + '<div class="grow"><h2 style="margin:0">' + nombreCon(a) + '</h2><div class="small muted ell">' + esc(a.email) + '</div>' +
      '<div class="row wrap" style="margin-top:6px">' + planTxt(a) + ver + '</div></div></div>' +
      '<div class="row" style="margin-top:12px"><a class="btn sec grow" href="#/mas/perfil">' + ico('edit') + ' Editar perfil</a><a class="btn sec" href="#/u/' + a.id + '" aria-label="Ver mi perfil">' + ico('eye') + '</a><button class="btn sec" id="cQR" aria-label="Mi QR">' + ico('qr') + '</button></div></div>' +
      (a.suspendido ? '<div class="aviso bad" style="margin-top:12px">Tu cuenta está suspendida. Escribe a soporte.</div>' : '') +
      (!a.verificado && a.verif_estado === 'rechazada' ? '<div class="aviso bad" style="margin-top:12px">Tu verificación fue rechazada: ' + esc(a.verif_motivo || '') + '. <a href="#/verificar">Enviar de nuevo</a></div>' : '') +

      '<div class="sec-tit">Mi QR y link para compartir</div><div class="card center">' +
      '<p class="small muted" style="margin-top:0">Quien lo escanee o abra el link ve tu perfil y tus estacionamientos.</p>' +
      '<div class="qr-caja" id="cQRv"></div><p class="small" style="word-break:break-all">' + esc(miLink) + '</p>' +
      '<button class="btn block" id="cComp">' + ico('share') + ' Compartir mi link</button>' +
      '<div class="grid2" style="margin-top:10px"><button class="btn sec small" id="cCop">🔗 Copiar link</button><button class="btn sec small" id="cWA">📲 WhatsApp</button>' +
      '<button class="btn sec small" id="cDesc">' + ico('download') + ' Descargar QR</button><button class="btn sec small" id="cInv">🎁 Invitar a la app</button></div></div>' +
      (a.admin ? '' : '<div class="sec-tit">Mi plan</div><div class="card">' +
      '<div class="row between small"><span>Estacionamientos publicados</span><b>' + a.uso.publicados + ' / ' + a.lim.publicar + '</b></div><div class="barra"><i style="width:' + Math.min(100, a.uso.publicados / a.lim.publicar * 100) + '%"></i></div>' +
      '<div class="row between small" style="margin-top:10px"><span>Arriendos activos</span><b>' + a.uso.arrendando + ' / ' + a.lim.arrendar + '</b></div><div class="barra"><i style="width:' + Math.min(100, a.uso.arrendando / a.lim.arrendar * 100) + '%"></i></div>' +
      '<a class="btn ' + (a.premium ? 'sec' : 'gold') + ' block" style="margin-top:14px" href="#/premium">' + (a.premium ? 'Ver mi Premium' : '⭐ Hazte Premium') + '</a></div>') +
      '<div class="sec-tit">Alerta de zona ' + (Api.puede('alertas') ? '' : '<span class="pill gold">Premium</span>') + '</div><div class="card' + (Api.puede('alertas') ? '' : ' candado') + '">' +
      '<p class="small" style="margin-top:0">Te avisamos cuando publiquen un estacionamiento cerca de la zona que elijas.</p>' +
      (a.alerta ? '<p class="small"><b>Activa:</b> radio de ' + a.alerta.km + ' km.</p>' : '') +
      '<div class="row"><select id="aKm" class="grow"><option value="0.5">500 m</option><option value="1">1 km</option><option value="2">2 km</option><option value="5">5 km</option></select>' +
      '<button class="btn small" id="aSet">Usar zona del mapa</button>' + (a.alerta ? '<button class="btn sec small" id="aDel">Quitar</button>' : '') + '</div></div>' +
      '<div class="sec-tit">Ajustes</div><div class="card stack">' +
      '<div class="row between"><span>👤 Mi perfil: foto, color, modo y contraseña</span><a class="btn small sec" href="#/mas/perfil">Abrir</a></div>' +
      '<div class="row between"><span>🔄 Versión ' + esc(cfg.VERSION) + '</span><button class="btn small sec" id="cAct">Buscar actualización</button></div>' +
      '<div class="row between" id="cInstWrap" hidden><span>' + ico('download') + ' Instalar la app</span><button class="btn small" id="cInst">Instalar</button></div></div>' +
      '<div class="sec-tit">Respaldo</div><div class="card stack"><p class="small muted" style="margin:0">Descarga en Excel tus estacionamientos, arriendos y pagos. Los avisos y mensajes se borran solos a los 30 días (te avisamos antes).</p>' +
      '<button class="btn sec small" id="cRespaldo">' + ico('download') + ' Descargar respaldo (Excel)</button></div>' +
      '<div class="sec-tit">Ayuda</div><div class="card stack"><a href="#/chat" id="cSop" class="row" style="color:var(--ink)">' + ico('help') + ' Soporte (chat)</a>' +
      '<a href="#/legal" class="row" style="color:var(--ink)">' + ico('shield') + ' Términos y privacidad</a>' +
      '<button class="row btn line" id="cSalir" style="justify-content:flex-start">' + ico('logout') + ' Cerrar sesión</button></div>' +
      '<p class="pie">© ' + new Date().getFullYear() + ' ' + esc(cfg.MARCA) + ' · ' + esc(cfg.AUTOR) + '<br>Versión ' + esc(cfg.VERSION) + '</p>';
    U.ponerIconos(T);
    $('cAct').onclick = () => buscarVersion(true);
    $('cQR').onclick = () => U.mostrarQR(a.nombre, 'Mi perfil en Estaciona', miLink, miColor);
    const qr = U.qrCanvas(miLink, miColor, 600); $('cQRv').appendChild(qr);
    const txt = '🅿️ Mira mi perfil y mis estacionamientos en *Estaciona*: ' + miLink;
    $('cCop').onclick = async () => { try { await navigator.clipboard.writeText(miLink); toast('Link copiado'); } catch (e) { prompt('Copia el link:', miLink); } };
    $('cWA').onclick = () => window.open('https://wa.me/?text=' + encodeURIComponent(txt), '_blank');
    $('cComp').onclick = () => U.compartir(a.nombre + ' en Estaciona', txt, miLink);
    $('cDesc').onclick = () => { const l = document.createElement('a'); l.href = qr.toDataURL('image/png'); l.download = 'estaciona-mi-qr.png'; l.click(); };
    $('cInv').onclick = () => U.mostrarQR('Invita a Estaciona', 'Arrienda o publica estacionamientos con personas verificadas', U.enlace(''), miColor);
    if (a.alerta) $('aKm').value = String(a.alerta.km);
    $('aSet').onclick = async () => {
      if (!Api.puede('alertas')) { location.hash = '#/premium'; return; }
      const c = JSON.parse(sessionStorage.getItem('est:vista') || 'null');
      const ll = c ? c.c : { lat: cfg.CENTRO[0], lng: cfg.CENTRO[1] };
      try { Api.guardar(await Api.rpc('guardar_alerta', { p_lat: ll.lat, p_lng: ll.lng, p_km: +$('aKm').value })); toast('Alerta activada en la zona que estabas viendo en el mapa'); vCuenta(T); } catch (e) { fallo(e); }
    };
    if ($('aDel')) $('aDel').onclick = async () => { Api.guardar(await Api.rpc('guardar_alerta', { p_lat: null, p_lng: null, p_km: null })); vCuenta(T); };
    if (instalar) { $('cInstWrap').hidden = false; $('cInst').onclick = () => { instalar.prompt(); instalar = null; $('cInstWrap').hidden = true; }; }
    else if (/iPhone|iPad/.test(navigator.userAgent) && !navigator.standalone) {
      $('cInstWrap').hidden = false; $('cInst').textContent = 'Cómo'; $('cInst').onclick = () => modal('<h2>Instalar en iPhone</h2><p>1. Abre esta página en <b>Safari</b>.<br>2. Toca <b>Compartir</b> (cuadrado con flecha).<br>3. Elige <b>Agregar a inicio</b>.</p>');
    }
    if (!a.admin) $('cSop').onclick = async (e) => { e.preventDefault(); try { location.hash = '#/chat/' + await Api.rpc('soporte'); } catch (er) { fallo(er); } };
    $('cRespaldo').onclick = async () => { try { CFX_RESPALDO.excel('estaciona-' + (a.nombre || 'respaldo'), await Api.rpc('mi_respaldo')); toast('Respaldo descargado'); } catch (e) { fallo(e); } };
    $('cSalir').onclick = async () => { await Api.salir(); toast('Sesión cerrada'); location.hash = '#/'; };
  }

  // Perfil común del núcleo (ayuda.js → CFX_PERFIL): aquí solo cómo guarda Estaciona.
  let avatarNuevo;
  const guardarPerfil = async (o) => {
    const a = Api.cuenta;
    Api.guardar(await Api.rpc('guardar_perfil', Object.assign({ p_nombre: a.nombre, p_comuna: a.comuna || '', p_bio: a.bio || '', p_icono: a.icono || '', p_color: a.color, p_avatar: a.avatar, p_whatsapp: a.whatsapp || '' }, o)));
    Api.empujar();
  };
  g.CFX_PERFIL_APP = {
    nombre: () => Api.cuenta.nombre || '', correo: () => Api.cuenta.email,
    foto: () => (Api.cuenta.avatar ? urlFoto(Api.cuenta.avatar) : ''),
    guardarFoto: async (f) => { avatarNuevo = f ? await U.subirFoto(f, 'fotos', { lado: 320, calidad: 0.78, cuadrado: true }) : null; },
    iconos: [''].concat(ICONOS), icono: () => Api.cuenta.icono || '', iconoQuitaFoto: true,
    campos: () => { const a = Api.cuenta; return [{ k: 'whatsapp', t: 'WhatsApp (solo lo ve quien tiene una reserva contigo)', tipo: 'tel', max: 20, ph: '+56 9 1234 5678', v: a.whatsapp || '' },
      { k: 'comuna', t: 'Comuna', max: 40, v: a.comuna || '' }, { k: 'bio', t: 'Sobre mí', tipo: 'area', max: 280, ph: 'Cuéntale a la comunidad quién eres', v: a.bio || '' }]; },
    guardar: async (d) => {
      const o = { p_nombre: d.nombre, p_comuna: d.comuna, p_bio: d.bio, p_icono: d.icono || '', p_whatsapp: d.whatsapp };
      if (avatarNuevo !== undefined) o.p_avatar = avatarNuevo;
      avatarNuevo = undefined;
      await guardarPerfil(o);
    },
    colores: COLORES_GRATIS, libre: true, color: () => Api.cuenta.color, probarColor: U.aplicarColor,
    guardarColor: async (c) => { U.aplicarColor(c); try { await guardarPerfil({ p_color: c }); } catch (e) { U.aplicarColor(Api.cuenta.color); throw e; } },
    bloqueo: (que) => (que === 'libre' && !Api.puede('color_libre') ? 'Color libre (RGB)' : ''),
    mejorar: () => { location.hash = '#/premium'; },
    // El mapa cambia sus teselas con el modo (sin recargar la página).
    modo: () => ({ light: 'claro', dark: 'oscuro' })[document.documentElement.dataset.theme] || 'auto',
    guardarModo: (m) => { U.aplicarTema(({ claro: 'light', oscuro: 'dark' })[m] || ''); if (g.Mapa && g.Mapa.repintar) g.Mapa.repintar(); },
    pushActiva: () => U.pushActivo(), activarPush: () => U.activarPush(),
    clave: async (n) => { const { error } = await Api.sb.auth.updateUser({ password: n }); if (error) throw new Error(U.amable(error)); },
    puedeEliminar: () => !Api.cuenta.admin,
    eliminarTexto: 'Se borran tu perfil, tus estacionamientos, fotos y mensajes. No se puede deshacer.',
    eliminar: async () => {
      if (!await confirmar('¿Eliminar tu cuenta? Se borran tu perfil, tus estacionamientos, fotos y mensajes. No se puede deshacer.', 'Eliminar para siempre', true)) return;
      await Api.funcion('eliminar_usuario'); await Api.salir(); toast('Tu cuenta fue eliminada'); location.hash = '#/';
    }
  };
  function vEditarPerfil(T) {
    T = T || V;
    T.innerHTML = '<div class="card" id="miPerfil"></div>';
    g.CFX_PERFIL.montar($('miPerfil'));
  }

  /* ======================= Verificación de identidad ======================= */
  function vVerificar() {
    const a = Api.cuenta;
    if (a.verificado) { V.innerHTML = volver() + '<div class="card center"><div style="font-size:48px">✅</div><h2>Tu identidad está verificada</h2><p class="muted">Ya puedes publicar, arrendar y chatear.</p><a class="btn" href="#/">Ir al mapa</a></div>'; return; }
    if (a.verif_estado === 'pendiente') { V.innerHTML = volver() + '<div class="card center"><div style="font-size:48px">🕐</div><h2>Estamos revisando tus datos</h2><p class="muted">Te avisaremos apenas el administrador apruebe tu verificación (normalmente el mismo día).</p><a class="btn sec" href="#/">Mientras, mira el mapa</a></div>'; return; }
    const fotos = {};
    V.innerHTML = volver() + '<h1>🪪 Verificar identidad</h1><p class="muted">Así nadie puede hacerse pasar por otra persona. Solo el administrador ve estos datos y <b>las fotos se borran apenas se revisan</b>.</p>' +
      (a.verif_estado === 'rechazada' ? '<div class="aviso bad">Rechazada: ' + esc(a.verif_motivo || '') + '. Corrige y envía de nuevo.</div>' : '') +
      '<form id="fVer" class="card" style="margin-top:12px"><label>RUT</label><input id="vRut" inputmode="text" autocomplete="off" placeholder="12.345.678-9" maxlength="12" required><div id="vRutE" class="hint"></div>' +
      '<label>Número de documento / serie de tu cédula</label><input id="vSerie" autocomplete="off" placeholder="Ej: 123.456.789" maxlength="14" required>' +
      '<div class="hint">Cédula nueva: “Número de documento” al frente (9 dígitos). Cédula antigua: “N° serie” atrás (ej: A012345678).</div>' +
      '<label>Foto de la cédula — frente</label><input type="file" id="vF" accept="image/*" capture="environment" required>' +
      '<label>Foto de la cédula — reverso</label><input type="file" id="vR" accept="image/*" capture="environment" required>' +
      '<label>Selfie sosteniendo tu cédula</label><input type="file" id="vS" accept="image/*" capture="user" required><div class="hint">Que se vea tu cara y la cédula al lado.</div>' +
      '<label class="check"><input type="checkbox" id="vOk" required> <span class="small">Declaro que soy el titular de esta cédula y autorizo a Estaciona a revisar estos datos solo para verificar mi identidad (Ley 19.628 y Ley 21.719 de protección de datos personales).</span></label>' +
      '<button class="btn block" id="vEnv">Enviar verificación</button></form>';
    $('vRut').oninput = (e) => {
      e.target.value = U.rutFormato(e.target.value);
      const ok = U.rutValido(e.target.value);
      $('vRutE').textContent = e.target.value.length > 8 ? (ok ? '✓ RUT válido' : '✗ El dígito verificador no coincide') : '';
      $('vRutE').style.color = ok ? 'var(--ok)' : 'var(--bad)';
    };
    $('fVer').onsubmit = async (e) => {
      e.preventDefault();
      if (!U.rutValido($('vRut').value)) { toast('Revisa tu RUT'); return; }
      const serie = $('vSerie').value.replace(/[^0-9a-z]/gi, '').toUpperCase();
      if (!/^[A-Z]?\d{9}$/.test(serie)) { toast('El número de documento debe tener 9 dígitos'); return; }
      const b = $('vEnv'); b.disabled = true;
      try {
        const subir = async (k, campo, n) => { b.textContent = 'Subiendo foto ' + n + ' de 3…'; fotos[k] = await U.subirFoto($(campo).files[0], 'privado', U.FOTO('documento')); };
        await subir('f', 'vF', 1); await subir('r', 'vR', 2); await subir('s', 'vS', 3);
        b.textContent = 'Enviando…';
        Api.guardar(await Api.rpc('enviar_verificacion', { p_rut: $('vRut').value, p_serie: serie, p_frente: fotos.f, p_reverso: fotos.r, p_selfie: fotos.s }));
        Api.empujar(); toast('¡Listo! Revisaremos tus datos pronto'); vVerificar();
      } catch (er) { toast(er.message); b.disabled = false; b.textContent = 'Enviar verificación'; }
    };
  }

  /* ======================= Premium ======================= */
  async function vPremium(T) {
    T = T || V;
    const aj = await Api.ajustes(true), a = Api.cuenta;
    const pl = aj.planes || {}, gr = (pl.gratis || {}).limites || {}, pr = (pl.premium || {}).limites || {};
    // Precios: los mismos de las 6 apps (núcleo: cfx_precios; se editan en el Centro de Mando → Pagos).
    // Quien publica paga como negocio; quien solo arrienda, como cliente.
    const px = await Api.rpc('cfx_precios').catch(() => null) || {}, grupo = a && a.uso && a.uso.publicados > 0 ? 'negocio' : 'cliente';
    const pz = px[grupo] || {}, an = pz.anual ? { precio: pz.anual } : null;
    const ops = { mes: { precio: pz.mensual || 0, dias: 30, nom: 'Mensual' } };
    if (an) ops.anual = { precio: an.precio, dias: 365, nom: 'Anual' };
    let per = 'mes';
    const ahorro = an && pz.mensual ? Math.round((1 - an.precio / (pz.mensual * 12)) * 100) : 0;
    // Admin: vende, no compra. Premium vitalicio: nada que comprar. Premium pagado: la venta queda tras "Renovar"
    // (se muestra sola cuando faltan pocos días). Prueba y Gratis: ven los planes para comprar.
    const vitalicio = a && a.premium && /infinity/i.test(String(a.premium_hasta));
    const diasRest = a && a.premium && a.premium_hasta && !vitalicio ? Math.ceil((new Date(a.premium_hasta) - Date.now()) / 864e5) : 0;
    const modo = a && a.admin ? 'admin' : vitalicio ? 'vitalicio'
      : a && a.premium && a.plan_origen !== 'prueba' && diasRest > ((aj.reglas || {}).dias_aviso_vencimiento || 3) ? 'activo' : 'comprar';
    const v = (x) => x === true ? '✓' : x === false || x == null ? '—' : x >= 500 ? 'Ilimitados' : x;
    const filas = [['Estacionamientos publicados', 'publicar'], ['Arriendos activos a la vez', 'arrendar'], ['Fotos por estacionamiento', 'fotos'], ['Favoritos', 'favoritos'],
      ['Pin dorado destacado', 'destacado'], ['Estadísticas', 'estadisticas'], ['Alerta de zona', 'alertas'], ['Color libre (RGB)', 'color_libre'], ['QR con tu color', 'qr_color']];
    const heroIni = '<div class="card center" style="background:linear-gradient(160deg,#0b1020,#1e3a8a);color:#fff;border:0"><div style="font-size:46px">⭐</div><h1>';
    const incluye = '<div class="card" style="margin-top:12px"><b>Incluye</b><ul class="small" style="margin:8px 0 0;padding-left:18px">' + ((pl.premium || {}).beneficios || []).map((b) => '<li>' + esc(b) + '</li>').join('') + '</ul></div>';
    if (modo === 'admin' || modo === 'vitalicio') {
      T.innerHTML = heroIni + (modo === 'admin' ? 'Tienes todo incluido</h1><p style="opacity:.85">Eres el administrador: tú vendes Premium. Precios, links de pago y planes se manejan en el Centro de Mando.</p></div>'
        : 'Premium de por vida</h1><p style="opacity:.85">Tienes todas las funciones Premium para siempre. ¡Gracias!</p></div>') + incluye;
      return;
    }
    T.innerHTML = (modo === 'activo' ? heroIni + 'Ya eres Premium ✓</h1><p style="opacity:.85">Vence el ' + fecha(a.premium_hasta) + ' (' + diasRest + ' días). Te avisaremos antes de que venza.</p>' +
        '<button class="btn sec" id="prRenovar">🔄 Renovar por adelantado</button></div><div id="prVenta" hidden style="margin-top:12px">' : '') +
      heroIni + esc(Api.texto('premium_titulo', 'Estaciona Premium')) + '</h1>' +
      '<p style="opacity:.85">' + esc(Api.texto('premium_texto', '')) + '</p>' +
      (an ? '<div class="seg" id="prPer" style="justify-content:center;margin:4px 0 10px"><button data-p="mes" class="on">📅 Mensual</button><button data-p="anual">🗓️ Anual' + (ahorro > 0 ? ' · ahorra ' + ahorro + '%' : '') + '</button></div>' : '') +
      '<div style="font-size:34px;font-weight:900" id="prPrecio"></div><div class="small" style="opacity:.8" id="prDur"></div></div>' +
      (a && a.premium && !a.admin ? '<div class="aviso" style="margin-top:12px">' + planTxt(a) + (a.premium_hasta && !/infinity/i.test(String(a.premium_hasta)) ? ' Vence el ' + fecha(a.premium_hasta) + '.' : '') + '</div>' : '') +
      '<div class="card" style="margin-top:12px"><b>Incluye</b><ul class="small" style="margin:8px 0 0;padding-left:18px">' + ((pl.premium || {}).beneficios || []).map((b) => '<li>' + esc(b) + '</li>').join('') + '</ul></div>' +
      '<table class="tabla card" style="margin-top:12px;padding:0"><tr><th></th><th>' + esc((pl.gratis || {}).nombre || 'Gratis') + '</th><th style="color:var(--gold)">' + esc((pl.premium || {}).nombre || 'Premium') + '</th></tr>' +
      filas.map((f) => '<tr><td>' + f[0] + '</td><td>' + v(gr[f[1]]) + '</td><td><b>' + v(pr[f[1]]) + '</b></td></tr>').join('') + '</table>' +
      '<div class="card" style="margin-top:12px"><b>Cómo activarlo</b><p class="small muted" style="margin:6px 0 10px">' + esc(Api.texto('pago_instrucciones', '')) + '</p>' +
      '<button class="btn gold block" id="prComprar"></button><p class="small muted" style="margin:8px 0 0">Paga con link o transferencia y sube la foto del comprobante. Se activa apenas lo revisemos.</p></div>' +
      '<div class="sec-tit">¿Tienes una key?</div><div class="row"><input id="prKey" placeholder="EST-XXXX-XXXX" autocapitalize="characters" class="grow"><button class="btn" id="prCanje">' + ico('key') + ' Activar</button></div>' +
      (modo === 'activo' ? '</div>' : '');
    U.ponerIconos(T);
    if ($('prRenovar')) $('prRenovar').onclick = () => { $('prVenta').hidden = false; $('prRenovar').hidden = true; $('prVenta').scrollIntoView({ behavior: 'smooth' }); };
    const pintar = () => {
      const o = ops[per];
      $('prPrecio').textContent = clp(o.precio);
      $('prDur').textContent = o.dias + ' días de Premium';
      $('prComprar').textContent = '💳 Pagar ' + clp(o.precio) + (an ? ' (' + o.nom.toLowerCase() + ')' : '');
      if ($('prPer')) $('prPer').querySelectorAll('button').forEach((b) => b.classList.toggle('on', b.dataset.p === per));
    };
    pintar();
    if ($('prPer')) $('prPer').onclick = (e) => { const b = e.target.closest('[data-p]'); if (b) { per = b.dataset.p; pintar(); } };
    $('prComprar').onclick = () => {
      if (!Api.logueado()) return pedirLogin('Crea tu cuenta para comprar Premium');
      CFX_PAGOS.abrir({ rpc: (f, x) => Api.rpc(f, x), alPagar: () => Api.empujar() });
    };
    $('prCanje').onclick = async () => {
      if (!Api.logueado()) return pedirLogin();
      try { Api.guardar(await Api.rpc('canjear_key', { p_key: $('prKey').value })); toast('¡Premium activado! ⭐'); vPremium(T); } catch (e) { toast(e.message); }
    };
  }

  /* ======================= Avisos ======================= */
  // Ventana de avisos (igual que BiciTaller): ✕ por aviso, "Borrar todos" y activar notificaciones, sin salir de donde estás.
  async function vAvisos() {
    const c = modal('<h2 style="margin:0 40px 8px 0">🔔 Avisos</h2><div id="avC" style="max-height:60vh;overflow:auto"><div class="spin"></div></div><div id="avPush"></div>');
    U.pushActivo().then((on) => {
      if (on || !$('avPush')) return;
      $('avPush').innerHTML = '<div class="aviso" style="margin:12px 0 0;align-items:center"><span class="grow small">Activa las notificaciones para enterarte aunque tengas la app cerrada.</span><button class="btn small" id="avAct">Activar</button></div>';
      $('avAct').onclick = async (e) => { e.target.disabled = true; try { await U.activarPush(); $('avPush').innerHTML = ''; toast('Notificaciones activadas 🔔'); } catch (er) { e.target.disabled = false; toast(er.message); } };
    });
    try {
      const r = await Api.rpc('mis_notificaciones');
      if (!$('avC')) return;
      $('avC').innerHTML = r.length ? r.map((n) => '<a class="item" href="' + esc(n.url || '#/') + '" style="' + (n.leida ? '' : 'border-color:var(--brand)') + '"><div class="grow"><b>' + esc(n.titulo) + '</b><div class="small">' + esc(n.cuerpo || '') + '</div><div class="small muted">' + hace(n.fecha) + '</div></div>' +
          '<button class="icon-btn" data-quitar="' + n.id + '" aria-label="Borrar aviso">✕</button></a>').join('') +
          '<div class="row between" style="margin-top:10px"><span class="small muted">Se borran solos a los 30 días.</span><button class="btn sec small" id="avTodo">Borrar todos</button></div>'
        : '<div class="vacio">' + ico('bell') + '<p>No tienes avisos.</p></div>';
      U.ponerIconos($('avC'));
      $('avC').onclick = async (ev) => {
        const b = ev.target.closest('[data-quitar]'), todo = ev.target.closest('#avTodo');
        if (!b && !todo) { if (ev.target.closest('a.item')) cerrarModal(); return; }
        ev.preventDefault();
        if (todo && !await confirmar('¿Borrar todos tus avisos?', 'Borrar', true)) return;
        if (todo && window.CFX_ANIM) await window.CFX_ANIM.salirTodos();
        try { await Api.rpc('borrar_notificacion', { p_id: b ? +b.dataset.quitar : null }); if (b) { b.closest('.item').remove(); if (!$('avC').querySelector('.item')) vAvisos(); } else vAvisos(); contadores(); } catch (e) { fallo(e); }
      };
      if (r.some((n) => !n.leida)) { await Api.rpc('marcar_leidas'); contadores(); }
    } catch (e) { if ($('avC')) $('avC').innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; }
  }


  /* ======================= Términos ======================= */
  function vLegal() {
    V.innerHTML = volver() + '<h1>Términos y privacidad</h1><div class="card small" style="line-height:1.6">' +
      '<h3>1. Qué es Estaciona</h3><p>Estaciona es una plataforma que conecta a personas que ofrecen estacionamientos en arriendo con personas que los buscan. Estaciona <b>no es parte del contrato de arriendo</b>, no cobra comisión por el arriendo ni recibe pagos entre usuarios: el precio, la forma de pago y las condiciones se acuerdan directamente entre las partes.</p>' +
      '<h3>2. Cuenta y verificación</h3><p>Para publicar, arrendar o chatear debes verificar tu identidad con tu RUT, el número de documento de tu cédula y fotos de la cédula y una selfie. Un RUT solo puede tener una cuenta. Entregar datos falsos o suplantar a otra persona es causal de eliminación de la cuenta y puede constituir delito.</p>' +
      '<h3>3. Publicaciones</h3><p>Quien publica declara que el estacionamiento le pertenece o que cuenta con autorización para arrendarlo (incluido el reglamento de copropiedad, si aplica), y que la información y las fotos son verdaderas. El administrador puede ocultar o eliminar publicaciones que no cumplan.</p>' +
      '<h3>4. Seguridad y conducta</h3><p>No pagues antes de ver el estacionamiento y conocer al dueño. El chat permite 3 mensajes seguidos y luego hay que esperar la respuesta, para evitar spam. Puedes bloquear y denunciar; las denuncias requieren evidencia y son revisadas por el administrador. Las denuncias falsas pueden llevar a la suspensión.</p>' +
      '<h3>5. Planes</h3><p>El plan Gratis permite 1 publicación y 1 arriendo activo. El plan Premium (pago único según el precio publicado) amplía estos límites y suma funciones. El primer pago de cada cuenta da 30 días de Premium. Si Premium vence, las publicaciones que superen el límite dejan de mostrarse en el mapa (no se borran).</p>' +
      '<h3>6. Privacidad (Ley 19.628 y Ley 21.719)</h3><p>Tratamos tus datos solo para operar el servicio. Tu RUT, número de documento, correo y teléfono <b>nunca se muestran</b> a otros usuarios. Las fotos de la cédula y la selfie se eliminan apenas se revisa la verificación. La dirección exacta del estacionamiento solo la ve quien tiene un arriendo aceptado. Los mensajes se borran automáticamente a los 30 días. Puedes eliminar tu cuenta y tus datos en cualquier momento desde Cuenta. Para ejercer tus derechos de acceso, rectificación, supresión u oposición, escribe a soporte en la app.</p>' +
      '<h3>7. Responsabilidad</h3><p>Estaciona actúa como intermediario de contacto y no responde por el estado de los estacionamientos ni por los acuerdos entre usuarios, sin perjuicio de colaborar con las autoridades cuando corresponda.</p>' +
      '<p class="muted">© ' + new Date().getFullYear() + ' ' + esc(cfg.MARCA) + ' · ' + esc(cfg.AUTOR) + '. Todos los derechos reservados.</p></div>';
    U.ponerIconos(V);
  }

  /* ======================= Contadores y cabecera ======================= */
  let avisosAntes = null;
  async function contadores() {
    if (!Api.logueado() || document.hidden) return;
    try {
      const c = await Api.rpc('contadores');
      const pon = (id, n) => { const b = $(id); b.textContent = n > 99 ? '99+' : n; b.classList.toggle('on', n > 0); };
      pon('bChat', c.mensajes); pon('bAvisos', c.avisos); pon('bMis', c.solicitudes);
      // Llegó un aviso con la app abierta → aviso emergente arriba (solo los de esta cuenta).
      if (window.CFX_ANIM && avisosAntes != null && c.avisos > avisosAntes) Api.rpc('mis_notificaciones').then((r) => { const n = r.find((x) => !x.leida); if (n) window.CFX_ANIM.emergente({ titulo: n.titulo, cuerpo: n.cuerpo }); }).catch(() => {});
      avisosAntes = c.avisos;
    } catch (e) { /* sin red */ }
  }
  // Administrador: barra propia (Resumen · Estacionamientos · + · Usuarios · Ajustes). El mapa sigue igual desde Estacionamientos → Ver en el mapa.
  const NAV_ADMIN = { mapa: ['#/admin/resumen', '📊', 'Resumen', 'adm-resumen'], reservas: ['#/admin/estacionamientos', '🚗', 'Lugares', 'adm-estacionamientos'],
    chat: ['#/admin/usuarios', '👥', 'Usuarios', 'adm-usuarios'], mas: ['#/admin/ajustes', '⚙️', 'Ajustes', 'adm-ajustes'] };
  let navEsAdmin = null;
  function navAdmin(si) {
    if (navEsAdmin === si) return; navEsAdmin = si;
    // Administrador: la cabecera dice solo "Administración" (sin el logo de Estaciona).
    const lg = document.querySelector('header.top .logo');
    if (lg) { lg.querySelector('.logo-p').style.display = si ? 'none' : ''; lg.querySelector('b').textContent = si ? 'Administración' : 'Estaciona'; lg.querySelector('b').style.fontSize = si ? '17px' : ''; }
    document.querySelectorAll('#nav a[data-r0], #nav a[data-r]').forEach((b) => {
      const r0 = b.dataset.r0 || b.dataset.r; if (!NAV_ADMIN[r0] || (!si && !b.dataset.r0)) return;
      if (!b.dataset.r0) { b.dataset.r0 = r0; b.dataset.h0 = b.getAttribute('href'); b.dataset.t0 = b.querySelector('small').textContent; b.dataset.i0 = b.querySelector('.i').innerHTML; }
      const d = NAV_ADMIN[r0];
      b.setAttribute('href', si ? d[0] : b.dataset.h0); b.dataset.r = si ? d[3] : r0;
      b.querySelector('small').textContent = si ? d[2] : b.dataset.t0;
      if (si) b.querySelector('.i').textContent = d[1]; else b.querySelector('.i').innerHTML = b.dataset.i0;
      const bd = b.querySelector('.badge'); if (bd) bd.hidden = si;
    });
  }
  function cabecera() {
    const a = Api.cuenta;
    $('btnEntrar').hidden = !!a; $('miniAv').hidden = !a; $('btnAvisos').hidden = !a; $('btnAvisos').onclick = (e) => { e.preventDefault(); if (Api.logueado()) vAvisos(); }; $('btnAdmin').hidden = !(a && a.admin);
    if (a) $('miniAv').innerHTML = avatar(a, 'xs');
    else ['bChat', 'bAvisos', 'bMis'].forEach((i) => $(i).classList.remove('on'));
    navAdmin(!!(a && a.admin));
  }

  /* ======================= Router ======================= */
  const RUTAS = [
    [/^\/?$/, 'mapa', null, false],
    [/^\/e\/([0-9a-f-]{36})$/, 'mapa', vDetalle, false],
    [/^\/u\/([0-9a-f-]{36})$/, '', vPerfil, 'Crea tu cuenta para ver perfiles'],
    [/^\/publicar$/, 'publicar', () => vPublicar(), 'Crea tu cuenta para publicar tu estacionamiento'],
    [/^\/editar\/([0-9a-f-]{36})$/, 'publicar', vPublicar, true],
    [/^\/r\/([0-9a-f-]{36})$/, 'reservas', vReserva, 'Ingresa para ver tu reserva'],
    [/^\/reservas(?:\/(\w+))?$/, 'reservas', vReservas, 'Crea tu cuenta para reservar o publicar'],
    [/^\/mas(?:\/(\w+))?$/, 'mas', vMas, 'Ingresa o crea tu cuenta'],
    [/^\/chat$/, 'chat', vChats, 'Crea tu cuenta para chatear'],
    [/^\/chat\/([0-9a-f-]{36})$/, 'chat', vConversacion, true],
    [/^\/verificar$/, 'mas', vVerificar, 'Crea tu cuenta para verificarte'],
    [/^\/premium$/, 'mas', (t) => vPremium(), false],
    [/^\/avisos$/, '', () => { history.replaceState(null, '', '#/'); router(); vAvisos(); }, true],
    [/^\/legal$/, '', vLegal, false],
    [/^\/admin(?:\/(\w+))?$/, 'mas', (t) => g.Admin.vista(t), true]
  ];
  // Direcciones antiguas (avisos y enlaces de la v1).
  const ALIAS = { '/cuenta': '/mas/cuenta', '/perfil': '/mas/perfil', '/mis': '/reservas', '/mis/publicados': '/mas/estacionamientos',
    '/mis/favoritos': '/mas/favoritos', '/mis/solicitudes': '/reservas/revisar', '/mis/arriendos': '/reservas/mias' };
  function router() {
    clearInterval(pollChat); pollChat = null;
    g.Mapa.limpiar();
    const h0 = location.hash.replace(/^#/, '');
    if (ALIAS[h0]) { location.replace('#' + ALIAS[h0]); return; }
    const h = h0;
    let ruta = RUTAS[0], m = null;
    for (const r of RUTAS) { m = h.match(r[0]); if (m) { ruta = r; break; } }
    if (!m) { location.hash = '#/'; return; }
    if (Api.admin() && !h && !router.admin) { router.admin = 1; location.replace('#/admin/resumen'); return; }
    rutaActual = h;
    const activo = !Api.admin() ? ruta[1] : /^\/admin/.test(h) ? 'adm-' + (m[1] || 'resumen') : ruta[1] === 'mapa' ? 'adm-estacionamientos' : ruta[1];
    document.querySelectorAll('.nav a').forEach((a) => a.classList.toggle('on', a.dataset.r === activo));
    const esMapa = !ruta[2];
    if (ruta[3] && !Api.logueado()) {
      // Sin sesión: se queda en el mapa y pide crear cuenta.
      $('mapaVista').hidden = false; V.hidden = true; g.Mapa.iniciar(); g.Mapa.refrescar();
      pedirLogin(typeof ruta[3] === 'string' ? ruta[3] : 'Ingresa para continuar');
      destino = '#' + h;
      history.replaceState(null, '', '#/');
      document.querySelectorAll('.nav a').forEach((a) => a.classList.toggle('on', a.dataset.r === 'mapa'));
      return;
    }
    if (/^\/admin/.test(h) && !Api.admin()) { location.hash = '#/'; return; }
    $('mapaVista').hidden = !esMapa; V.hidden = esMapa;
    if (esMapa) { g.Mapa.iniciar(); g.Mapa.refrescar(); return; }
    cerrarModal();
    window.scrollTo(0, 0);
    ruta[2].apply(null, m.slice(1));
  }

  /* ======================= Inicio ======================= */
  let instalar = null;
  window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); instalar = e; });
  document.addEventListener('cuenta', cabecera);
  window.addEventListener('hashchange', router);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) contadores(); });

  // Actualizaciones: compara version.json con la versión instalada y muestra "Hay una versión nueva → Actualizar ahora".
  let swReg = null;
  const mayor = (a, b) => { const x = String(a).split('.').map(Number), y = String(b).split('.').map(Number);
    for (let i = 0; i < 3; i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0); } return false; };
  async function actualizarAhora(btn) {
    if (btn) { btn.disabled = true; btn.textContent = 'Actualizando…'; }
    const limpiar = (async () => {
      try { const rs = await navigator.serviceWorker.getRegistrations(); await Promise.all(rs.map((r) => r.unregister())); } catch (e) { /* nada */ }
      try { const ks = await caches.keys(); await Promise.all(ks.filter((k) => k !== 'est-fotos').map((k) => caches.delete(k))); } catch (e) { /* nada */ }
    })();
    await Promise.race([limpiar, new Promise((ok) => setTimeout(ok, 2500))]);
    location.replace(location.pathname + '?v=' + Date.now() + location.hash);
  }
  async function buscarVersion(manual) {
    let v = '';
    try { v = String((await (await fetch('version.json?t=' + Date.now(), { cache: 'no-store' })).json()).version || ''); } catch (e) { if (manual) toast('Sin conexión'); return; }
    // El admin ve la versión nueva apenas se publica (para probarla); el resto, cuando el admin la libera.
    const lib = ((await Api.ajustes(true)).textos || {}).version_liberada || '';
    const nueva = v && mayor(v, cfg.VERSION) && (Api.admin() || (lib && !mayor(v, lib)));
    if (!nueva) { if (manual) toast('Ya tienes la última versión (v' + cfg.VERSION + ') ✅'); return; }
    // Núcleo: si ya está liberada, se instala sola (sin botón). El admin ve el aviso solo mientras no la libera.
    if (lib && !mayor(v, lib) && !manual && g.CodeFixAuto) { g.CodeFixAuto(v, () => actualizarAhora()); return; }
    if (document.getElementById('upd')) return;
    const d = document.createElement('div'); d.id = 'upd'; d.className = 'actualizar';
    d.innerHTML = '<div class="grow"><b>🔄 Hay una versión nueva</b><br><small>Tienes la v' + esc(cfg.VERSION) + ' · nueva v' + esc(v) + (Api.admin() && lib !== v ? ' (solo tú: pruébala y libérala en Admin → Ajustes → Mantención)' : '') + '</small></div><button class="btn small">Actualizar ahora</button>';
    d.querySelector('button').onclick = (e) => actualizarAhora(e.target);
    document.body.appendChild(d);
  }
  function registrarSW() {
    if (!('serviceWorker' in navigator) || location.protocol === 'file:') { buscarVersion(); return; }
    navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' }).then((reg) => { swReg = reg; reg.update().catch(() => {}); }).catch(() => {});
    let recargado = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (!recargado) { recargado = true; location.reload(); } });
    buscarVersion();
    setInterval(buscarVersion, 10 * 60 * 1000);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) buscarVersion(); });
  }

  async function iniciar() {
    U.ponerIconos(document);
    Api.ajustes();
    $('btnEntrar').onclick = () => vLogin('', 'in');
    cabecera();
    Api.sb.auth.onAuthStateChange((ev) => {
      if (ev === 'PASSWORD_RECOVERY') {
        const c = modal('<h2>Crea tu contraseña nueva</h2><input type="password" id="nc" minlength="6" placeholder="Mínimo 6 caracteres"><button class="btn block" style="margin-top:12px" id="ncOk">Guardar</button>');
        c.querySelector('#ncOk').onclick = async () => {
          const { error } = await Api.sb.auth.updateUser({ password: c.querySelector('#nc').value });
          if (error) toast(U.amable(error)); else { cerrarModal(); toast('Contraseña actualizada'); Api.refrescar(); }
        };
      }
    });
    router();
    registrarSW();
    await Api.refrescar();
    cabecera();
    const a = Api.cuenta;
    if (a) {
      U.sincronizarPush(); contadores(); setInterval(contadores, 30000);
      if (!a.acepto) {
        const c = modal('<h2>Términos y privacidad</h2><p>Para seguir usando Estaciona acepta los <a href="#/legal">términos y la política de privacidad</a>.</p><button class="btn block" id="tOk">Acepto</button>');
        c.querySelector('#tOk').onclick = async () => { await Api.rpc('aceptar_terminos'); cerrarModal(); Api.refrescar(); };
      }
      if (rutaActual && !/^\/?$/.test(rutaActual)) router();
    }
  }
  g.App = { vCuenta, actualizarAhora, mayor, router, contadores, fallo, pedirLogin, denunciar, MODAL, ESTADO_EST, precioTxt, planTxt };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})(window);
