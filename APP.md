# APP.md

(Mapa completo pendiente: G42j.)

## 🅿️ Reservas (G84)
- Tabla `arriendos` (instalar.sql ~l.71 + columnas ~l.955) · funciones: solicitar_arriendo (con p_patente), subir_comprobante, responder_arriendo, cerrar_arriendo (cancelar/finalizar/devuelto; finalizar antes = devolución proporcional en devolver_monto), pedir_extension / responder_extension (ext_*), mis_arriendos.
- Patentes: tabla `patentes` + mis_patentes/guardar_patente/borrar_patente/patente_arriendo. Pantallas en js/app.js: reservar(), vReserva(), vPatentes() (Más → Mis patentes).
- 🔎 Filtros (G84 c): js/mapa.js F + pasa() + chips() + abrirFiltros(); características en estacionamientos (techado, acceso24, seguridad, carga, camara, porton); mapa() devuelve t,h,sg,cg,cam,pt; g84c() = la base ya trae cam. Publicar: js/app.js #pCam/#pPt. Prueba: SaaS/pruebas/g84c.js.
- ⏰🔔🔁 (G84 d+e, bd 46): avisar_por_terminar() y renovar_mensuales() las llama liberar_vencidas(); trigger arr_liberado → _alerta_liberado (alerta de zona); renovar_arriendo(id, si) y comprobante_extension(id, ruta) las llama js/app.js (#rRenovar, #rExtComp/#rExtSubir en vReserva). mis_arriendos trae renovar y ext.auto/ext.pago. Prueba: SaaS/pruebas/g84d.js.
- Versiones: js/config.js l.9 + version.json + instalar.sql ('version_bd'). Prueba: SaaS/pruebas/g84.js.
- G100 a (2.14.92 · bd 57): ⚡ _cobro_listo(dueño) = link activo o MP conectado → mi_cuenta.link_listo, panel.falta.link y guía. Prueba: SaaS/pruebas/g100.js.
- G99 a (2.14.91 · bd 56 · enviar 1.3): ⚡ aviso instantáneo de Mercado Pago (núcleo): cfx_mp_aviso_url_app · enviar atiende ?cfx_mp=. Prueba: SaaS/pruebas/g99.js.
- G98 (2.14.90 · bd 55): ⚡ pago con el Mercado Pago del dueño (núcleo mp_negocio.sql): arriendo_mp_pagar/arriendo_mp_revisar(id) · mis_arriendos.mp · refs 'arriendo:<id>' y 'ext:<id>:<ext_at>' (🔁 mes / más tiempo) · gancho cfx_mp_neg_pagado_app acepta como el dueño (responder_arriendo / responder_extension) · columnas mp_desde/mp_pago · js/app.js [data-mp] en vReserva, volver ?mp=<id>#/r/<id> · dueño: Más → 💳 Links de pago (#lkMp). Prueba: SaaS/pruebas/g98.js.

- G95 (2.14.87 · bd 52): la cuenta parte FREE (_nuevo_usuario sin dias_regalo) · cfx_pro_prueba_app → plan_origen 'prueba' · cuentas de antes anotadas 1 vez (g95_pruebas). Prueba: SaaS/pruebas/g95.js.

- G104 (2.14.96 · bd 61): 🧩 4 módulos más → 🌙 tarifas (estacionamientos.finde_pct/noche_pct · _tarifa_total por hora/día, no mes · tarifa_guardar) · 🔁 frecuentes (perfiles.frec_pct/frec_desde · _desc_frecuente: se usa el MAYOR entre este y el de estadía larga · frecuentes/frecuentes_guardar) · 📅 calendario (tabla cierres · _cierre_choca en solicitar_arriendo · cierres_mios/cierre_guardar/cierre_borrar) · 🔔 avisame (tabla esperas · espera_anotar/esperas_mias · trigger est_espera al volver a disponible). Ficha: estacionamiento_detalle.g104 = _g104_ficha(e, me). Hojas de Más: T.querySelector (ids duplicados). Prueba: SaaS/pruebas/g104b.js.

## 🧠 Del núcleo: falta aplicar aquí
- G42e (núcleo 2.78): utilidades Bootstrap 5.3.8 ya usan los colores CodeFix (--bs-* → --cfx-*). Al revisar esta app: si quiere Bootstrap, enlazar vendor/bootstrap-utilities.min.css ANTES de su CSS (nunca el Bootstrap completo: choca con .btn/.card/.modal/.row/.toast).
- G48 (núcleo 2.77): revisar en el celular ✋ mover secciones desde el título y 🎨 Color y modo → Colores a tu gusto (fondo, texto, íconos y +); si la app pinta íconos o fondo con colores fijos, pasarlos a var(--cfx-icono)/var(--cfx-fondo).
- G37 (núcleo 2.76): 🧾 comprobante.js + 🖨️ impresora.js son del núcleo (OPCIONAL). Aplicar: sumar "estacionamiento" a OPCIONAL en sincronizar.py + <script> + FILES de sw.js; definir window.CFX_COMPROBANTE_DATOS = async (c) => ({ logo, firma }) y abrir CFX_COMPROBANTE.abrir({...}) en cobro de reserva. 🧾 Boleta SII: hoy solo Despega (SQL boleta_*); si esta app la necesita, pasarla primero a nucleo/sql/boleta.sql. · 🔑 Entrar con QR: la función ya atiende qr_entrar (enviar 1.1); falta en la app: <script qr.js> + #lQR en el ingreso (como CM/Barbería) + ?qr=.
- G42 (núcleo 2.75, ya activo solo): ⬆️ subir, 🪟 ventanas del núcleo (✕+Cerrar / ← Volver), 📌 títulos fijos y ✋ ordenar en CFX_AJUSTES/CFX_MENU. Falta aquí: ✋ marcar otras listas propias con data-cfx-orden si sirve; 🪟 revisar ventanas propias (dialog) que no usan la hoja del núcleo; 🔐 usar CFX_TAPAR en avisos de enlace/validación y CFX_URL en links que pone el negocio (boleta, pago).
- G43: revisar la tarjeta "🚀 Termina de armar tu negocio" (núcleo) en el inicio (o marcar data-cfx-guia); afinar guiaPasos (#/publicar, #/mas/perfil → campo exacto); quitar avisos propios de instalar/notificaciones si se repiten.
