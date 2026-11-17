// Edge Function "enviar" de Estaciona:
//  · push: envía las notificaciones pendientes al celular (aunque la app esté cerrada)
//    y borra del almacenamiento las fotos que ya no se usan;
//  · limpiar (admin): limpieza completa de la base de datos y de fotos huérfanas;
//  · eliminar_usuario: el admin elimina una cuenta (o la persona elimina la suya) con todas sus fotos.
// Se despliega en Supabase → Edge Functions → nombre "enviar" (con "Verify JWT" apagado).
import webpush from 'npm:web-push@3.6.7';
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.45.4';

// ---------- G61 a · 📲 Push insistente (núcleo push.sql): cada aviso lleva su "grupo"; el celular confirma al recibirlo
// (service worker → cfx_push_recibido). Sin confirmación se reenvía a 1, 2, 5, 10, 15, 30 min y luego cada 1 h, hasta 48 h.
// deno-lint-ignore no-explicit-any
type Rpc = { rpc: (f: string, a?: Record<string, unknown>) => any };
type SubPush = { endpoint: string; p256dh: string; auth: string };
const ACK_URL = (Deno.env.get('SUPABASE_URL') || '') + '/rest/v1/rpc/cfx_push_recibido';
const ACK_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';
function conAck(payload: string, grupo: string) {
  try { const o = JSON.parse(payload); o.ack = grupo; o.ackUrl = ACK_URL; o.ackKey = ACK_KEY; return JSON.stringify(o); } catch { return payload; }
}
async function anotarPush(s: Rpc, lista: (SubPush & { grupo: string; payload: string })[]) {
  if (!lista.length) return;
  try { await s.rpc('cfx_push_anotar', { p_lista: lista.map((x) => ({ grupo: x.grupo, endpoint: x.endpoint, p256dh: x.p256dh, auth: x.auth, payload: x.payload })) }); } catch { /* sin push.sql todavía */ }
}
async function reintentarPush(s: Rpc, preparar: () => Promise<boolean>) {
  let data: (SubPush & { payload: string })[] | null = null;
  try { const r = await s.rpc('cfx_push_tomar'); data = r.error ? null : r.data; } catch { return 0; }
  if (!data?.length || !(await preparar())) return 0;
  let n = 0;
  await Promise.allSettled(data.map(async (e) => {
    try { await webpush.sendNotification({ endpoint: e.endpoint, keys: { p256dh: e.p256dh, auth: e.auth } }, e.payload, { TTL: 86400, urgency: 'high' }); n++; }
    catch (err) { const c = (err as { statusCode?: number })?.statusCode; if (c === 404 || c === 410) await s.rpc('cfx_push_muerto', { p_endpoint: e.endpoint }); }
  }));
  return n;
}

const VERSION = '1.3';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function adminDb() {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Borra archivos "bucket/ruta" del almacenamiento.
async function borrarRutas(db: SupabaseClient, rutas: string[]) {
  const porBucket: Record<string, string[]> = {};
  for (const r of rutas) {
    const i = r.indexOf('/');
    if (i > 0) (porBucket[r.slice(0, i)] ||= []).push(r.slice(i + 1));
  }
  let n = 0;
  for (const [b, nombres] of Object.entries(porBucket)) {
    for (let i = 0; i < nombres.length; i += 100) {
      const { error } = await db.storage.from(b).remove(nombres.slice(i, i + 100));
      if (!error) n += Math.min(100, nombres.length - i);
    }
  }
  return n;
}

async function procesarPorBorrar(db: SupabaseClient, max = 300) {
  const { data } = await db.from('por_borrar').select('ruta').order('creado').limit(max);
  const rutas = (data || []).map((r: { ruta: string }) => r.ruta);
  if (!rutas.length) return 0;
  await borrarRutas(db, rutas);
  await db.from('por_borrar').delete().in('ruta', rutas);
  return rutas.length;
}

async function enviarPush(db: SupabaseClient) {
  const { data: pend } = await db.from('notificaciones').select('id, usuario, titulo, cuerpo, url')
    .eq('push_pendiente', true).order('id').limit(300);
  if (!pend?.length) return { enviados: 0 };
  const ids = pend.map((n: { id: number }) => n.id);
  await db.from('notificaciones').update({ push_pendiente: false }).in('id', ids);

  const { data: aj } = await db.from('ajustes').select('clave, valor').in('clave', ['vapid_public', 'vapid_private']);
  const k = Object.fromEntries((aj || []).map((r: { clave: string; valor: string }) => [r.clave, r.valor]));
  if (!k.vapid_public || !k.vapid_private) return { enviados: 0, error: 'Faltan las claves push (Admin → Ajustes)' };
  webpush.setVapidDetails('mailto:juanjosuecastilloloyola@gmail.com', k.vapid_public, k.vapid_private);

  const usuarios = [...new Set(pend.map((n: { usuario: string }) => n.usuario))];
  const { data: subs } = await db.from('push_subs').select('endpoint, usuario, p256dh, auth').in('usuario', usuarios);
  let enviados = 0;
  const tareas: Promise<unknown>[] = [];
  const anotar: (SubPush & { grupo: string; payload: string })[] = [];
  for (const n of pend) {
    const g = crypto.randomUUID(), payload = conAck(JSON.stringify({ title: n.titulo, body: n.cuerpo || '', url: n.url || './', tag: 'n' + n.id }), g);
    for (const s of (subs || []).filter((x: { usuario: string }) => x.usuario === n.usuario)) {
      anotar.push({ endpoint: s.endpoint, p256dh: s.p256dh, auth: s.auth, grupo: g, payload });
      tareas.push(webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400, urgency: 'high' })
        .then(() => { enviados++; })
        .catch(async (e: { statusCode?: number }) => {
          if (e?.statusCode === 404 || e?.statusCode === 410) await db.from('push_subs').delete().eq('endpoint', s.endpoint);
        }));
    }
  }
  await anotarPush(db, anotar);
  await Promise.allSettled(tareas);
  return { enviados };
}

async function quien(db: SupabaseClient, req: Request) {
  const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!jwt) return null;
  const { data } = await db.auth.getUser(jwt);
  if (!data?.user) return null;
  const { data: p } = await db.from('perfiles').select('id, es_admin').eq('id', data.user.id).single();
  return p as { id: string; es_admin: boolean } | null;
}

async function listarCarpeta(db: SupabaseClient, bucket: string, carpeta: string) {
  const out: string[] = [];
  for (let off = 0; off < 5000; off += 1000) {
    const { data } = await db.storage.from(bucket).list(carpeta, { limit: 1000, offset: off });
    if (!data?.length) break;
    out.push(...data.map((f: { name: string }) => bucket + '/' + carpeta + '/' + f.name));
    if (data.length < 1000) break;
  }
  return out;
}

async function eliminarUsuario(db: SupabaseClient, req: Request, id?: string) {
  const yo = await quien(db, req);
  if (!yo) return { ok: false, error: 'Inicia sesión de nuevo' };
  const objetivo = id && /^[0-9a-f-]{36}$/i.test(id) ? id : yo.id;
  if (objetivo !== yo.id && !yo.es_admin) return { ok: false, error: 'Solo el administrador' };
  const { data: p } = await db.from('perfiles').select('es_admin').eq('id', objetivo).single();
  if (p?.es_admin) return { ok: false, error: 'La cuenta de administrador no se puede eliminar' };
  const archivos = [...await listarCarpeta(db, 'fotos', objetivo), ...await listarCarpeta(db, 'privado', objetivo)];
  await borrarRutas(db, archivos);
  const { error } = await db.auth.admin.deleteUser(objetivo);
  if (error) return { ok: false, error: error.message };
  await procesarPorBorrar(db);
  return { ok: true, archivos: archivos.length };
}

// G37 · Entrar con QR ({accion: 'qr_entrar'}): el computador entra con la sesión que aprobó el celular (núcleo qr.js + qr.sql).
async function qrEntrar(b: { token?: string; secreto?: string }) {
  const s = adminDb();
  const { data: email, error } = await s.rpc('cfx_qr_canjear', { p_token: String(b.token || ''), p_secreto: String(b.secreto || '') });
  if (error) return { ok: false, error: 'Actualiza la base de datos (falta Entrar con QR)' };
  if (!email) return { ok: false, error: 'El código venció o ya se usó' };
  const { data, error: e2 } = await s.auth.admin.generateLink({ type: 'magiclink', email: String(email) });
  if (e2 || !data?.properties?.hashed_token) return { ok: false, error: 'No se pudo abrir la sesión' };
  return { ok: true, token_hash: data.properties.hashed_token };
}

async function limpiar(db: SupabaseClient, req: Request) {
  const yo = await quien(db, req);
  if (!yo?.es_admin) return { ok: false, error: 'Solo el administrador' };
  await db.rpc('limpieza');
  let borrados = 0;
  for (let i = 0; i < 10; i++) { const n = await procesarPorBorrar(db, 500); borrados += n; if (n < 500) break; }
  const { data: huerfanos } = await db.rpc('srv_huerfanos');
  const rutas = (huerfanos || []) as string[];
  if (rutas.length) borrados += await borrarRutas(db, rutas);
  return { ok: true, borrados };
}

if (Deno.env.get('SUPABASE_URL')) {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
    // G99 a ⚡ Aviso de Mercado Pago (webhook): no se confía en lo que llega; la base vuelve a preguntarle a MP por esa referencia.
    { const ref = new URL(req.url).searchParams.get('cfx_mp'); if (ref) { try { await adminDb().rpc('cfx_mp_aviso', { p_ref: ref.slice(0, 80) }); } catch { /* el cron revisa igual */ } return new Response('ok', { headers: CORS }); } }
    const json = (o: unknown, status = 200) =>
      new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
    try {
      const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
      const db = adminDb();
      switch (body?.accion) {
        case 'ping':
          return json({ ok: true, version: VERSION, servicio: !!Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') });
        case 'eliminar_usuario':
          return json(await eliminarUsuario(db, req, body.id));
        case 'qr_entrar':
          return json(await qrEntrar(body));
        case 'limpiar':
          return json(await limpiar(db, req));
        default: {
          const reenviados = await reintentarPush(db, async () => {
            const { data: aj } = await db.from('ajustes').select('clave, valor').in('clave', ['vapid_public', 'vapid_private']);
            const k = Object.fromEntries((aj || []).map((r: { clave: string; valor: string }) => [r.clave, r.valor]));
            if (!k.vapid_public || !k.vapid_private) return false;
            webpush.setVapidDetails('mailto:soporte@codefix.app', k.vapid_public, k.vapid_private); return true;
          });
          const push = { ...(await enviarPush(db)), reenviados };
          const borrados = await procesarPorBorrar(db, 100);
          return json({ ok: true, ...push, borrados });
        }
      }
    } catch (e) {
      return json({ ok: false, error: String((e as Error).message || e) }, 500);
    }
  });
}
