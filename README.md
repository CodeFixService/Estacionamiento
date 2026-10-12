# 🅿️ Estaciona

App web instalable (PWA) para **arrendar y publicar estacionamientos en Santiago**, con personas verificadas,
mapa interactivo y chat seguro. © CodeFix · Josué Castillo.

**Configurar:** ver [docs/CONFIGURAR.md](docs/CONFIGURAR.md).

## Roles
| Rol | Qué puede hacer |
|---|---|
| **Visitante** (sin cuenta) | Ve el mapa con los estacionamientos, precio, comuna y foto. Para ver el detalle debe crear su cuenta. |
| **Usuario** | Una sola cuenta para todo: busca y arrienda, publica sus estacionamientos, chatea, califica, denuncia. |
| **Súper admin** | Resumen y estado del servidor, verificaciones, denuncias, pagos, usuarios, estacionamientos, keys, avisos y ajustes. |

## Gratis vs Premium
| | Gratis | Premium ⭐ |
|---|---|---|
| Publicar estacionamientos | 1 | 10 |
| Arriendos activos a la vez | 1 | 10 |
| Fotos por estacionamiento | 3 | 8 |
| Favoritos | 3 | Ilimitados |
| Pin dorado destacado y primero en la lista | — | ✓ |
| Estadísticas (visitas, favoritos, solicitudes) | — | ✓ |
| Alerta "nuevo estacionamiento cerca" | — | ✓ |
| Color del perfil | 6 colores | Selector RGB libre |
| QR con tu color, sello PRO | — | ✓ |

Cuenta nueva = **7 días Premium de prueba**. Pago único ($4.900, editable) con tu link de pago; se activa con
"Ya pagué" (apruebas en el panel) o con una **key** `EST-XXXX-XXXX`.

## Seguridad antiestafa
- Verificación de identidad: **RUT** (dígito verificador), **N° de documento** de la cédula, fotos de la cédula y **selfie**.
  El admin la aprueba (con botón a la consulta de vigencia del Registro Civil). Un RUT = una cuenta. Las fotos se borran al revisar.
- Solo verificados publican, arriendan y chatean entre usuarios. Soporte siempre disponible.
- Ubicación **aproximada** en el mapa; la dirección exacta solo al aceptar el arriendo.
- Chat: **máximo 3 mensajes seguidos** (luego esperar respuesta), 100 al día, ✓/✓✓, **bloquear** y **denunciar con evidencia obligatoria**.
- Calificaciones en ambos sentidos. El admin solo puede leer conversaciones **denunciadas**.
- Todo validado en el servidor (`supabase/instalar.sql`): las tablas no se pueden leer directo, solo por funciones con reglas.

## Archivos
- `index.html`, `css/`, `js/` — la app (sin compilación). `vendor/` — Supabase, Leaflet, MarkerCluster, QR.
- `supabase/instalar.sql` — base de datos completa. `supabase/functions/enviar/` — notificaciones push y limpieza.
- `sw.js` — funciona offline y avisa "Actualizar" cuando subes una versión (cambia `VERSION` en `sw.js` y en `js/config.js`).
