/* Estaciona · pantallas de la app (rutas con #). */
(function (g) {
  'use strict';
  const U = g.U, Api = g.Api, cfg = g.EST_CONFIG;
  const { $, esc, clp, ico, toast, modal, cerrarModal, confirmar, avatar, nombreCon, estrellas, imgMini, urlFoto, hace, fecha, hora } = U;
  const V = $('vista');
  let rutaActual = '', pollChat = null, ajustes = null;
  const COLORES_GRATIS = [['Azul', '#2563eb'], ['Negro', '#0f172a'], ['Verde', '#16a34a'], ['Rojo', '#dc2626'], ['Violeta', '#7c3aed'], ['Naranja', '#ea580c']];
  const ICONOS = ['🚗', '🏍️', '🛻', '🚙', '🚕', '🅿️', '😎', '⭐', '🔑', '🏠', '🐶', '⚽'];
  const MODAL = { hora: 'Por hora', dia: 'Por día', mes: 'Mensual' };
  const ESTADO_ARR = { pendiente: ['warn', 'Pendiente'], aceptado: ['ok', 'Aceptado'], rechazado: ['bad', 'Rechazado'], cancelado: ['', 'Cancelado'], finalizado: ['brand', 'Finalizado'] };
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
      '<div class="aviso small">🎁 Al crear tu cuenta tienes <b>7 días de Premium gratis</b>.</div>' +
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
      try { await Api.registrar(c.querySelector('#rNombre').value, c.querySelector('#rEmail').value, c.querySelector('#rClave').value); cerrarModal(); toast('¡Cuenta creada! Tienes 7 días Premium 🎁'); despuesDeIngresar(true); }
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

  /* ======================= Detalle de estacionamiento ======================= */
  async function vDetalle(id) {
    cargando();
    let d;
    try { d = await Api.rpc('estacionamiento_detalle', { p_id: id }); } catch (e) { V.innerHTML = volver() + '<div class="vacio">' + esc(e.message) + '</div>'; return; }
    const est = ESTADO_EST[d.estado] || ['', d.estado];
    const fotos = (d.fotos || []).map((f) => '<img src="' + esc(urlFoto(f)) + '" alt="Foto del estacionamiento" loading="lazy">').join('');
    const precios = [['hora', d.ph, '/hora'], ['dia', d.pd, '/día'], ['mes', d.pm, '/mes']].filter((p) => p[1])
      .map((p) => '<div class="precio"><b>' + clp(p[1]) + '</b><small>' + MODAL[p[0]] + '</small></div>').join('');
    const arr = d.mi_arriendo;
    V.innerHTML = volver('Mapa') + '<div class="galeria">' + (fotos || '<img alt="">') + '</div>' +
      '<div class="row between" style="margin-top:14px"><h1 class="grow">' + esc(d.titulo) + '</h1>' + (d.estado !== 'disponible' ? pill(est) : '') + '</div>' +
      '<div class="muted">' + ico('pin') + ' ' + esc(d.comuna || 'Santiago') + '</div>' +
      '<div class="precios">' + precios + '</div>' +
      '<div class="carac">' + g.Mapa.caracs({ t: d.techado, h: d.acceso24, sg: d.seguridad, cg: d.carga, v: d.vehiculo }).map((x) => '<span class="pill">' + esc(x) + '</span>').join('') + '</div>' +
      (d.descripcion ? '<p style="margin-top:12px;white-space:pre-line">' + esc(d.descripcion) + '</p>' : '') +
      (d.mio && !d.visible ? '<div class="aviso warn" style="margin-top:12px">⚠️ Este estacionamiento <b>no se ve en el mapa</b> porque superas el límite de tu plan. <a href="#/premium">Hazte Premium</a> para mostrar hasta 10.</div>' : '') +
      '<div class="sec-tit">Ubicación</div><div class="mini-mapa" id="mm"></div>' +
      (d.exacta ? '<div class="card" style="margin-top:8px"><b>📍 ' + esc(d.direccion) + '</b><div class="row" style="margin-top:8px"><a class="btn small sec" target="_blank" rel="noopener" href="https://www.google.com/maps/dir/?api=1&destination=' + d.lat + ',' + d.lng + '">Cómo llegar</a></div></div>'
        : '<p class="small muted">🔒 Ubicación aproximada. La dirección exacta aparece cuando el dueño acepta tu solicitud.</p>') +
      '<div class="sec-tit">Publicado por</div><a class="item" href="#/u/' + d.dueno.id + '">' + avatar(d.dueno) + '<div class="grow"><b>' + nombreCon(d.dueno) + '</b><div class="small">' + estrellas(d.dueno.calif) +
      (d.dueno.calif_n ? ' <span class="muted">(' + d.dueno.calif_n + ')</span>' : '') + ' · <span class="muted">desde ' + fecha(d.dueno.desde) + '</span></div></div>' + ico('back', 'rot') + '</a>' +
      (arr ? '<div class="aviso" style="margin-top:12px">Tu solicitud (' + esc(MODAL[arr.modalidad]) + '): ' + pill(ESTADO_ARR[arr.estado]) + ' <a href="#/mis/arriendos">Ver</a></div>' : '') +
      (d.mio ? '<div class="sec-tit">Tu estacionamiento</div><div class="card"><div class="row between"><span>Estado</span><select id="dEstado" style="width:auto"' + (d.estado === 'oculto' ? ' disabled' : '') + '>' +
        ['disponible', 'ocupado', 'pausado'].map((s) => '<option value="' + s + '"' + (d.estado === s ? ' selected' : '') + '>' + ESTADO_EST[s][1] + '</option>').join('') + '</select></div>' +
        '<p class="small muted" style="margin:8px 0 0">' + ico('eye') + ' ' + (Api.premium() ? (d.vistas || 0) + ' visitas' : 'Estadísticas de visitas: <a href="#/premium">Premium</a>') + '</p></div>' : '') +
      '<p class="small muted" style="margin-top:14px">🔒 Consejo: nunca pagues antes de ver el estacionamiento y conocer al dueño. Si algo parece estafa, denúncialo.</p>' +
      '<div class="acciones">' + (d.mio
        ? '<a class="btn grow" href="#/editar/' + d.id + '">' + ico('edit') + ' Editar</a><button class="btn sec" id="dQR" aria-label="QR">' + ico('qr') + '</button>'
        : (!arr && d.estado === 'disponible' ? '<button class="btn grow" id="dSol">Solicitar arriendo</button>' : '') +
          '<button class="btn sec' + (arr || d.estado !== 'disponible' ? ' grow' : '') + '" id="dChat">' + ico('chat') + (arr || d.estado !== 'disponible' ? ' Contactar' : '') + '</button>' +
          '<button class="btn sec" id="dFav" aria-label="Favorito" style="' + (d.favorito ? 'color:#e11d48' : '') + '">' + ico('heart') + '</button>' +
          '<button class="btn sec" id="dQR" aria-label="QR">' + ico('qr') + '</button><button class="btn sec" id="dDen" aria-label="Denunciar">' + ico('flag') + '</button>') + '</div>';
    U.ponerIconos(V);
    g.Mapa.mini($('mm'), d.lat, d.lng, d.exacta);
    const url = U.enlace('#/e/' + d.id);
    $('dQR').onclick = () => U.mostrarQR(d.titulo, 'Escanea para ver este estacionamiento en Estaciona', url, Api.premium() ? Api.cuenta.color : '#000');
    if (d.mio) {
      $('dEstado').onchange = async (e) => { try { await Api.rpc('estado_estacionamiento', { p_id: d.id, p_estado: e.target.value }); toast('Estado actualizado'); g.Mapa.recargar(); } catch (er) { fallo(er); } };
      return;
    }
    if ($('dSol')) $('dSol').onclick = () => solicitar(d);
    $('dChat').onclick = () => contactar(d.dueno.id);
    $('dFav').onclick = async () => {
      try { const si = await Api.rpc('favorito', { p_id: d.id }); $('dFav').style.color = si ? '#e11d48' : ''; toast(si ? 'Guardado en favoritos ❤️' : 'Quitado de favoritos'); }
      catch (e) { fallo(e); }
    };
    $('dDen').onclick = () => denunciar('estacionamiento', d.id, d.titulo);
  }

  function solicitar(d) {
    const ops = [['hora', d.ph], ['dia', d.pd], ['mes', d.pm]].filter((x) => x[1]);
    const hoy = new Date(); hoy.setMinutes(hoy.getMinutes() - hoy.getTimezoneOffset());
    const c = modal('<h2>Solicitar arriendo</h2><p class="muted small">' + esc(d.titulo) + '</p><label>Modalidad</label>' +
      ops.map((o, i) => '<label class="check"><input type="radio" name="sMod" value="' + o[0] + '"' + (i === 0 ? ' checked' : '') + '> ' + MODAL[o[0]] + ' · <b>' + clp(o[1]) + '</b></label>').join('') +
      '<label>¿Desde cuándo?</label><input type="date" id="sDesde" value="' + hoy.toISOString().slice(0, 10) + '" min="' + hoy.toISOString().slice(0, 10) + '">' +
      '<label>Mensaje para el dueño (opcional)</label><textarea id="sNota" maxlength="300" placeholder="Ej: Hola, tengo un auto mediano y lo necesito de lunes a viernes."></textarea>' +
      '<p class="small muted">El pago se acuerda directo con el dueño. Estaciona no cobra ni recibe dinero.</p>' +
      '<button class="btn block" id="sOk">Enviar solicitud</button>');
    c.querySelector('#sOk').onclick = async (e) => {
      e.target.disabled = true;
      try {
        await Api.rpc('solicitar_arriendo', { p_id: d.id, p_modalidad: c.querySelector('input[name=sMod]:checked').value, p_desde: c.querySelector('#sDesde').value || null, p_nota: c.querySelector('#sNota').value });
        Api.empujar(); cerrarModal(); toast('¡Solicitud enviada! Te avisaremos cuando responda'); vDetalle(d.id); Api.refrescar();
      } catch (er) { e.target.disabled = false; cerrarModal(); fallo(er); }
    };
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
      '<div class="row" style="margin-top:14px;justify-content:center">' + (mio ? '<a class="btn" href="#/perfil">Editar mi perfil</a>'
        : '<button class="btn" id="pChat">' + ico('chat') + ' Contactar</button><button class="btn sec" id="pBlq">' + ico('ban') + ' ' + (p.bloqueado ? 'Desbloquear' : 'Bloquear') + '</button><button class="btn sec" id="pDen" aria-label="Denunciar">' + ico('flag') + '</button>') +
      '<button class="btn sec" id="pQR" aria-label="QR">' + ico('qr') + '</button></div></div>' +
      '<div class="sec-tit">Estacionamientos (' + p.estacionamientos.length + ')</div>' +
      (p.estacionamientos.length ? p.estacionamientos.map((e) => '<a class="item" href="#/e/' + e.id + '">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div></div></a>').join('') : '<div class="vacio">Aún no publica estacionamientos</div>') +
      '<div class="sec-tit">Opiniones</div>' + (p.opiniones.length ? p.opiniones.map((o) => '<div class="card"><div class="row between"><b>' + esc(o.autor) + '</b><span class="estrellas">' + '★'.repeat(o.estrellas) + '<span class="muted">' + '★'.repeat(5 - o.estrellas) + '</span></span></div>' +
        (o.comentario ? '<p style="margin:6px 0 0">' + esc(o.comentario) + '</p>' : '') + '<div class="small muted">' + hace(o.fecha) + '</div></div>').join('') : '<div class="vacio">Sin opiniones todavía</div>');
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
    let e = { fotos: [], vehiculo: 'auto' };
    if (id) {
      cargando();
      try { e = await Api.rpc('estacionamiento_detalle', { p_id: id }); } catch (er) { V.innerHTML = '<div class="vacio">' + esc(er.message) + '</div>'; return; }
      if (!e.mio) { location.hash = '#/e/' + id; return; }
    } else if (a.uso.publicados >= a.lim.publicar) {
      V.innerHTML = '<h1>Publicar estacionamiento</h1><div class="card center"><div style="font-size:48px">⭐</div><h2>Llegaste al límite de tu plan</h2>' +
        '<p class="muted">Con el plan Gratis puedes publicar ' + a.lim.publicar + ' estacionamiento. Con <b>Premium</b> publicas hasta <b>10</b>, con pin destacado y estadísticas.</p>' +
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
          f.ruta = await U.subirFoto(f.file, 'fotos', { lado: 1280, calidad: 0.72, conMini: true });
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

  /* ======================= Mis cosas ======================= */
  async function vMis(tab) {
    tab = tab || 'publicados';
    const tabs = [['publicados', 'Mis estacionamientos'], ['solicitudes', 'Solicitudes recibidas'], ['arriendos', 'Mis arriendos'], ['favoritos', 'Favoritos']];
    V.innerHTML = '<h1>Mis cosas</h1><div class="tabs">' + tabs.map((t) => '<a href="#/mis/' + t[0] + '" class="' + (t[0] === tab ? 'on' : '') + '">' + t[1] + '</a>').join('') + '</div><div id="misC"><div class="spin"></div></div>';
    const C = $('misC'), a = Api.cuenta;
    try {
      if (tab === 'publicados') {
        const r = await Api.rpc('mis_estacionamientos');
        C.innerHTML = '<div class="row between"><span class="muted small">Usas ' + r.length + ' de ' + a.lim.publicar + ' publicaciones</span><a class="btn small" href="#/publicar">' + ico('plus') + ' Publicar</a></div>' +
          '<div class="barra"><i style="width:' + Math.min(100, r.length / a.lim.publicar * 100) + '%"></i></div>' +
          (!Api.premium() ? '<a class="aviso" style="display:block;margin:10px 0;color:var(--ink)" href="#/premium">⭐ <b>Premium:</b> publica hasta 10, pin dorado destacado y estadísticas de visitas.</a>' : '') +
          (r.length ? r.map((e) => '<div class="card" style="margin-top:10px"><a class="row" href="#/e/' + e.id + '" style="color:var(--ink)">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div>' +
              '<div style="margin-top:4px">' + pill(ESTADO_EST[e.estado]) + (!e.visible ? ' <span class="pill warn">No visible: supera tu plan</span>' : '') + '</div></div></a>' +
              (e.stats ? '<div class="row small muted" style="margin-top:8px;gap:14px">' + ico('eye') + ' ' + e.stats.vistas + ' visitas · ❤️ ' + e.stats.favoritos + ' · 📩 ' + e.stats.solicitudes + ' solicitudes</div>'
                : '<div class="small muted" style="margin-top:8px">📊 Estadísticas: <a href="#/premium">solo Premium</a></div>') +
              '<div class="row" style="margin-top:10px"><select data-est="' + e.id + '" class="grow"' + (e.estado === 'oculto' ? ' disabled' : '') + '>' + ['disponible', 'ocupado', 'pausado'].map((s) => '<option value="' + s + '"' + (e.estado === s ? ' selected' : '') + '>' + ESTADO_EST[s][1] + '</option>').join('') + '</select>' +
              '<a class="btn sec small" href="#/editar/' + e.id + '">' + ico('edit') + ' Editar</a></div></div>').join('')
            : '<div class="vacio">' + ico('car') + '<p>¿Tienes un estacionamiento sin usar? Publícalo y gana plata extra.</p><a class="btn" href="#/publicar">Publicar ahora</a></div>');
        C.onchange = async (ev) => {
          const s = ev.target.closest('[data-est]'); if (!s) return;
          try { await Api.rpc('estado_estacionamiento', { p_id: s.dataset.est, p_estado: s.value }); toast('Estado actualizado'); g.Mapa.recargar(); } catch (er) { fallo(er); }
        };
      } else if (tab === 'favoritos') {
        const r = await Api.rpc('mis_favoritos');
        C.innerHTML = '<p class="muted small">' + r.length + ' de ' + (Api.premium() ? 'ilimitados' : a.lim.favoritos) + ' favoritos</p>' +
          (r.length ? r.map((e) => '<a class="item" href="#/e/' + e.id + '">' + imgMini(e.foto) + '<div class="grow"><b>' + esc(e.titulo) + '</b><div class="small muted">' + esc(e.comuna || '') + '</div><div class="small">' + esc(precioTxt(e)) + '</div></div>' + (e.estado !== 'disponible' ? pill(ESTADO_EST[e.estado]) : '') + '</a>').join('')
            : '<div class="vacio">' + ico('heart') + '<p>Guarda estacionamientos con ❤️ para encontrarlos rápido.</p></div>');
      } else {
        const dueno = tab === 'solicitudes';
        const r = (await Api.rpc('mis_arriendos')).filter((x) => x.soy_dueno === dueno);
        C.innerHTML = (!dueno ? '<p class="muted small">Arriendos activos: ' + a.uso.arrendando + ' de ' + a.lim.arrendar + (Api.premium() ? '' : ' · <a href="#/premium">Premium: hasta 10</a>') + '</p>' : '') +
          (r.length ? r.map((x) => tarjetaArriendo(x, dueno)).join('')
            : '<div class="vacio">' + ico(dueno ? 'bell' : 'car') + '<p>' + (dueno ? 'Aún no recibes solicitudes.' : 'Aún no arriendas. Busca en el mapa y solicita.') + '</p>' + (dueno ? '' : '<a class="btn" href="#/">Ir al mapa</a>') + '</div>');
        C.onclick = (ev) => accionArriendo(ev, tab);
      }
      U.ponerIconos(C);
    } catch (e) { C.innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; }
  }
  function tarjetaArriendo(x, dueno) {
    const b = [];
    if (dueno && x.estado === 'pendiente') b.push('<button class="btn ok small" data-a="aceptar" data-id="' + x.id + '">Aceptar</button>', '<button class="btn sec small" data-a="rechazar" data-id="' + x.id + '">Rechazar</button>');
    if (x.estado === 'aceptado') b.push('<button class="btn small" data-a="finalizar" data-id="' + x.id + '">Finalizar</button>');
    if (['pendiente', 'aceptado'].includes(x.estado) && !(dueno && x.estado === 'pendiente')) b.push('<button class="btn line small" data-a="cancelar" data-id="' + x.id + '">Cancelar</button>');
    if (x.estado === 'finalizado' && !x.calificado) b.push('<button class="btn gold small" data-a="calificar" data-id="' + x.id + '" data-n="' + esc(x.otro.nombre) + '">⭐ Calificar</button>');
    b.push('<button class="btn sec small" data-a="chat" data-u="' + x.otro.id + '">' + ico('chat') + ' Chat</button>');
    return '<div class="card" style="margin-top:10px"><a class="row" href="#/e/' + x.est.id + '" style="color:var(--ink)">' + imgMini(x.est.foto, 'thumb sm') + '<div class="grow"><b class="ell" style="display:block">' + esc(x.est.titulo) + '</b>' +
      '<div class="small muted">' + MODAL[x.modalidad] + (x.desde ? ' · desde ' + fecha(x.desde) : '') + ' · ' + hace(x.creado) + '</div></div>' + pill(ESTADO_ARR[x.estado]) + '</a>' +
      '<a class="row" href="#/u/' + x.otro.id + '" style="margin-top:10px;color:var(--ink)">' + avatar(x.otro, 'xs') + '<span class="small"><b>' + nombreCon(x.otro) + '</b> · ' + estrellas(x.otro.calif) + '</span></a>' +
      (x.nota ? '<p class="small" style="background:var(--card2);padding:8px 10px;border-radius:10px;margin:8px 0 0">“' + esc(x.nota) + '”</p>' : '') +
      '<div class="row wrap" style="margin-top:10px">' + b.join('') + '</div></div>';
  }
  async function accionArriendo(ev, tab) {
    const b = ev.target.closest('[data-a]'); if (!b) return;
    const a = b.dataset.a, id = b.dataset.id;
    try {
      if (a === 'chat') return contactar(b.dataset.u);
      if (a === 'aceptar') { if (!await confirmar('¿Aceptar esta solicitud? La persona verá la dirección exacta.', 'Aceptar')) return; await Api.rpc('responder_arriendo', { p_id: id, p_aceptar: true }); toast('Aceptado ✅'); }
      if (a === 'rechazar') { if (!await confirmar('¿Rechazar esta solicitud?', 'Rechazar', true)) return; await Api.rpc('responder_arriendo', { p_id: id, p_aceptar: false }); toast('Rechazada'); }
      if (a === 'finalizar') { if (!await confirmar('¿Marcar este arriendo como finalizado?', 'Finalizar')) return; await Api.rpc('cerrar_arriendo', { p_id: id, p_accion: 'finalizar' }); toast('Finalizado. ¡Ahora califica! ⭐'); }
      if (a === 'cancelar') { if (!await confirmar('¿Cancelar este arriendo?', 'Sí, cancelar', true)) return; await Api.rpc('cerrar_arriendo', { p_id: id, p_accion: 'cancelar' }); toast('Cancelado'); }
      if (a === 'calificar') return calificar(id, b.dataset.n, tab);
      Api.empujar(); await Api.refrescar(); g.Mapa.recargar(); vMis(tab); contadores();
    } catch (e) { fallo(e); }
  }
  function calificar(id, nombre, tab) {
    let n = 5;
    const c = modal('<div class="center"><h2>¿Cómo te fue con ' + esc(nombre) + '?</h2><div id="cEst" style="font-size:40px;letter-spacing:6px;cursor:pointer;color:var(--gold)">★★★★★</div></div>' +
      '<label>Comentario (opcional)</label><textarea id="cCom" maxlength="200" placeholder="Cuenta tu experiencia"></textarea><button class="btn block" style="margin-top:12px" id="cOk">Enviar calificación</button>');
    const pintar = () => { c.querySelector('#cEst').innerHTML = '★'.repeat(n) + '<span style="color:var(--line)">' + '★'.repeat(5 - n) + '</span>'; };
    c.querySelector('#cEst').onclick = (e) => { const r = e.currentTarget.getBoundingClientRect(); n = Math.min(5, Math.max(1, Math.ceil((e.clientX - r.left) / r.width * 5))); pintar(); };
    c.querySelector('#cOk').onclick = async () => {
      try { await Api.rpc('calificar', { p_arriendo: id, p_estrellas: n, p_comentario: c.querySelector('#cCom').value }); cerrarModal(); toast('¡Gracias por calificar!'); vMis(tab); } catch (e) { toast(e.message); }
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
  async function vCuenta() {
    await Api.refrescar();
    const a = Api.cuenta; if (!a) { router(); return; }
    const ver = a.verificado ? '<span class="pill ok">' + ico('shield') + ' Verificado</span>'
      : a.verif_estado === 'pendiente' ? '<span class="pill warn">🕐 Verificación en revisión</span>'
        : '<a class="pill bad" href="#/verificar">Sin verificar · Verificar ahora</a>';
    const tema = document.documentElement.dataset.theme || '';
    V.innerHTML = '<div class="card"><div class="row">' + avatar(a, 'lg') + '<div class="grow"><h2 style="margin:0">' + nombreCon(a) + '</h2><div class="small muted ell">' + esc(a.email) + '</div>' +
      '<div class="row wrap" style="margin-top:6px">' + planTxt(a) + ver + '</div></div></div>' +
      '<div class="row" style="margin-top:12px"><a class="btn sec grow" href="#/perfil">' + ico('edit') + ' Editar perfil</a><a class="btn sec" href="#/u/' + a.id + '" aria-label="Ver mi perfil">' + ico('eye') + '</a><button class="btn sec" id="cQR" aria-label="Mi QR">' + ico('qr') + '</button></div></div>' +
      (a.suspendido ? '<div class="aviso bad" style="margin-top:12px">Tu cuenta está suspendida. Escribe a soporte.</div>' : '') +
      (!a.verificado && a.verif_estado === 'rechazada' ? '<div class="aviso bad" style="margin-top:12px">Tu verificación fue rechazada: ' + esc(a.verif_motivo || '') + '. <a href="#/verificar">Enviar de nuevo</a></div>' : '') +
      (a.admin ? '<a class="btn dark block" style="margin-top:12px" href="#/admin">' + ico('server') + ' Panel de administración</a>' : '') +
      '<div class="sec-tit">Mi plan</div><div class="card">' +
      '<div class="row between small"><span>Estacionamientos publicados</span><b>' + a.uso.publicados + ' / ' + a.lim.publicar + '</b></div><div class="barra"><i style="width:' + Math.min(100, a.uso.publicados / a.lim.publicar * 100) + '%"></i></div>' +
      '<div class="row between small" style="margin-top:10px"><span>Arriendos activos</span><b>' + a.uso.arrendando + ' / ' + a.lim.arrendar + '</b></div><div class="barra"><i style="width:' + Math.min(100, a.uso.arrendando / a.lim.arrendar * 100) + '%"></i></div>' +
      (a.admin ? '' : '<a class="btn ' + (a.premium ? 'sec' : 'gold') + ' block" style="margin-top:14px" href="#/premium">' + (a.premium ? 'Ver mi Premium' : '⭐ Hazte Premium') + '</a>') + '</div>' +
      '<div class="sec-tit">Alerta de zona ' + (a.premium ? '' : '<span class="pill gold">Premium</span>') + '</div><div class="card' + (a.premium ? '' : ' candado') + '">' +
      '<p class="small" style="margin-top:0">Te avisamos cuando publiquen un estacionamiento cerca de la zona que elijas.</p>' +
      (a.alerta ? '<p class="small"><b>Activa:</b> radio de ' + a.alerta.km + ' km.</p>' : '') +
      '<div class="row"><select id="aKm" class="grow"><option value="0.5">500 m</option><option value="1">1 km</option><option value="2">2 km</option><option value="5">5 km</option></select>' +
      '<button class="btn small" id="aSet">Usar zona del mapa</button>' + (a.alerta ? '<button class="btn sec small" id="aDel">Quitar</button>' : '') + '</div></div>' +
      '<div class="sec-tit">Ajustes</div><div class="card stack">' +
      '<div class="row between"><span>' + ico('bell') + ' Notificaciones en este celular</span><button class="btn small sec" id="cPush">Activar</button></div>' +
      '<div class="row between"><span>🌓 Apariencia</span><select id="cTema" style="width:auto"><option value="">Automática</option><option value="light">Clara</option><option value="dark">Oscura</option></select></div>' +
      '<div class="row between" id="cInstWrap" hidden><span>' + ico('download') + ' Instalar la app</span><button class="btn small" id="cInst">Instalar</button></div></div>' +
      '<div class="sec-tit">Ayuda</div><div class="card stack"><a href="#/chat" id="cSop" class="row" style="color:var(--ink)">' + ico('help') + ' Soporte (chat)</a>' +
      '<a href="#/legal" class="row" style="color:var(--ink)">' + ico('shield') + ' Términos y privacidad</a>' +
      '<button class="row btn line" id="cSalir" style="justify-content:flex-start">' + ico('logout') + ' Cerrar sesión</button></div>' +
      (a.admin ? '' : '<button class="btn line block small" id="cBorrar" style="margin-top:20px;color:var(--bad)">Eliminar mi cuenta y mis datos</button>') +
      '<p class="pie">© ' + new Date().getFullYear() + ' ' + esc(cfg.MARCA) + ' · ' + esc(cfg.AUTOR) + '<br>Versión ' + esc(cfg.VERSION) + '</p>';
    U.ponerIconos(V);
    $('cTema').value = tema;
    $('cTema').onchange = (e) => { U.aplicarTema(e.target.value); location.reload(); };
    $('cQR').onclick = () => U.mostrarQR(a.nombre, 'Mi perfil en Estaciona', U.enlace('#/u/' + a.id), a.premium ? a.color : '#000');
    if (a.alerta) $('aKm').value = String(a.alerta.km);
    $('aSet').onclick = async () => {
      if (!a.premium) { location.hash = '#/premium'; return; }
      const c = JSON.parse(sessionStorage.getItem('est:vista') || 'null');
      const ll = c ? c.c : { lat: cfg.CENTRO[0], lng: cfg.CENTRO[1] };
      try { Api.guardar(await Api.rpc('guardar_alerta', { p_lat: ll.lat, p_lng: ll.lng, p_km: +$('aKm').value })); toast('Alerta activada en la zona que estabas viendo en el mapa'); vCuenta(); } catch (e) { fallo(e); }
    };
    if ($('aDel')) $('aDel').onclick = async () => { Api.guardar(await Api.rpc('guardar_alerta', { p_lat: null, p_lng: null, p_km: null })); vCuenta(); };
    U.pushActivo().then((on) => { if (on) { $('cPush').textContent = 'Activas ✓'; $('cPush').disabled = true; } });
    $('cPush').onclick = async (e) => { e.target.disabled = true; try { await U.activarPush(); e.target.textContent = 'Activas ✓'; toast('Notificaciones activadas 🔔'); } catch (er) { e.target.disabled = false; toast(er.message); } };
    if (instalar) { $('cInstWrap').hidden = false; $('cInst').onclick = () => { instalar.prompt(); instalar = null; $('cInstWrap').hidden = true; }; }
    else if (/iPhone|iPad/.test(navigator.userAgent) && !navigator.standalone) {
      $('cInstWrap').hidden = false; $('cInst').textContent = 'Cómo'; $('cInst').onclick = () => modal('<h2>Instalar en iPhone</h2><p>1. Abre esta página en <b>Safari</b>.<br>2. Toca <b>Compartir</b> (cuadrado con flecha).<br>3. Elige <b>Agregar a inicio</b>.</p>');
    }
    if (!a.admin) $('cSop').onclick = async (e) => { e.preventDefault(); try { location.hash = '#/chat/' + await Api.rpc('soporte'); } catch (er) { fallo(er); } };
    $('cSalir').onclick = async () => { await Api.salir(); toast('Sesión cerrada'); location.hash = '#/'; };
    if ($('cBorrar')) $('cBorrar').onclick = async () => {
      if (!await confirmar('¿Eliminar tu cuenta? Se borran tu perfil, tus estacionamientos, fotos y mensajes. No se puede deshacer.', 'Eliminar para siempre', true)) return;
      try { await Api.funcion('eliminar_usuario'); await Api.salir(); toast('Tu cuenta fue eliminada'); location.hash = '#/'; } catch (e) { toast(e.message); }
    };
  }

  function vEditarPerfil() {
    const a = Api.cuenta;
    const st = { color: a.color, icono: a.icono || '', avatar: a.avatar, file: null };
    V.innerHTML = volver() + '<h1>Editar perfil</h1><div class="card"><div class="row"><span id="ePrev"></span><div class="grow"><button class="btn sec small" id="eFoto">' + ico('cam') + ' Cambiar foto</button>' +
      (a.avatar ? ' <button class="btn line small" id="eQuitar">Quitar foto</button>' : '') + '<input type="file" id="eFile" accept="image/*" hidden></div></div>' +
      '<label>O elige un ícono</label><div class="iconos" id="eIcos">' + ICONOS.map((i) => '<button type="button" data-ic="' + i + '">' + i + '</button>').join('') + '</div>' +
      '<label>Nombre</label><input id="eNom" maxlength="60" value="' + esc(a.nombre) + '"><label>Comuna</label><input id="eCom" maxlength="40" value="' + esc(a.comuna || '') + '">' +
      '<label>Sobre mí</label><textarea id="eBio" maxlength="280" placeholder="Cuéntale a la comunidad quién eres">' + esc(a.bio || '') + '</textarea>' +
      '<label>Color del perfil</label><div class="colores" id="eCols">' + COLORES_GRATIS.map((c) => '<button type="button" class="color-op" title="' + c[0] + '" data-c="' + c[1] + '" style="background:' + c[1] + '"></button>').join('') + '</div>' +
      '<div class="' + (a.premium ? '' : 'candado') + '" style="margin-top:12px;padding:12px;border:1px dashed var(--line);border-radius:12px"><div class="row"><input type="color" id="eRGB" value="' + esc(a.color) + '"' + (a.premium ? '' : ' disabled') + '>' +
      '<div><b>Color libre (RGB)</b><div class="small muted">' + (a.premium ? 'Elige cualquier color.' : 'Cualquier color que quieras con <a href="#/premium">Premium</a>.') + '</div></div></div></div>' +
      '<button class="btn block" id="eOk" style="margin-top:16px">Guardar</button></div>';
    U.ponerIconos(V);
    const prev = () => {
      $('ePrev').innerHTML = st.file ? '<span class="av lg"><img src="' + URL.createObjectURL(st.file) + '"></span>' : avatar({ nombre: $('eNom').value, avatar: st.avatar, icono: st.icono, color: st.color, premium: a.premium }, 'lg');
      $('eIcos').querySelectorAll('button').forEach((b) => b.classList.toggle('on', b.dataset.ic === st.icono));
      $('eCols').querySelectorAll('button').forEach((b) => b.classList.toggle('on', b.dataset.c === st.color));
    };
    prev();
    $('eFoto').onclick = () => $('eFile').click();
    $('eFile').onchange = () => { st.file = $('eFile').files[0] || null; prev(); };
    if ($('eQuitar')) $('eQuitar').onclick = () => { st.avatar = null; st.file = null; prev(); };
    $('eIcos').onclick = (e) => { const b = e.target.closest('[data-ic]'); if (!b) return; st.icono = st.icono === b.dataset.ic ? '' : b.dataset.ic; st.avatar = null; st.file = null; prev(); };
    $('eCols').onclick = (e) => { const b = e.target.closest('[data-c]'); if (!b) return; st.color = b.dataset.c; U.aplicarColor(st.color); prev(); };
    $('eRGB').oninput = (e) => { st.color = e.target.value; U.aplicarColor(st.color); prev(); };
    $('eOk').onclick = async (e) => {
      e.target.disabled = true;
      try {
        if (st.file) { e.target.textContent = 'Subiendo foto…'; st.avatar = await U.subirFoto(st.file, 'fotos', { lado: 320, calidad: 0.78, cuadrado: true }); }
        Api.guardar(await Api.rpc('guardar_perfil', { p_nombre: $('eNom').value, p_comuna: $('eCom').value, p_bio: $('eBio').value, p_icono: st.icono, p_color: st.color, p_avatar: st.avatar }));
        Api.empujar(); toast('Perfil guardado'); location.hash = '#/cuenta';
      } catch (er) { U.aplicarColor(a.color); fallo(er); e.target.disabled = false; e.target.textContent = 'Guardar'; }
    };
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
        const subir = async (k, campo, n) => { b.textContent = 'Subiendo foto ' + n + ' de 3…'; fotos[k] = await U.subirFoto($(campo).files[0], 'privado', { lado: 1600, calidad: 0.78 }); };
        await subir('f', 'vF', 1); await subir('r', 'vR', 2); await subir('s', 'vS', 3);
        b.textContent = 'Enviando…';
        Api.guardar(await Api.rpc('enviar_verificacion', { p_rut: $('vRut').value, p_serie: serie, p_frente: fotos.f, p_reverso: fotos.r, p_selfie: fotos.s }));
        Api.empujar(); toast('¡Listo! Revisaremos tus datos pronto'); vVerificar();
      } catch (er) { toast(er.message); b.disabled = false; b.textContent = 'Enviar verificación'; }
    };
  }

  /* ======================= Premium ======================= */
  async function vPremium() {
    const aj = await ajustesPub(), a = Api.cuenta;
    const meses = +aj.meses_por_pago;
    const filas = [['Publicar estacionamientos', '1', '10'], ['Arriendos activos a la vez', '1', '10'], ['Fotos por estacionamiento', '3', '8'], ['Favoritos', '3', 'Ilimitados'],
      ['Pin dorado destacado en el mapa', '—', '✓'], ['Aparecer primero en la lista', '—', '✓'], ['Estadísticas (visitas, solicitudes)', '—', '✓'], ['Alerta "nuevo estacionamiento cerca"', '—', '✓'],
      ['Color libre del perfil (RGB)', '6 colores', 'Cualquiera'], ['QR con tu color', '—', '✓'], ['Sello PRO y marco dorado', '—', '✓']];
    V.innerHTML = volver() + '<div class="card center" style="background:linear-gradient(160deg,#0b1020,#1e3a8a);color:#fff;border:0"><div style="font-size:46px">⭐</div><h1>Estaciona Premium</h1>' +
      '<p style="opacity:.85">Publica más, destaca en el mapa y arrienda sin límites.</p><div style="font-size:34px;font-weight:900">' + clp(aj.precio || 4900) + '</div>' +
      '<div class="small" style="opacity:.8">Pago único · ' + (meses === 0 ? 'Premium de por vida' : meses + (meses === 1 ? ' mes' : ' meses') + ' de Premium') + '</div></div>' +
      (a && a.premium && !a.admin ? '<div class="aviso" style="margin-top:12px">' + planTxt(a) + (a.premium_hasta && !/infinity/i.test(String(a.premium_hasta)) ? ' Vence el ' + fecha(a.premium_hasta) + '.' : '') + '</div>' : '') +
      '<table class="tabla card" style="margin-top:12px;padding:0"><tr><th></th><th>Gratis</th><th style="color:var(--gold)">Premium</th></tr>' +
      filas.map((f) => '<tr><td>' + f[0] + '</td><td>' + f[1] + '</td><td><b>' + f[2] + '</b></td></tr>').join('') + '</table>' +
      '<div class="stack" style="margin-top:14px"><button class="btn gold block" id="prComprar">Comprar Premium</button><button class="btn sec block" id="prPague">Ya pagué: avisar al administrador</button></div>' +
      '<div class="sec-tit">¿Tienes una key?</div><div class="row"><input id="prKey" placeholder="EST-XXXX-XXXX" autocapitalize="characters" class="grow"><button class="btn" id="prCanje">' + ico('key') + ' Activar</button></div>' +
      '<p class="small muted" style="margin-top:14px">Cuando pagues, el administrador activa tu Premium o te entrega una key para activarlo aquí.</p>';
    U.ponerIconos(V);
    $('prComprar').onclick = () => {
      if (!Api.logueado()) return pedirLogin('Crea tu cuenta para comprar Premium');
      if (!aj.link_pago) { toast('El link de pago estará disponible pronto. Escribe a soporte.'); return; }
      window.open(aj.link_pago, '_blank', 'noopener');
    };
    $('prPague').onclick = async () => {
      if (!Api.logueado()) return pedirLogin();
      const nota = await U.pedirTexto('Avisar mi pago', 'Ej: Pagué con Mercado Pago a nombre de Camila Rojas', 'Avisar');
      if (nota == null) return;
      try { await Api.rpc('ya_pague', { p_nota: nota }); Api.empujar(); toast('¡Aviso enviado! Te activaremos pronto'); } catch (e) { toast(e.message); }
    };
    $('prCanje').onclick = async () => {
      if (!Api.logueado()) return pedirLogin();
      try { Api.guardar(await Api.rpc('canjear_key', { p_key: $('prKey').value })); toast('¡Premium activado! ⭐'); vPremium(); } catch (e) { toast(e.message); }
    };
  }

  /* ======================= Avisos ======================= */
  async function vAvisos() {
    V.innerHTML = '<h1>Avisos</h1><div id="avC"><div class="spin"></div></div>';
    try {
      const r = await Api.rpc('mis_notificaciones');
      $('avC').innerHTML = r.length ? r.map((n) => '<a class="item" href="' + esc(n.url || '#/avisos') + '" style="' + (n.leida ? '' : 'border-color:var(--brand)') + '"><div class="grow"><b>' + esc(n.titulo) + '</b><div class="small">' + esc(n.cuerpo || '') + '</div><div class="small muted">' + hace(n.fecha) + '</div></div></a>').join('')
        : '<div class="vacio">' + ico('bell') + '<p>No tienes avisos.</p></div>';
      U.ponerIconos($('avC'));
      if (r.some((n) => !n.leida)) { await Api.rpc('marcar_leidas'); contadores(); }
    } catch (e) { $('avC').innerHTML = '<div class="vacio">' + esc(e.message) + '</div>'; }
  }

  /* ======================= Términos ======================= */
  function vLegal() {
    V.innerHTML = volver() + '<h1>Términos y privacidad</h1><div class="card small" style="line-height:1.6">' +
      '<h3>1. Qué es Estaciona</h3><p>Estaciona es una plataforma que conecta a personas que ofrecen estacionamientos en arriendo con personas que los buscan. Estaciona <b>no es parte del contrato de arriendo</b>, no cobra comisión por el arriendo ni recibe pagos entre usuarios: el precio, la forma de pago y las condiciones se acuerdan directamente entre las partes.</p>' +
      '<h3>2. Cuenta y verificación</h3><p>Para publicar, arrendar o chatear debes verificar tu identidad con tu RUT, el número de documento de tu cédula y fotos de la cédula y una selfie. Un RUT solo puede tener una cuenta. Entregar datos falsos o suplantar a otra persona es causal de eliminación de la cuenta y puede constituir delito.</p>' +
      '<h3>3. Publicaciones</h3><p>Quien publica declara que el estacionamiento le pertenece o que cuenta con autorización para arrendarlo (incluido el reglamento de copropiedad, si aplica), y que la información y las fotos son verdaderas. El administrador puede ocultar o eliminar publicaciones que no cumplan.</p>' +
      '<h3>4. Seguridad y conducta</h3><p>No pagues antes de ver el estacionamiento y conocer al dueño. El chat permite 3 mensajes seguidos y luego hay que esperar la respuesta, para evitar spam. Puedes bloquear y denunciar; las denuncias requieren evidencia y son revisadas por el administrador. Las denuncias falsas pueden llevar a la suspensión.</p>' +
      '<h3>5. Planes</h3><p>El plan Gratis permite 1 publicación y 1 arriendo activo. El plan Premium (pago único según el precio publicado) amplía estos límites y suma funciones. Toda cuenta nueva recibe 7 días de prueba Premium. Si Premium vence, las publicaciones que superen el límite dejan de mostrarse en el mapa (no se borran).</p>' +
      '<h3>6. Privacidad (Ley 19.628 y Ley 21.719)</h3><p>Tratamos tus datos solo para operar el servicio. Tu RUT, número de documento, correo y teléfono <b>nunca se muestran</b> a otros usuarios. Las fotos de la cédula y la selfie se eliminan apenas se revisa la verificación. La dirección exacta del estacionamiento solo la ve quien tiene un arriendo aceptado. Los mensajes se borran automáticamente a los 30 días. Puedes eliminar tu cuenta y tus datos en cualquier momento desde Cuenta. Para ejercer tus derechos de acceso, rectificación, supresión u oposición, escribe a soporte en la app.</p>' +
      '<h3>7. Responsabilidad</h3><p>Estaciona actúa como intermediario de contacto y no responde por el estado de los estacionamientos ni por los acuerdos entre usuarios, sin perjuicio de colaborar con las autoridades cuando corresponda.</p>' +
      '<p class="muted">© ' + new Date().getFullYear() + ' ' + esc(cfg.MARCA) + ' · ' + esc(cfg.AUTOR) + '. Todos los derechos reservados.</p></div>';
    U.ponerIconos(V);
  }

  /* ======================= Contadores y cabecera ======================= */
  async function contadores() {
    if (!Api.logueado() || document.hidden) return;
    try {
      const c = await Api.rpc('contadores');
      const pon = (id, n) => { const b = $(id); b.textContent = n > 99 ? '99+' : n; b.classList.toggle('on', n > 0); };
      pon('bChat', c.mensajes); pon('bAvisos', c.avisos); pon('bMis', c.solicitudes);
    } catch (e) { /* sin red */ }
  }
  function cabecera() {
    const a = Api.cuenta;
    $('btnEntrar').hidden = !!a; $('miniAv').hidden = !a; $('btnAvisos').hidden = !a; $('btnAdmin').hidden = !(a && a.admin);
    if (a) $('miniAv').innerHTML = avatar(a, 'xs');
    else ['bChat', 'bAvisos', 'bMis'].forEach((i) => $(i).classList.remove('on'));
  }

  /* ======================= Router ======================= */
  const RUTAS = [
    [/^\/?$/, 'mapa', null, false],
    [/^\/e\/([0-9a-f-]{36})$/, 'mapa', vDetalle, 'Crea tu cuenta para ver los detalles y arrendar'],
    [/^\/u\/([0-9a-f-]{36})$/, '', vPerfil, 'Crea tu cuenta para ver perfiles'],
    [/^\/publicar$/, 'publicar', () => vPublicar(), 'Crea tu cuenta para publicar tu estacionamiento'],
    [/^\/editar\/([0-9a-f-]{36})$/, 'publicar', vPublicar, true],
    [/^\/mis(?:\/(\w+))?$/, 'mis', vMis, 'Crea tu cuenta para arrendar o publicar'],
    [/^\/chat$/, 'chat', vChats, 'Crea tu cuenta para chatear'],
    [/^\/chat\/([0-9a-f-]{36})$/, 'chat', vConversacion, true],
    [/^\/cuenta$/, 'cuenta', vCuenta, 'Ingresa o crea tu cuenta'],
    [/^\/perfil$/, 'cuenta', vEditarPerfil, true],
    [/^\/verificar$/, 'cuenta', vVerificar, 'Crea tu cuenta para verificarte'],
    [/^\/premium$/, 'cuenta', vPremium, false],
    [/^\/avisos$/, '', vAvisos, true],
    [/^\/legal$/, '', vLegal, false],
    [/^\/admin(?:\/(\w+))?$/, 'cuenta', (t) => g.Admin.vista(t), true]
  ];
  function router() {
    clearInterval(pollChat); pollChat = null;
    const h = location.hash.replace(/^#/, '');
    let ruta = RUTAS[0], m = null;
    for (const r of RUTAS) { m = h.match(r[0]); if (m) { ruta = r; break; } }
    if (!m) { location.hash = '#/'; return; }
    rutaActual = h;
    document.querySelectorAll('.nav a').forEach((a) => a.classList.toggle('on', a.dataset.r === ruta[1]));
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

  function registrarSW() {
    if (!('serviceWorker' in navigator) || location.protocol === 'file:') return;
    navigator.serviceWorker.register('sw.js').then((reg) => {
      const avisar = (w) => {
        if (document.getElementById('upd')) return;
        const d = document.createElement('div'); d.id = 'upd'; d.className = 'actualizar';
        d.innerHTML = '<div class="grow"><b>🔄 Nueva versión disponible</b></div><button class="btn small">Actualizar</button>';
        d.querySelector('button').onclick = () => w.postMessage('saltar');
        document.body.appendChild(d);
      };
      if (reg.waiting && navigator.serviceWorker.controller) avisar(reg.waiting);
      reg.addEventListener('updatefound', () => {
        const w = reg.installing;
        w && w.addEventListener('statechange', () => { if (w.state === 'installed' && navigator.serviceWorker.controller) avisar(w); });
      });
      setInterval(() => reg.update().catch(() => {}), 30 * 60 * 1000);
    }).catch(() => {});
    let recargado = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (!recargado) { recargado = true; location.reload(); } });
  }

  async function iniciar() {
    U.ponerIconos(document);
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
  g.App = { router, contadores, fallo, pedirLogin, denunciar, MODAL, ESTADO_EST, precioTxt, planTxt };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})(window);
