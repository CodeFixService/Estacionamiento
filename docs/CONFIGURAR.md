# Configurar Estaciona (una sola vez, ~15 minutos)

Todo se hace en https://supabase.com/dashboard → tu proyecto (`wphxtspicejywwzlbuux`) y en GitHub.

## 1. Crear tu cuenta de administrador (PRIMERO)
**Authentication → Users → Add user → Create new user**
- Email: `juanjosuecastilloloyola@gmail.com`
- Una contraseña solo tuya · marca **Auto Confirm User** → **Create user**.

> Hazlo antes del paso 3. Esa cuenta queda como súper admin y como "Soporte Estaciona".

## 2. Apagar el correo de confirmación
**Authentication → Sign In / Providers → Email** → apaga **Confirm email** → **Save**.

## 3. Crear la base de datos
**SQL Editor → + New query** → pega todo [`supabase/instalar.sql`](../supabase/instalar.sql) → **Run**.
(Desde el celular puedes pegar [`supabase/instalar-corto.sql`](../supabase/instalar-corto.sql), son 4 líneas.)
Si aparece un aviso de operación destructiva, toca **Run this query** (es normal). Al final dice `Estaciona instalada ✅`.
Se puede volver a ejecutar cuando haya una actualización: no borra datos.

## 4. Crear la función "enviar" (notificaciones y limpieza de fotos)
**Edge Functions → Deploy a new function → Via Editor** → borra el ejemplo → pega todo
[`supabase/functions/enviar/index.ts`](../supabase/functions/enviar/index.ts) (o la versión de una línea
[`corto.ts`](../supabase/functions/enviar/corto.ts)) → nombre **`enviar`** → **Deploy function**.
Luego en la función: **Details / Settings** → apaga **Verify JWT** → **Save changes**.

## 5. Publicar en GitHub Pages
GitHub → repositorio **Estacionamiento** → **Settings → Pages** → *Source*: **Deploy from a branch** →
Branch **main** y carpeta **/ (root)** → **Save**. En 1–2 minutos queda en:
`https://codefixservice.github.io/Estacionamiento/`

## 6. Dirección de la app en Supabase
**Authentication → URL Configuration**
- Site URL: `https://codefixservice.github.io/Estacionamiento/` → Save
- Redirect URLs → Add URL: `https://codefixservice.github.io/Estacionamiento/**` → Save URLs

## 7. Primer ingreso como admin
1. Abre la app, toca **Ingresar** con la cuenta del paso 1 (verás **ADMIN** arriba).
2. **Administración → Ajustes**: pega tu **link de pago**, revisa el precio ($4.900) y cuánto Premium entrega cada pago → Guardar.
3. **Ajustes → Generar claves push** (una vez) → **Probar función "enviar"** → **Prueba: aviso solo a mí**.
4. **Cuenta → Notificaciones en este celular → Activar**.

## Cómo se vende Premium
- La persona toca **Comprar Premium** (abre tu link de pago) y luego **Ya pagué**.
- Te llega a **Administración → Pagos**: apruebas y se activa solo. O creas una **Key** y se la mandas por WhatsApp.
- En **Usuarios** puedes dar +1/+3/+12 meses, de por vida, quitar Premium, suspender o eliminar cuentas.

## Límites del plan gratis de Supabase
500 MB de base de datos y 1 GB de fotos. **Administración → Resumen → Estado del servidor** muestra cuánto
llevas (🟢/🟡/🔴). Las fotos se comprimen a WebP (~120 KB cada una, miniatura ~20 KB), las cédulas se borran
apenas se revisan, los mensajes a los 30 días, y el botón **🧹 Limpiar ahora** borra fotos que ya no se usan.
Supabase pausa el proyecto si no hay actividad en 7 días (se reactiva con un clic).

## Actualizar a la versión 2.0
1. Supabase → **SQL Editor** → pega `supabase/instalar-corto.sql` (o el `instalar.sql` completo) → **Run**. No borra datos.
2. **Administración → Ajustes**: revisa **Precios y links** (2 espacios, uno activo), **Planes**, **Reglas** y **Textos**.
3. Cada dueño configura su link en **Más → Links de pago** y su WhatsApp en **Más → Perfil**.

### Cómo funciona una reserva
1. El cliente elige modalidad (hora, día o mes), desde cuándo y cuánto tiempo → queda **apartado** N minutos.
2. Paga con el link activo del dueño (o el abono fijo, si lo puso) y sube la foto del comprobante → **en revisión**.
3. El dueño aprueba (**confirmada**) o rechaza. Si no se sube el comprobante a tiempo, se **libera sola**.
4. Cancelar: dentro de N minutos → se devuelve; con H horas o más → **saldo a favor** con ese dueño (se descuenta solo en la
   próxima reserva); con menos → se pierde. Si cancela el dueño, siempre devuelve. Todo se cambia en **Ajustes → Reglas**.
