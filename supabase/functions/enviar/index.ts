// Edge Function "enviar" de Estaciona:
//  · push: envía las notificaciones pendientes al celular (aunque la app esté cerrada)
//    y borra del almacenamiento las fotos que ya no se usan;
//  · limpiar (admin): limpieza completa de la base de datos y de fotos huérfanas;
//  · eliminar_usuario: el admin elimina una cuenta (o la persona elimina la suya) con todas sus fotos.
// Se despliega en Supabase → Edge Functions → nombre "enviar" (con "Verify JWT" apagado).
import webpush from 'npm:web-push@3.6.7';
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.45.4';

const VERSION = '1.0';
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
  for (const n of pend) {
    for (const s of (subs || []).filter((x: { usuario: string }) => x.usuario === n.usuario)) {
      const payload = JSON.stringify({ title: n.titulo, body: n.cuerpo || '', url: n.url || './', tag: 'n' + n.id });
      tareas.push(webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400 })
        .then(() => { enviados++; })
        .catch(async (e: { statusCode?: number }) => {
          if (e?.statusCode === 404 || e?.statusCode === 410) await db.from('push_subs').delete().eq('endpoint', s.endpoint);
        }));
    }
  }
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
        case 'limpiar':
          return json(await limpiar(db, req));
        default: {
          const push = await enviarPush(db);
          const borrados = await procesarPorBorrar(db, 100);
          return json({ ok: true, ...push, borrados });
        }
      }
    } catch (e) {
      return json({ ok: false, error: String((e as Error).message || e) }, 500);
    }
  });
}
