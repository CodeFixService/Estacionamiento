-- =====================================================================
--  ESTACIONA · Base de datos completa (Supabase)
--  Pegar en Supabase → SQL Editor → Run. Se puede volver a ejecutar:
--  actualiza todo sin borrar datos.
--  © CodeFix · Josué Castillo
-- =====================================================================

-- ---------- Tablas ----------
create table if not exists public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  nombre text not null default '',
  avatar text,                 -- ruta en el bucket "fotos"
  icono text,                  -- emoji si no tiene foto
  color text not null default '#2563eb',
  comuna text,
  bio text,
  es_admin boolean not null default false,
  premium_hasta timestamptz,
  plan_origen text,            -- prueba | key | pago | admin
  verificado boolean not null default false,
  suspendido boolean not null default false,
  acepto_terminos timestamptz,
  calif_suma int not null default 0,
  calif_n int not null default 0,
  alerta_lat double precision,
  alerta_lng double precision,
  alerta_km real,
  creado timestamptz not null default now(),
  ultimo_acceso timestamptz
);

create table if not exists public.verificaciones (
  usuario uuid primary key references public.perfiles (id) on delete cascade,
  rut text not null,
  serie text not null,
  frente text, reverso text, selfie text,   -- rutas en el bucket "privado"
  estado text not null default 'pendiente' check (estado in ('pendiente', 'aprobada', 'rechazada')),
  motivo text,
  enviada timestamptz not null default now(),
  revisada timestamptz
);
create unique index if not exists verificaciones_rut on public.verificaciones (rut);

create table if not exists public.estacionamientos (
  id uuid primary key default gen_random_uuid(),
  dueno uuid not null references public.perfiles (id) on delete cascade,
  titulo text not null,
  descripcion text,
  direccion text not null,      -- exacta: solo la ven el dueño y quien tiene el arriendo aceptado
  comuna text,
  lat double precision not null,
  lng double precision not null,
  lat_pub double precision,     -- aproximada (±150 m) para el mapa
  lng_pub double precision,
  precio_hora int, precio_dia int, precio_mes int,
  vehiculo text not null default 'auto' check (vehiculo in ('moto', 'auto', 'camioneta')),
  techado boolean not null default false,
  acceso24 boolean not null default false,
  seguridad boolean not null default false,
  carga boolean not null default false,
  fotos text[] not null default '{}',
  estado text not null default 'disponible' check (estado in ('disponible', 'ocupado', 'pausado', 'oculto')),
  vistas int not null default 0,
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
create index if not exists est_pub on public.estacionamientos (lat_pub, lng_pub);
create index if not exists est_dueno on public.estacionamientos (dueno, creado);

create table if not exists public.arriendos (
  id uuid primary key default gen_random_uuid(),
  estacionamiento uuid not null references public.estacionamientos (id) on delete cascade,
  dueno uuid not null references public.perfiles (id) on delete cascade,
  arrendatario uuid not null references public.perfiles (id) on delete cascade,
  modalidad text not null check (modalidad in ('hora', 'dia', 'mes')),
  desde date,
  nota text,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'aceptado', 'rechazado', 'cancelado', 'finalizado')),
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
create index if not exists arr_dueno on public.arriendos (dueno, estado);
create index if not exists arr_arrendatario on public.arriendos (arrendatario, estado);

create table if not exists public.calificaciones (
  arriendo uuid not null references public.arriendos (id) on delete cascade,
  autor uuid not null references public.perfiles (id) on delete cascade,
  destino uuid not null references public.perfiles (id) on delete cascade,
  estrellas int not null check (estrellas between 1 and 5),
  comentario text,
  creado timestamptz not null default now(),
  primary key (arriendo, autor)
);
create index if not exists calif_destino on public.calificaciones (destino, creado desc);

create table if not exists public.favoritos (
  usuario uuid not null references public.perfiles (id) on delete cascade,
  estacionamiento uuid not null references public.estacionamientos (id) on delete cascade,
  creado timestamptz not null default now(),
  primary key (usuario, estacionamiento)
);

create table if not exists public.conversaciones (
  id uuid primary key default gen_random_uuid(),
  a uuid not null references public.perfiles (id) on delete cascade,
  b uuid not null references public.perfiles (id) on delete cascade,
  ultimo timestamptz not null default now(),
  ultimo_texto text,
  ultimo_autor uuid,
  check (a < b),
  unique (a, b)
);
create index if not exists conv_b on public.conversaciones (b);

create table if not exists public.mensajes (
  id bigint generated always as identity primary key,
  conv uuid not null references public.conversaciones (id) on delete cascade,
  autor uuid not null references public.perfiles (id) on delete cascade,
  texto text not null,
  creado timestamptz not null default now(),
  visto boolean not null default false
);
create index if not exists msj_conv on public.mensajes (conv, id);
create index if not exists msj_autor on public.mensajes (autor, creado);

create table if not exists public.bloqueos (
  quien uuid not null references public.perfiles (id) on delete cascade,
  bloqueado uuid not null references public.perfiles (id) on delete cascade,
  creado timestamptz not null default now(),
  primary key (quien, bloqueado)
);

create table if not exists public.denuncias (
  id uuid primary key default gen_random_uuid(),
  autor uuid not null references public.perfiles (id) on delete cascade,
  tipo text not null check (tipo in ('usuario', 'estacionamiento', 'conversacion')),
  objetivo uuid not null,
  denunciado uuid references public.perfiles (id) on delete cascade,
  motivo text not null,
  detalle text not null,
  evidencia text not null,      -- ruta en el bucket "privado"
  estado text not null default 'abierta' check (estado in ('abierta', 'resuelta', 'descartada')),
  resolucion text,
  creado timestamptz not null default now()
);

create table if not exists public.notificaciones (
  id bigint generated always as identity primary key,
  usuario uuid not null references public.perfiles (id) on delete cascade,
  titulo text not null,
  cuerpo text,
  url text,
  chat boolean not null default false,
  leida boolean not null default false,
  push_pendiente boolean not null default true,
  creado timestamptz not null default now()
);
create index if not exists notif_usuario on public.notificaciones (usuario, id desc);
create index if not exists notif_push on public.notificaciones (id) where push_pendiente;

create table if not exists public.push_subs (
  endpoint text primary key,
  usuario uuid not null references public.perfiles (id) on delete cascade,
  p256dh text not null,
  auth text not null,
  creado timestamptz not null default now()
);
create index if not exists push_usuario on public.push_subs (usuario);

create table if not exists public.licencias (
  key text primary key,
  meses int not null default 1,      -- 0 = Premium de por vida
  nota text,
  creada timestamptz not null default now(),
  canjeada_por uuid references public.perfiles (id) on delete set null,
  canjeada timestamptz,
  revocada boolean not null default false
);

create table if not exists public.pagos (
  id uuid primary key default gen_random_uuid(),
  usuario uuid not null references public.perfiles (id) on delete cascade,
  nota text,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'aprobado', 'rechazado')),
  creado timestamptz not null default now()
);

create table if not exists public.ajustes (
  clave text primary key,
  valor text
);
insert into public.ajustes (clave, valor) values
  ('precio', '4900'), ('link_pago', ''), ('meses_por_pago', '1'), ('vapid_public', ''), ('vapid_private', '')
on conflict (clave) do nothing;

-- Archivos que la función "enviar" debe borrar del almacenamiento ("bucket/ruta").
create table if not exists public.por_borrar (
  ruta text primary key,
  creado timestamptz not null default now()
);

-- Todo se lee y escribe por funciones (RPC): sin políticas, nadie accede directo a las tablas.
alter table public.perfiles enable row level security;
alter table public.verificaciones enable row level security;
alter table public.estacionamientos enable row level security;
alter table public.arriendos enable row level security;
alter table public.calificaciones enable row level security;
alter table public.favoritos enable row level security;
alter table public.conversaciones enable row level security;
alter table public.mensajes enable row level security;
alter table public.bloqueos enable row level security;
alter table public.denuncias enable row level security;
alter table public.notificaciones enable row level security;
alter table public.push_subs enable row level security;
alter table public.licencias enable row level security;
alter table public.pagos enable row level security;
alter table public.ajustes enable row level security;
alter table public.por_borrar enable row level security;

-- ---------- Almacenamiento (fotos comprimidas) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('fotos', 'fotos', true, 614400, array['image/webp', 'image/jpeg']),
  ('privado', 'privado', false, 1048576, array['image/webp', 'image/jpeg'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------- Utilidades ----------
create or replace function public.es_admin() returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  -- Administrador o socio (núcleo: cfx_socios, se agregan desde el Centro de Mando). Sin sesión no se llega a cfx_es_socio.
  if auth.uid() is null then return false; end if;
  return coalesce((select es_admin from public.perfiles where id = auth.uid()), false) or public.cfx_es_socio();
end $$;

drop policy if exists "est fotos subir" on storage.objects;
create policy "est fotos subir" on storage.objects for insert to authenticated
  with check (bucket_id in ('fotos', 'privado') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "est fotos borrar" on storage.objects;
create policy "est fotos borrar" on storage.objects for delete to authenticated
  using (bucket_id in ('fotos', 'privado') and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public._premium(p public.perfiles) returns boolean
language sql stable as $$ select p.es_admin or coalesce(p.premium_hasta > now(), false) $$;


create or replace function public._yo() returns public.perfiles
language plpgsql stable security definer set search_path = public as $$
declare p public.perfiles;
begin
  select * into p from public.perfiles where id = auth.uid();
  if not found then raise exception 'Inicia sesión para continuar'; end if;
  if p.suspendido and not p.es_admin then raise exception 'Tu cuenta está suspendida. Escribe a soporte.'; end if;
  return p;
end $$;

create or replace function public._verificado(p public.perfiles) returns void
language plpgsql as $$
begin
  if not (p.verificado or p.es_admin) then
    raise exception 'Primero verifica tu identidad (Cuenta → Verificar identidad)';
  end if;
end $$;

-- Datos públicos de un perfil (nunca RUT, correo ni teléfono).
create or replace function public._pj(uid uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'nombre', p.nombre, 'avatar', p.avatar, 'icono', p.icono, 'color', p.color,
    'comuna', p.comuna, 'bio', p.bio, 'verificado', p.verificado, 'premium', public._premium(p), 'admin', p.es_admin or (uid = auth.uid() and public.es_admin()),
    'calif', case when p.calif_n > 0 then round(p.calif_suma::numeric / p.calif_n, 1) end, 'calif_n', p.calif_n,
    'desde', p.creado)
  from public.perfiles p where p.id = uid
$$;

create or replace function public._notificar(uid uuid, t text, c text, u text, es_chat boolean default false) returns void
language sql security definer set search_path = public as $$
  insert into public.notificaciones (usuario, titulo, cuerpo, url, chat, leida)
  values (uid, left(t, 80), left(c, 200), u, es_chat, es_chat)
$$;

create or replace function public._admin_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.perfiles where es_admin order by creado limit 1
$$;

create or replace function public.rut_limpio(r text) returns text
language sql immutable as $$ select upper(regexp_replace(coalesce(r, ''), '[^0-9kK]', '', 'g')) $$;

create or replace function public.rut_valido(r text) returns boolean
language plpgsql immutable as $$
declare c text := public.rut_limpio(r); cuerpo text; s int := 0; m int := 2; i int; res int;
begin
  if length(c) < 8 or length(c) > 9 then return false; end if;
  cuerpo := left(c, length(c) - 1);
  if cuerpo !~ '^[0-9]+$' then return false; end if;
  for i in reverse length(cuerpo)..1 loop
    s := s + substr(cuerpo, i, 1)::int * m;
    m := case when m = 7 then 2 else m + 1 end;
  end loop;
  res := 11 - (s % 11);
  return right(c, 1) = case res when 11 then '0' when 10 then 'K' else res::text end;
end $$;

-- ---------- Disparadores ----------
create or replace function public._nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare es_adm boolean := lower(coalesce(new.email, '')) = 'juanjosuecastilloloyola@gmail.com';
begin
  insert into public.perfiles (id, email, nombre, premium_hasta, plan_origen, es_admin, verificado, acepto_terminos)
  values (new.id, lower(coalesce(new.email, '')), left(coalesce(new.raw_user_meta_data ->> 'nombre', ''), 60),
    case when public._cfg('dias_regalo') > 0 then now() + make_interval(days => public._cfg('dias_regalo')) end, 'prueba',
    es_adm, es_adm, case when new.raw_user_meta_data ->> 'acepta' = 'si' then now() end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists est_nuevo_usuario on auth.users;
create trigger est_nuevo_usuario after insert on auth.users for each row execute function public._nuevo_usuario();

-- Cuentas que ya existían antes de instalar (por ejemplo, la del administrador).
insert into public.perfiles (id, email, nombre, premium_hasta, plan_origen)
select u.id, lower(coalesce(u.email, '')), left(coalesce(u.raw_user_meta_data ->> 'nombre', ''), 60), now() + interval '7 days', 'prueba'
from auth.users u on conflict (id) do nothing;
update public.perfiles set es_admin = true, verificado = true, nombre = case when nombre = '' then 'Soporte Estaciona' else nombre end
where email = 'juanjosuecastilloloyola@gmail.com';

-- Ubicación aproximada: desplazamiento fijo de hasta ~150 m según el id.
create or replace function public._ubicacion_pub() returns trigger
language plpgsql as $$
begin
  new.lat_pub := new.lat; new.lng_pub := new.lng; new.actualizado := now();
  return new;
end $$;
drop trigger if exists est_ubicacion on public.estacionamientos;
create trigger est_ubicacion before insert or update of lat, lng, titulo, descripcion, direccion, fotos, precio_hora, precio_dia, precio_mes, estado
  on public.estacionamientos for each row execute function public._ubicacion_pub();

-- Fotos que dejan de usarse se mandan a borrar (ahorra espacio).
create or replace function public._borrar_fotos() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'estacionamientos' then
    insert into public.por_borrar (ruta)
    select 'fotos/' || y from unnest(old.fotos) x, unnest(array[x, regexp_replace(x, '\.(webp|jpg)$', '_t.\1')]) y
    where tg_op = 'DELETE' or not (x = any (new.fotos)) on conflict do nothing;
  elsif tg_table_name = 'perfiles' then
    if old.avatar is not null and (tg_op = 'DELETE' or new.avatar is distinct from old.avatar) then
      insert into public.por_borrar (ruta) values ('fotos/' || old.avatar) on conflict do nothing;
    end if;
  elsif tg_table_name = 'verificaciones' then
    insert into public.por_borrar (ruta)
    select 'privado/' || x from unnest(array[old.frente, old.reverso, old.selfie]) x
    where x is not null and (tg_op = 'DELETE'
      or (x is distinct from new.frente and x is distinct from new.reverso and x is distinct from new.selfie))
    on conflict do nothing;
  elsif tg_table_name = 'denuncias' then
    insert into public.por_borrar (ruta) values ('privado/' || old.evidencia) on conflict do nothing;
  elsif tg_table_name in ('arriendos', 'pagos') then
    if old.comprobante is not null and (tg_op = 'DELETE' or new.comprobante is distinct from old.comprobante) then
      insert into public.por_borrar (ruta) values ('privado/' || old.comprobante) on conflict do nothing;
    end if;
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists est_borrar_fotos on public.estacionamientos;
create trigger est_borrar_fotos after update of fotos or delete on public.estacionamientos for each row execute function public._borrar_fotos();
drop trigger if exists per_borrar_fotos on public.perfiles;
create trigger per_borrar_fotos after update of avatar or delete on public.perfiles for each row execute function public._borrar_fotos();
drop trigger if exists ver_borrar_fotos on public.verificaciones;
create trigger ver_borrar_fotos after update or delete on public.verificaciones for each row execute function public._borrar_fotos();
drop trigger if exists den_borrar_fotos on public.denuncias;
create trigger den_borrar_fotos after delete on public.denuncias for each row execute function public._borrar_fotos();

-- Alerta Premium: "nuevo estacionamiento cerca de mí".
create or replace function public._alerta_cercanos() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notificaciones (usuario, titulo, cuerpo, url)
  select p.id, '📍 Nuevo estacionamiento cerca', left(new.titulo || coalesce(' · ' || new.comuna, ''), 200), '#/e/' || new.id
  from public.perfiles p
  where p.alerta_km is not null and p.id <> new.dueno and public._premium(p) and not p.suspendido
    and 6371 * 2 * asin(sqrt(power(sin(radians(new.lat - p.alerta_lat) / 2), 2) +
      cos(radians(p.alerta_lat)) * cos(radians(new.lat)) * power(sin(radians(new.lng - p.alerta_lng) / 2), 2))) <= p.alerta_km
  limit 300;
  return new;
end $$;
drop trigger if exists est_alerta on public.estacionamientos;
create trigger est_alerta after insert on public.estacionamientos for each row execute function public._alerta_cercanos();

-- =====================================================================
--  Funciones públicas (sin sesión)
-- =====================================================================

-- Pines del mapa dentro del rectángulo visible. Datos mínimos para que cargue rápido.

-- =====================================================================
--  Cuenta
-- =====================================================================

create or replace function public.aceptar_terminos() returns void
language sql security definer set search_path = public as $$
  update public.perfiles set acepto_terminos = now() where id = auth.uid()
$$;


create or replace function public.enviar_verificacion(p_rut text, p_serie text, p_frente text, p_reverso text, p_selfie text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo(); r text := public.rut_limpio(p_rut);
  s text := upper(regexp_replace(coalesce(p_serie, ''), '[^0-9A-Za-z]', '', 'g')); patron text := '^' || p.id || '/[A-Za-z0-9._-]+$';
begin
  if p.verificado then raise exception 'Tu cuenta ya está verificada'; end if;
  if not public.rut_valido(r) then raise exception 'El RUT no es válido (revisa el dígito verificador)'; end if;
  if s !~ '^[A-Z]?[0-9]{9}$' then raise exception 'El número de serie no es válido (está en tu cédula, 9 dígitos)'; end if;
  if coalesce(p_frente, '') !~ patron or coalesce(p_reverso, '') !~ patron or coalesce(p_selfie, '') !~ patron then
    raise exception 'Faltan las fotos de la cédula o la selfie';
  end if;
  if exists (select 1 from public.verificaciones where rut = r and usuario <> p.id) then
    raise exception 'Ese RUT ya está registrado en otra cuenta';
  end if;
  insert into public.verificaciones (usuario, rut, serie, frente, reverso, selfie, estado, motivo, enviada, revisada)
  values (p.id, r, s, p_frente, p_reverso, p_selfie, 'pendiente', null, now(), null)
  on conflict (usuario) do update set rut = excluded.rut, serie = excluded.serie, frente = excluded.frente,
    reverso = excluded.reverso, selfie = excluded.selfie, estado = 'pendiente', motivo = null, enviada = now(), revisada = null;
  perform public._notificar(public._admin_id(), '🪪 Nueva verificación', p.nombre || ' envió su cédula para revisar', '#/admin/verificaciones');
  return public.mi_cuenta();
end $$;


create or replace function public.canjear_key(p_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo(); l public.licencias; k text := upper(trim(coalesce(p_key, '')));
begin
  select * into l from public.licencias where key = k for update;
  if not found or l.revocada then raise exception 'La key no existe'; end if;
  if l.canjeada_por is not null then raise exception 'Esa key ya fue usada'; end if;
  update public.licencias set canjeada_por = p.id, canjeada = now() where key = k;
  update public.perfiles set plan_origen = 'key', premium_hasta = case when l.meses = 0 then 'infinity'::timestamptz
    else greatest(now(), coalesce(premium_hasta, now())) + make_interval(months => l.meses) end
  where id = p.id;
  return public.mi_cuenta();
end $$;



create or replace function public.guardar_push(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo();
begin
  insert into public.push_subs (endpoint, usuario, p256dh, auth) values (p_endpoint, p.id, p_p256dh, p_auth)
  on conflict (endpoint) do update set usuario = excluded.usuario, p256dh = excluded.p256dh, auth = excluded.auth;
end $$;

create or replace function public.quitar_push(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from public.push_subs where endpoint = p_endpoint and usuario = auth.uid()
$$;


create or replace function public.mis_notificaciones() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x ->> 'id')::bigint desc), '[]') from (
    select jsonb_build_object('id', id, 'titulo', titulo, 'cuerpo', cuerpo, 'url', url, 'leida', leida, 'fecha', creado) x
    from public.notificaciones where usuario = auth.uid() and not chat order by id desc limit 60) q
$$;

create or replace function public.marcar_leidas() returns void
language sql security definer set search_path = public as $$
  update public.notificaciones set leida = true where usuario = auth.uid() and not leida
$$;

-- =====================================================================
--  Estacionamientos
-- =====================================================================
create or replace function public.guardar_estacionamiento(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); eid uuid := nullif(p ->> 'id', '')::uuid; e public.estacionamientos;
  v_fotos text[] := coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(p -> 'fotos', '[]')) x), '{}');
  v_lat double precision := (p ->> 'lat')::double precision; v_lng double precision := (p ->> 'lng')::double precision;
  ph int := nullif((p ->> 'precio_hora')::int, 0); pd int := nullif((p ->> 'precio_dia')::int, 0); pm int := nullif((p ->> 'precio_mes')::int, 0);
  x text;
begin
  perform public._verificado(yo);
  if length(trim(coalesce(p ->> 'titulo', ''))) < 3 then raise exception 'Escribe un título'; end if;
  if length(trim(coalesce(p ->> 'direccion', ''))) < 5 then raise exception 'Escribe la dirección'; end if;
  if v_lat is null or v_lng is null or v_lat not between -56 and -17 or v_lng not between -76 and -66 then
    raise exception 'Marca la ubicación en el mapa';
  end if;
  if coalesce(ph, 0) <= 0 and coalesce(pd, 0) <= 0 and coalesce(pm, 0) <= 0 then raise exception 'Pon al menos un precio'; end if;
  if greatest(coalesce(ph, 0), coalesce(pd, 0), coalesce(pm, 0)) > 5000000 or least(coalesce(ph, 1), coalesce(pd, 1), coalesce(pm, 1)) < 0 then
    raise exception 'Revisa los precios';
  end if;
  if array_length(v_fotos, 1) is null then raise exception 'Sube al menos una foto'; end if;
  if array_length(v_fotos, 1) > public._lim(yo, 'fotos') then
    raise exception 'Tu plan permite % fotos por estacionamiento', public._lim(yo, 'fotos');
  end if;
  foreach x in array v_fotos loop
    if x !~ ('^' || yo.id || '/[A-Za-z0-9._-]+$') then raise exception 'Foto no válida'; end if;
  end loop;

  if eid is null then
    if (select count(*) from public.estacionamientos where dueno = yo.id) >= public._lim(yo, 'publicar') then
      raise exception 'Tu plan permite publicar % estacionamiento(s). Hazte Premium para publicar hasta 10.', public._lim(yo, 'publicar');
    end if;
    if (select count(*) from public.estacionamientos where dueno = yo.id and creado > now() - interval '1 day') >= 10 then
      raise exception 'Demasiadas publicaciones hoy';
    end if;
    insert into public.estacionamientos (dueno, titulo, descripcion, direccion, comuna, lat, lng, precio_hora, precio_dia, precio_mes,
      vehiculo, techado, acceso24, seguridad, carga, fotos)
    values (yo.id, left(trim(p ->> 'titulo'), 60), left(p ->> 'descripcion', 600), left(trim(p ->> 'direccion'), 140), left(p ->> 'comuna', 40),
      v_lat, v_lng, ph, pd, pm, coalesce(p ->> 'vehiculo', 'auto'), coalesce((p ->> 'techado')::boolean, false),
      coalesce((p ->> 'acceso24')::boolean, false), coalesce((p ->> 'seguridad')::boolean, false), coalesce((p ->> 'carga')::boolean, false), v_fotos)
    returning id into eid;
  else
    select * into e from public.estacionamientos where id = eid for update;
    if not found or e.dueno <> yo.id then raise exception 'No puedes editar este estacionamiento'; end if;
    update public.estacionamientos set titulo = left(trim(p ->> 'titulo'), 60), descripcion = left(p ->> 'descripcion', 600),
      direccion = left(trim(p ->> 'direccion'), 140), comuna = left(p ->> 'comuna', 40), lat = v_lat, lng = v_lng,
      precio_hora = ph, precio_dia = pd, precio_mes = pm, vehiculo = coalesce(p ->> 'vehiculo', 'auto'),
      techado = coalesce((p ->> 'techado')::boolean, false), acceso24 = coalesce((p ->> 'acceso24')::boolean, false),
      seguridad = coalesce((p ->> 'seguridad')::boolean, false), carga = coalesce((p ->> 'carga')::boolean, false), fotos = v_fotos
    where id = eid;
  end if;
  return eid;
end $$;

create or replace function public.estado_estacionamiento(p_id uuid, p_estado text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  if p_estado not in ('disponible', 'ocupado', 'pausado') then raise exception 'Estado no válido'; end if;
  update public.estacionamientos set estado = p_estado where id = p_id and dueno = yo.id and estado <> 'oculto';
  if not found then raise exception 'No se pudo cambiar (¿lo ocultó el administrador?)'; end if;
end $$;

create or replace function public.borrar_estacionamiento(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  delete from public.estacionamientos where id = p_id and (dueno = yo.id or yo.es_admin);
end $$;



create or replace function public.favorito(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  if exists (select 1 from public.favoritos where usuario = yo.id and estacionamiento = p_id) then
    delete from public.favoritos where usuario = yo.id and estacionamiento = p_id;
    return false;
  end if;
  if (select count(*) from public.favoritos where usuario = yo.id) >= public._lim(yo, 'favoritos') then
    raise exception 'En Gratis puedes guardar % favoritos. Con Premium, ilimitados.', public._lim(yo, 'favoritos');
  end if;
  insert into public.favoritos (usuario, estacionamiento) values (yo.id, p_id);
  return true;
end $$;

create or replace function public.mis_favoritos() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'titulo', e.titulo, 'comuna', e.comuna, 'foto', e.fotos[1],
    'estado', e.estado, 'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes) order by f.creado desc), '[]')
  from public.favoritos f join public.estacionamientos e on e.id = f.estacionamiento
  where f.usuario = auth.uid() and e.estado <> 'oculto'
$$;

-- =====================================================================
--  Arriendos
-- =====================================================================




create or replace function public.calificar(p_arriendo uuid, p_estrellas int, p_comentario text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); a public.arriendos; otro uuid;
begin
  select * into a from public.arriendos where id = p_arriendo;
  if not found or yo.id not in (a.dueno, a.arrendatario) or a.estado <> 'finalizado' then
    raise exception 'Solo puedes calificar arriendos finalizados';
  end if;
  if p_estrellas not between 1 and 5 then raise exception 'Elige de 1 a 5 estrellas'; end if;
  otro := case when yo.id = a.dueno then a.arrendatario else a.dueno end;
  insert into public.calificaciones (arriendo, autor, destino, estrellas, comentario)
  values (p_arriendo, yo.id, otro, p_estrellas, left(nullif(trim(p_comentario), ''), 200));
  update public.perfiles set calif_suma = calif_suma + p_estrellas, calif_n = calif_n + 1 where id = otro;
exception when unique_violation then raise exception 'Ya calificaste este arriendo';
end $$;

-- =====================================================================
--  Chat (3 mensajes seguidos, luego esperar respuesta)
-- =====================================================================
create or replace function public.abrir_conversacion(p_con uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); otro public.perfiles; cid uuid; x uuid := least(yo.id, p_con); y uuid := greatest(yo.id, p_con);
begin
  select * into otro from public.perfiles where id = p_con;
  if not found or p_con = yo.id then raise exception 'Usuario no encontrado'; end if;
  if not (otro.es_admin or yo.es_admin) then
    perform public._verificado(yo);
    if exists (select 1 from public.bloqueos where (quien = otro.id and bloqueado = yo.id) or (quien = yo.id and bloqueado = otro.id)) then
      raise exception 'No puedes chatear con esta persona (bloqueo)';
    end if;
  end if;
  select id into cid from public.conversaciones where a = x and b = y;
  if cid is null then
    insert into public.conversaciones (a, b) values (x, y) on conflict (a, b) do nothing returning id into cid;
    if cid is null then select id into cid from public.conversaciones where a = x and b = y; end if;
  end if;
  return cid;
end $$;

create or replace function public.soporte() returns uuid
language plpgsql security definer set search_path = public as $$
declare adm uuid := public._admin_id();
begin
  if adm is null then raise exception 'Soporte aún no está disponible'; end if;
  if adm = auth.uid() then raise exception 'Tú eres el soporte 🙂'; end if;
  return public.abrir_conversacion(adm);
end $$;

create or replace function public.mis_conversaciones() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ultimo', c.ultimo, 'texto', c.ultimo_texto, 'mio', c.ultimo_autor = auth.uid(),
      'otro', public._pj(case when c.a = auth.uid() then c.b else c.a end),
      'no_leidos', (select count(*) from public.mensajes m where m.conv = c.id and m.autor <> auth.uid() and not m.visto))
    order by c.ultimo desc), '[]')
  from public.conversaciones c
  where (c.a = auth.uid() or c.b = auth.uid()) and (c.ultimo_texto is not null)
$$;

create or replace function public.leer_mensajes(p_conv uuid, p_desde bigint default 0) returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); c public.conversaciones; otro uuid;
begin
  select * into c from public.conversaciones where id = p_conv;
  if not found or yo.id not in (c.a, c.b) then raise exception 'Conversación no encontrada'; end if;
  otro := case when c.a = yo.id then c.b else c.a end;
  update public.mensajes set visto = true where conv = p_conv and autor <> yo.id and not visto;
  return jsonb_build_object('otro', public._pj(otro),
    'bloqueado', exists (select 1 from public.bloqueos where quien = yo.id and bloqueado = otro),
    'me_bloqueo', exists (select 1 from public.bloqueos where quien = otro and bloqueado = yo.id),
    'visto_hasta', (select max(id) from public.mensajes where conv = p_conv and autor = yo.id and visto),
    'mensajes', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'mio', autor = yo.id, 'texto', texto, 'fecha', creado, 'visto', visto) order by id)
      from (select * from public.mensajes where conv = p_conv and id > coalesce(p_desde, 0) order by id desc limit 200) q), '[]'));
end $$;


create or replace function public.bloquear(p_usuario uuid, p_si boolean) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  if p_usuario = yo.id or p_usuario = public._admin_id() then raise exception 'No se puede bloquear'; end if;
  if p_si then insert into public.bloqueos (quien, bloqueado) values (yo.id, p_usuario) on conflict do nothing;
  else delete from public.bloqueos where quien = yo.id and bloqueado = p_usuario; end if;
end $$;

create or replace function public.denunciar(p_tipo text, p_objetivo uuid, p_motivo text, p_detalle text, p_evidencia text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); den uuid; c public.conversaciones;
begin
  if p_tipo = 'usuario' then den := p_objetivo;
  elsif p_tipo = 'estacionamiento' then select dueno into den from public.estacionamientos where id = p_objetivo;
  elsif p_tipo = 'conversacion' then
    select * into c from public.conversaciones where id = p_objetivo;
    if not found or yo.id not in (c.a, c.b) then raise exception 'Conversación no encontrada'; end if;
    den := case when c.a = yo.id then c.b else c.a end;
  else raise exception 'Tipo no válido'; end if;
  if den is null or den = yo.id then raise exception 'No se puede denunciar'; end if;
  if length(trim(coalesce(p_detalle, ''))) < 10 then raise exception 'Cuenta qué pasó (mínimo 10 letras)'; end if;
  if coalesce(p_evidencia, '') !~ ('^' || yo.id || '/[A-Za-z0-9._-]+$') then
    raise exception 'Adjunta una evidencia (pantallazo o foto)';
  end if;
  if (select count(*) from public.denuncias where autor = yo.id and creado > now() - interval '1 day') >= 5 then
    raise exception 'Máximo 5 denuncias por día';
  end if;
  insert into public.denuncias (autor, tipo, objetivo, denunciado, motivo, detalle, evidencia)
  values (yo.id, p_tipo, p_objetivo, den, left(p_motivo, 60), left(trim(p_detalle), 800), p_evidencia);
  perform public._notificar(public._admin_id(), '🚩 Nueva denuncia', left(p_motivo, 60) || ' · ' || yo.nombre, '#/admin/denuncias');
end $$;

-- =====================================================================
--  Administración (solo el súper admin)
-- =====================================================================
create or replace function public._solo_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.es_admin() then raise exception 'Solo el administrador'; end if;
end $$;




create or replace function public.admin_suspender(p_id uuid, p_si boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  if p_id = auth.uid() then raise exception 'No puedes suspenderte'; end if;
  update public.perfiles set suspendido = p_si where id = p_id;
end $$;

create or replace function public.admin_verificaciones() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('usuario', v.usuario, 'nombre', p.nombre, 'email', p.email, 'rut', v.rut,
      'serie', v.serie, 'frente', v.frente, 'reverso', v.reverso, 'selfie', v.selfie, 'enviada', v.enviada) order by v.enviada)
    from public.verificaciones v join public.perfiles p on p.id = v.usuario where v.estado = 'pendiente'), '[]');
end $$;

create or replace function public.admin_resolver_verificacion(p_id uuid, p_aprobar boolean, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  -- Las fotos de la cédula se borran apenas se revisan: solo queda el resultado.
  update public.verificaciones set estado = case when p_aprobar then 'aprobada' else 'rechazada' end,
    motivo = case when p_aprobar then null else left(coalesce(nullif(trim(p_motivo), ''), 'Fotos poco claras'), 200) end,
    revisada = now(), frente = null, reverso = null, selfie = null
  where usuario = p_id;
  update public.perfiles set verificado = p_aprobar where id = p_id;
  if p_aprobar then
    perform public._notificar(p_id, '✅ Identidad verificada', 'Ya puedes publicar, arrendar y chatear', '#/cuenta');
  else
    -- Libera el RUT para que pueda corregirlo.
    update public.verificaciones set rut = 'X' || p_id::text where usuario = p_id;
    perform public._notificar(p_id, '❌ Verificación rechazada', coalesce(nullif(trim(p_motivo), ''), 'Fotos poco claras') || '. Vuelve a enviarla.', '#/verificar');
  end if;
end $$;

create or replace function public.admin_estacionamientos(p_q text, p_off int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare q text := '%' || lower(coalesce(trim(p_q), '')) || '%';
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', e.id, 'titulo', e.titulo, 'comuna', e.comuna, 'direccion', e.direccion, 'foto', e.fotos[1],
      'estado', e.estado, 'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes, 'vistas', e.vistas, 'creado', e.creado,
      'dueno', p.nombre, 'dueno_id', p.id) x
    from public.estacionamientos e join public.perfiles p on p.id = e.dueno
    where lower(e.titulo) like q or lower(coalesce(e.comuna, '')) like q or lower(p.nombre) like q or lower(e.direccion) like q
    order by e.creado desc offset greatest(coalesce(p_off, 0), 0) limit 50) q), '[]');
end $$;

create or replace function public.admin_ocultar(p_id uuid, p_ocultar boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  update public.estacionamientos set estado = case when p_ocultar then 'oculto' else 'pausado' end where id = p_id;
end $$;

create or replace function public.admin_denuncias(p_estado text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', d.id, 'tipo', d.tipo, 'objetivo', d.objetivo, 'motivo', d.motivo, 'detalle', d.detalle,
      'evidencia', d.evidencia, 'estado', d.estado, 'resolucion', d.resolucion, 'creado', d.creado,
      'autor', public._pj(d.autor), 'denunciado', public._pj(d.denunciado),
      'previas', (select count(*) from public.denuncias x where x.denunciado = d.denunciado)) x
    from public.denuncias d where d.estado = coalesce(p_estado, 'abierta') order by d.creado desc limit 100) q), '[]');
end $$;

create or replace function public.admin_resolver_denuncia(p_id uuid, p_accion text, p_nota text) returns void
language plpgsql security definer set search_path = public as $$
declare d public.denuncias;
begin
  perform public._solo_admin();
  select * into d from public.denuncias where id = p_id;
  if not found then raise exception 'Denuncia no encontrada'; end if;
  if p_accion = 'suspender' then update public.perfiles set suspendido = true where id = d.denunciado and not es_admin; end if;
  if p_accion = 'ocultar' and d.tipo = 'estacionamiento' then update public.estacionamientos set estado = 'oculto' where id = d.objetivo; end if;
  update public.denuncias set estado = case when p_accion = 'descartar' then 'descartada' else 'resuelta' end,
    resolucion = left(coalesce(nullif(trim(p_nota), ''), p_accion), 200) where id = p_id;
  perform public._notificar(d.autor, '🛡️ Revisamos tu denuncia', case when p_accion = 'descartar' then 'No encontramos una falta. Gracias por avisar.'
    else 'Tomamos medidas. Gracias por ayudar a cuidar la comunidad.' end, '#/avisos');
end $$;

-- El admin solo puede leer una conversación si fue denunciada.
create or replace function public.admin_conversacion(p_conv uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c public.conversaciones;
begin
  perform public._solo_admin();
  if not exists (select 1 from public.denuncias where tipo = 'conversacion' and objetivo = p_conv) then
    raise exception 'Solo puedes ver conversaciones denunciadas';
  end if;
  select * into c from public.conversaciones where id = p_conv;
  return jsonb_build_object('a', public._pj(c.a), 'b', public._pj(c.b),
    'mensajes', coalesce((select jsonb_agg(jsonb_build_object('autor', m.autor, 'texto', m.texto, 'fecha', m.creado) order by m.id)
      from public.mensajes m where m.conv = p_conv), '[]'));
end $$;

create or replace function public.admin_keys() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('key', l.key, 'meses', l.meses, 'nota', l.nota, 'creada', l.creada, 'canjeada', l.canjeada,
      'revocada', l.revocada, 'usuario', p.nombre, 'email', p.email) x
    from public.licencias l left join public.perfiles p on p.id = l.canjeada_por order by l.creada desc limit 200) q), '[]');
end $$;

create or replace function public.admin_crear_keys(p_meses int, p_cantidad int, p_nota text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k text; out text[] := '{}'; i int;
begin
  perform public._solo_admin();
  for i in 1..least(greatest(coalesce(p_cantidad, 1), 1), 50) loop
    loop
      k := 'EST-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4)) || '-' ||
        upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
      exit when not exists (select 1 from public.licencias where key = k);
    end loop;
    insert into public.licencias (key, meses, nota) values (k, greatest(coalesce(p_meses, 1), 0), left(p_nota, 80));
    out := out || k;
  end loop;
  return to_jsonb(out);
end $$;

create or replace function public.admin_revocar_key(p_key text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  update public.licencias set revocada = true where key = p_key;
end $$;



create or replace function public.admin_ajustes() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return (select jsonb_object_agg(clave, case when clave = 'vapid_private' then (case when coalesce(valor, '') <> '' then 'ok' else '' end) else valor end)
    from public.ajustes);
end $$;

create or replace function public.admin_guardar_ajustes(p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  perform public._solo_admin();
  for k in select jsonb_object_keys(p) loop
    if k in ('precio', 'link_pago', 'meses_por_pago', 'vapid_public', 'vapid_private') then
      insert into public.ajustes (clave, valor) values (k, left(p ->> k, 500))
      on conflict (clave) do update set valor = excluded.valor;
    end if;
  end loop;
end $$;

create or replace function public.admin_aviso(p_titulo text, p_cuerpo text) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform public._solo_admin();
  if length(trim(coalesce(p_titulo, ''))) < 2 then raise exception 'Escribe un título'; end if;
  insert into public.notificaciones (usuario, titulo, cuerpo, url)
  select id, left(trim(p_titulo), 80), left(p_cuerpo, 200), '#/avisos' from public.perfiles where not suspendido and not es_admin;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.admin_prueba_push() returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  perform public._notificar(auth.uid(), '🔔 Prueba de Estaciona', 'Si ves esto, las notificaciones funcionan', '#/avisos');
end $$;

-- =====================================================================
--  VERSIÓN 2 · Modelo BiciTaller adaptado a estacionamientos
--  Reglas, textos y planes editables · 2 links de pago · reservas con
--  tiempo retenido y comprobante · saldo a favor · ubicación exacta.
-- =====================================================================
create table if not exists public.config (clave text primary key, valor jsonb not null);
insert into public.config (clave, valor) values
  ('minutos_pago', '30'),            -- tiempo para pagar y subir el comprobante (la reserva queda retenida)
  ('minutos_devolucion', '10'),      -- cancelar dentro de este tiempo: se devuelve lo pagado
  ('horas_cancelacion', '24'),       -- con esta anticipación o más: queda como saldo a favor
  ('dias_saldo', '90'),              -- días que dura el saldo a favor
  ('dias_regalo', '7'),              -- Premium de regalo al crear una cuenta
  ('dias_aviso_vencimiento', '3'),   -- aviso antes de que venza el Premium
  ('dias_comprobantes', '30'),       -- los comprobantes se borran solos después de estos días
  ('dias_mensajes', '30'),           -- los mensajes del chat se borran solos después de estos días
  ('mensajes_seguidos', '3'),        -- mensajes seguidos sin respuesta
  ('mensajes_dia', '100'),           -- mensajes por día por persona
  ('dias_devolucion', '3'),          -- días que tiene el dueño para devolver un pago antes de avisar al administrador
  ('dias_anual', '365')              -- días de Premium que entrega el pago anual (el mensual usa la duración del plan)
on conflict (clave) do nothing;
insert into public.config (clave, valor) values ('version_bd', '27') on conflict (clave) do update set valor = excluded.valor;
alter table public.config enable row level security;

create table if not exists public.textos (clave text primary key, valor text not null default '');
insert into public.textos (clave, valor) values
  ('app_lema', 'Arrienda o publica estacionamientos con personas verificadas'),
  ('reserva_pago', 'Tu reserva queda apartada {minutos} minutos. Paga con el botón "Pagar", toma una captura del comprobante y súbela aquí. Si no subes el comprobante a tiempo, la reserva se libera.'),
  ('reserva_politica', 'Puedes cancelar sin costo dentro de los primeros {devolucion} minutos (se te devuelve lo pagado). Después, si cancelas con {horas} horas o más de anticipación, lo pagado queda como saldo a favor con ese dueño por {dias} días. Con menos de {horas} horas o si no llegas, pierdes lo pagado.'),
  ('premium_titulo', 'Estaciona Premium'),
  ('premium_texto', 'Publica más estacionamientos, destaca en el mapa con pin dorado, arrienda sin límites y recibe alertas de zona.'),
  ('pago_instrucciones', 'Toca "Pagar", paga en Mercado Pago, toma una captura del comprobante y súbela aquí. Te avisamos apenas se apruebe.'),
  ('bienvenida', '¡Bienvenido a Estaciona! Verifica tu identidad, completa tu perfil y configura tu link de pago para empezar a arrendar.'),
  ('aviso_seguridad', 'Nunca pagues fuera de la app sin conocer al dueño. Si algo parece estafa, denúncialo con evidencia.'),
  ('version_liberada', '')
on conflict (clave) do nothing;
alter table public.textos enable row level security;

create table if not exists public.planes (
  codigo        text primary key check (codigo in ('gratis', 'premium')),
  nombre        text not null,
  descripcion   text not null default '',
  limites       jsonb not null default '{}',
  beneficios    jsonb not null default '[]',
  duracion_dias int not null default 30 check (duracion_dias between 1 and 3650)
);
insert into public.planes (codigo, nombre, descripcion, limites, beneficios, duracion_dias) values
  ('gratis', 'Gratis', 'Lo básico para arrendar y publicar.',
   '{"publicar": 1, "arrendar": 1, "fotos": 3, "favoritos": 3, "destacado": false, "estadisticas": false, "alertas": false, "color_libre": false, "qr_color": false}',
   '["1 estacionamiento publicado", "1 arriendo activo a la vez", "3 fotos por estacionamiento", "Reservas con comprobante y chat seguro"]', 30),
  ('premium', 'Premium', 'Para quien arrienda en serio.',
   '{"publicar": 10, "arrendar": 10, "fotos": 8, "favoritos": 500, "destacado": true, "estadisticas": true, "alertas": true, "color_libre": true, "qr_color": true}',
   '["Hasta 10 estacionamientos publicados", "Hasta 10 arriendos activos", "8 fotos por estacionamiento", "Pin dorado destacado y primero en la lista", "Estadísticas de visitas, reservas e ingresos", "Alerta de nuevos estacionamientos cerca", "Color libre del perfil y QR con tu color"]', 30)
on conflict (codigo) do nothing;
alter table public.planes enable row level security;

-- Links de pago: 2 espacios por tipo, uno activo. "arriendo" = del dueño (le pagan a él). "premium" = del administrador.
create table if not exists public.links_pago (
  id          uuid primary key default gen_random_uuid(),
  dueno       uuid references public.perfiles (id) on delete cascade,
  tipo        text not null check (tipo in ('arriendo', 'premium', 'premium_anual')),
  slot        smallint not null check (slot in (1, 2)),
  monto       int not null default 0 check (monto >= 0 and monto <= 5000000),
  url         text not null default '' check (url = '' or url ~ '^https://'),
  texto       text not null default '' check (length(texto) <= 300),
  activo      boolean not null default false,
  actualizado timestamptz not null default now(),
  check ((tipo = 'arriendo') = (dueno is not null))
);
create unique index if not exists links_pago_uni on public.links_pago (coalesce(dueno, '00000000-0000-0000-0000-000000000000'::uuid), tipo, slot);
alter table public.links_pago enable row level security;
insert into public.links_pago (dueno, tipo, slot, monto, url, activo)
select null, 'premium', s,
  coalesce((select nullif(regexp_replace(valor, '\D', '', 'g'), '')::int from public.ajustes where clave = 'precio'), 4900),
  case when s = 1 then coalesce((select valor from public.ajustes where clave = 'link_pago' and valor ~ '^https://'), '') else '' end,
  s = 1
from generate_series(1, 2) s
where not exists (select 1 from public.links_pago l where l.dueno is null and l.tipo = 'premium' and l.slot = s);
-- Premium anual: "premium" es el mensual; "premium_anual" tiene sus propios 2 espacios y precio.
alter table public.links_pago drop constraint if exists links_pago_tipo_check;
alter table public.links_pago add constraint links_pago_tipo_check check (tipo in ('arriendo', 'premium', 'premium_anual'));
insert into public.links_pago (dueno, tipo, slot, monto, activo)
select null, 'premium_anual', s, 0, s = 1 from generate_series(1, 2) s
where not exists (select 1 from public.links_pago l where l.dueno is null and l.tipo = 'premium_anual' and l.slot = s);

alter table public.perfiles add column if not exists whatsapp text;

alter table public.arriendos
  add column if not exists inicio timestamptz,
  add column if not exists fin timestamptz,
  add column if not exists cantidad int not null default 1,
  add column if not exists total int not null default 0,
  add column if not exists monto_pagar int not null default 0,
  add column if not exists saldo_aplicado int not null default 0,
  add column if not exists saldo_monto int not null default 0,
  add column if not exists saldo_hasta timestamptz,
  add column if not exists expira_at timestamptz,
  add column if not exists pago_estado text not null default 'sin_pago',
  add column if not exists comprobante text,
  add column if not exists comprobante_at timestamptz,
  add column if not exists motivo text,
  add column if not exists devolver_desde timestamptz,
  add column if not exists devolver_aviso timestamptz;
update public.arriendos set devolver_desde = actualizado where pago_estado = 'devolver' and devolver_desde is null;
alter table public.arriendos drop constraint if exists arriendos_estado_check;
alter table public.arriendos add constraint arriendos_estado_check
  check (estado in ('pendiente', 'por_pagar', 'en_revision', 'aceptado', 'rechazado', 'cancelado', 'finalizado', 'expirado'));
alter table public.arriendos drop constraint if exists arriendos_pago_estado_check;
alter table public.arriendos add constraint arriendos_pago_estado_check
  check (pago_estado in ('sin_pago', 'pendiente', 'en_revision', 'pagado', 'rechazado', 'devolver', 'devuelto', 'saldo', 'perdido', 'aplicado', 'no_pagado'));
update public.arriendos set inicio = coalesce(desde::timestamptz, creado),
  fin = coalesce(desde::timestamptz, creado) + case modalidad when 'hora' then interval '1 hour' when 'dia' then interval '1 day' else interval '1 month' end
where inicio is null;
create index if not exists arr_rango on public.arriendos (estacionamiento, inicio);
create index if not exists arr_vence on public.arriendos (expira_at) where estado = 'por_pagar';
create index if not exists arr_termina on public.arriendos (fin) where estado = 'aceptado';
create index if not exists arr_devolver on public.arriendos (devolver_desde) where pago_estado = 'devolver';

alter table public.pagos
  add column if not exists monto int not null default 0,
  add column if not exists comprobante text,
  add column if not exists motivo text,
  add column if not exists resuelto timestamptz,
  add column if not exists periodo text not null default 'mes';
alter table public.pagos drop constraint if exists pagos_periodo_check;
alter table public.pagos add constraint pagos_periodo_check check (periodo in ('mes', 'anual'));

-- Ubicación exacta: el pin queda justo en el estacionamiento.
update public.estacionamientos set lat_pub = lat, lng_pub = lng where lat_pub is distinct from lat or lng_pub is distinct from lng;

-- ---------- Utilidades de configuración y planes ----------
create or replace function public._cfg(k text) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select (valor #>> '{}')::int from public.config where clave = k), 0)
$$;

create or replace function public._plan(p public.perfiles) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select limites from public.planes where codigo = case when public._premium(p) then 'premium' else 'gratis' end), '{}')
$$;

create or replace function public._lim(p public.perfiles, que text) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((public._plan(p) ->> que)::int, 0)
$$;

create or replace function public._puede(p public.perfiles, que text) returns boolean
language sql stable security definer set search_path = public as $$
  select p.es_admin or coalesce((public._plan(p) ->> que)::boolean, false)
$$;

-- Se puede reservar solo si el dueño está activo y verificado, y el estacionamiento está dentro de su plan
-- (si se le vence Premium, los que superan el límite se esconden del mapa y tampoco reciben reservas por link o QR).
create or replace function public._reservable(e public.estacionamientos) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select not p.suspendido and (p.verificado or p.es_admin) and r.n <= public._lim(p, 'publicar')
    from public.perfiles p
    join (select x.id, row_number() over (order by x.creado) n from public.estacionamientos x where x.dueno = e.dueno) r on r.id = e.id
    where p.id = e.dueno), false)
$$;

create or replace function public.puede_ver_privado(nombre text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.es_admin() or split_part(nombre, '/', 1) = auth.uid()::text
    or exists (select 1 from public.arriendos a where a.comprobante = nombre and a.dueno = auth.uid())
$$;
drop policy if exists "est privado ver" on storage.objects;
create policy "est privado ver" on storage.objects for select to authenticated
  using (bucket_id = 'privado' and public.puede_ver_privado(name));

-- ---------- Archivos que dejan de usarse ----------
drop trigger if exists arr_borrar_fotos on public.arriendos;
create trigger arr_borrar_fotos after update of comprobante or delete on public.arriendos for each row execute function public._borrar_fotos();
drop trigger if exists pag_borrar_fotos on public.pagos;
create trigger pag_borrar_fotos after update of comprobante or delete on public.pagos for each row execute function public._borrar_fotos();

-- ---------- Cuenta nueva: días de Premium de regalo (editable) ----------

-- =====================================================================
--  Datos públicos (también sin sesión)
-- =====================================================================
create or replace function public.ajustes_publicos() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'precio', coalesce(l.monto, 0), 'link_pago', coalesce(l.url, ''), 'texto_pago', coalesce(l.texto, ''),
    'vapid_public', (select valor from public.ajustes where clave = 'vapid_public'),
    'version_bd', (select valor #>> '{}' from public.config where clave = 'version_bd'),
    'reglas', (select jsonb_object_agg(clave, valor) from public.config where clave <> 'version_bd'),
    'textos', (select jsonb_object_agg(clave, valor) from public.textos),
    'planes', (select jsonb_object_agg(codigo, jsonb_build_object('nombre', nombre, 'descripcion', descripcion, 'limites', limites,
      'beneficios', beneficios, 'duracion_dias', duracion_dias)) from public.planes),
    'anual', case when coalesce(la.monto, 0) > 0 then jsonb_build_object('precio', la.monto, 'link_pago', la.url, 'texto_pago', la.texto,
      'dias', public._cfg('dias_anual')) end)
  from (select 1) x
  left join lateral (select * from public.links_pago where dueno is null and tipo = 'premium' and activo order by slot limit 1) l on true
  left join lateral (select * from public.links_pago where dueno is null and tipo = 'premium_anual' and activo order by slot limit 1) la on true
$$;

create or replace function public.mapa(p_s double precision, p_w double precision, p_n double precision, p_e double precision)
returns table (id uuid, la double precision, lo double precision, ph int, pd int, pm int, v text,
  t boolean, h boolean, sg boolean, cg boolean, c text, f text, d boolean)
language sql stable security definer set search_path = public as $$
  with vis as (
    select e.*, public._puede(p, 'destacado') as dest, public._lim(p, 'publicar') as lim,
      row_number() over (partition by e.dueno order by e.creado) as n
    from public.estacionamientos e join public.perfiles p on p.id = e.dueno
    where e.estado = 'disponible' and not p.suspendido and (p.verificado or p.es_admin)
  )
  select vis.id, vis.lat, vis.lng, vis.precio_hora, vis.precio_dia, vis.precio_mes, vis.vehiculo,
    vis.techado, vis.acceso24, vis.seguridad, vis.carga, vis.comuna, vis.fotos[1], vis.dest
  from vis
  where vis.n <= vis.lim and vis.lat between p_s and p_n and vis.lng between p_w and p_e
  order by vis.dest desc, vis.creado desc
  limit 400
$$;

-- Ficha pública: dirección y ubicación exactas. Para reservar hay que iniciar sesión.
create or replace function public.estacionamiento_detalle(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); yo public.perfiles; e public.estacionamientos; visible boolean; arr jsonb;
begin
  if me is not null then select * into yo from public.perfiles where id = me; end if;
  select * into e from public.estacionamientos where id = p_id;
  if not found or (e.estado = 'oculto' and e.dueno is distinct from me and not coalesce(yo.es_admin, false)) then
    raise exception 'Este estacionamiento ya no está disponible';
  end if;
  select (r.n <= public._lim(p, 'publicar')) into visible from (
    select x.id, row_number() over (order by x.creado) n from public.estacionamientos x where x.dueno = e.dueno) r
    join public.perfiles p on p.id = e.dueno where r.id = p_id;
  if e.dueno is distinct from me then update public.estacionamientos set vistas = vistas + 1 where id = p_id; end if;
  if me is not null then
    select jsonb_build_object('id', a.id, 'estado', a.estado, 'modalidad', a.modalidad) into arr from public.arriendos a
    where a.estacionamiento = p_id and a.arrendatario = me and a.estado in ('pendiente', 'por_pagar', 'en_revision', 'aceptado')
    order by a.creado desc limit 1;
  end if;
  return jsonb_build_object('id', e.id, 'titulo', e.titulo, 'descripcion', e.descripcion, 'comuna', e.comuna,
    'lat', e.lat, 'lng', e.lng, 'exacta', true, 'direccion', e.direccion,
    'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes, 'vehiculo', e.vehiculo, 'techado', e.techado,
    'acceso24', e.acceso24, 'seguridad', e.seguridad, 'carga', e.carga, 'fotos', to_jsonb(e.fotos), 'estado', e.estado,
    'visible', coalesce(visible, false), 'reservable', public._reservable(e), 'creado', e.creado, 'mio', e.dueno = me, 'logueado', me is not null,
    'vistas', case when e.dueno = me or coalesce(yo.es_admin, false) then e.vistas end,
    'favorito', me is not null and exists (select 1 from public.favoritos f where f.usuario = me and f.estacionamiento = p_id),
    'mi_arriendo', arr, 'dueno', public._pj(e.dueno),
    'ocupado', coalesce((select jsonb_agg(jsonb_build_object('inicio', a.inicio, 'fin', a.fin) order by a.inicio)
      from public.arriendos a where a.estacionamiento = p_id and a.estado in ('por_pagar', 'en_revision', 'aceptado') and a.fin > now()), '[]'));
end $$;

-- =====================================================================
--  Cuenta
-- =====================================================================
create or replace function public.mi_cuenta() returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.perfiles; v public.verificaciones;
begin
  select * into p from public.perfiles where id = auth.uid();
  if not found then return null; end if;
  perform public.liberar_vencidas();
  update public.perfiles set ultimo_acceso = now() where id = p.id and (ultimo_acceso is null or ultimo_acceso < now() - interval '1 hour');
  select * into v from public.verificaciones where usuario = p.id;
  return public._pj(p.id) || jsonb_build_object(
    'email', p.email, 'whatsapp', p.whatsapp, 'premium_hasta', p.premium_hasta, 'plan_origen', p.plan_origen, 'suspendido', p.suspendido,
    'acepto', p.acepto_terminos is not null, 'verif_estado', v.estado, 'verif_motivo', v.motivo,
    'alerta', case when p.alerta_km is not null then jsonb_build_object('lat', p.alerta_lat, 'lng', p.alerta_lng, 'km', p.alerta_km) end,
    'plan', public._plan(p),
    'lim', jsonb_build_object('publicar', public._lim(p, 'publicar'), 'arrendar', public._lim(p, 'arrendar'),
      'fotos', public._lim(p, 'fotos'), 'favoritos', public._lim(p, 'favoritos')),
    'uso', jsonb_build_object(
      'publicados', (select count(*) from public.estacionamientos where dueno = p.id),
      'arrendando', (select count(*) from public.arriendos where arrendatario = p.id and estado in ('pendiente', 'por_pagar', 'en_revision', 'aceptado')),
      'favoritos', (select count(*) from public.favoritos where usuario = p.id)),
    'link_listo', exists (select 1 from public.links_pago where dueno = p.id and tipo = 'arriendo' and activo and url <> ''));
end $$;

drop function if exists public.guardar_perfil(text, text, text, text, text, text);
create or replace function public.guardar_perfil(p_nombre text, p_comuna text, p_bio text, p_icono text, p_color text, p_avatar text, p_whatsapp text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo(); col text := lower(coalesce(p_color, '')); w text := regexp_replace(coalesce(p_whatsapp, ''), '[^0-9+]', '', 'g');
begin
  if length(trim(coalesce(p_nombre, ''))) < 2 then raise exception 'Escribe tu nombre'; end if;
  if col !~ '^#[0-9a-f]{6}$' then col := '#2563eb'; end if;
  if not public._puede(p, 'color_libre') and col <> p.color and col not in ('#2563eb', '#0f172a', '#16a34a', '#dc2626', '#7c3aed', '#ea580c') then
    raise exception 'El color libre (RGB) es Premium. Elige uno de la lista o hazte Premium.';
  end if;
  if p_avatar is not null and p_avatar !~ ('^' || p.id || '/[A-Za-z0-9._-]+$') then raise exception 'Foto no válida'; end if;
  if w <> '' and length(regexp_replace(w, '\D', '', 'g')) not between 8 and 15 then raise exception 'Revisa tu WhatsApp (ej: +56912345678)'; end if;
  update public.perfiles set nombre = left(trim(p_nombre), 60), comuna = left(nullif(trim(p_comuna), ''), 40),
    bio = left(nullif(trim(p_bio), ''), 280), icono = left(nullif(p_icono, ''), 8), color = col, avatar = p_avatar, whatsapp = nullif(w, '')
  where id = p.id;
  return public.mi_cuenta();
end $$;

create or replace function public.guardar_alerta(p_lat double precision, p_lng double precision, p_km real) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo();
begin
  if p_km is not null and not public._puede(p, 'alertas') then raise exception 'Las alertas de zona son Premium'; end if;
  update public.perfiles set alerta_lat = p_lat, alerta_lng = p_lng, alerta_km = least(greatest(p_km, 0.3), 20) where id = p.id;
  return public.mi_cuenta();
end $$;

drop function if exists public.ya_pague(text);
drop function if exists public.ya_pague(text, text);
create or replace function public.ya_pague(p_nota text, p_comprobante text, p_periodo text default 'mes') returns void
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo(); l public.links_pago; per text := case when p_periodo = 'anual' then 'anual' else 'mes' end;
begin
  if coalesce(p_comprobante, '') !~ ('^' || p.id || '/[A-Za-z0-9._-]+$') then raise exception 'Sube la foto del comprobante'; end if;
  if exists (select 1 from public.pagos where usuario = p.id and estado = 'pendiente') then
    raise exception 'Ya enviaste un comprobante. El administrador lo revisará pronto.';
  end if;
  select * into l from public.links_pago where dueno is null and tipo = case per when 'anual' then 'premium_anual' else 'premium' end
    and activo order by slot limit 1;
  if per = 'anual' and coalesce(l.monto, 0) = 0 then raise exception 'El plan anual no está disponible ahora'; end if;
  insert into public.pagos (usuario, nota, monto, comprobante, periodo) values (p.id, left(p_nota, 200), coalesce(l.monto, 0), p_comprobante, per);
  perform public._notificar(public._admin_id(), '💳 Comprobante de Premium ' || case per when 'anual' then 'anual' else 'mensual' end,
    p.nombre || ' subió su comprobante', '#/admin/pagos');
end $$;

-- ---------- Links de pago del dueño ----------
create or replace function public.mis_links() returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo();
begin
  insert into public.links_pago (dueno, tipo, slot, activo)
  select p.id, 'arriendo', s, false from generate_series(1, 2) s
  where not exists (select 1 from public.links_pago l where l.dueno = p.id and l.tipo = 'arriendo' and l.slot = s);
  return (select jsonb_agg(jsonb_build_object('slot', slot, 'monto', monto, 'url', url, 'texto', texto, 'activo', activo) order by slot)
    from public.links_pago where dueno = p.id and tipo = 'arriendo');
end $$;

create or replace function public._guardar_link(p_dueno uuid, p_tipo text, p_slot int, p_monto int, p_url text, p_texto text, p_activo boolean) returns void
language plpgsql security definer set search_path = public as $$
declare u text := trim(coalesce(p_url, ''));
begin
  if p_slot not in (1, 2) then raise exception 'Espacio no válido'; end if;
  if u <> '' and u !~ '^https://' then raise exception 'El link debe empezar con https://'; end if;
  if coalesce(p_monto, 0) < 0 or coalesce(p_monto, 0) > 5000000 then raise exception 'Revisa el monto'; end if;
  insert into public.links_pago (dueno, tipo, slot, activo) select p_dueno, p_tipo, x, false from generate_series(1, 2) x
  where not exists (select 1 from public.links_pago where dueno is not distinct from p_dueno and tipo = p_tipo and slot = x);
  update public.links_pago set monto = coalesce(p_monto, 0), url = u, texto = left(coalesce(p_texto, ''), 300),
    activo = coalesce(p_activo, false), actualizado = now()
  where dueno is not distinct from p_dueno and tipo = p_tipo and slot = p_slot;
  if p_activo then
    update public.links_pago set activo = false where dueno is not distinct from p_dueno and tipo = p_tipo and slot <> p_slot;
  end if;
end $$;

create or replace function public.guardar_link(p_slot int, p_monto int, p_url text, p_texto text, p_activo boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p public.perfiles := public._yo();
begin
  perform public._guardar_link(p.id, 'arriendo', p_slot, p_monto, p_url, p_texto, p_activo);
  return public.mis_links();
end $$;

-- =====================================================================
--  Reservas (modelo BiciTaller): se aparta, se paga, se sube comprobante,
--  el dueño aprueba o rechaza; si no se paga a tiempo se libera sola.
-- =====================================================================
create or replace function public.liberar_vencidas() returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in update public.arriendos set estado = 'expirado',
      pago_estado = case when saldo_aplicado > 0 then 'saldo' else 'no_pagado' end,
      saldo_monto = saldo_aplicado,
      saldo_hasta = case when saldo_aplicado > 0 then now() + make_interval(days => public._cfg('dias_saldo')) end,
      actualizado = now()
    where estado = 'por_pagar' and expira_at < now()
    returning id, arrendatario, dueno loop
    n := n + 1;
    perform public._notificar(r.arrendatario, '⌛ Tu reserva se liberó', 'No alcanzaste a subir el comprobante a tiempo', '#/reservas');
    perform public._notificar(r.dueno, '⌛ Reserva liberada', 'Una reserva no se pagó a tiempo y se liberó', '#/reservas');
  end loop;
  perform public.finalizar_terminados();
  perform public.avisar_devoluciones();
  return n;
end $$;

-- Los arriendos confirmados terminan solos al pasar su hora de término (así no bloquean el cupo del plan)
-- y se pide la calificación a ambos.
create or replace function public.finalizar_terminados() returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in update public.arriendos a set estado = 'finalizado', actualizado = now()
    from public.estacionamientos e
    where e.id = a.estacionamiento and a.estado = 'aceptado' and a.fin < now()
    returning a.id, a.dueno, a.arrendatario, a.modalidad, a.estacionamiento, e.titulo loop
    n := n + 1;
    perform public._notificar(r.arrendatario, '⭐ Tu arriendo terminó', '¿Cómo te fue en "' || r.titulo || '"? Califica al dueño', '#/r/' || r.id);
    perform public._notificar(r.dueno, '⭐ Arriendo terminado', 'Terminó el arriendo de "' || r.titulo || '". Califica a quien arrendó', '#/r/' || r.id);
    if r.modalidad = 'mes' then
      update public.estacionamientos set estado = 'disponible' where id = r.estacionamiento and estado = 'ocupado'
        and not exists (select 1 from public.arriendos x where x.estacionamiento = r.estacionamiento and x.estado = 'aceptado' and x.modalidad = 'mes');
    end if;
  end loop;
  return n;
end $$;

-- Pagos "por devolver" que pasan del plazo: avisa al administrador (y le recuerda al dueño), una sola vez.
create or replace function public.avisar_devoluciones() returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0; adm uuid := public._admin_id();
begin
  for r in update public.arriendos a set devolver_aviso = now()
    from public.estacionamientos e, public.perfiles d
    where e.id = a.estacionamiento and d.id = a.dueno and a.pago_estado = 'devolver' and a.devolver_aviso is null
      and a.devolver_desde < now() - make_interval(days => greatest(public._cfg('dias_devolucion'), 1))
    returning a.id, a.dueno, replace(to_char(a.monto_pagar + a.saldo_aplicado, 'FM999,999,999'), ',', '.') as monto, e.titulo, d.nombre loop
    n := n + 1;
    perform public._notificar(r.dueno, '💸 Tienes una devolución pendiente', 'Devuelve $' || r.monto || ' de "' || r.titulo || '" y márcalo como devuelto', '#/r/' || r.id);
    if adm is not null and adm <> r.dueno then
      perform public._notificar(adm, '💸 Devolución atrasada', r.nombre || ' no ha devuelto $' || r.monto || ' de "' || r.titulo || '"', '#/admin');
    end if;
  end loop;
  return n;
end $$;

drop function if exists public.solicitar_arriendo(uuid, text, date, text);
create or replace function public.solicitar_arriendo(p_id uuid, p_modalidad text, p_inicio timestamptz, p_cantidad int, p_nota text) returns uuid
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); e public.estacionamientos; nid uuid; precio int; unidad interval; v_fin timestamptz;
  v_total int; v_pagar int; lk public.links_pago; v_saldo int := 0; max_c int;
begin
  perform public.liberar_vencidas();
  perform public._verificado(yo);
  select * into e from public.estacionamientos where id = p_id;
  if not found or e.estado <> 'disponible' then raise exception 'Este estacionamiento no está disponible ahora'; end if;
  if e.dueno = yo.id then raise exception 'Es tu propio estacionamiento'; end if;
  if not public._reservable(e) then raise exception 'Este estacionamiento no está recibiendo reservas por ahora'; end if;
  precio := case p_modalidad when 'hora' then e.precio_hora when 'dia' then e.precio_dia when 'mes' then e.precio_mes end;
  if coalesce(precio, 0) <= 0 then raise exception 'Este estacionamiento no se arrienda de esa forma'; end if;
  unidad := case p_modalidad when 'hora' then interval '1 hour' when 'dia' then interval '1 day' else interval '1 month' end;
  max_c := case p_modalidad when 'hora' then 24 when 'dia' then 31 else 12 end;
  if p_cantidad is null or p_cantidad < 1 or p_cantidad > max_c then raise exception 'Cantidad no válida (máximo %)', max_c; end if;
  if p_inicio is null or p_inicio < now() - interval '15 minutes' then raise exception 'Elige una fecha y hora desde ahora en adelante'; end if;
  if p_inicio > now() + interval '180 days' then raise exception 'Puedes reservar con hasta 180 días de anticipación'; end if;
  v_fin := p_inicio + unidad * p_cantidad;
  if exists (select 1 from public.bloqueos where (quien = e.dueno and bloqueado = yo.id) or (quien = yo.id and bloqueado = e.dueno)) then
    raise exception 'No puedes contactar a esta persona';
  end if;
  if exists (select 1 from public.arriendos where estacionamiento = p_id and arrendatario = yo.id and estado in ('pendiente', 'por_pagar', 'en_revision')) then
    raise exception 'Ya tienes una reserva en curso para este estacionamiento';
  end if;
  if (select count(*) from public.arriendos where arrendatario = yo.id and estado in ('pendiente', 'por_pagar', 'en_revision', 'aceptado')) >= public._lim(yo, 'arrendar') then
    raise exception 'Tu plan permite % arriendo(s) a la vez. Hazte Premium para tener más.', public._lim(yo, 'arrendar');
  end if;
  if exists (select 1 from public.arriendos a where a.estacionamiento = p_id and a.estado in ('por_pagar', 'en_revision', 'aceptado')
      and tstzrange(a.inicio, a.fin) && tstzrange(p_inicio, v_fin)) then
    raise exception 'Ese horario ya está reservado. Elige otro.';
  end if;
  v_total := precio * p_cantidad;
  select * into lk from public.links_pago where dueno = e.dueno and tipo = 'arriendo' and activo order by slot limit 1;
  -- Si el dueño fijó un abono, se paga eso para confirmar (el resto se paga al llegar).
  v_pagar := case when coalesce(lk.monto, 0) > 0 then least(lk.monto, v_total) else v_total end;
  with s as (
    update public.arriendos set pago_estado = 'aplicado', actualizado = now()
    where arrendatario = yo.id and dueno = e.dueno and pago_estado = 'saldo' and saldo_hasta > now()
    returning saldo_monto)
  select coalesce(sum(saldo_monto), 0) into v_saldo from s;
  v_pagar := greatest(0, v_pagar - v_saldo);
  insert into public.arriendos (estacionamiento, dueno, arrendatario, modalidad, desde, inicio, fin, cantidad, total, monto_pagar,
    saldo_aplicado, nota, estado, pago_estado, expira_at)
  values (p_id, e.dueno, yo.id, p_modalidad, (p_inicio at time zone 'America/Santiago')::date, p_inicio, v_fin, p_cantidad, v_total, v_pagar,
    v_saldo, left(p_nota, 300), case when v_pagar > 0 then 'por_pagar' else 'en_revision' end,
    case when v_pagar > 0 then 'pendiente' else 'en_revision' end,
    now() + make_interval(mins => greatest(public._cfg('minutos_pago'), 5)))
  returning id into nid;
  perform public._notificar(e.dueno, case when v_pagar > 0 then '⏳ Nueva reserva: esperando pago' else '🧾 Nueva reserva por revisar' end,
    yo.nombre || ' reservó "' || e.titulo || '"', '#/reservas');
  return nid;
end $$;

create or replace function public.subir_comprobante(p_id uuid, p_ruta text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); a public.arriendos;
begin
  perform public.liberar_vencidas();
  select * into a from public.arriendos where id = p_id for update;
  if not found or a.arrendatario <> yo.id then raise exception 'Reserva no encontrada'; end if;
  if a.estado not in ('por_pagar', 'en_revision') then raise exception 'Esta reserva ya no espera pago'; end if;
  if coalesce(p_ruta, '') !~ ('^' || yo.id || '/[A-Za-z0-9._-]+$') then raise exception 'Sube la foto del comprobante'; end if;
  update public.arriendos set estado = 'en_revision', pago_estado = 'en_revision', comprobante = p_ruta, comprobante_at = now(), actualizado = now()
  where id = p_id;
  perform public._notificar(a.dueno, '🧾 Comprobante por revisar', yo.nombre || ' subió el comprobante de su reserva', '#/reservas');
end $$;

drop function if exists public.responder_arriendo(uuid, boolean);
create or replace function public.responder_arriendo(p_id uuid, p_aceptar boolean, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); a public.arriendos; e public.estacionamientos; o record;
begin
  select * into a from public.arriendos where id = p_id for update;
  if not found or a.dueno <> yo.id or a.estado not in ('pendiente', 'por_pagar', 'en_revision') then
    raise exception 'Esta reserva ya no está pendiente';
  end if;
  select * into e from public.estacionamientos where id = a.estacionamiento;
  if p_aceptar then
    update public.arriendos set estado = 'aceptado', expira_at = null,
      pago_estado = case when a.monto_pagar > 0 or a.saldo_aplicado > 0 or a.pago_estado = 'en_revision' then 'pagado' else a.pago_estado end,
      actualizado = now() where id = p_id;
    perform public._notificar(a.arrendatario, '✅ ¡Reserva confirmada!', 'Tu reserva en "' || e.titulo || '" está confirmada', '#/reservas');
    if a.modalidad = 'mes' then
      update public.estacionamientos set estado = 'ocupado' where id = e.id and estado = 'disponible';
      for o in update public.arriendos set estado = 'rechazado', actualizado = now()
        where estacionamiento = e.id and estado = 'pendiente' and id <> p_id returning arrendatario loop
        perform public._notificar(o.arrendatario, '❌ Solicitud no aceptada', '"' || e.titulo || '" ya fue arrendado', '#/reservas');
      end loop;
    end if;
  else
    update public.arriendos set estado = 'rechazado', motivo = left(nullif(trim(p_motivo), ''), 300), expira_at = null,
      pago_estado = case when a.saldo_aplicado > 0 then 'saldo' when a.pago_estado = 'en_revision' then 'rechazado' else a.pago_estado end,
      saldo_monto = a.saldo_aplicado,
      saldo_hasta = case when a.saldo_aplicado > 0 then now() + make_interval(days => public._cfg('dias_saldo')) end,
      actualizado = now() where id = p_id;
    perform public._notificar(a.arrendatario, '❌ Reserva no aceptada', coalesce(nullif(trim(p_motivo), ''), 'El dueño de "' || e.titulo || '" no aceptó tu reserva'), '#/reservas');
  end if;
end $$;

create or replace function public.cerrar_arriendo(p_id uuid, p_accion text) returns void
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); a public.arriendos; t text; otro uuid; pagado int; res text; txt text;
begin
  select * into a from public.arriendos where id = p_id for update;
  if not found or yo.id not in (a.dueno, a.arrendatario) then raise exception 'Reserva no encontrada'; end if;
  select titulo into t from public.estacionamientos where id = a.estacionamiento;
  otro := case when yo.id = a.dueno then a.arrendatario else a.dueno end;
  pagado := a.monto_pagar + a.saldo_aplicado;
  if p_accion = 'cancelar' and a.estado in ('pendiente', 'por_pagar') then
    update public.arriendos set estado = 'cancelado', expira_at = null,
      pago_estado = case when a.saldo_aplicado > 0 then 'saldo' else 'sin_pago' end, saldo_monto = a.saldo_aplicado,
      saldo_hasta = case when a.saldo_aplicado > 0 then now() + make_interval(days => public._cfg('dias_saldo')) end,
      actualizado = now() where id = p_id;
    perform public._notificar(otro, '🚫 Reserva cancelada', yo.nombre || ' canceló la reserva de "' || t || '"', '#/reservas');
  elsif p_accion = 'cancelar' and a.estado in ('en_revision', 'aceptado') then
    res := case
      when pagado = 0 then 'sin_pago'
      when yo.id = a.dueno then 'devolver'
      when now() - a.creado <= make_interval(mins => public._cfg('minutos_devolucion')) then 'devolver'
      when a.inicio - now() >= make_interval(hours => public._cfg('horas_cancelacion')) then 'saldo'
      else 'perdido' end;
    update public.arriendos set estado = 'cancelado', pago_estado = res,
      devolver_desde = case when res = 'devolver' then now() end, devolver_aviso = null,
      saldo_monto = case when res = 'saldo' then pagado else 0 end,
      saldo_hasta = case when res = 'saldo' then now() + make_interval(days => public._cfg('dias_saldo')) end,
      actualizado = now() where id = p_id;
    txt := case res when 'devolver' then 'Se debe devolver lo pagado' when 'saldo' then 'Lo pagado queda como saldo a favor'
      when 'perdido' then 'Se canceló con poca anticipación: no hay devolución' else '' end;
    perform public._notificar(otro, '🚫 Reserva cancelada', yo.nombre || ' canceló "' || t || '". ' || txt, '#/reservas');
  elsif p_accion = 'finalizar' and a.estado = 'aceptado' then
    update public.arriendos set estado = 'finalizado', actualizado = now() where id = p_id;
    perform public._notificar(otro, '⭐ Arriendo finalizado', 'Califica tu experiencia en "' || t || '"', '#/reservas');
  elsif p_accion = 'devuelto' and yo.id = a.dueno and a.pago_estado = 'devolver' then
    update public.arriendos set pago_estado = 'devuelto', actualizado = now() where id = p_id;
    perform public._notificar(otro, '💸 Te devolvieron el pago', 'El dueño de "' || t || '" marcó la devolución', '#/reservas');
    return;
  else
    raise exception 'No se puede hacer esto con esta reserva';
  end if;
  if a.estado = 'aceptado' and a.modalidad = 'mes' then
    update public.estacionamientos set estado = 'disponible' where id = a.estacionamiento and estado = 'ocupado'
      and not exists (select 1 from public.arriendos x where x.estacionamiento = a.estacionamiento and x.estado = 'aceptado' and x.modalidad = 'mes');
  end if;
end $$;

create or replace function public.mis_arriendos() returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  perform public.liberar_vencidas();
  return coalesce((select jsonb_agg(x order by (x ->> 'orden')::int, x ->> 'inicio') from (
    select jsonb_build_object('id', a.id, 'estado', a.estado, 'pago_estado', a.pago_estado, 'modalidad', a.modalidad,
      'inicio', a.inicio, 'fin', a.fin, 'cantidad', a.cantidad, 'total', a.total, 'monto_pagar', a.monto_pagar,
      'saldo_aplicado', a.saldo_aplicado, 'saldo_monto', a.saldo_monto, 'saldo_hasta', a.saldo_hasta, 'expira_at', a.expira_at,
      'motivo', a.motivo, 'nota', a.nota, 'creado', a.creado, 'soy_dueno', a.dueno = me, 'comprobante', a.comprobante,
      'orden', case a.estado when 'en_revision' then 0 when 'por_pagar' then 1 when 'pendiente' then 1 when 'aceptado' then 2 else 3 end,
      'est', jsonb_build_object('id', e.id, 'titulo', e.titulo, 'comuna', e.comuna, 'foto', e.fotos[1], 'direccion', e.direccion,
        'lat', e.lat, 'lng', e.lng, 'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes),
      'otro', public._pj(case when a.dueno = me then a.arrendatario else a.dueno end),
      'whatsapp', case when a.estado in ('aceptado', 'finalizado', 'en_revision') then
        (select whatsapp from public.perfiles where id = case when a.dueno = me then a.arrendatario else a.dueno end) end,
      'pago', case when a.arrendatario = me and a.estado in ('por_pagar', 'en_revision') then
        (select jsonb_build_object('url', l.url, 'texto', l.texto) from public.links_pago l
         where l.dueno = a.dueno and l.tipo = 'arriendo' and l.activo order by l.slot limit 1) end,
      'calificado', exists (select 1 from public.calificaciones c where c.arriendo = a.id and c.autor = me)) x
    from public.arriendos a join public.estacionamientos e on e.id = a.estacionamiento
    where a.dueno = me or a.arrendatario = me
    order by a.creado desc limit 300) q), '[]');
end $$;

create or replace function public.panel() returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); hoy date := (now() at time zone 'America/Santiago')::date;
begin
  perform public.liberar_vencidas();
  return jsonb_build_object(
    'revisar', (select count(*) from public.arriendos where dueno = yo.id and estado in ('en_revision', 'pendiente')),
    'hoy', (select count(*) from public.arriendos where dueno = yo.id and estado = 'aceptado'
      and (inicio at time zone 'America/Santiago')::date <= hoy and (fin at time zone 'America/Santiago')::date >= hoy),
    'pagando', (select count(*) from public.arriendos where dueno = yo.id and estado = 'por_pagar'),
    'devolver', (select count(*) from public.arriendos where dueno = yo.id and pago_estado = 'devolver'),
    'falta', jsonb_build_object(
      'verificar', not yo.verificado,
      'whatsapp', yo.whatsapp is null,
      'link', not exists (select 1 from public.links_pago where dueno = yo.id and tipo = 'arriendo' and activo and url <> ''),
      'publicar', not exists (select 1 from public.estacionamientos where dueno = yo.id)));
end $$;

create or replace function public.mis_estadisticas() returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  if not public._puede(yo, 'estadisticas') then raise exception 'Las estadísticas son Premium'; end if;
  return jsonb_build_object(
    'meses', coalesce((select jsonb_agg(jsonb_build_object('mes', to_char(m, 'MM/YY'),
        'reservas', (select count(*) from public.arriendos a where a.dueno = yo.id and a.estado in ('aceptado', 'finalizado')
          and date_trunc('month', a.inicio at time zone 'America/Santiago') = m),
        'ingresos', (select coalesce(sum(a.total), 0) from public.arriendos a where a.dueno = yo.id and a.estado in ('aceptado', 'finalizado')
          and date_trunc('month', a.inicio at time zone 'America/Santiago') = m)) order by m)
      from generate_series(date_trunc('month', now() at time zone 'America/Santiago') - interval '5 months',
        date_trunc('month', now() at time zone 'America/Santiago'), interval '1 month') m), '[]'),
    'vistas', (select coalesce(sum(vistas), 0) from public.estacionamientos where dueno = yo.id),
    'favoritos', (select count(*) from public.favoritos f join public.estacionamientos e on e.id = f.estacionamiento where e.dueno = yo.id),
    'canceladas', (select count(*) from public.arriendos where dueno = yo.id and estado in ('cancelado', 'expirado')),
    'por_modalidad', (select coalesce(jsonb_object_agg(modalidad, n), '{}') from (select modalidad, count(*) n from public.arriendos
      where dueno = yo.id and estado in ('aceptado', 'finalizado') group by 1) q));
end $$;

create or replace function public.mis_estacionamientos() returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); st boolean := public._puede(yo, 'estadisticas'); lim int := public._lim(yo, 'publicar');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'titulo', e.titulo, 'comuna', e.comuna, 'foto', e.fotos[1],
      'estado', e.estado, 'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes, 'visible', r.n <= lim,
      'stats', case when st then jsonb_build_object('vistas', e.vistas,
        'favoritos', (select count(*) from public.favoritos f where f.estacionamiento = e.id),
        'solicitudes', (select count(*) from public.arriendos a where a.estacionamiento = e.id)) end) order by e.creado)
    from public.estacionamientos e
    join (select id, row_number() over (order by creado) n from public.estacionamientos where dueno = yo.id) r on r.id = e.id
    where e.dueno = yo.id), '[]');
end $$;

create or replace function public.contadores() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'mensajes', (select count(*) from public.mensajes m join public.conversaciones c on c.id = m.conv
      where (c.a = auth.uid() or c.b = auth.uid()) and m.autor <> auth.uid() and not m.visto),
    'avisos', (select count(*) from public.notificaciones where usuario = auth.uid() and not leida and not chat),
    'solicitudes', (select count(*) from public.arriendos where dueno = auth.uid() and estado in ('pendiente', 'en_revision')
      or (dueno = auth.uid() and pago_estado = 'devolver')))
$$;

-- Perfil público: solo el promedio de estrellas (sin comentarios).
create or replace function public.perfil_publico(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo();
begin
  if not exists (select 1 from public.perfiles where id = p_id) then raise exception 'Perfil no encontrado'; end if;
  return public._pj(p_id) || jsonb_build_object(
    'bloqueado', exists (select 1 from public.bloqueos where quien = yo.id and bloqueado = p_id),
    'estacionamientos', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'titulo', e.titulo, 'comuna', e.comuna,
        'foto', e.fotos[1], 'ph', e.precio_hora, 'pd', e.precio_dia, 'pm', e.precio_mes) order by e.creado)
      from public.estacionamientos e where e.dueno = p_id and e.estado in ('disponible', 'ocupado')), '[]'),
    'opiniones', '[]'::jsonb);
end $$;

create or replace function public.enviar_mensaje(p_conv uuid, p_texto text) returns bigint
language plpgsql security definer set search_path = public as $$
declare yo public.perfiles := public._yo(); c public.conversaciones; otro public.perfiles; t text := trim(coalesce(p_texto, ''));
  seguidos int; mid bigint; lim_seg int := greatest(public._cfg('mensajes_seguidos'), 1); lim_dia int := greatest(public._cfg('mensajes_dia'), 1);
begin
  select * into c from public.conversaciones where id = p_conv;
  if not found or yo.id not in (c.a, c.b) then raise exception 'Conversación no encontrada'; end if;
  select * into otro from public.perfiles where id = case when c.a = yo.id then c.b else c.a end;
  if t = '' then raise exception 'Escribe un mensaje'; end if;
  if length(t) > 500 then raise exception 'Máximo 500 caracteres'; end if;
  if not yo.es_admin then
    if not otro.es_admin then
      perform public._verificado(yo);
      if exists (select 1 from public.bloqueos where (quien = otro.id and bloqueado = yo.id) or (quien = yo.id and bloqueado = otro.id)) then
        raise exception 'No puedes escribir a esta persona (bloqueo)';
      end if;
    end if;
    select count(*) into seguidos from public.mensajes where conv = p_conv and autor = yo.id
      and id > coalesce((select max(id) from public.mensajes where conv = p_conv and autor <> yo.id), 0);
    if seguidos >= lim_seg then raise exception 'Máximo % mensajes seguidos. Espera la respuesta 🙂', lim_seg; end if;
    if (select count(*) from public.mensajes where autor = yo.id and creado > now() - interval '1 day') >= lim_dia then
      raise exception 'Llegaste al máximo de % mensajes por día', lim_dia;
    end if;
  end if;
  insert into public.mensajes (conv, autor, texto) values (p_conv, yo.id, t) returning id into mid;
  update public.conversaciones set ultimo = now(), ultimo_texto = left(t, 80), ultimo_autor = yo.id where id = p_conv;
  if not exists (select 1 from public.bloqueos where quien = otro.id and bloqueado = yo.id) then
    perform public._notificar(otro.id, '💬 ' || yo.nombre, t, '#/chat/' || p_conv, true);
  end if;
  return mid;
end $$;

-- =====================================================================
--  Administración v2
-- =====================================================================
create or replace function public.admin_resumen() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  perform public.liberar_vencidas();
  return jsonb_build_object(
    'usuarios', (select count(*) from public.perfiles),
    'nuevos7', (select count(*) from public.perfiles where creado > now() - interval '7 days'),
    'activos7', (select count(*) from public.perfiles where ultimo_acceso > now() - interval '7 days'),
    'verificados', (select count(*) from public.perfiles where verificado),
    'premium', (select count(*) from public.perfiles p where p.premium_hasta > now() and p.plan_origen <> 'prueba' and not p.es_admin),
    'prueba', (select count(*) from public.perfiles p where p.premium_hasta > now() and p.plan_origen = 'prueba' and not p.es_admin),
    'por_vencer', (select count(*) from public.perfiles p where p.premium_hasta between now() and now() + interval '7 days' and not p.es_admin),
    'suspendidos', (select count(*) from public.perfiles where suspendido),
    'estacionamientos', (select count(*) from public.estacionamientos),
    'disponibles', (select count(*) from public.estacionamientos where estado = 'disponible'),
    'arriendos_activos', (select count(*) from public.arriendos where estado = 'aceptado'),
    'arriendos_total', (select count(*) from public.arriendos),
    'reservas_revision', (select count(*) from public.arriendos where estado = 'en_revision'),
    'pend_verif', (select count(*) from public.verificaciones where estado = 'pendiente'),
    'pend_denuncias', (select count(*) from public.denuncias where estado = 'abierta'),
    'pend_pagos', (select count(*) from public.pagos where estado = 'pendiente'),
    'devoluciones', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'titulo', e.titulo, 'monto', a.monto_pagar + a.saldo_aplicado,
        'desde', a.devolver_desde, 'dueno', public._pj(a.dueno), 'arrendatario', public._pj(a.arrendatario)) order by a.devolver_desde)
      from public.arriendos a join public.estacionamientos e on e.id = a.estacionamiento
      where a.pago_estado = 'devolver' and a.devolver_desde < now() - make_interval(days => greatest(public._cfg('dias_devolucion'), 1))), '[]'),
    'ingresos_mes', (select coalesce(sum(monto), 0) from public.pagos where estado = 'aprobado'
      and date_trunc('month', coalesce(resuelto, creado)) = date_trunc('month', now())),
    'keys_libres', (select count(*) from public.licencias where canjeada_por is null and not revocada),
    'version_bd', (select valor #>> '{}' from public.config where clave = 'version_bd'),
    'registros', coalesce((select jsonb_agg(jsonb_build_object('d', d, 'n', n) order by d) from (
      select g::date d, (select count(*) from public.perfiles where creado::date = g::date) n
      from generate_series(current_date - 13, current_date, interval '1 day') g) q), '[]'),
    'comunas', coalesce((select jsonb_agg(jsonb_build_object('c', comuna, 'n', n)) from (
      select coalesce(comuna, 'Sin comuna') comuna, count(*) n from public.estacionamientos group by 1 order by 2 desc limit 6) q), '[]'),
    'tablas', coalesce((select jsonb_agg(jsonb_build_object('t', c.relname, 'b', pg_total_relation_size(c.oid), 'n', greatest(c.reltuples, 0)::bigint)
        order by pg_total_relation_size(c.oid) desc)
      from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r'), '[]'),
    'servidor', jsonb_build_object(
      'db', pg_database_size(current_database()), 'db_lim', 500 * 1024 * 1024,
      'fotos', (select coalesce(sum((metadata ->> 'size')::bigint), 0) from storage.objects where bucket_id = 'fotos'),
      'privado', (select coalesce(sum((metadata ->> 'size')::bigint), 0) from storage.objects where bucket_id = 'privado'),
      'archivos', (select count(*) from storage.objects where bucket_id in ('fotos', 'privado')),
      'st_lim', 1024 * 1024 * 1024,
      'mensajes', (select count(*) from public.mensajes),
      'por_borrar', (select count(*) from public.por_borrar)));
end $$;

create or replace function public.admin_usuarios(p_q text, p_filtro text, p_off int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare q text := '%' || lower(coalesce(trim(p_q), '')) || '%';
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('id', p.id, 'nombre', p.nombre, 'email', p.email, 'avatar', p.avatar, 'icono', p.icono, 'color', p.color,
      'verificado', p.verificado, 'premium_hasta', p.premium_hasta, 'premium', public._premium(p), 'plan_origen', p.plan_origen,
      'suspendido', p.suspendido, 'admin', p.es_admin, 'creado', p.creado, 'ultimo_acceso', p.ultimo_acceso, 'rut', v.rut, 'whatsapp', p.whatsapp,
      'publicados', (select count(*) from public.estacionamientos e where e.dueno = p.id),
      'arriendos', (select count(*) from public.arriendos a where a.arrendatario = p.id or a.dueno = p.id),
      'denuncias', (select count(*) from public.denuncias d where d.denunciado = p.id)) x
    from public.perfiles p left join public.verificaciones v on v.usuario = p.id
    where (lower(p.nombre) like q or p.email like q or coalesce(v.rut, '') like upper(q))
      and case coalesce(p_filtro, '')
        when 'premium' then public._premium(p) and not p.es_admin
        when 'gratis' then not public._premium(p)
        when 'por_vencer' then p.premium_hasta between now() and now() + interval '7 days'
        when 'inactivos' then coalesce(p.ultimo_acceso, p.creado) < now() - interval '30 days'
        when 'verificados' then p.verificado
        when 'sin_verificar' then not p.verificado
        when 'suspendidos' then p.suspendido
        else true end
    order by p.creado desc offset greatest(coalesce(p_off, 0), 0) limit 50) q), '[]');
end $$;

-- Dar o quitar Premium por días: >0 suma días · 0 de por vida · -1 quita.
drop function if exists public.admin_premium(uuid, int);
create or replace function public.admin_premium(p_id uuid, p_dias int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  update public.perfiles set
    premium_hasta = case when p_dias < 0 then null when p_dias = 0 then 'infinity'::timestamptz
      else greatest(now(), coalesce(premium_hasta, now())) + make_interval(days => p_dias) end,
    plan_origen = case when p_dias < 0 then plan_origen else 'admin' end
  where id = p_id;
  perform public._notificar(p_id, case when p_dias < 0 then 'Tu Premium terminó' else '⭐ ¡Ya eres Premium!' end,
    case when p_dias < 0 then 'Tu cuenta volvió al plan Gratis' else 'Disfruta todas las funciones Premium' end, '#/premium');
end $$;

drop function if exists public.admin_pagos();
create or replace function public.admin_pagos(p_estado text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return coalesce((select jsonb_agg(x) from (select jsonb_build_object('id', g.id, 'nota', g.nota, 'monto', g.monto, 'comprobante', g.comprobante,
      'estado', g.estado, 'motivo', g.motivo, 'creado', g.creado, 'periodo', g.periodo, 'resuelto', g.resuelto, 'usuario', public._pj(g.usuario), 'email', p.email) x
    from public.pagos g join public.perfiles p on p.id = g.usuario
    where g.estado = coalesce(nullif(p_estado, ''), 'pendiente') order by g.creado desc limit 100) q), '[]');
end $$;

drop function if exists public.admin_resolver_pago(uuid, boolean);
create or replace function public.admin_resolver_pago(p_id uuid, p_aprobar boolean, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
declare g public.pagos; d int;
begin
  perform public._solo_admin();
  select * into g from public.pagos where id = p_id and estado = 'pendiente';
  if not found then raise exception 'Ese pago ya fue revisado'; end if;
  d := case when g.periodo = 'anual' then greatest(public._cfg('dias_anual'), 1)
    else coalesce((select duracion_dias from public.planes where codigo = 'premium'), 30) end;
  update public.pagos set estado = case when p_aprobar then 'aprobado' else 'rechazado' end, resuelto = now(),
    motivo = left(nullif(trim(p_motivo), ''), 200) where id = p_id;
  if p_aprobar then
    perform public.admin_premium(g.usuario, d);
    update public.perfiles set plan_origen = 'pago' where id = g.usuario;
  else
    perform public._notificar(g.usuario, '❌ Pago no aprobado', coalesce(nullif(trim(p_motivo), ''), 'No encontramos tu pago') || '. Escríbenos a soporte.', '#/premium');
  end if;
end $$;

create or replace function public.admin_config() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  return jsonb_build_object(
    'reglas', (select jsonb_object_agg(clave, valor) from public.config where clave <> 'version_bd'),
    'textos', (select jsonb_object_agg(clave, valor) from public.textos),
    'planes', (select jsonb_agg(to_jsonb(p) order by p.codigo desc) from public.planes p),
    'links', (select jsonb_agg(jsonb_build_object('slot', slot, 'monto', monto, 'url', url, 'texto', texto, 'activo', activo) order by slot)
      from public.links_pago where dueno is null and tipo = 'premium'),
    'links_anual', (select jsonb_agg(jsonb_build_object('slot', slot, 'monto', monto, 'url', url, 'texto', texto, 'activo', activo) order by slot)
      from public.links_pago where dueno is null and tipo = 'premium_anual'),
    'push', (select coalesce(valor, '') <> '' from public.ajustes where clave = 'vapid_private'),
    'vapid_public', (select valor from public.ajustes where clave = 'vapid_public'));
end $$;

create or replace function public.admin_guardar_config(p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare k text; v int;
begin
  perform public._solo_admin();
  for k in select jsonb_object_keys(p) loop
    if k <> 'version_bd' and exists (select 1 from public.config where clave = k) then
      v := (p ->> k)::int;
      if v < 0 or v > 100000 then raise exception 'Valor fuera de rango en %', k; end if;
      update public.config set valor = to_jsonb(v) where clave = k;
    end if;
  end loop;
end $$;

create or replace function public.admin_guardar_textos(p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  perform public._solo_admin();
  for k in select jsonb_object_keys(p) loop
    update public.textos set valor = left(p ->> k, 2000) where clave = k;
  end loop;
end $$;

create or replace function public.admin_guardar_plan(p_codigo text, p_nombre text, p_descripcion text, p_limites jsonb, p_beneficios jsonb, p_duracion int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  if jsonb_typeof(p_limites) <> 'object' or jsonb_typeof(p_beneficios) <> 'array' then raise exception 'Datos del plan no válidos'; end if;
  update public.planes set nombre = left(coalesce(nullif(trim(p_nombre), ''), nombre), 40), descripcion = left(coalesce(p_descripcion, ''), 300),
    limites = limites || p_limites, beneficios = p_beneficios, duracion_dias = least(greatest(coalesce(p_duracion, duracion_dias), 1), 3650)
  where codigo = p_codigo;
  if not found then raise exception 'Plan no encontrado'; end if;
end $$;

drop function if exists public.admin_guardar_link(int, int, text, text, boolean);
create or replace function public.admin_guardar_link(p_slot int, p_monto int, p_url text, p_texto text, p_activo boolean, p_tipo text default 'premium') returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._solo_admin();
  if coalesce(p_tipo, '') not in ('premium', 'premium_anual') then raise exception 'Tipo de link no válido'; end if;
  perform public._guardar_link(null, p_tipo, p_slot, p_monto, p_url, p_texto, p_activo);
end $$;

-- Aviso automático antes de que venza el Premium (y el día que vence).
create or replace function public.avisar_vencimientos() returns void
language plpgsql security definer set search_path = public as $$
declare hoy date := (now() at time zone 'America/Santiago')::date; n int := public._cfg('dias_aviso_vencimiento');
begin
  insert into public.notificaciones (usuario, titulo, cuerpo, url)
  select id, '⭐ Tu Premium vence en ' || n || ' día(s)', 'Renuévalo para no perder tus beneficios: toca aquí para pagar y subir el comprobante.', '#/premium'
  from public.perfiles where not es_admin and premium_hasta < 'infinity' and (premium_hasta at time zone 'America/Santiago')::date = hoy + n;
  insert into public.notificaciones (usuario, titulo, cuerpo, url)
  select id, 'Tu Premium venció', 'Tu cuenta pasó a Gratis sin perder nada. Renueva cuando quieras.', '#/premium'
  from public.perfiles where not es_admin and (premium_hasta at time zone 'America/Santiago')::date = hoy - 1;
end $$;

create or replace function public.limpieza() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.mensajes where creado < now() - make_interval(days => greatest(public._cfg('dias_mensajes'), 1));
  delete from public.conversaciones c where c.ultimo < now() - interval '30 days'
    and not exists (select 1 from public.mensajes m where m.conv = c.id)
    and not exists (select 1 from public.denuncias d where d.objetivo = c.id and d.estado = 'abierta');
  delete from public.notificaciones where (leida and creado < now() - interval '30 days') or creado < now() - interval '60 days';
  update public.notificaciones set push_pendiente = false where push_pendiente and creado < now() - interval '1 day';
  -- Comprobantes: la imagen se borra después de N días (el registro queda).
  update public.arriendos set comprobante = null
    where comprobante is not null and estado <> 'en_revision'
      and comprobante_at < now() - make_interval(days => greatest(public._cfg('dias_comprobantes'), 1));
  update public.pagos set comprobante = null
    where comprobante is not null and estado <> 'pendiente'
      and creado < now() - make_interval(days => greatest(public._cfg('dias_comprobantes'), 1));
  delete from public.arriendos where estado in ('rechazado', 'cancelado', 'expirado') and actualizado < now() - interval '120 days'
    and pago_estado not in ('saldo', 'devolver');
  delete from public.pagos where estado <> 'pendiente' and creado < now() - interval '365 days';
  delete from public.denuncias where estado <> 'abierta' and creado < now() - interval '90 days';
end $$;

-- =====================================================================
--  Solo para la función "enviar" (clave de servidor)
-- =====================================================================
create or replace function public.srv_huerfanos() returns setof text
language sql stable security definer set search_path = public as $$
  select o.bucket_id || '/' || o.name from storage.objects o
  where o.bucket_id in ('fotos', 'privado') and o.created_at < now() - interval '1 day'
    and not exists (select 1 from public.perfiles p where p.avatar = o.name)
    and not exists (select 1 from public.estacionamientos e where regexp_replace(o.name, '_t\.(webp|jpg)$', '.\1') = any (e.fotos))
    and not exists (select 1 from public.verificaciones v where o.name in (v.frente, v.reverso, v.selfie))
    and not exists (select 1 from public.denuncias d where d.evidencia = o.name)
  limit 500
$$;

-- Limpieza diaria: mantiene la base de datos liviana.

-- ---------- Tareas automáticas (pg_cron) ----------
do $$ begin
  create extension if not exists pg_cron with schema pg_catalog;
  perform cron.unschedule(jobid) from cron.job where jobname like 'estaciona-%';
  perform cron.schedule('estaciona-liberar', '* * * * *', 'select public.liberar_vencidas()');
  perform cron.schedule('estaciona-limpieza', '15 7 * * *', 'select public.limpieza()');
  perform cron.schedule('estaciona-vencimientos', '5 13 * * *', 'select public.avisar_vencimientos()');
exception when others then raise notice 'pg_cron no disponible: las reservas vencidas se liberan al abrir la app.';
end $$;
-- Push cada minuto (necesita la función "enviar" y pg_net).
do $$ begin
  create extension if not exists pg_net with schema extensions;
  perform cron.schedule('estaciona-push', '* * * * *',
    $c$select net.http_post(url := 'https://wphxtspicejywwzlbuux.supabase.co/functions/v1/enviar',
      headers := '{"Content-Type": "application/json"}'::jsonb, body := '{"accion": "push"}'::jsonb)$c$);
exception when others then raise notice 'pg_net no disponible: el push se envía desde la app.';
end $$;

-- =====================================================================
--  v6 · Limpieza y respaldo
--   · Avisos y mensajes se guardan máximo 30 días (antes se avisa). Cada persona borra un aviso o una conversación.
--   · Cada lunes: estacionamientos pausados u ocultos hace más de 30 días, para borrarlos si ya no se arriendan.
--   · Cada persona descarga su respaldo en Excel. Funciones cfx_* para el Centro de Mando.
-- =====================================================================
alter table public.perfiles add column if not exists aviso_limpieza_at timestamptz;

create or replace function public.borrar_notificacion(p_id bigint default null) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  delete from public.notificaciones where usuario = auth.uid() and not chat and (p_id is null or id = p_id);
  get diagnostics n = row_count;
  return n;
end $$;

-- Borra una conversación completa (para ambos). Si tiene una denuncia abierta, se conserva como evidencia.
create or replace function public.borrar_conversacion(p_conv uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not exists (select 1 from public.conversaciones where id = p_conv and auth.uid() in (a, b)) then raise exception 'Conversación no encontrada'; end if;
  if exists (select 1 from public.denuncias where objetivo = p_conv and estado = 'abierta') then raise exception 'Tiene una denuncia en revisión: se borra cuando se resuelva'; end if;
  delete from public.mensajes where conv = p_conv;
  get diagnostics n = row_count;
  delete from public.notificaciones where usuario = auth.uid() and chat and url like '%' || p_conv::text || '%';
  delete from public.conversaciones where id = p_conv;
  return n;
end $$;

create or replace function public.recordar_pausados() returns int
language plpgsql security definer set search_path = public as $$
declare r record; k int := 0;
begin
  for r in select dueno, count(*) as n from public.estacionamientos where estado in ('pausado', 'oculto') and actualizado < now() - interval '30 days' group by dueno
  loop
    insert into public.notificaciones (usuario, titulo, cuerpo, url) values (r.dueno, '🧹 Ordena tus publicaciones',
      case when r.n = 1 then '1 estacionamiento lleva' else r.n || ' estacionamientos llevan' end || ' más de 30 días pausado u oculto. Si ya no lo arriendas, bórralo en Publicar.', '#/publicar');
    k := k + 1;
  end loop;
  return k;
end $$;

create or replace function public.limpieza() returns void
language plpgsql security definer set search_path = public as $$
declare r record; d int := least(greatest(public._cfg('dias_mensajes'), 3), 30);
begin
  -- v6: avisos y mensajes se guardan máximo 30 días; antes se avisa (máx. 1 vez por semana, al menos 2 días antes).
  for r in select p.id,
             (select count(*) from public.mensajes m join public.conversaciones c on c.id = m.conv where (c.a = p.id or c.b = p.id)
                and m.creado < now() - make_interval(days => greatest(d - 9, 1))) as ms,
             (select count(*) from public.notificaciones x where x.usuario = p.id and not x.chat and x.creado < now() - interval '21 days') as av
           from public.perfiles p
           where not p.suspendido and (p.aviso_limpieza_at is null or p.aviso_limpieza_at < now() - interval '7 days')
             and (exists (select 1 from public.mensajes m join public.conversaciones c on c.id = m.conv where (c.a = p.id or c.b = p.id)
                    and m.creado < now() - make_interval(days => greatest(d - 2, 1)))
               or exists (select 1 from public.notificaciones x where x.usuario = p.id and not x.chat and x.creado < now() - interval '28 days'))
  loop
    insert into public.notificaciones (usuario, titulo, cuerpo, url) values (r.id, '🧹 Limpieza automática',
      concat_ws(' y ', case when r.ms = 1 then '1 mensaje' when r.ms > 1 then r.ms || ' mensajes' end, case when r.av = 1 then '1 aviso' when r.av > 1 then r.av || ' avisos' end)
        || ' antiguos se borran solos en los próximos días. Tus estacionamientos y arriendos no se tocan.', '#/');
    update public.perfiles set aviso_limpieza_at = now() where id = r.id;
  end loop;
  if extract(isodow from now() at time zone 'America/Santiago') = 1 then perform public.recordar_pausados(); end if;
  delete from public.mensajes where creado < now() - make_interval(days => d);
  delete from public.conversaciones c where c.ultimo < now() - interval '30 days'
    and not exists (select 1 from public.mensajes m where m.conv = c.id)
    and not exists (select 1 from public.denuncias d where d.objetivo = c.id and d.estado = 'abierta');
  delete from public.notificaciones where creado < now() - interval '30 days';
  update public.notificaciones set push_pendiente = false where push_pendiente and creado < now() - interval '1 day';
  -- Comprobantes: la imagen se borra después de N días (el registro queda).
  update public.arriendos set comprobante = null
    where comprobante is not null and estado <> 'en_revision'
      and comprobante_at < now() - make_interval(days => greatest(public._cfg('dias_comprobantes'), 1));
  update public.pagos set comprobante = null
    where comprobante is not null and estado <> 'pendiente'
      and creado < now() - make_interval(days => greatest(public._cfg('dias_comprobantes'), 1));
  delete from public.arriendos where estado in ('rechazado', 'cancelado', 'expirado') and actualizado < now() - interval '120 days'
    and pago_estado not in ('saldo', 'devolver');
  delete from public.pagos where estado <> 'pendiente' and creado < now() - interval '365 days';
  delete from public.denuncias where estado <> 'abierta' and creado < now() - interval '90 days';
end $$;

-- Mi respaldo (Excel): mis estacionamientos, arriendos (como dueño o arrendatario) y pagos.
create or replace function public.mi_respaldo() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Inicia sesión'; end if;
  return jsonb_build_object(
    'Mis estacionamientos', (select coalesce(jsonb_agg(x order by x.creado), '[]') from (select titulo, direccion, comuna, precio_hora, precio_dia, precio_mes, vehiculo,
        techado, acceso24, seguridad, carga, estado, vistas, creado from public.estacionamientos where dueno = u) x),
    'Arriendos', (select coalesce(jsonb_agg((to_jsonb(a) - 'comprobante' - 'id' - 'estacionamiento' - 'dueno' - 'arrendatario')
        || jsonb_build_object('estacionamiento', e.titulo, 'yo_soy', case when a.dueno = u then 'dueño' else 'arrendatario' end,
           'otra_persona', (select nombre from public.perfiles where id = case when a.dueno = u then a.arrendatario else a.dueno end)) order by a.creado), '[]')
      from public.arriendos a join public.estacionamientos e on e.id = a.estacionamiento where a.dueno = u or a.arrendatario = u),
    'Pagos', (select coalesce(jsonb_agg(to_jsonb(g) - 'comprobante' - 'id' - 'usuario' order by g.creado), '[]') from public.pagos g where g.usuario = u));
end $$;

-- ---------- Centro de Mando: respaldo y limpieza (común a las 6 apps) ----------
create or replace function public.cfx_es_admin() returns void language plpgsql stable security definer set search_path = public as $$
begin if not public.es_admin() then raise exception 'Solo el administrador'; end if; end $$;

create or replace function public.cfx_respaldo() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object(
    'Usuarios', (select coalesce(jsonb_agg(x order by x.creado), '[]') from (select email as correo, nombre, comuna, verificado, premium_hasta, plan_origen, suspendido,
        calif_n as calificaciones, creado, ultimo_acceso from public.perfiles) x),
    'Estacionamientos', (select coalesce(jsonb_agg(x order by x.creado), '[]') from (select e.titulo, e.comuna, p.email as dueno, e.precio_hora, e.precio_dia, e.precio_mes,
        e.estado, e.vistas, e.creado from public.estacionamientos e join public.perfiles p on p.id = e.dueno) x),
    'Arriendos', (select coalesce(jsonb_agg(to_jsonb(a) - 'comprobante' order by a.creado), '[]') from public.arriendos a),
    'Pagos', (select coalesce(jsonb_agg((to_jsonb(g) - 'comprobante') || jsonb_build_object('correo', p.email) order by g.creado), '[]') from public.pagos g join public.perfiles p on p.id = g.usuario),
    'Denuncias', (select coalesce(jsonb_agg(to_jsonb(d) - 'evidencia' order by d.creado), '[]') from public.denuncias d),
    'Ajustes', (select coalesce(jsonb_agg(jsonb_build_object('clave', clave, 'valor', valor #>> '{}') order by clave), '[]') from public.config));
end $$;

create or replace function public.cfx_limpieza_app() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare dc int := greatest(public._cfg('dias_comprobantes'), 1); dm int := least(greatest(public._cfg('dias_mensajes'), 3), 30);
begin
  perform public.cfx_es_admin();
  return jsonb_build_array(
    jsonb_build_object('clave', 'comprobantes', 'titulo', 'Comprobantes revisados', 'detalle', 'Más de ' || dc || ' días (se borran solos cada día).',
      'filas', (select count(*) from public.arriendos where comprobante is not null and estado <> 'en_revision' and comprobante_at < now() - make_interval(days => dc))
             + (select count(*) from public.pagos where comprobante is not null and estado <> 'pendiente' and creado < now() - make_interval(days => dc))),
    jsonb_build_object('clave', 'mensajes', 'titulo', 'Avisos y mensajes', 'detalle', 'Mensajes de más de ' || dm || ' días y avisos de más de 30.',
      'filas', (select count(*) from public.mensajes where creado < now() - make_interval(days => dm)) + (select count(*) from public.notificaciones where creado < now() - interval '30 days')),
    jsonb_build_object('clave', 'arriendos', 'titulo', 'Arriendos cerrados', 'detalle', 'Rechazados, cancelados o expirados hace más de 120 días.',
      'filas', (select count(*) from public.arriendos where estado in ('rechazado', 'cancelado', 'expirado') and actualizado < now() - interval '120 days' and pago_estado not in ('saldo', 'devolver'))),
    jsonb_build_object('clave', 'denuncias', 'titulo', 'Denuncias resueltas', 'detalle', 'Más de 90 días.',
      'filas', (select count(*) from public.denuncias where estado <> 'abierta' and creado < now() - interval '90 days')));
end $$;

-- Cualquier opción corre la limpieza diaria completa (avisa antes de borrar avisos y mensajes).
create or replace function public.cfx_limpiar_app(p_clave text) returns int
language plpgsql security definer set search_path = public as $$
declare antes bigint; despues bigint;
begin
  perform public.cfx_es_admin();
  if p_clave not in ('comprobantes', 'mensajes', 'arriendos', 'denuncias') then raise exception 'Opción no válida'; end if;
  select coalesce(sum((x ->> 'filas')::bigint), 0) into antes from jsonb_array_elements(public.cfx_limpieza_app()) x;
  perform public.limpieza();
  select coalesce(sum((x ->> 'filas')::bigint), 0) into despues from jsonb_array_elements(public.cfx_limpieza_app()) x;
  return antes - despues;
end $$;



-- ---------- Permisos ----------
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.ajustes_publicos(), public.mapa(double precision, double precision, double precision, double precision),
  public.estacionamiento_detalle(uuid) to anon, authenticated;
grant execute on function
  public.es_admin(), public.puede_ver_privado(text), public.mi_cuenta(), public.aceptar_terminos(),
  public.guardar_perfil(text, text, text, text, text, text, text),
  public.enviar_verificacion(text, text, text, text, text), public.perfil_publico(uuid), public.canjear_key(text), public.ya_pague(text, text, text),
  public.guardar_alerta(double precision, double precision, real), public.guardar_push(text, text, text), public.quitar_push(text),
  public.contadores(), public.mis_notificaciones(), public.marcar_leidas(), public.mis_links(), public.guardar_link(int, int, text, text, boolean),
  public.guardar_estacionamiento(jsonb), public.estado_estacionamiento(uuid, text), public.borrar_estacionamiento(uuid),
  public.mis_estacionamientos(), public.favorito(uuid), public.mis_favoritos(),
  public.solicitar_arriendo(uuid, text, timestamptz, int, text), public.subir_comprobante(uuid, text),
  public.responder_arriendo(uuid, boolean, text), public.cerrar_arriendo(uuid, text),
  public.mis_arriendos(), public.panel(), public.mis_estadisticas(), public.calificar(uuid, int, text),
  public.abrir_conversacion(uuid), public.soporte(), public.mis_conversaciones(), public.leer_mensajes(uuid, bigint),
  public.enviar_mensaje(uuid, text), public.bloquear(uuid, boolean), public.denunciar(text, uuid, text, text, text),
  public.admin_resumen(), public.admin_usuarios(text, text, int), public.admin_premium(uuid, int), public.admin_suspender(uuid, boolean),
  public.admin_verificaciones(), public.admin_resolver_verificacion(uuid, boolean, text), public.admin_estacionamientos(text, int),
  public.admin_ocultar(uuid, boolean), public.admin_denuncias(text), public.admin_resolver_denuncia(uuid, text, text),
  public.admin_conversacion(uuid), public.admin_keys(), public.admin_crear_keys(int, int, text), public.admin_revocar_key(text),
  public.admin_pagos(text), public.admin_resolver_pago(uuid, boolean, text), public.admin_ajustes(), public.admin_guardar_ajustes(jsonb),
  public.admin_aviso(text, text), public.admin_prueba_push(), public.admin_config(), public.admin_guardar_config(jsonb),
  public.admin_guardar_textos(jsonb), public.admin_guardar_plan(text, text, text, jsonb, jsonb, int), public.admin_guardar_link(int, int, text, text, boolean, text)
  to authenticated;
grant execute on function public.srv_huerfanos(), public.limpieza(), public.liberar_vencidas(),
  public.finalizar_terminados(), public.avisar_devoluciones() to service_role;
grant execute on function public.borrar_notificacion(bigint), public.borrar_conversacion(uuid), public.mi_respaldo(),
  public.cfx_respaldo(), public.cfx_limpieza_app(), public.cfx_limpiar_app(text) to authenticated;

-- =====================================================================
--  Ganchos para el núcleo (pagos): quien publica estacionamientos = negocio; quien solo arrienda = cliente.
-- =====================================================================
create or replace function public.cfx_yo() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'email', p.email, 'nombre', p.nombre, 'premium_hasta', p.premium_hasta, 'creado', p.creado,
    'rol', case when p.es_admin then 'admin' when exists (select 1 from public.estacionamientos e where e.dueno = p.id) then 'negocio' else 'cliente' end)
  from public.perfiles p where p.id = auth.uid()
$$;
create or replace function public.cfx_dar_premium(p_cuenta uuid, p_rol text, p_dias int) returns timestamptz
language sql security definer set search_path = public as $$
  update public.perfiles set premium_hasta = greatest(coalesce(premium_hasta, now()), now()) + make_interval(days => p_dias), plan_origen = 'pago'
  where id = p_cuenta returning premium_hasta
$$;
create or replace function public.cfx_avisar(p_cuenta uuid, p_titulo text, p_cuerpo text) returns void
language sql security definer set search_path = public as $$ insert into public.notificaciones (usuario, titulo, cuerpo, url) values (p_cuenta, p_titulo, p_cuerpo, '#/premium') $$;
create or replace function public.cfx_avisar_admin(p_titulo text, p_cuerpo text) returns void
language sql security definer set search_path = public as $$ insert into public.notificaciones (usuario, titulo, cuerpo, url) select public._admin_id(), p_titulo, p_cuerpo, '#/admin' where public._admin_id() is not null $$;

-- Ganchos de administración para el núcleo (planes, textos, a quién avisar y verificación).
create or replace function public.cfx_planes_app() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('grupo', m.g, 'clave', k, 'free', f.limites -> k, 'premium', p.limites -> k) order by m.g, k), '[]')
  from (values ('negocio', 'gratis', 'premium')) m(g, fc, pc) join public.planes f on f.codigo = m.fc join public.planes p on p.codigo = m.pc,
  lateral (select jsonb_object_keys(f.limites || p.limites) as k) x
$$;
create or replace function public.cfx_plan_guardar_app(p_grupo text, p_clave text, p_free jsonb, p_premium jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare fc text; pc text;
begin
  select m.fc, m.pc into fc, pc from (values ('negocio', 'gratis', 'premium')) m(g, fc, pc) where m.g = p_grupo;
  if fc is null or p_clave !~ '^[a-z_]{2,40}$' then raise exception 'Plan no válido'; end if;
  update public.planes set limites = limites || jsonb_build_object(p_clave, p_free) where codigo = fc;
  update public.planes set limites = limites || jsonb_build_object(p_clave, p_premium) where codigo = pc;
end $$;
create or replace function public.cfx_textos_app() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('clave', clave, 'valor', valor) order by clave), '[]') from public.textos
$$;
create or replace function public.cfx_texto_guardar_app(p_clave text, p_valor text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.textos set valor = p_valor where clave = p_clave;
  if not found then raise exception 'Texto no encontrado'; end if;
end $$;
create or replace function public.cfx_destinatarios(p_destino text) returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id from public.perfiles p where not p.suspendido and not p.es_admin
    and (p_destino = 'todos' or (p_destino = 'negocios' and exists (select 1 from public.estacionamientos e where e.dueno = p.id))
      or (p_destino = 'clientes' and not exists (select 1 from public.estacionamientos e where e.dueno = p.id))
      or (p_destino = 'premium' and p.premium_hasta > now()) or (p_destino = 'gratis' and (p.premium_hasta is null or p.premium_hasta <= now())))
$$;
-- La verificación del núcleo también marca a la persona como verificada en Estaciona.
create or replace function public.cfx_marcar_verificado(p_cuenta uuid, p_si boolean) returns void
language sql security definer set search_path = public as $$ update public.perfiles set verificado = p_si where id = p_cuenta $$;

-- Guía para partir (núcleo · ayuda): lo que le falta a quien publica estacionamientos. Usa su propia verificación.
create or replace function public.cfx_guia_app() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_array(
    jsonb_build_object('k', 'publicar', 't', 'Publica tu estacionamiento', 'd', 'Con fotos, precio y horario.', 'ir', '#/publicar',
      'ok', exists (select 1 from public.estacionamientos e where e.dueno = p.id)),
    jsonb_build_object('k', 'verificar', 't', 'Verifica tu identidad', 'd', 'Solo las personas verificadas pueden arrendar y publicar.', 'ir', '#/verificar', 'ok', p.verificado),
    jsonb_build_object('k', 'whatsapp', 't', 'Tu WhatsApp', 'd', 'Para coordinar con quien arrienda.', 'ir', '#/mas/perfil', 'ok', p.whatsapp is not null),
    jsonb_build_object('k', 'link', 't', 'Tu link de pago', 'd', 'Para que te paguen el arriendo.', 'ir', '#/mas/links',
      'ok', exists (select 1 from public.links_pago l where l.dueno = p.id and l.tipo = 'arriendo' and l.activo and l.url <> '')))
  from public.perfiles p where p.id = auth.uid()), '[]'::jsonb)
$$;

-- >>> CFX núcleo (no editar aquí: se copia de saas/nucleo/sql con sincronizar.py)
-- ---------------------------------------------------------------------
-- CodeFix · Pagos (igual en las 6 apps; lo reparte nucleo/sincronizar.py). Se administra desde el Centro de Mando → Pagos.
--   Precios iguales en las 6: negocio (inicio, mensual, anual) y cliente (mensual, anual). Link de pago SIN monto (la persona
--   escribe el monto; se le suma el cargo por pago online, visible como una línea aparte), tarjeta (otro link, con su propio cargo)
--   o transferencia (precio exacto, sin cargo), y foto del comprobante. Tú apruebas y se activa el Premium por días enteros.
--   Liberar: por N días nadie queda bloqueado y las cuentas creadas en ese tiempo no pagan el primer pago (quedan en gratis).
--   El comprobante se borra al aprobar o rechazar (ya no sirve). Negocios nuevos: bloqueados hasta su primer pago (si está activado).
--   Cada app define antes: cfx_yo(), cfx_dar_premium(uuid, text, int), cfx_avisar(uuid, text, text) y cfx_avisar_admin(text, text).
-- ---------------------------------------------------------------------
create table if not exists public.cfx_config (clave text primary key, valor jsonb not null);
alter table public.cfx_config enable row level security;
insert into public.cfx_config (clave, valor) values ('pagos', jsonb_build_object(
  'negocio', jsonb_build_object('inicio', 4900, 'inicio_dias', 30, 'mensual', 4900, 'anual', 49900, 'exigir_inicio', true),
  'cliente', jsonb_build_object('mensual', 3000, 'anual', 29900),
  'link', '', 'comision_pct', 0, 'whatsapp', '', 'tarjeta', jsonb_build_object('link', '', 'comision_pct', 0),
  'transferencia', jsonb_build_object('banco', '', 'tipo', '', 'numero', '', 'rut', '', 'titular', '', 'correo', ''),
  'inicio_desde', now()))
on conflict (clave) do nothing;

create table if not exists public.cfx_pagos (
  id          uuid primary key default gen_random_uuid(),
  cuenta      uuid not null,
  email       text not null default '',
  nombre      text not null default '',
  rol         text not null check (rol in ('negocio', 'cliente', 'otro')),
  periodo     text not null check (periodo in ('inicio', 'mensual', 'anual', 'otro')),
  monto       int not null check (monto between 1 and 100000000),
  medio       text not null check (medio in ('link', 'transferencia')),
  nota        text not null default '' check (length(nota) <= 300),
  comprobante text check (comprobante is null or (comprobante ~ '^data:image/(jpeg|png|webp);base64,' and length(comprobante) <= 400000)),
  estado      text not null default 'pendiente' check (estado in ('pendiente', 'aprobado', 'rechazado')),
  dias        int,
  motivo      text not null default '',
  creado      timestamptz not null default now(),
  resuelto    timestamptz
);
alter table public.cfx_pagos add column if not exists cupon text;
alter table public.cfx_pagos add column if not exists meses int check (meses is null or meses between 1 and 24);
-- G19: pago de un módulo o pack (null = Premium).
alter table public.cfx_pagos add column if not exists producto text check (producto is null or producto ~ '^[a-z_]{2,30}$');
alter table public.cfx_pagos drop constraint if exists cfx_pagos_medio_check;
alter table public.cfx_pagos add constraint cfx_pagos_medio_check check (medio in ('link', 'transferencia', 'tarjeta'));
alter table public.cfx_pagos drop constraint if exists cfx_pagos_periodo_check;
alter table public.cfx_pagos add constraint cfx_pagos_periodo_check check (periodo in ('inicio', 'mensual', 'meses', 'anual', 'otro'));
create index if not exists cfx_pagos_cuenta_idx on public.cfx_pagos (cuenta, creado desc);
create index if not exists cfx_pagos_estado_idx on public.cfx_pagos (estado, creado);
alter table public.cfx_pagos enable row level security;
create table if not exists public.cfx_exentos (cuenta uuid primary key, nota text not null default '', creado timestamptz not null default now());
alter table public.cfx_exentos enable row level security;
revoke all on public.cfx_config, public.cfx_pagos, public.cfx_exentos from anon, authenticated;

-- ¿Cómo estoy? Precios, mi rol, si debo el primer pago y mi último pago.
create or replace function public.cfx_pago_estado() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare c jsonb := (select valor from public.cfx_config where clave = 'pagos'); y jsonb := public.cfx_yo(); pagado boolean; debe boolean; bloq boolean;
        lib jsonb := (select valor from public.cfx_config where clave = 'liberar'); ld timestamptz := (lib ->> 'desde')::timestamptz; lh timestamptz := (lib ->> 'hasta')::timestamptz;
begin
  if y is null or (y ->> 'id') is null then raise exception 'Inicia sesión'; end if;
  pagado := exists (select 1 from public.cfx_pagos where cuenta = (y ->> 'id')::uuid and estado = 'aprobado')
    or exists (select 1 from public.cfx_exentos where cuenta = (y ->> 'id')::uuid);
  -- debe_inicio: cuenta nueva (desde que activaste la regla) sin primer pago. bloqueado: además es un negocio.
  -- Solo si ya hay una forma de pago configurada (si no, nadie podría pagar).
  debe := coalesce((c #>> '{negocio,exigir_inicio}')::boolean, false) and not pagado
     and (coalesce(c ->> 'link', '') <> '' or coalesce(c #>> '{transferencia,numero}', '') <> '' or coalesce(c #>> '{tarjeta,link}', '') <> '')
     and (y ->> 'creado')::timestamptz > coalesce((c ->> 'inicio_desde')::timestamptz, now())
     -- Liberado: mientras dure nadie queda bloqueado; las cuentas creadas en ese tiempo quedan en gratis sin primer pago.
     and not (lh is not null and (now() < lh or (y ->> 'creado')::timestamptz between coalesce(ld, '-infinity') and lh));
  bloq := debe and y ->> 'rol' = 'negocio';
  return jsonb_build_object('config', c - 'inicio_desde', 'yo', y, 'pagado', pagado, 'bloqueado', bloq, 'debe_inicio', debe,
    'liberado_hasta', case when lh > now() then lh end,
    'ultimo', (select to_jsonb(x) from (select id, periodo, monto, medio, estado, dias, motivo, creado, resuelto from public.cfx_pagos
               where cuenta = (y ->> 'id')::uuid order by creado desc limit 1) x));
end $$;

drop function if exists public.cfx_pago_pedir(text, int, text, text, text);
drop function if exists public.cfx_pago_pedir(text, int, text, text, text, text);
drop function if exists public.cfx_pago_pedir(text, int, text, text, text, text, int);  -- G36: la de 7 dejaba 2 versiones ("Could not choose the best candidate")
drop function if exists public.cfx_pago_pedir(text, int, text, text, text, text, int, text);
create or replace function public.cfx_pago_pedir(p_periodo text, p_monto int, p_medio text, p_comprobante text, p_nota text default '', p_cupon text default null, p_meses int default null, p_producto text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); i uuid; cup text := nullif(upper(trim(coalesce(p_cupon, ''))), '');
begin
  if y is null or (y ->> 'id') is null then raise exception 'Inicia sesión'; end if;
  if y ->> 'rol' not in ('negocio', 'cliente') and p_periodo <> 'otro' then raise exception 'Pide al dueño de la cuenta que haga el pago'; end if;
  if p_periodo not in ('inicio', 'mensual', 'meses', 'anual', 'otro') or p_medio not in ('link', 'transferencia', 'tarjeta') then raise exception 'Datos no válidos'; end if;
  if p_periodo = 'meses' and coalesce(p_meses, 0) not between 2 and 11 then raise exception 'Elige de 2 a 11 meses'; end if;
  -- Módulo o pack (G19): solo el dueño del negocio, 1 mes o 1 año, y que se venda en esta app.
  if p_producto is not null then
    if public.cfx_negocio_cuenta((y ->> 'id')::uuid) is distinct from (y ->> 'id')::uuid then raise exception 'Pide al dueño del negocio que haga el pago'; end if;
    if p_periodo not in ('mensual', 'anual') or not coalesce((public.cfx_venta() ->> 'activo')::boolean, false) or cardinality(public.cfx_venta_modulos(p_producto)) = 0 then raise exception 'Módulo no válido'; end if;
  end if;
  if coalesce(p_monto, 0) < 1 then raise exception 'Escribe el monto que pagaste'; end if;
  if coalesce(length(p_comprobante), 0) < 200 then raise exception 'Sube la foto del comprobante'; end if;
  if cup is not null then perform public.cfx_cupon_ver(cup); end if;
  if exists (select 1 from public.cfx_pagos where cuenta = (y ->> 'id')::uuid and estado = 'pendiente') then raise exception 'Ya tienes un pago en revisión. Te avisamos apenas se apruebe.'; end if;
  if (select count(*) from public.cfx_pagos where cuenta = (y ->> 'id')::uuid and creado > now() - interval '1 day') >= 5 then raise exception 'Demasiados intentos hoy. Escribe a soporte.'; end if;
  insert into public.cfx_pagos (cuenta, email, nombre, rol, periodo, monto, medio, nota, comprobante, cupon, meses, producto)
  values ((y ->> 'id')::uuid, coalesce(y ->> 'email', ''), left(coalesce(y ->> 'nombre', ''), 80), case when y ->> 'rol' in ('negocio', 'cliente') then y ->> 'rol' else 'otro' end,
          p_periodo, p_monto, p_medio, left(coalesce(p_nota, ''), 300), p_comprobante, cup, case when p_periodo = 'meses' then p_meses end, p_producto)
  returning id into i;
  -- Aviso al tiro: al Centro de Mando si la app está vinculada (si no, al administrador de esta app).
  perform public.cfx_al_cm('💳 Pago por revisar', coalesce(nullif(y ->> 'nombre', ''), y ->> 'email') || ' · $' || p_monto || coalesce(' · 🧩 ' || p_producto, '') || ' (' || case p_periodo when 'meses' then p_meses || ' meses' else p_periodo end || ', ' || p_medio || ')' || coalesce(' · cupón ' || cup, ''), 'pago');
  return i;
end $$;

-- Precios públicos (para la portada, sin iniciar sesión).
create or replace function public.cfx_precios() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('negocio', valor -> 'negocio', 'cliente', valor -> 'cliente', 'comision_pct', valor -> 'comision_pct',
    'liberado_hasta', (select case when (l.valor ->> 'hasta')::timestamptz > now() then l.valor -> 'hasta' end from public.cfx_config l where l.clave = 'liberar'))
  from public.cfx_config where clave = 'pagos'
$$;
revoke all on function public.cfx_precios() from public;
grant execute on function public.cfx_precios() to anon, authenticated;

-- ---------- Administrador (lo llama el Centro de Mando) ----------
create or replace function public.cfx_pagos_config() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select valor from public.cfx_config where clave = 'pagos');
end $$;

create or replace function public.cfx_pagos_config_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := (select valor from public.cfx_config where clave = 'pagos');
begin
  perform public.cfx_es_admin();
  if jsonb_typeof(p) <> 'object' then raise exception 'Datos no válidos'; end if;
  if coalesce(p ->> 'link', '') <> '' and (p ->> 'link') !~ '^https://[^ ]+$' then raise exception 'El link de pago debe empezar con https://'; end if;
  if coalesce((p ->> 'comision_pct')::numeric, 0) not between 0 and 20 or coalesce((p #>> '{tarjeta,comision_pct}')::numeric, 0) not between 0 and 20 then raise exception 'El cargo por pago online va de 0 a 20 %%'; end if;
  if coalesce(p #>> '{tarjeta,link}', '') <> '' and (p #>> '{tarjeta,link}') !~ '^https://[^ ]+$' then raise exception 'El link de tarjeta debe empezar con https://'; end if;
  -- Al activar "bloquear hasta el primer pago", solo aplica a los negocios que se registren desde ahora.
  -- También cuando se configura la primera forma de pago (antes nadie podía pagar, así que nadie quedó obligado).
  if coalesce((p #>> '{negocio,exigir_inicio}')::boolean, false) and (not coalesce((v #>> '{negocio,exigir_inicio}')::boolean, false)
     or (coalesce(v ->> 'link', '') = '' and coalesce(v #>> '{transferencia,numero}', '') = '' and coalesce(v #>> '{tarjeta,link}', '') = ''
         and (coalesce(p ->> 'link', '') <> '' or coalesce(p #>> '{transferencia,numero}', '') <> '' or coalesce(p #>> '{tarjeta,link}', '') <> ''))) then
    p := p || jsonb_build_object('inicio_desde', now());
  end if;
  v := v || (p - 'inicio_desde') || case when p ? 'inicio_desde' then jsonb_build_object('inicio_desde', p -> 'inicio_desde') else '{}'::jsonb end;
  update public.cfx_config set valor = v where clave = 'pagos';
  return v;
end $$;

create or replace function public.cfx_pagos_lista(p_estado text default 'pendiente') returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(x order by x.creado desc), '[]') from (
    select id, cuenta, email, nombre, rol, periodo, meses, producto, monto, medio, nota, estado, dias, motivo, creado, resuelto, comprobante is not null as con_comprobante,
      public.cfx_dias_sugeridos(g) as sugeridos,
      (select count(*) from public.cfx_pagos z where z.cuenta = g.cuenta and z.estado = 'aprobado') as aprobados
    from public.cfx_pagos g where p_estado = 'todos' or estado = p_estado order by creado desc limit 200) x);
end $$;

create or replace function public.cfx_pago_comprobante(p_id uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select comprobante from public.cfx_pagos where id = p_id);
end $$;

-- Días que corresponden a un pago (siempre días enteros): mensual 30, anual 365, N meses = N × 30, primer pago lo configurado,
-- y "otro monto" en proporción al precio mensual (sin contar el cargo por pago online).
create or replace function public.cfx_dias_sugeridos(g public.cfx_pagos) returns int
language plpgsql stable security definer set search_path = '' as $$
declare c jsonb := (select valor from public.cfx_config where clave = 'pagos'); m numeric; pct numeric; neto numeric;
begin
  if g.periodo = 'inicio' then return coalesce((c #>> '{negocio,inicio_dias}')::int, 30); end if;
  if g.periodo = 'mensual' then return 30; end if;
  if g.periodo = 'anual' then return 365; end if;
  if g.periodo = 'meses' then return 30 * coalesce(g.meses, 1); end if;
  m := nullif((c #>> array[case when g.rol = 'cliente' then 'cliente' else 'negocio' end, 'mensual'])::numeric, 0);
  pct := case g.medio when 'link' then coalesce((c ->> 'comision_pct')::numeric, 0) when 'tarjeta' then coalesce((c #>> '{tarjeta,comision_pct}')::numeric, 0) else 0 end;
  neto := g.monto / (1 + pct / 100);
  return case when m is null then 0 else least(3660, floor(neto * 30 / m))::int end;
end $$;
revoke all on function public.cfx_dias_sugeridos(public.cfx_pagos) from public, anon, authenticated;

create or replace function public.cfx_pago_resolver(p_id uuid, p_aprobar boolean, p_dias int default null, p_motivo text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare g public.cfx_pagos; c jsonb := (select valor from public.cfx_config where clave = 'pagos'); d int; hasta timestamptz;
begin
  perform public.cfx_es_admin();
  select * into g from public.cfx_pagos where id = p_id and estado = 'pendiente' for update;
  if g.id is null then raise exception 'Pago no encontrado o ya resuelto'; end if;
  d := coalesce(p_dias, public.cfx_dias_sugeridos(g));
  if p_aprobar then
    if d < 0 or d > 3660 then raise exception 'Días no válidos'; end if;
    if d > 0 and g.producto is not null then hasta := public.cfx_modulos_dar(public.cfx_negocio_cuenta(g.cuenta), g.producto, d, 'pago');
    elsif d > 0 then hasta := public.cfx_dar_premium(g.cuenta, g.rol, d); end if;
    update public.cfx_pagos set estado = 'aprobado', dias = d, motivo = left(coalesce(p_motivo, ''), 200), resuelto = now(), comprobante = null where id = p_id;
    perform public.cfx_avisar(g.cuenta, '✅ Pago aprobado', case when hasta is not null then case when g.producto is not null then '🧩 Módulo activo' else 'Premium activo' end || ' hasta el ' || to_char(hasta at time zone 'America/Santiago', 'DD/MM/YYYY') || '. ¡Gracias!' else 'Gracias, tu pago quedó registrado.' end);
  else
    update public.cfx_pagos set estado = 'rechazado', motivo = left(coalesce(nullif(p_motivo, ''), 'No pudimos validar el comprobante'), 200), resuelto = now(), comprobante = null where id = p_id;
    perform public.cfx_avisar(g.cuenta, '⚠️ Pago rechazado', left(coalesce(nullif(p_motivo, ''), 'No pudimos validar el comprobante'), 200) || '. Puedes subirlo de nuevo.');
  end if;
  return jsonb_build_object('estado', case when p_aprobar then 'aprobado' else 'rechazado' end, 'dias', d, 'hasta', hasta);
end $$;

-- Liberar el registro por N días (0 = terminar ahora). Sin p_dias solo devuelve cómo está.
create or replace function public.cfx_liberar(p_dias int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := (select valor from public.cfx_config where clave = 'liberar');
begin
  perform public.cfx_es_admin();
  if p_dias is not null then
    if p_dias < 0 or p_dias > 90 then raise exception 'De 0 a 90 días'; end if;
    v := case when p_dias = 0 then coalesce(v, '{}'::jsonb) || jsonb_build_object('hasta', least(coalesce((v ->> 'hasta')::timestamptz, now()), now()))
         else jsonb_build_object('desde', case when (v ->> 'hasta')::timestamptz > now() then v -> 'desde' else to_jsonb(now()) end, 'hasta', now() + make_interval(days => p_dias)) end;
    insert into public.cfx_config (clave, valor) values ('liberar', v) on conflict (clave) do update set valor = excluded.valor;
  end if;
  return jsonb_build_object('desde', v -> 'desde', 'hasta', v -> 'hasta', 'activo', coalesce((v ->> 'hasta')::timestamptz > now(), false));
end $$;
revoke all on function public.cfx_liberar(int) from public, anon;
grant execute on function public.cfx_liberar(int) to authenticated;

-- Cuentas que no pagan el inicio (por ejemplo, las que creas tú de regalo).
create or replace function public.cfx_exento(p_cuenta uuid, p_si boolean, p_nota text default '') returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if p_si then insert into public.cfx_exentos (cuenta, nota) values (p_cuenta, left(coalesce(p_nota, ''), 200)) on conflict (cuenta) do update set nota = excluded.nota;
  else delete from public.cfx_exentos where cuenta = p_cuenta; end if;
end $$;

create or replace function public.cfx_exento_email(p_email text, p_si boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare u uuid;
begin
  perform public.cfx_es_admin();
  select id into u from auth.users where lower(email) = lower(trim(coalesce(p_email, '')));
  if u is null then raise exception 'No hay una cuenta con ese correo en esta app'; end if;
  perform public.cfx_exento(u, p_si, 'Desde el Centro de Mando');
  return lower(trim(p_email));
end $$;

revoke all on function public.cfx_exento_email(text, boolean) from public, anon;
grant execute on function public.cfx_exento_email(text, boolean) to authenticated;
revoke all on function public.cfx_pago_estado(), public.cfx_pago_pedir(text, int, text, text, text, text, int, text), public.cfx_pagos_config(), public.cfx_pagos_config_guardar(jsonb),
  public.cfx_pagos_lista(text), public.cfx_pago_comprobante(uuid), public.cfx_pago_resolver(uuid, boolean, int, text), public.cfx_exento(uuid, boolean, text) from public, anon;
grant execute on function public.cfx_pago_estado(), public.cfx_pago_pedir(text, int, text, text, text, text, int, text), public.cfx_pagos_config(), public.cfx_pagos_config_guardar(jsonb),
  public.cfx_pagos_lista(text), public.cfx_pago_comprobante(uuid), public.cfx_pago_resolver(uuid, boolean, int, text), public.cfx_exento(uuid, boolean, text) to authenticated;
revoke all on function public.cfx_yo(), public.cfx_dar_premium(uuid, text, int), public.cfx_avisar(uuid, text, text), public.cfx_avisar_admin(text, text) from public, anon, authenticated;
-- ---------------------------------------------------------------------
-- CodeFix · Administración común (igual en las 6 apps; se maneja desde el Centro de Mando → Control).
--   Planes (interruptores sí/no y límites), textos, aviso a todos, keys de Premium, cupones de descuento,
--   verificación de identidad y registro de lo que hace el administrador.
--   Cada app define antes: cfx_planes_app(), cfx_plan_guardar_app(text, text, jsonb, jsonb), cfx_textos_app(),
--   cfx_texto_guardar_app(text, text), cfx_destinatarios(text) y cfx_marcar_verificado(uuid, boolean).
-- ---------------------------------------------------------------------
create table if not exists public.cfx_registro (
  id bigserial primary key, quien text not null default '', accion text not null, detalle text not null default '', creado timestamptz not null default now());
create table if not exists public.cfx_keys (
  id uuid primary key default gen_random_uuid(), hash text not null unique, ultimos text not null, rol text not null check (rol in ('negocio', 'cliente')),
  dias int not null check (dias between 1 and 3660), nota text not null default '', creado timestamptz not null default now(),
  usada_por uuid, usada_email text, usada_at timestamptz, revocada boolean not null default false);
create table if not exists public.cfx_cupones (
  codigo text primary key check (codigo ~ '^[A-Z0-9-]{3,20}$'), pct int not null check (pct between 1 and 100), usos_max int, usos int not null default 0,
  vence date, activo boolean not null default true, creado timestamptz not null default now());
create table if not exists public.cfx_verificaciones (
  cuenta uuid primary key, email text not null default '', nombre text not null default '', rut text not null, documento text not null default '',
  frente text, reverso text, selfie text, estado text not null default 'pendiente' check (estado in ('pendiente', 'aprobada', 'rechazada')),
  motivo text not null default '', creado timestamptz not null default now(), resuelto timestamptz);
alter table public.cfx_registro enable row level security;
alter table public.cfx_keys enable row level security;
alter table public.cfx_cupones enable row level security;
alter table public.cfx_verificaciones enable row level security;
revoke all on public.cfx_registro, public.cfx_keys, public.cfx_cupones, public.cfx_verificaciones from anon, authenticated;

create or replace function public.cfx_anotar(p_accion text, p_detalle text) returns void
language sql security definer set search_path = '' as $$
  insert into public.cfx_registro (quien, accion, detalle) values (coalesce((select email from auth.users where id = auth.uid()), 'sistema'), left(p_accion, 60), left(coalesce(p_detalle, ''), 400))
$$;
create or replace function public.cfx_registro_lista(p_limite int default 200) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(x order by x.id desc), '[]') from (select * from public.cfx_registro order by id desc limit greatest(1, least(coalesce(p_limite, 200), 2000))) x);
end $$;

-- ---------- Planes: [{grupo, clave, free, premium}] (números o sí/no) ----------
-- Borrar el registro de cambios (el común y el propio de la app, si tiene): lo de más de N días, o todo con 0. Solo el administrador.
create or replace function public.cfx_registro_borrar(p_dias int default 30) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; k int; col text; desde timestamptz := case when coalesce(p_dias, 0) <= 0 then 'infinity'::timestamptz else now() - make_interval(days => p_dias) end;
begin
  perform public.cfx_es_admin();
  delete from public.cfx_registro where creado < desde; get diagnostics n = row_count;
  if to_regclass('public.auditoria') is not null then
    select c.column_name into col from information_schema.columns c where c.table_schema = 'public' and c.table_name = 'auditoria'
      and c.column_name in ('created_at', 'at', 'creado', 'fecha') and c.data_type like 'timestamp%' order by c.ordinal_position limit 1;
    if col is not null then execute format('delete from public.auditoria where %I < $1', col) using desde; get diagnostics k = row_count; n := n + k; end if;
  end if;
  insert into public.cfx_registro (quien, accion, detalle) values (coalesce((select email from auth.users where id = auth.uid()), 'sistema'), 'registro borrado',
    case when coalesce(p_dias, 0) <= 0 then 'todo' else 'más de ' || p_dias || ' días' end || ' (' || n || ' filas)');
  return n;
end $$;
revoke all on function public.cfx_registro_borrar(int) from public, anon;
grant execute on function public.cfx_registro_borrar(int) to authenticated;

create or replace function public.cfx_planes() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return public.cfx_planes_app();
end $$;
create or replace function public.cfx_plan_guardar(p_grupo text, p_clave text, p_free jsonb, p_premium jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if jsonb_typeof(p_free) not in ('number', 'boolean') or jsonb_typeof(p_premium) not in ('number', 'boolean') then raise exception 'Valor no válido'; end if;
  perform public.cfx_plan_guardar_app(p_grupo, p_clave, p_free, p_premium);
  perform public.cfx_anotar('plan', p_grupo || '.' || p_clave || ': gratis ' || p_free::text || ' · premium ' || p_premium::text);
end $$;

-- ---------- Textos: [{clave, valor}] ----------
create or replace function public.cfx_textos() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return public.cfx_textos_app();
end $$;
create or replace function public.cfx_texto_guardar(p_clave text, p_valor text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  perform public.cfx_texto_guardar_app(p_clave, left(coalesce(p_valor, ''), 2000));
  perform public.cfx_anotar('texto', p_clave);
end $$;

-- ---------- Aviso a todos: destino todos | negocios | clientes | premium | gratis ----------
create or replace function public.cfx_aviso_masivo(p_destino text, p_titulo text, p_cuerpo text) returns int
language plpgsql security definer set search_path = '' as $$
declare u uuid; n int := 0;
begin
  perform public.cfx_es_admin();
  if trim(coalesce(p_titulo, '')) = '' then raise exception 'Escribe el título'; end if;
  if p_destino not in ('todos', 'negocios', 'clientes', 'premium', 'gratis', 'ofertas') then raise exception 'Destino no válido'; end if;
  -- 'ofertas' = publicidad: solo a quienes aceptaron recibir ofertas (consentimiento, sql/legal.sql).
  for u in select d from public.cfx_destinatarios(case when p_destino = 'ofertas' then 'todos' else p_destino end) d where p_destino <> 'ofertas' or public.cfx_acepta(d, 'ofertas') loop
    perform public.cfx_avisar(u, left(p_titulo, 80), left(coalesce(p_cuerpo, ''), 240));
    n := n + 1;
  end loop;
  perform public.cfx_anotar('aviso', p_destino || ' (' || n || '): ' || p_titulo);
  return n;
end $$;

-- ---------- Nueva versión disponible: push a todos al liberar (una sola vez por versión) ----------
-- La llama el Centro de Mando después de liberar (Apps → Liberar) con las notas que se escriben ahí.
create table if not exists public.cfx_versiones (version text primary key, notas text not null default '', avisados int not null default 0, creado timestamptz not null default now());
alter table public.cfx_versiones enable row level security;
create or replace function public.cfx_avisar_version(p_version text, p_notas text default '', p_app text default '') returns int
language plpgsql security definer set search_path = '' as $$
declare u uuid; n int := 0; v text := trim(coalesce(p_version, '')); nt text := left(trim(coalesce(p_notas, '')), 140);
begin
  perform public.cfx_es_admin();
  if v !~ '^[0-9]+(\.[0-9]+){0,3}$' then raise exception 'Versión no válida'; end if;
  if exists (select 1 from public.cfx_versiones where version = v) then return 0; end if;
  for u in select * from public.cfx_destinatarios('todos') loop
    perform public.cfx_avisar(u, '🚀 Nueva versión disponible', left(coalesce(nullif(trim(p_app), '') || ' ', '') || 'v' || v || case when nt <> '' then ' · ' || nt else '' end || '. Se actualiza sola al abrirla.', 240));
    n := n + 1;
  end loop;
  insert into public.cfx_versiones (version, notas, avisados) values (v, nt, n);
  perform public.cfx_anotar('version', 'v' || v || ' avisada a ' || n);
  return n;
end $$;
revoke execute on function public.cfx_avisar_version(text, text, text) from public, anon;
grant execute on function public.cfx_avisar_version(text, text, text) to authenticated;

-- ---------- Keys de Premium (de un solo uso). Se guardan cifradas: el código completo solo se ve al crearlas. ----------
create or replace function public.cfx_keys_crear(p_n int, p_rol text, p_dias int, p_nota text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c text; out jsonb := '[]'::jsonb;
begin
  perform public.cfx_es_admin();
  if p_rol not in ('negocio', 'cliente') or coalesce(p_dias, 0) not between 1 and 3660 or coalesce(p_n, 0) not between 1 and 50 then raise exception 'Datos no válidos'; end if;
  for i in 1..p_n loop
    c := upper(replace(gen_random_uuid()::text, '-', ''));
    c := 'CFX-' || substr(c, 1, 4) || '-' || substr(c, 5, 4) || '-' || substr(c, 9, 4);
    insert into public.cfx_keys (hash, ultimos, rol, dias, nota) values (encode(sha256(convert_to(c, 'UTF8')), 'hex'), right(c, 4), p_rol, p_dias, left(coalesce(p_nota, ''), 120));
    out := out || to_jsonb(c);
  end loop;
  perform public.cfx_anotar('keys', p_n || ' keys ' || p_rol || ' de ' || p_dias || ' días');
  return out;
end $$;
create or replace function public.cfx_keys_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(to_jsonb(k) - 'hash' order by k.creado desc), '[]') from (select * from public.cfx_keys order by creado desc limit 300) k);
end $$;
create or replace function public.cfx_key_revocar(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  update public.cfx_keys set revocada = true where id = p_id and usada_por is null;
  perform public.cfx_anotar('key revocada', p_id::text);
end $$;
create or replace function public.cfx_key_canjear(p_codigo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); k public.cfx_keys; h timestamptz; c text := upper(trim(coalesce(p_codigo, '')));
begin
  if y is null or (y ->> 'id') is null then raise exception 'Inicia sesión'; end if;
  if (select count(*) from public.cfx_registro where accion = 'key fallida' and detalle = (y ->> 'id') and creado > now() - interval '1 hour') >= 10 then
    raise exception 'Demasiados intentos. Prueba en una hora.';
  end if;
  select * into k from public.cfx_keys where hash = encode(sha256(convert_to(c, 'UTF8')), 'hex') for update;
  if k.id is null or k.revocada or k.usada_por is not null then
    -- Sin raise: si no, el registro se deshace y el límite de 10 por hora nunca cuenta (núcleo 2.48).
    insert into public.cfx_registro (quien, accion, detalle) values (coalesce(y ->> 'email', ''), 'key fallida', y ->> 'id');
    return jsonb_build_object('error', 'Key no válida o ya usada');
  end if;
  if k.rol <> coalesce(y ->> 'rol', '') then raise exception 'Esta key es para cuentas de %', case when k.rol = 'negocio' then 'negocio' else 'cliente' end; end if;
  h := public.cfx_dar_premium((y ->> 'id')::uuid, k.rol, k.dias);
  update public.cfx_keys set usada_por = (y ->> 'id')::uuid, usada_email = y ->> 'email', usada_at = now() where id = k.id;
  insert into public.cfx_exentos (cuenta, nota) values ((y ->> 'id')::uuid, 'Key ' || k.ultimos) on conflict (cuenta) do nothing;
  perform public.cfx_avisar_admin('🔑 Key canjeada', coalesce(y ->> 'email', '') || ' · ' || k.dias || ' días');
  return jsonb_build_object('hasta', h, 'dias', k.dias);
end $$;

-- ---------- Cupones de descuento (se aplican al pagar Premium) ----------
create or replace function public.cfx_cupon_ver(p_codigo text) returns int
language plpgsql stable security definer set search_path = '' as $$
declare c public.cfx_cupones;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select * into c from public.cfx_cupones where codigo = upper(trim(coalesce(p_codigo, '')));
  if c.codigo is null or not c.activo or (c.vence is not null and c.vence < current_date) or (c.usos_max is not null and c.usos >= c.usos_max) then
    raise exception 'Cupón no válido o vencido';
  end if;
  return c.pct;
end $$;
create or replace function public.cfx_cupones_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(to_jsonb(c) order by c.creado desc), '[]') from public.cfx_cupones c);
end $$;
create or replace function public.cfx_cupon_guardar(p_codigo text, p_pct int, p_usos_max int default null, p_vence date default null, p_activo boolean default true) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  insert into public.cfx_cupones (codigo, pct, usos_max, vence, activo) values (upper(trim(p_codigo)), p_pct, p_usos_max, p_vence, coalesce(p_activo, true))
  on conflict (codigo) do update set pct = excluded.pct, usos_max = excluded.usos_max, vence = excluded.vence, activo = excluded.activo;
  perform public.cfx_anotar('cupón', upper(trim(p_codigo)) || ' ' || p_pct || '%');
end $$;
create or replace function public.cfx_cupon_borrar(p_codigo text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  delete from public.cfx_cupones where codigo = upper(trim(p_codigo));
end $$;

-- ---------- Verificación de identidad (RUT, N° de documento, fotos de la cédula y selfie). Las fotos se borran al revisar. ----------
create or replace function public.cfx_rut_ok(r text) returns boolean
language plpgsql immutable as $$
declare s text := upper(regexp_replace(coalesce(r, ''), '[^0-9kK]', '', 'g')); cuerpo text; dv text; suma int := 0; m int := 2; res text;
begin
  if length(s) < 2 then return false; end if;
  cuerpo := left(s, length(s) - 1); dv := right(s, 1);
  if cuerpo !~ '^[0-9]+$' then return false; end if;
  for i in reverse length(cuerpo)..1 loop
    suma := suma + substr(cuerpo, i, 1)::int * m; m := case when m = 7 then 2 else m + 1 end;
  end loop;
  res := case 11 - suma % 11 when 11 then '0' when 10 then 'K' else (11 - suma % 11)::text end;
  return res = dv;
end $$;
create or replace function public.cfx_verif_estado() returns jsonb
language sql stable security definer set search_path = '' as $$
  select (select jsonb_build_object('estado', estado, 'motivo', motivo, 'creado', creado, 'resuelto', resuelto) from public.cfx_verificaciones where cuenta = auth.uid())
$$;
create or replace function public.cfx_verif_enviar(p_rut text, p_documento text, p_frente text, p_reverso text, p_selfie text) returns void
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); r text := upper(regexp_replace(coalesce(p_rut, ''), '[^0-9kK]', '', 'g'));
begin
  if y is null or (y ->> 'id') is null then raise exception 'Inicia sesión'; end if;
  if not public.cfx_rut_ok(r) then raise exception 'RUT no válido'; end if;
  if exists (select 1 from public.cfx_verificaciones where rut = r and cuenta <> (y ->> 'id')::uuid and estado <> 'rechazada') then raise exception 'Ese RUT ya está en otra cuenta'; end if;
  if exists (select 1 from public.cfx_verificaciones where cuenta = (y ->> 'id')::uuid and estado = 'aprobada') then raise exception 'Tu identidad ya está verificada'; end if;
  if coalesce(length(p_frente), 0) < 200 or coalesce(length(p_reverso), 0) < 200 or coalesce(length(p_selfie), 0) < 200 then raise exception 'Faltan fotos'; end if;
  if length(p_frente) > 500000 or length(p_reverso) > 500000 or length(p_selfie) > 500000 then raise exception 'Fotos muy pesadas'; end if;
  insert into public.cfx_verificaciones (cuenta, email, nombre, rut, documento, frente, reverso, selfie, estado, motivo, creado, resuelto)
  values ((y ->> 'id')::uuid, coalesce(y ->> 'email', ''), left(coalesce(y ->> 'nombre', ''), 80), r, left(coalesce(p_documento, ''), 20), p_frente, p_reverso, p_selfie, 'pendiente', '', now(), null)
  on conflict (cuenta) do update set rut = excluded.rut, documento = excluded.documento, frente = excluded.frente, reverso = excluded.reverso, selfie = excluded.selfie,
    estado = 'pendiente', motivo = '', creado = now(), resuelto = null;
  perform public.cfx_avisar_admin('🪪 Verificación por revisar', coalesce(nullif(y ->> 'nombre', ''), y ->> 'email'));
end $$;
create or replace function public.cfx_verif_lista(p_estado text default 'pendiente') returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(x order by x.creado desc), '[]') from (select cuenta, email, nombre, rut, documento, estado, motivo, creado, resuelto
    from public.cfx_verificaciones where p_estado = 'todos' or estado = p_estado order by creado desc limit 200) x);
end $$;
create or replace function public.cfx_verif_fotos(p_cuenta uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select jsonb_build_object('frente', frente, 'reverso', reverso, 'selfie', selfie) from public.cfx_verificaciones where cuenta = p_cuenta);
end $$;
create or replace function public.cfx_verif_resolver(p_cuenta uuid, p_aprobar boolean, p_motivo text default '') returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  update public.cfx_verificaciones set estado = case when p_aprobar then 'aprobada' else 'rechazada' end, motivo = left(coalesce(p_motivo, ''), 200),
    resuelto = now(), frente = null, reverso = null, selfie = null where cuenta = p_cuenta and estado = 'pendiente';
  if not found then raise exception 'No hay una verificación pendiente'; end if;
  perform public.cfx_marcar_verificado(p_cuenta, p_aprobar);
  perform public.cfx_avisar(p_cuenta, case when p_aprobar then '🪪 Identidad verificada' else '🪪 Verificación rechazada' end,
    case when p_aprobar then 'Ya apareces como persona verificada.' else coalesce(nullif(p_motivo, ''), 'Revisa las fotos') || '. Puedes enviarla de nuevo.' end);
  perform public.cfx_anotar(case when p_aprobar then 'verificación aprobada' else 'verificación rechazada' end, p_cuenta::text);
end $$;

create or replace function public.cfx_cupon_usado() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 'aprobado' and old.estado = 'pendiente' and new.cupon is not null then update public.cfx_cupones set usos = usos + 1 where codigo = new.cupon; end if;
  return new;
end $$;
drop trigger if exists cfx_cupon_usado on public.cfx_pagos;
create trigger cfx_cupon_usado after update of estado on public.cfx_pagos for each row execute function public.cfx_cupon_usado();

-- ---------- Verificación humana (Cloudflare Turnstile): la site key es pública; la secret key va en Supabase → Authentication → CAPTCHA ----------
-- y, para las compras/reservas sin cuenta, también aquí (cfx_secretos, nunca sale de la base): la base revisa el token con Cloudflare.
insert into public.cfx_config (clave, valor) values ('humano', '{"site_key": ""}') on conflict (clave) do nothing;
create table if not exists public.cfx_secretos (clave text primary key, valor text not null, updated_at timestamptz not null default now());
alter table public.cfx_secretos enable row level security;
revoke all on public.cfx_secretos from anon, authenticated;
create or replace function public.cfx_humano() returns jsonb
language sql stable security definer set search_path = '' as $$
  select valor || jsonb_build_object('invitados', exists (select 1 from public.cfx_secretos where clave = 'turnstile'))
  from public.cfx_config where clave = 'humano' $$;
drop function if exists public.cfx_humano_guardar(text);
create or replace function public.cfx_humano_guardar(p_site_key text, p_secreto text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if coalesce(p_site_key, '') <> '' and p_site_key !~ '^[0-9A-Za-z_-]{10,60}$' then raise exception 'Site key no válida'; end if;
  if coalesce(p_secreto, '') <> '' and p_secreto !~ '^[0-9A-Za-z_-]{10,80}$' then raise exception 'Secret key no válida'; end if;
  update public.cfx_config set valor = jsonb_build_object('site_key', coalesce(p_site_key, '')) where clave = 'humano';
  -- null = dejar la secret key como está; '' = quitarla (o si se apaga la site key).
  if coalesce(p_site_key, '') = '' or p_secreto = '' then delete from public.cfx_secretos where clave = 'turnstile';
  elsif p_secreto is not null then
    insert into public.cfx_secretos (clave, valor) values ('turnstile', p_secreto)
    on conflict (clave) do update set valor = excluded.valor, updated_at = now();
  end if;
  perform public.cfx_anotar('humano', case when coalesce(p_site_key, '') = '' then 'apagado' else 'site key ' || right(p_site_key, 4) ||
    case when exists (select 1 from public.cfx_secretos where clave = 'turnstile') then ' + compras sin cuenta' else '' end end);
end $$;
-- ¿El token de Turnstile es de una persona? Sin secret key no se exige. Si Cloudflare no responde, no frena la venta.
create or replace function public.cfx_humano_ok(p_token text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare k text := (select valor from public.cfx_secretos where clave = 'turnstile'); st int; c text;
begin
  if k is null then return true; end if;
  if coalesce(p_token, '') = '' or length(p_token) > 4000 then return false; end if;
  begin
    perform extensions.http_set_curlopt('CURLOPT_TIMEOUT', '5');
    execute 'select status, content from extensions.http(row($1, $2, $3, $4, $5)::extensions.http_request)' into st, c
      using 'POST', 'https://challenges.cloudflare.com/turnstile/v0/siteverify', array[]::extensions.http_header[],
            'application/x-www-form-urlencoded', 'secret=' || k || '&response=' || p_token;
  exception when others then return true;
  end;
  if st is distinct from 200 or c !~ '^\s*\{' then return true; end if;
  return coalesce((c::jsonb ->> 'success')::boolean, false);
end $$;
revoke all on function public.cfx_humano(), public.cfx_humano_guardar(text, text), public.cfx_humano_ok(text) from public, anon, authenticated;
grant execute on function public.cfx_humano() to anon, authenticated;
grant execute on function public.cfx_humano_guardar(text, text) to authenticated;

revoke all on function public.cfx_anotar(text, text), public.cfx_cupon_usado() from public, anon, authenticated;
revoke all on function public.cfx_registro_lista(int), public.cfx_planes(), public.cfx_plan_guardar(text, text, jsonb, jsonb), public.cfx_textos(), public.cfx_texto_guardar(text, text),
  public.cfx_aviso_masivo(text, text, text), public.cfx_keys_crear(int, text, int, text), public.cfx_keys_lista(), public.cfx_key_revocar(uuid), public.cfx_key_canjear(text),
  public.cfx_cupon_ver(text), public.cfx_cupones_lista(), public.cfx_cupon_guardar(text, int, int, date, boolean), public.cfx_cupon_borrar(text),
  public.cfx_verif_estado(), public.cfx_verif_enviar(text, text, text, text, text), public.cfx_verif_lista(text), public.cfx_verif_fotos(uuid), public.cfx_verif_resolver(uuid, boolean, text) from public, anon;
grant execute on function public.cfx_registro_lista(int), public.cfx_planes(), public.cfx_plan_guardar(text, text, jsonb, jsonb), public.cfx_textos(), public.cfx_texto_guardar(text, text),
  public.cfx_aviso_masivo(text, text, text), public.cfx_keys_crear(int, text, int, text), public.cfx_keys_lista(), public.cfx_key_revocar(uuid), public.cfx_key_canjear(text),
  public.cfx_cupon_ver(text), public.cfx_cupones_lista(), public.cfx_cupon_guardar(text, int, int, date, boolean), public.cfx_cupon_borrar(text),
  public.cfx_verif_estado(), public.cfx_verif_enviar(text, text, text, text, text), public.cfx_verif_lista(text), public.cfx_verif_fotos(uuid), public.cfx_verif_resolver(uuid, boolean, text) to authenticated;
revoke all on function public.cfx_planes_app(), public.cfx_plan_guardar_app(text, text, jsonb, jsonb), public.cfx_textos_app(), public.cfx_texto_guardar_app(text, text),
  public.cfx_destinatarios(text), public.cfx_marcar_verificado(uuid, boolean) from public, anon, authenticated;

-- ---------- Series para el Resumen del Centro de Mando: por mes, cuentas nuevas y pagos/ingresos aprobados (últimos N meses) ----------
create or replace function public.cfx_series(p_meses int default 6) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare n int := greatest(1, least(coalesce(p_meses, 6), 24));
begin
  perform public.cfx_es_admin();
  return (select jsonb_agg(jsonb_build_object('mes', to_char(m, 'YYYY-MM'),
      'cuentas', (select count(*) from auth.users u where u.created_at >= m and u.created_at < m + interval '1 month'),
      'pagos', (select count(*) from public.cfx_pagos p where p.estado = 'aprobado' and p.creado >= m and p.creado < m + interval '1 month'),
      'ingresos', (select coalesce(sum(p.monto), 0) from public.cfx_pagos p where p.estado = 'aprobado' and p.creado >= m and p.creado < m + interval '1 month')) order by m)
    from generate_series(date_trunc('month', now()) - make_interval(months => n - 1), date_trunc('month', now()), interval '1 month') m);
end $$;
revoke all on function public.cfx_series(int) from public, anon;
grant execute on function public.cfx_series(int) to authenticated;

-- ---------- Servidor (igual en las 7 apps): uso de la base, cuentas, tablas más pesadas y tareas automáticas ----------
-- El Centro de Mando lo muestra en el carrusel de servidores. "tareas" sirve para ver si el envío de push está corriendo.
create or replace function public.cfx_servidor() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare t jsonb := '[]'; tb jsonb;
begin
  perform public.cfx_es_admin();
  select coalesce(jsonb_agg(x), '[]') into tb from (
    select jsonb_build_object('tabla', c.relname, 'bytes', pg_total_relation_size(c.oid), 'filas', greatest(c.reltuples, 0)::bigint) x
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' order by pg_total_relation_size(c.oid) desc limit 6) q;
  begin
    execute $q$ select coalesce(jsonb_agg(jsonb_build_object('nombre', j.jobname, 'activa', j.active, 'cada', j.schedule,
        'ultima', r.end_time, 'ok', r.status = 'succeeded', 'error', left(r.return_message, 160)) order by j.jobname), '[]')
      from cron.job j left join lateral (select end_time, status, return_message from cron.job_run_details d where d.jobid = j.jobid order by d.runid desc limit 1) r on true $q$ into t;
  exception when others then t := '[]';
  end;
  return jsonb_build_object('db_bytes', pg_database_size(current_database()), 'limite_bytes', 500 * 1024 * 1024,
    'cuentas', (select count(*) from auth.users), 'tablas', tb, 'tareas', t, 'hora', now());
end $$;
revoke all on function public.cfx_servidor() from public, anon;
grant execute on function public.cfx_servidor() to authenticated;

-- ---------- Actualizar la base ahora (núcleo 2.31, igual en las 7 apps) ----------
-- El Centro de Mando lo usa cuando una base quedó atrás ("se está actualizando sola" que no avanza).
-- Programa una tarea de un solo uso (en máx. 1 minuto, sin el límite de tiempo de la app) que corre auto_actualizar() y anota
-- su resultado en cfx_registro ('auto'): así se ve la causa real si falla (la tarea de cada 10 min siempre figura "ok").
drop function if exists public.cfx_actualizar_ahora();
create or replace function public.cfx_actualizar_ahora(p_programar boolean default true) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare prog text := 'ok'; t jsonb := '[]'; ult jsonb;
begin
  perform public.cfx_es_admin();
  if p_programar then begin
    execute $q$ select cron.schedule('cfx-ahora', '* * * * *', $c$do $d$ declare r text; begin r := public.auto_actualizar(); perform public.cfx_anotar('auto', r); end $d$; select cron.unschedule('cfx-ahora')$c$) $q$;
  exception when others then prog := sqlerrm;
  end; else prog := ''; end if;
  begin
    execute $q$ select coalesce(jsonb_agg(jsonb_build_object('nombre', j.jobname, 'activa', j.active, 'cada', j.schedule, 'ultima', r.end_time, 'ok', r.status = 'succeeded', 'error', left(r.return_message, 160)) order by j.jobname), '[]')
      from cron.job j left join lateral (select end_time, status, return_message from cron.job_run_details d where d.jobid = j.jobid order by d.runid desc limit 1) r on true
      where j.jobname ~ 'auto|ahora' $q$ into t;
  exception when others then t := '[]';
  end;
  select coalesce(jsonb_agg(jsonb_build_object('detalle', detalle, 'creado', creado) order by id desc), '[]') into ult
    from (select * from public.cfx_registro where accion = 'auto' order by id desc limit 3) q;
  if p_programar then perform public.cfx_anotar('version', 'Actualizar base ahora: ' || left(prog, 200)); end if;
  return jsonb_build_object('programada', prog, 'tareas', t, 'ultimos', ult, 'hora', now());
end $$;
revoke all on function public.cfx_actualizar_ahora(boolean) from public, anon;
grant execute on function public.cfx_actualizar_ahora(boolean) to authenticated;

-- ---------- G20 · 🏪 Negocios desde el Centro de Mando (Control → app → Negocios) ----------
-- Lista de cuentas de la app, Premium 1 mes / 3 meses / 1 año o quitarlo, e ingresar una key a nombre de esa cuenta.
-- Ganchos de cada app (opcionales: sin ellos se avisa que llega en su turno):
--   cfx_cuentas_app(p_rol text, p_q text) → jsonb [{ id, email, nombre, rol, premium_hasta, creado }] · cfx_quitar_premium(p_cuenta uuid)
create or replace function public.cfx_negocios(p_q text default '', p_rol text default 'negocio') returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  perform public.cfx_es_admin();
  if to_regprocedure('public.cfx_cuentas_app(text,text)') is null then return jsonb_build_object('error', 'Esta app aún no tiene la lista de negocios: llega cuando le toque su turno.'); end if;
  execute 'select public.cfx_cuentas_app($1, $2)' into r using case when p_rol = 'cliente' then 'cliente' else 'negocio' end, left(coalesce(p_q, ''), 80);
  return coalesce(r, '[]'::jsonb);
end $$;
create or replace function public.cfx_premium_cuenta(p_cuenta uuid, p_rol text, p_dias int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare h timestamptz;
begin
  perform public.cfx_es_admin();
  if p_cuenta is null or coalesce(p_rol, '') not in ('negocio', 'cliente') or p_dias is null or p_dias > 3660 then return jsonb_build_object('error', 'Datos no válidos'); end if;
  if p_dias > 0 then
    h := public.cfx_dar_premium(p_cuenta, p_rol, p_dias);
    if h is null then return jsonb_build_object('error', 'No se encontró la cuenta'); end if;
    perform public.cfx_avisar(p_cuenta, '⭐ Premium activado', 'Tienes Premium hasta el ' || to_char(h at time zone 'America/Santiago', 'DD-MM-YYYY') || '.');
    perform public.cfx_anotar('premium', p_dias || ' días a ' || p_cuenta);
    return jsonb_build_object('hasta', h);
  end if;
  if to_regprocedure('public.cfx_quitar_premium(uuid)') is null then return jsonb_build_object('error', 'Esta app aún no permite quitar Premium desde aquí.'); end if;
  execute 'select public.cfx_quitar_premium($1)' using p_cuenta;
  perform public.cfx_anotar('premium quitado', p_cuenta::text);
  return jsonb_build_object('hasta', null);
end $$;
create or replace function public.cfx_key_aplicar(p_cuenta uuid, p_rol text, p_email text, p_codigo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare k public.cfx_keys; h timestamptz; c text := upper(trim(coalesce(p_codigo, '')));
begin
  perform public.cfx_es_admin();
  if p_cuenta is null or coalesce(p_rol, '') not in ('negocio', 'cliente') then return jsonb_build_object('error', 'Datos no válidos'); end if;
  select * into k from public.cfx_keys where hash = encode(sha256(convert_to(c, 'UTF8')), 'hex') for update;
  if k.id is null or k.revocada or k.usada_por is not null then return jsonb_build_object('error', 'Key no válida o ya usada'); end if;
  if k.rol <> p_rol then return jsonb_build_object('error', 'Esta key es para cuentas de ' || k.rol); end if;
  h := public.cfx_dar_premium(p_cuenta, k.rol, k.dias);
  if h is null then return jsonb_build_object('error', 'No se encontró la cuenta'); end if;
  update public.cfx_keys set usada_por = p_cuenta, usada_email = left(coalesce(p_email, ''), 200), usada_at = now() where id = k.id;
  insert into public.cfx_exentos (cuenta, nota) values (p_cuenta, 'Key ' || k.ultimos) on conflict (cuenta) do nothing;
  perform public.cfx_avisar(p_cuenta, '🔑 Premium activado', 'Tienes Premium por ' || k.dias || ' días.');
  perform public.cfx_anotar('key aplicada', '…' || k.ultimos || ' a ' || coalesce(p_email, p_cuenta::text));
  return jsonb_build_object('hasta', h, 'dias', k.dias);
end $$;
revoke all on function public.cfx_negocios(text, text), public.cfx_premium_cuenta(uuid, text, int), public.cfx_key_aplicar(uuid, text, text, text) from public, anon;
grant execute on function public.cfx_negocios(text, text), public.cfx_premium_cuenta(uuid, text, int), public.cfx_key_aplicar(uuid, text, text, text) to authenticated;
-- ---------------------------------------------------------------------
-- CodeFix · Ayuda (igual en las 6 apps; lo reparte nucleo/sincronizar.py).
--   1) Puente al Centro de Mando: los avisos importantes (pagos por revisar, mensajes de soporte) le llegan al tiro
--      al Centro de Mando. El Centro de Mando vincula cada app solo (cfx_cm_vincular) al abrir Pagos o Mensajes.
--   2) Chat de soporte: cada persona escribe desde su app y tú respondes desde el Centro de Mando → Mensajes.
--   3) Guía para partir: lo que le falta configurar a cada negocio (cfx_guia_app() de cada app). No se marca
--      como listo hasta que de verdad lo hace, y se le recuerda cada vez que entra.
--   Cada app define antes: cfx_guia_app() → [{ k, t, d, ok, ir }].
-- ---------------------------------------------------------------------

-- ---------- 1) Puente al Centro de Mando ----------
create or replace function public.cfx_cm_vincular(p_url text, p_key text, p_secreto text, p_app text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if coalesce(p_url, '') !~ '^https://[a-z0-9.-]+$' or length(coalesce(p_key, '')) < 20 or length(coalesce(p_secreto, '')) < 24 or coalesce(p_app, '') !~ '^[a-z]{2,20}$' then
    raise exception 'Datos de vínculo no válidos';
  end if;
  insert into public.cfx_config (clave, valor) values ('cm', jsonb_build_object('url', p_url, 'key', p_key, 'secreto', p_secreto, 'app', p_app, 'desde', now()))
  on conflict (clave) do update set valor = excluded.valor;
  return jsonb_build_object('vinculado', true, 'app', p_app);
end $$;

create or replace function public.cfx_cm_estado() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb := (select valor from public.cfx_config where clave = 'cm');
begin
  perform public.cfx_es_admin();
  return jsonb_build_object('vinculado', coalesce(v ->> 'secreto', '') <> '', 'app', v ->> 'app', 'url', v ->> 'url', 'desde', v -> 'desde');
end $$;

-- Avisa al Centro de Mando (si la app está vinculada); si no, al administrador de esta app. Nunca hace fallar lo que la llama.
create or replace function public.cfx_al_cm(p_titulo text, p_cuerpo text, p_tipo text default 'aviso') returns void
language plpgsql security definer set search_path = '' as $$
declare v jsonb := (select valor from public.cfx_config where clave = 'cm');
begin
  if coalesce(v ->> 'secreto', '') = '' then
    perform public.cfx_avisar_admin(p_titulo, p_cuerpo);
    return;
  end if;
  begin
    perform net.http_post(
      url := (v ->> 'url') || '/rest/v1/rpc/cfx_aviso_externo',
      body := jsonb_build_object('p_app', v ->> 'app', 'p_secreto', v ->> 'secreto', 'p_titulo', left(p_titulo, 90), 'p_cuerpo', left(coalesce(p_cuerpo, ''), 240), 'p_tipo', p_tipo),
      headers := jsonb_build_object('apikey', v ->> 'key', 'Authorization', 'Bearer ' || (v ->> 'key'), 'Content-Type', 'application/json'));
  exception when others then
    begin perform public.cfx_avisar_admin(p_titulo, p_cuerpo); exception when others then null; end;
  end;
end $$;

-- ---------- 2) Chat de soporte ----------
create table if not exists public.cfx_chat (
  id      bigserial primary key,
  cuenta  uuid not null,
  email   text not null default '',
  nombre  text not null default '',
  rol     text not null default '',
  de      text not null check (de in ('persona', 'soporte')),
  texto   text not null check (length(texto) between 1 and 1000),
  leido   boolean not null default false,
  creado  timestamptz not null default now()
);
create index if not exists cfx_chat_cuenta_idx on public.cfx_chat (cuenta, id);
create index if not exists cfx_chat_sin_leer_idx on public.cfx_chat (de, leido) where not leido;
alter table public.cfx_chat enable row level security;
revoke all on public.cfx_chat from anon, authenticated;

create or replace function public.cfx_chat_mio() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); u uuid := (y ->> 'id')::uuid;
begin
  if u is null then raise exception 'Inicia sesión'; end if;
  update public.cfx_chat set leido = true where cuenta = u and de = 'soporte' and not leido;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'de', de, 'texto', texto, 'creado', creado) order by id), '[]')
          from (select * from public.cfx_chat where cuenta = u order by id desc limit 100) x);
end $$;

create or replace function public.cfx_chat_sin_leer() returns int
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.cfx_chat where cuenta = auth.uid() and de = 'soporte' and not leido
$$;

create or replace function public.cfx_chat_enviar(p_texto text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); u uuid := (y ->> 'id')::uuid; t text := trim(coalesce(p_texto, '')); i bigint;
begin
  if u is null then raise exception 'Inicia sesión'; end if;
  if t = '' then raise exception 'Escribe tu mensaje'; end if;
  if length(t) > 1000 then raise exception 'Máximo 1000 letras'; end if;
  if (select count(*) from public.cfx_chat where cuenta = u and de = 'persona' and creado > now() - interval '1 hour') >= 20 then
    raise exception 'Muchos mensajes seguidos. Espera un poco y te respondemos.';
  end if;
  insert into public.cfx_chat (cuenta, email, nombre, rol, de, texto)
  values (u, coalesce(y ->> 'email', ''), left(coalesce(y ->> 'nombre', ''), 80), coalesce(y ->> 'rol', ''), 'persona', t) returning id into i;
  delete from public.cfx_chat where cuenta = u and creado < now() - interval '365 days';
  perform public.cfx_al_cm('💬 ' || coalesce(nullif(y ->> 'nombre', ''), y ->> 'email', 'Mensaje'), left(t, 200), 'chat');
  return i;
end $$;

-- Administrador: bandeja (una fila por persona), conversación y respuesta.
create or replace function public.cfx_chat_bandeja() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select coalesce(jsonb_agg(x order by x.ultimo desc), '[]') from (
    select c.cuenta, max(c.email) as email, max(c.nombre) as nombre, max(c.rol) as rol, max(c.creado) as ultimo,
      (array_agg(c.texto order by c.id desc))[1] as texto, (array_agg(c.de order by c.id desc))[1] as de,
      count(*) filter (where c.de = 'persona' and not c.leido) as sin_leer
    from public.cfx_chat c group by c.cuenta order by max(c.creado) desc limit 200) x);
end $$;

create or replace function public.cfx_chat_hilo(p_cuenta uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  update public.cfx_chat set leido = true where cuenta = p_cuenta and de = 'persona' and not leido;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'de', de, 'texto', texto, 'creado', creado) order by id), '[]')
          from (select * from public.cfx_chat where cuenta = p_cuenta order by id desc limit 200) x);
end $$;

create or replace function public.cfx_chat_responder(p_cuenta uuid, p_texto text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare t text := trim(coalesce(p_texto, '')); i bigint; o public.cfx_chat;
begin
  perform public.cfx_es_admin();
  if t = '' or length(t) > 1000 then raise exception 'Escribe la respuesta (máx. 1000 letras)'; end if;
  select * into o from public.cfx_chat where cuenta = p_cuenta order by id desc limit 1;
  if o.id is null then raise exception 'Conversación no encontrada'; end if;
  insert into public.cfx_chat (cuenta, email, nombre, rol, de, texto, leido) values (p_cuenta, o.email, o.nombre, o.rol, 'soporte', t, false) returning id into i;
  update public.cfx_chat set leido = true where cuenta = p_cuenta and de = 'persona' and not leido;
  perform public.cfx_avisar(p_cuenta, '💬 Soporte te respondió', left(t, 200));
  return i;
end $$;

-- El administrador escribe primero a una cuenta (consejos o recomendaciones): queda en su chat de soporte (🛟) y en CM → Mensajes.
create or replace function public.cfx_chat_iniciar(p_cuenta uuid, p_texto text, p_email text default '', p_nombre text default '', p_rol text default 'negocio') returns bigint
language plpgsql security definer set search_path = '' as $$
declare t text := trim(coalesce(p_texto, '')); i bigint; o public.cfx_chat;
begin
  perform public.cfx_es_admin();
  if t = '' or length(t) > 1000 then raise exception 'Escribe el mensaje (máx. 1000 letras)'; end if;
  select * into o from public.cfx_chat where cuenta = p_cuenta order by id desc limit 1;
  insert into public.cfx_chat (cuenta, email, nombre, rol, de, texto, leido)
  values (p_cuenta, coalesce(o.email, left(coalesce(p_email, ''), 200)), coalesce(o.nombre, left(coalesce(p_nombre, ''), 120)), coalesce(o.rol, left(coalesce(p_rol, 'negocio'), 20)), 'soporte', t, false)
  returning id into i;
  perform public.cfx_avisar(p_cuenta, '💬 Soporte te escribió', left(t, 200));
  return i;
end $$;
revoke all on function public.cfx_chat_iniciar(uuid, text, text, text, text) from public, anon;
grant execute on function public.cfx_chat_iniciar(uuid, text, text, text, text) to authenticated;

-- ---------- 3) Guía para partir ----------
-- Pendientes de configuración del negocio (los arma cada app) + verificar identidad. Solo para negocios.
create or replace function public.cfx_guia() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); l jsonb;
begin
  if y is null or (y ->> 'id') is null then raise exception 'Inicia sesión'; end if;
  if y ->> 'rol' <> 'negocio' then return jsonb_build_object('items', '[]'::jsonb, 'sin_leer', public.cfx_chat_sin_leer()); end if;
  l := coalesce(public.cfx_guia_app(), '[]'::jsonb);
  -- Sin guía propia (Centro de Mando): nada que mostrar.
  if jsonb_array_length(l) > 0 and not exists (select 1 from jsonb_array_elements(l) e where e ->> 'k' = 'verificar') then l := l || jsonb_build_array(jsonb_build_object('k', 'verificar', 't', 'Verifica tu identidad',
    'd', 'Tus clientes confían más en un negocio verificado. Toma 2 minutos.',
    'ok', exists (select 1 from public.cfx_verificaciones v where v.cuenta = (y ->> 'id')::uuid and v.estado = 'aprobada'), 'ir', 'verificar')); end if;
  return jsonb_build_object('items', l, 'sin_leer', public.cfx_chat_sin_leer());
end $$;

revoke all on function public.cfx_al_cm(text, text, text) from public, anon, authenticated;
revoke all on function public.cfx_cm_vincular(text, text, text, text), public.cfx_cm_estado(), public.cfx_chat_mio(), public.cfx_chat_sin_leer(), public.cfx_chat_enviar(text),
  public.cfx_chat_bandeja(), public.cfx_chat_hilo(uuid), public.cfx_chat_responder(uuid, text), public.cfx_guia() from public, anon;
grant execute on function public.cfx_cm_vincular(text, text, text, text), public.cfx_cm_estado(), public.cfx_chat_mio(), public.cfx_chat_sin_leer(), public.cfx_chat_enviar(text),
  public.cfx_chat_bandeja(), public.cfx_chat_hilo(uuid), public.cfx_chat_responder(uuid, text), public.cfx_guia() to authenticated;
revoke all on function public.cfx_guia_app() from public, anon, authenticated;

-- ---------- PIN de la app (4 a 6 números), guardado en la cuenta. Se pide al abrir la app y tras 5 min sin usarla. ----------
create table if not exists public.cfx_pin (
  usuario    uuid primary key references auth.users (id) on delete cascade,
  hash       text not null,
  fallos     int not null default 0,
  espera     timestamptz,
  actualizado timestamptz not null default now()
);
alter table public.cfx_pin enable row level security;
revoke all on public.cfx_pin from anon, authenticated;

create or replace function public.cfx_pin_estado() returns boolean
language sql stable security definer set search_path = '' as $$ select exists (select 1 from public.cfx_pin where usuario = auth.uid()) $$;

create or replace function public.cfx_pin_guardar(p_pin text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  if coalesce(p_pin, '') = '' then delete from public.cfx_pin where usuario = auth.uid(); return false; end if;
  if p_pin !~ '^[0-9]{4,6}$' then raise exception 'El PIN debe tener de 4 a 6 números'; end if;
  insert into public.cfx_pin (usuario, hash) values (auth.uid(), encode(sha256(convert_to(auth.uid()::text || ':' || p_pin, 'UTF8')), 'hex'))
  on conflict (usuario) do update set hash = excluded.hash, fallos = 0, espera = null, actualizado = now();
  return true;
end $$;

create or replace function public.cfx_pin_verificar(p_pin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.cfx_pin;
begin
  select * into r from public.cfx_pin where usuario = auth.uid();
  if not found then return jsonb_build_object('ok', true); end if;
  if r.espera is not null and r.espera > now() then return jsonb_build_object('ok', false, 'espera', ceil(extract(epoch from r.espera - now()))); end if;
  if r.hash = encode(sha256(convert_to(auth.uid()::text || ':' || coalesce(p_pin, ''), 'UTF8')), 'hex') then
    update public.cfx_pin set fallos = 0, espera = null where usuario = auth.uid(); return jsonb_build_object('ok', true);
  end if;
  update public.cfx_pin set fallos = case when r.fallos + 1 >= 5 then 0 else r.fallos + 1 end,
    espera = case when r.fallos + 1 >= 5 then now() + interval '5 minutes' else null end where usuario = auth.uid();
  return jsonb_build_object('ok', false, 'quedan', greatest(0, 4 - r.fallos), 'espera', case when r.fallos + 1 >= 5 then 300 else 0 end);
end $$;
revoke all on function public.cfx_pin_estado(), public.cfx_pin_guardar(text), public.cfx_pin_verificar(text) from public, anon;
grant execute on function public.cfx_pin_estado(), public.cfx_pin_guardar(text), public.cfx_pin_verificar(text) to authenticated;
-- ---------------------------------------------------------------------
-- CodeFix · Legal (igual en las 7 apps; lo reparte nucleo/sincronizar.py).
--   Términos y Política de privacidad con versión (Ley 19.628 modificada por la Ley 21.719, vigente desde el 1-dic-2026).
--   El texto vive en nucleo/ayuda.js (CFX_LEGAL.version). Aquí solo queda la prueba de quién aceptó qué versión y cuándo.
--   cfx_legal_estado()          → última versión aceptada por la cuenta (0 = ninguna).
--   cfx_legal_aceptar(version)  → guarda la aceptación (una fila por versión, nunca se pisa).
--   cfx_legal_resumen()         → admin: cuántas cuentas aceptaron cada versión.
-- ---------------------------------------------------------------------
create table if not exists public.cfx_legal (
  cuenta    uuid not null,
  version   int  not null check (version between 1 and 10000),
  aceptado  timestamptz not null default now(),
  agente    text not null default '',
  primary key (cuenta, version)
);
alter table public.cfx_legal enable row level security;
revoke all on public.cfx_legal from anon, authenticated;

create or replace function public.cfx_legal_estado() returns int
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(max(version), 0) from public.cfx_legal where cuenta = auth.uid()
$$;

create or replace function public.cfx_legal_aceptar(p_version int) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Inicia sesión para aceptar.'; end if;
  if p_version is null or p_version < 1 or p_version > 10000 then raise exception 'Versión no válida.'; end if;
  insert into public.cfx_legal (cuenta, version, agente)
  values (u, p_version, left(coalesce(current_setting('request.headers', true)::jsonb ->> 'user-agent', ''), 300))
  on conflict (cuenta, version) do nothing;
end $$;

create or replace function public.cfx_legal_resumen() returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('version', version, 'cuentas', n, 'ultima', u) order by version desc)
    from (select version, count(*) n, max(aceptado) u from public.cfx_legal group by version) x), '[]'::jsonb);
end $$;

revoke all on function public.cfx_legal_estado(), public.cfx_legal_aceptar(int), public.cfx_legal_resumen() from public, anon;
grant execute on function public.cfx_legal_estado(), public.cfx_legal_aceptar(int), public.cfx_legal_resumen() to authenticated;

-- ---------------------------------------------------------------------
-- A2 · Consentimientos aparte de los términos (se dan y se retiran cuando quieras; queda el historial).
--   'ofertas'  = novedades y ofertas de CodeFix (parte en NO: solo con consentimiento expreso).
--   'negocios' = ofertas de los negocios donde eres cliente (parte en SÍ por la relación de cliente; se puede retirar).
--   cfx_consent_estado() · cfx_consent_guardar(tipo, si) · cfx_acepta(cuenta, tipo) (uso interno) · admin cfx_consent_resumen().
-- A3 · Derechos del titular (acceso, rectificación, supresión, oposición, portabilidad y bloqueo) con plazo de 30 días (+30 una vez).
--   cfx_mis_datos() → copia de todo lo de la cuenta (acceso y portabilidad al instante; queda registrado como solicitud respondida).
--   cfx_derecho_pedir(tipo, detalle) · cfx_derechos_mios() · admin cfx_derechos_lista(todas) y cfx_derecho_responder(id, accion, respuesta).
-- Brechas de seguridad (registro y aviso a la Agencia y a los afectados): admin cfx_brechas_lista(), cfx_brecha_guardar(jsonb),
--   cfx_brecha_marcar(id, 'agencia' | 'cerrar'), cfx_brecha_avisar(id, destino, titulo, cuerpo). Resumen: cfx_privacidad_resumen().
-- ---------------------------------------------------------------------
create table if not exists public.cfx_consent (
  cuenta uuid not null, tipo text not null check (tipo in ('ofertas', 'negocios')), si boolean not null,
  cambiado timestamptz not null default now(), agente text not null default '', primary key (cuenta, tipo));
create table if not exists public.cfx_consent_hist (
  id bigserial primary key, cuenta uuid not null, tipo text not null, si boolean not null, creado timestamptz not null default now(), agente text not null default '');
create table if not exists public.cfx_derechos (
  id bigserial primary key, cuenta uuid not null, email text not null default '',
  tipo text not null check (tipo in ('acceso', 'rectificacion', 'supresion', 'oposicion', 'portabilidad', 'bloqueo')),
  detalle text not null default '', estado text not null default 'pendiente' check (estado in ('pendiente', 'prorrogada', 'respondida', 'rechazada')),
  creado timestamptz not null default now(), vence timestamptz not null default now() + interval '30 days', respuesta text not null default '', respondido timestamptz);
create index if not exists cfx_derechos_cuenta on public.cfx_derechos (cuenta, creado desc);
create table if not exists public.cfx_brechas (
  id bigserial primary key, detectada timestamptz not null default now(), descripcion text not null, datos text not null default '',
  afectados int not null default 0, riesgo text not null default 'medio' check (riesgo in ('bajo', 'medio', 'alto')), medidas text not null default '',
  agencia timestamptz, titulares timestamptz, avisados int not null default 0, cerrada timestamptz, creado timestamptz not null default now());
alter table public.cfx_consent enable row level security;
alter table public.cfx_consent_hist enable row level security;
alter table public.cfx_derechos enable row level security;
alter table public.cfx_brechas enable row level security;
revoke all on public.cfx_consent, public.cfx_consent_hist, public.cfx_derechos, public.cfx_brechas from anon, authenticated;

create or replace function public.cfx_agente() returns text language sql stable set search_path = '' as $$
  select left(coalesce(current_setting('request.headers', true)::jsonb ->> 'user-agent', ''), 300) $$;
create or replace function public.cfx_acepta(p_cuenta uuid, p_tipo text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select si from public.cfx_consent where cuenta = p_cuenta and tipo = p_tipo), p_tipo = 'negocios') $$;
create or replace function public.cfx_consent_estado() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('ofertas', public.cfx_acepta(auth.uid(), 'ofertas'), 'negocios', public.cfx_acepta(auth.uid(), 'negocios'),
    'cambiado', coalesce((select jsonb_object_agg(tipo, cambiado) from public.cfx_consent where cuenta = auth.uid()), '{}'::jsonb)) $$;
create or replace function public.cfx_consent_guardar(p_tipo text, p_si boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Inicia sesión.'; end if;
  if p_tipo not in ('ofertas', 'negocios') or p_si is null then raise exception 'Opción no válida.'; end if;
  insert into public.cfx_consent (cuenta, tipo, si, agente) values (u, p_tipo, p_si, public.cfx_agente())
  on conflict (cuenta, tipo) do update set si = excluded.si, cambiado = now(), agente = excluded.agente;
  insert into public.cfx_consent_hist (cuenta, tipo, si, agente) values (u, p_tipo, p_si, public.cfx_agente());
  return public.cfx_consent_estado();
end $$;
create or replace function public.cfx_consent_resumen() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'si', s, 'no', n) order by tipo)
    from (select tipo, count(*) filter (where si) s, count(*) filter (where not si) n from public.cfx_consent group by tipo) x), '[]'::jsonb);
end $$;

-- Copia de los datos de la cuenta: cada tabla con una columna de dueño (cuenta, owner_id, user_id, cliente_id…) = la cuenta.
-- No incluye claves, PIN, tokens ni llaves de API (se quitan esas columnas). Máx. 1000 filas por tabla.
create or replace function public.cfx_mis_datos() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); r record; filas jsonb; out jsonb := '{}'::jsonb; quitar text[];
begin
  if u is null then raise exception 'Inicia sesión.'; end if;
  for r in
    select c.table_schema s, c.table_name t, c.column_name col
    from information_schema.columns c join information_schema.tables tb on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
    where c.table_schema in ('public', 'privado') and c.data_type = 'uuid'
      and (c.column_name in ('cuenta', 'owner_id', 'user_id', 'usuario_id', 'cliente_id', 'target_id', 'autor_id', 'creado_por', 'created_by')
        or (c.column_name = 'id' and c.table_name in ('profiles', 'perfiles', 'usuarios', 'cuentas')))
      and c.table_name not in ('cfx_pin', 'cfx_keys', 'boleta_cuentas', 'push_subscriptions', 'app_secrets', 'cfx_verificaciones')
      and c.table_name !~ '(secret|clave|token)'
    order by 1, 2, 3
  loop
    select coalesce(array_agg(column_name::text), '{}') into quitar from information_schema.columns
      where table_schema = r.s and table_name = r.t and column_name ~* '(hash|^pin|pass|token|apikey|api_key|secret|clave|endpoint|^p256dh|^auth$)';
    execute format('select coalesce(jsonb_agg(to_jsonb(x) - $2), ''[]''::jsonb) from (select * from %I.%I where %I = $1 limit 1000) x', r.s, r.t, r.col) into filas using u, quitar;
    if jsonb_array_length(filas) > 0 then
      out := jsonb_set(out, array[r.s || '.' || r.t], coalesce(out -> (r.s || '.' || r.t), '[]'::jsonb) || filas);
    end if;
  end loop;
  insert into public.cfx_derechos (cuenta, email, tipo, detalle, estado, respuesta, respondido)
  values (u, coalesce((select email from auth.users where id = u), ''), 'portabilidad', 'Descarga desde la app', 'respondida', 'Copia entregada al instante (archivo JSON).', now());
  return jsonb_build_object('generado', now(), 'cuenta', jsonb_build_object('id', u, 'email', (select email from auth.users where id = u)),
    'consentimientos', public.cfx_consent_estado(), 'terminos_aceptados', (select coalesce(jsonb_agg(jsonb_build_object('version', version, 'aceptado', aceptado)), '[]'::jsonb) from public.cfx_legal where cuenta = u),
    'datos', out);
end $$;

create or replace function public.cfx_derecho_pedir(p_tipo text, p_detalle text default '') returns bigint
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); e text; i bigint; nom text;
begin
  if u is null then raise exception 'Inicia sesión.'; end if;
  if p_tipo not in ('acceso', 'rectificacion', 'supresion', 'oposicion', 'portabilidad', 'bloqueo') then raise exception 'Tipo de solicitud no válido.'; end if;
  if p_tipo in ('rectificacion', 'oposicion') and length(trim(coalesce(p_detalle, ''))) < 3 then raise exception 'Cuéntanos qué dato o qué uso (en pocas palabras).'; end if;
  if (select count(*) from public.cfx_derechos where cuenta = u and estado in ('pendiente', 'prorrogada')) >= 5 then raise exception 'Ya tienes 5 solicitudes en curso: espera la respuesta.'; end if;
  select email into e from auth.users where id = u;
  insert into public.cfx_derechos (cuenta, email, tipo, detalle) values (u, coalesce(e, ''), p_tipo, left(trim(coalesce(p_detalle, '')), 600)) returning id into i;
  nom := case p_tipo when 'acceso' then 'acceso' when 'rectificacion' then 'rectificación' when 'supresion' then 'supresión (borrar)' when 'oposicion' then 'oposición'
    when 'portabilidad' then 'portabilidad' else 'bloqueo' end;
  perform public.cfx_anotar('derecho', 'Solicitud de ' || nom || ' #' || i || ' de ' || coalesce(e, u::text));
  begin perform public.cfx_avisar_admin('🔒 Solicitud de datos: ' || nom, coalesce(e, '') || ' · responder antes del ' || to_char(now() + interval '30 days', 'DD-MM-YYYY')); exception when others then null; end;
  return i;
end $$;
create or replace function public.cfx_derechos_mios() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'tipo', tipo, 'detalle', detalle, 'estado', estado, 'creado', creado, 'vence', vence, 'respuesta', respuesta, 'respondido', respondido) order by creado desc), '[]'::jsonb)
  from (select * from public.cfx_derechos where cuenta = auth.uid() order by creado desc limit 50) x $$;
create or replace function public.cfx_derechos_lista(p_todas boolean default false) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'cuenta', cuenta, 'email', email, 'tipo', tipo, 'detalle', detalle, 'estado', estado, 'creado', creado, 'vence', vence,
      'dias', ceil(extract(epoch from vence - now()) / 86400)::int, 'respuesta', respuesta, 'respondido', respondido) order by (estado in ('pendiente', 'prorrogada')) desc, vence)
    from (select * from public.cfx_derechos where p_todas or estado in ('pendiente', 'prorrogada') order by creado desc limit 300) x), '[]'::jsonb);
end $$;
create or replace function public.cfx_derecho_responder(p_id bigint, p_accion text, p_respuesta text) returns void
language plpgsql security definer set search_path = '' as $$
declare d public.cfx_derechos; t text := left(trim(coalesce(p_respuesta, '')), 800);
begin
  perform public.cfx_es_admin();
  select * into d from public.cfx_derechos where id = p_id for update;
  if d.id is null then raise exception 'No existe esa solicitud.'; end if;
  if d.estado not in ('pendiente', 'prorrogada') then raise exception 'Esa solicitud ya se respondió.'; end if;
  if length(t) < 3 then raise exception 'Escribe la respuesta (o el motivo).'; end if;
  if p_accion = 'prorrogar' then
    if d.estado = 'prorrogada' then raise exception 'Solo se puede prorrogar una vez.'; end if;
    update public.cfx_derechos set estado = 'prorrogada', vence = vence + interval '30 days', respuesta = t where id = p_id;
    perform public.cfx_avisar(d.cuenta, '🔒 Tu solicitud de datos tomará más tiempo', left('Respondemos antes del ' || to_char(d.vence + interval '30 days', 'DD-MM-YYYY') || '. ' || t, 240));
  elsif p_accion in ('responder', 'rechazar') then
    update public.cfx_derechos set estado = case when p_accion = 'responder' then 'respondida' else 'rechazada' end, respuesta = t, respondido = now() where id = p_id;
    perform public.cfx_avisar(d.cuenta, case when p_accion = 'responder' then '🔒 Respondimos tu solicitud de datos' else '🔒 Tu solicitud de datos no se pudo acoger' end, left(t, 240));
  else raise exception 'Acción no válida.'; end if;
  perform public.cfx_anotar('derecho', p_accion || ' #' || p_id || ' (' || d.tipo || ', ' || d.email || ')');
end $$;

create or replace function public.cfx_brechas_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(to_jsonb(b) order by b.detectada desc) from public.cfx_brechas b), '[]'::jsonb);
end $$;
create or replace function public.cfx_brecha_guardar(p jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare i bigint := nullif(p ->> 'id', '')::bigint; d text := left(trim(coalesce(p ->> 'descripcion', '')), 1000);
begin
  perform public.cfx_es_admin();
  if length(d) < 5 then raise exception 'Describe qué pasó.'; end if;
  if coalesce(p ->> 'riesgo', 'medio') not in ('bajo', 'medio', 'alto') then raise exception 'Riesgo no válido.'; end if;
  if i is null then
    insert into public.cfx_brechas (detectada, descripcion, datos, afectados, riesgo, medidas)
    values (coalesce(nullif(p ->> 'detectada', '')::timestamptz, now()), d, left(coalesce(p ->> 'datos', ''), 500), greatest(coalesce(nullif(p ->> 'afectados', '')::int, 0), 0),
      coalesce(p ->> 'riesgo', 'medio'), left(coalesce(p ->> 'medidas', ''), 1000)) returning id into i;
    perform public.cfx_anotar('brecha', 'Nueva #' || i || ' (' || coalesce(p ->> 'riesgo', 'medio') || '): ' || d);
  else
    update public.cfx_brechas set descripcion = d, datos = left(coalesce(p ->> 'datos', ''), 500), afectados = greatest(coalesce(nullif(p ->> 'afectados', '')::int, 0), 0),
      riesgo = coalesce(p ->> 'riesgo', 'medio'), medidas = left(coalesce(p ->> 'medidas', ''), 1000) where id = i;
    if not found then raise exception 'No existe ese registro.'; end if;
    perform public.cfx_anotar('brecha', 'Editada #' || i);
  end if;
  return i;
end $$;
create or replace function public.cfx_brecha_marcar(p_id bigint, p_que text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if p_que = 'agencia' then update public.cfx_brechas set agencia = coalesce(agencia, now()) where id = p_id;
  elsif p_que = 'cerrar' then update public.cfx_brechas set cerrada = coalesce(cerrada, now()) where id = p_id;
  else raise exception 'Acción no válida.'; end if;
  if not found then raise exception 'No existe ese registro.'; end if;
  perform public.cfx_anotar('brecha', p_que || ' #' || p_id);
end $$;
create or replace function public.cfx_brecha_avisar(p_id bigint, p_destino text, p_titulo text, p_cuerpo text) returns int
language plpgsql security definer set search_path = '' as $$
declare u uuid; n int := 0;
begin
  perform public.cfx_es_admin();
  if not exists (select 1 from public.cfx_brechas where id = p_id) then raise exception 'No existe ese registro.'; end if;
  if trim(coalesce(p_titulo, '')) = '' or trim(coalesce(p_cuerpo, '')) = '' then raise exception 'Escribe el título y el mensaje.'; end if;
  if p_destino not in ('todos', 'negocios', 'clientes', 'premium', 'gratis') then raise exception 'Destino no válido'; end if;
  for u in select * from public.cfx_destinatarios(p_destino) loop
    perform public.cfx_avisar(u, left(p_titulo, 80), left(p_cuerpo, 240)); n := n + 1;
  end loop;
  update public.cfx_brechas set titulares = now(), avisados = avisados + n where id = p_id;
  perform public.cfx_anotar('brecha', 'Aviso a ' || p_destino || ' (' || n || ') #' || p_id);
  return n;
end $$;
create or replace function public.cfx_privacidad_resumen() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object('pendientes', (select count(*) from public.cfx_derechos where estado in ('pendiente', 'prorrogada')),
    'vencen', (select count(*) from public.cfx_derechos where estado in ('pendiente', 'prorrogada') and vence < now() + interval '5 days'),
    'brechas', (select count(*) from public.cfx_brechas where cerrada is null), 'consent', public.cfx_consent_resumen(), 'legal', public.cfx_legal_resumen());
end $$;

revoke all on function public.cfx_agente(), public.cfx_acepta(uuid, text) from public, anon, authenticated;
revoke all on function public.cfx_consent_estado(), public.cfx_consent_guardar(text, boolean), public.cfx_consent_resumen(), public.cfx_mis_datos(),
  public.cfx_derecho_pedir(text, text), public.cfx_derechos_mios(), public.cfx_derechos_lista(boolean), public.cfx_derecho_responder(bigint, text, text),
  public.cfx_brechas_lista(), public.cfx_brecha_guardar(jsonb), public.cfx_brecha_marcar(bigint, text), public.cfx_brecha_avisar(bigint, text, text, text), public.cfx_privacidad_resumen() from public, anon;
grant execute on function public.cfx_consent_estado(), public.cfx_consent_guardar(text, boolean), public.cfx_consent_resumen(), public.cfx_mis_datos(),
  public.cfx_derecho_pedir(text, text), public.cfx_derechos_mios(), public.cfx_derechos_lista(boolean), public.cfx_derecho_responder(bigint, text, text),
  public.cfx_brechas_lista(), public.cfx_brecha_guardar(jsonb), public.cfx_brecha_marcar(bigint, text), public.cfx_brecha_avisar(bigint, text, text, text), public.cfx_privacidad_resumen() to authenticated;
-- ---------------------------------------------------------------------
-- CodeFix · Referidos (igual en las 7 apps; lo reparte nucleo/sincronizar.py). Se administra desde CM → Control → Referidos.
--   Cada usuario (negocio o cliente, nunca el admin) tiene su código. Quien se registra con él queda asociado a esa cuenta.
--   El admin ve quién invitó a quién, da días de Premium o manda un sticker de ánimo. Premio automático (opcional):
--   cuando el invitado paga su primer Premium, quien lo invitó recibe N días (cfx_config 'referidos' → dias_auto; 0 = apagado).
--   Usa lo que cada app define para los pagos: cfx_yo(), cfx_dar_premium(uuid, text, int) y cfx_avisar(uuid, text, text).
-- ---------------------------------------------------------------------
create table if not exists public.cfx_ref_codigos (cuenta uuid primary key, codigo text not null unique check (codigo ~ '^[A-Z0-9]{4,12}$'), creado timestamptz not null default now());
create table if not exists public.cfx_referidos (
  invitado uuid primary key, invito uuid not null, codigo text not null, email text not null default '', nombre text not null default '',
  creado timestamptz not null default now(), premiado boolean not null default false, dias_dados int not null default 0, stickers int not null default 0);
create index if not exists cfx_referidos_invito_idx on public.cfx_referidos (invito);
alter table public.cfx_ref_codigos enable row level security;
alter table public.cfx_referidos enable row level security;
revoke all on public.cfx_ref_codigos, public.cfx_referidos from anon, authenticated;
insert into public.cfx_config (clave, valor) values ('referidos', '{"dias_auto": 0}') on conflict (clave) do nothing;

-- Mi código para invitar (y cuántos se registraron con él). El admin no tiene.
create or replace function public.cfx_ref_mio() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); c text; i int := 0;
begin
  if y is null or y ->> 'rol' = 'admin' then return null; end if;
  select codigo into c from public.cfx_ref_codigos where cuenta = (y ->> 'id')::uuid;
  while c is null and i < 20 loop
    c := upper(left(regexp_replace(translate(coalesce(nullif(y ->> 'nombre', ''), split_part(y ->> 'email', '@', 1)), 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN'), '[^A-Za-z]', '', 'g'), 6));
    c := (case when length(c) < 2 then 'CF' else c end) || lpad((floor(random() * 10000))::int::text, 4, '0'); i := i + 1;
    begin insert into public.cfx_ref_codigos (cuenta, codigo) values ((y ->> 'id')::uuid, c); exception when unique_violation then c := null; end;
  end loop;
  return jsonb_build_object('codigo', c, 'invitados', (select count(*) from public.cfx_referidos where invito = (y ->> 'id')::uuid),
    'pagaron', (select count(*) from public.cfx_referidos r where r.invito = (y ->> 'id')::uuid and r.premiado));
end $$;
-- La cuenta nueva que llegó con un código queda asociada (una sola vez, solo en sus primeros 3 días, nunca consigo misma).
create or replace function public.cfx_ref_registrar(p_codigo text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare y jsonb := public.cfx_yo(); o uuid; quien text;
begin
  if y is null or y ->> 'rol' = 'admin' then return false; end if;
  if (select created_at from auth.users where id = (y ->> 'id')::uuid) < now() - interval '3 days' then return false; end if;
  select cuenta into o from public.cfx_ref_codigos where codigo = upper(trim(p_codigo));
  if o is null or o = (y ->> 'id')::uuid then return false; end if;
  insert into public.cfx_referidos (invitado, invito, codigo, email, nombre) values ((y ->> 'id')::uuid, o, upper(trim(p_codigo)), coalesce(y ->> 'email', ''), coalesce(y ->> 'nombre', ''))
    on conflict (invitado) do nothing;
  if not found then return false; end if;
  quien := coalesce(nullif(y ->> 'nombre', ''), split_part(y ->> 'email', '@', 1));
  perform public.cfx_avisar(o, '🎉 ' || quien || ' se registró con tu código', 'Gracias por recomendarnos. ¡Sigue invitando!');
  return true;
end $$;
-- Panel: quién invitó a quién (con correo de ambos), si el invitado ya pagó y lo que se le ha dado a quien invitó.
create or replace function public.cfx_ref_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object('config', (select valor from public.cfx_config where clave = 'referidos'), 'filas', coalesce((select jsonb_agg(x order by x.creado desc) from (
    select r.invitado, r.email, r.nombre, r.creado, r.codigo, r.invito, u.email invito_email, r.premiado, r.dias_dados, r.stickers,
      exists (select 1 from public.cfx_pagos g where g.cuenta = r.invitado and g.estado = 'aprobado') pago
    from public.cfx_referidos r left join auth.users u on u.id = r.invito limit 1000) x), '[]'));
end $$;
-- Dar días de Premium y/o mandar un sticker (mensaje de ánimo) a quien invita.
create or replace function public.cfx_ref_premiar(p_cuenta uuid, p_dias int default 0, p_mensaje text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare hasta timestamptz; d int := greatest(0, least(coalesce(p_dias, 0), 365)); n int;
begin
  perform public.cfx_es_admin();
  select count(*) into n from public.cfx_referidos where invito = p_cuenta;
  if n = 0 then raise exception 'Esa cuenta no ha invitado a nadie'; end if;
  if d > 0 then
    hasta := public.cfx_dar_premium(p_cuenta, 'otro', d);
    update public.cfx_referidos set dias_dados = dias_dados + d where invitado = (select invitado from public.cfx_referidos where invito = p_cuenta order by creado desc limit 1);
  end if;
  if coalesce(trim(p_mensaje), '') <> '' or d > 0 then
    perform public.cfx_avisar(p_cuenta, left(coalesce(nullif(trim(p_mensaje), ''), '🏆 ¡Gracias por invitar!'), 90),
      case when d > 0 then '🎁 Te regalamos ' || d || ' días de Premium por recomendarnos (' || n || ' invitado' || case when n > 1 then 's' else '' end || ').' else 'Vas en ' || n || ' invitado' || case when n > 1 then 's' else '' end || '. ¡Sigue así!' end);
    update public.cfx_referidos set stickers = stickers + 1 where invitado = (select invitado from public.cfx_referidos where invito = p_cuenta order by creado desc limit 1);
  end if;
  perform public.cfx_anotar('referido', 'premio a ' || coalesce((select email from auth.users where id = p_cuenta), p_cuenta::text) || ': ' || d || ' días');
  return jsonb_build_object('dias', d, 'hasta', hasta);
end $$;
create or replace function public.cfx_ref_config_guardar(p_dias_auto int) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  insert into public.cfx_config (clave, valor) values ('referidos', jsonb_build_object('dias_auto', greatest(0, least(coalesce(p_dias_auto, 0), 365))))
    on conflict (clave) do update set valor = excluded.valor;
  return (select valor from public.cfx_config where clave = 'referidos');
end $$;
-- Premio automático: al aprobarse el primer pago del invitado, quien lo invitó recibe dias_auto días (una sola vez por invitado).
create or replace function public.cfx_ref_al_pagar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r public.cfx_referidos; d int := coalesce(((select valor from public.cfx_config where clave = 'referidos') ->> 'dias_auto')::int, 0);
begin
  if new.estado <> 'aprobado' or old.estado = 'aprobado' then return new; end if;
  select * into r from public.cfx_referidos where invitado = new.cuenta and not premiado for update;
  if r.invitado is null then return new; end if;
  update public.cfx_referidos set premiado = true, dias_dados = dias_dados + case when d > 0 then d else 0 end where invitado = r.invitado;
  if d > 0 then
    perform public.cfx_dar_premium(r.invito, 'otro', d);
    perform public.cfx_avisar(r.invito, '🎁 ¡Ganaste ' || d || ' días de Premium!', coalesce(nullif(r.nombre, ''), split_part(r.email, '@', 1)) || ' pagó su Premium gracias a tu invitación.');
  end if;
  return new;
end $$;
drop trigger if exists cfx_ref_al_pagar on public.cfx_pagos;
create trigger cfx_ref_al_pagar after update of estado on public.cfx_pagos for each row execute function public.cfx_ref_al_pagar();
revoke all on function public.cfx_ref_al_pagar() from public, anon, authenticated;
revoke all on function public.cfx_ref_mio(), public.cfx_ref_registrar(text), public.cfx_ref_lista(), public.cfx_ref_premiar(uuid, int, text), public.cfx_ref_config_guardar(int) from public, anon;
grant execute on function public.cfx_ref_mio(), public.cfx_ref_registrar(text), public.cfx_ref_lista(), public.cfx_ref_premiar(uuid, int, text), public.cfx_ref_config_guardar(int) to authenticated;

-- ---------------------------------------------------------------------
-- CodeFix · Socios comunes (lo reparte nucleo/sincronizar.py). Los usan Billetera, Órbita y Estaciona (las otras apps tienen
-- sus propios socios). El socio entra con su correo y administra igual que el admin (cada app lo reconoce en su función de
-- administrador), pero solo el administrador dueño agrega o quita socios (CM → Control → 🤝 Socios). Lo que hace queda en el registro.
-- ---------------------------------------------------------------------
create table if not exists public.cfx_socios (email text primary key check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  nombre text not null default '' check (length(nombre) <= 60), creado timestamptz not null default now());
alter table public.cfx_socios enable row level security;
revoke all on public.cfx_socios from anon, authenticated;
create or replace function public.cfx_es_socio() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from public.cfx_socios s join auth.users u on lower(u.email) = s.email where u.id = auth.uid())
$$;
create or replace function public.cfx_socios_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('email', s.email, 'nombre', s.nombre, 'creado', s.creado, 'tiene_cuenta', exists (select 1 from auth.users u where lower(u.email) = s.email)) order by s.creado) from public.cfx_socios s), '[]');
end $$;
create or replace function public.cfx_socio_guardar(p_email text, p_nombre text default '', p_si boolean default true) returns void
language plpgsql security definer set search_path = '' as $$
declare e text := lower(trim(p_email));
begin
  perform public.cfx_es_admin();
  if public.cfx_es_socio() then raise exception 'Solo el administrador agrega o quita socios'; end if;
  if coalesce(p_si, true) then
    insert into public.cfx_socios (email, nombre) values (e, left(coalesce(trim(p_nombre), ''), 60)) on conflict (email) do update set nombre = excluded.nombre;
    perform public.cfx_anotar('socio', 'agregó a ' || e);
  else
    delete from public.cfx_socios where email = e;
    perform public.cfx_anotar('socio', 'quitó a ' || e);
  end if;
end $$;
revoke all on function public.cfx_es_socio(), public.cfx_socios_lista(), public.cfx_socio_guardar(text, text, boolean) from public, anon;
grant execute on function public.cfx_es_socio(), public.cfx_socios_lista(), public.cfx_socio_guardar(text, text, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- CodeFix · Inventario (igual en las 6 apps; lo usa el Centro de Mando → Apps → Respaldo y limpieza).
--   Muestra las tablas que esta versión ya NO usa (restos de versiones antiguas) con cuántas filas tienen.
--   Nada se borra solo: las vacías se borran con un toque; las que tienen datos piden descargar el respaldo y escribir "sí".
--   cfx_tablas() = las tablas que crea este archivo (la revisa pruebas/inventario.py --verificar).
-- ---------------------------------------------------------------------
create or replace function public.cfx_tablas() returns text[] language sql immutable as $$ select array['public.ajustes', 'public.arriendos', 'public.bloqueos', 'public.calificaciones', 'public.cfx_analisis', 'public.cfx_bloqueos', 'public.cfx_brechas', 'public.cfx_calificaciones', 'public.cfx_cargas', 'public.cfx_carritos', 'public.cfx_chat', 'public.cfx_config', 'public.cfx_consent', 'public.cfx_consent_hist', 'public.cfx_cupones', 'public.cfx_derechos', 'public.cfx_descuentos', 'public.cfx_errores', 'public.cfx_exentos', 'public.cfx_keys', 'public.cfx_legal', 'public.cfx_login_fallos', 'public.cfx_login_qr', 'public.cfx_mensajes', 'public.cfx_modulos_negocio', 'public.cfx_modulos_pruebas', 'public.cfx_pagos', 'public.cfx_pin', 'public.cfx_ref_codigos', 'public.cfx_referidos', 'public.cfx_registro', 'public.cfx_reportes', 'public.cfx_salud', 'public.cfx_secretos', 'public.cfx_sellos', 'public.cfx_sellos_cfg', 'public.cfx_socios', 'public.cfx_verificaciones', 'public.cfx_versiones', 'public.config', 'public.conversaciones', 'public.denuncias', 'public.estacionamientos', 'public.favoritos', 'public.licencias', 'public.links_pago', 'public.mensajes', 'public.notificaciones', 'public.pagos', 'public.perfiles', 'public.planes', 'public.por_borrar', 'public.push_subs', 'public.textos', 'public.verificaciones'] $$;
create or replace function public.cfx_inventario() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; n bigint; out jsonb := '[]'::jsonb;
begin
  perform public.cfx_es_admin();
  for r in select s.nspname || '.' || c.relname as t, pg_total_relation_size(c.oid) as b from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname in ('public', 'privado') and c.relkind in ('r', 'p') and not (s.nspname || '.' || c.relname = any (public.cfx_tablas()))
           and not exists (select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by 1
  loop
    execute 'select count(*) from ' || r.t into n;
    out := out || jsonb_build_object('tabla', r.t, 'filas', n, 'bytes', r.b);
  end loop;
  return out;
end $$;
create or replace function public.cfx_inventario_datos(p_tabla text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare j jsonb;
begin
  perform public.cfx_es_admin();
  if not exists (select 1 from jsonb_array_elements(public.cfx_inventario()) x where x ->> 'tabla' = p_tabla) then raise exception 'Esa tabla no está en la lista de sobrantes'; end if;
  execute 'select coalesce(jsonb_agg(to_jsonb(t)), ''[]'') from (select * from ' || p_tabla || ' limit 20000) t' into j;
  return j;
end $$;
create or replace function public.cfx_inventario_borrar(p_tabla text, p_confirmacion text default '') returns text
language plpgsql security definer set search_path = '' as $$
declare x jsonb;
begin
  perform public.cfx_es_admin();
  select e into x from jsonb_array_elements(public.cfx_inventario()) e where e ->> 'tabla' = p_tabla;
  if x is null then raise exception 'Esa tabla no está en la lista de sobrantes'; end if;
  if (x ->> 'filas')::bigint > 0 and lower(trim(coalesce(p_confirmacion, ''))) not in ('sí', 'si') then
    raise exception 'La tabla tiene % filas: descarga el respaldo y escribe "sí" para borrarla', x ->> 'filas';
  end if;
  execute 'drop table ' || p_tabla || ' cascade';
  return p_tabla || ' borrada';
end $$;
revoke all on function public.cfx_tablas(), public.cfx_inventario(), public.cfx_inventario_datos(text), public.cfx_inventario_borrar(text, text) from public, anon;
grant execute on function public.cfx_inventario(), public.cfx_inventario_datos(text), public.cfx_inventario_borrar(text, text) to authenticated;

-- ---------- Salud (G8): errores de la app en los teléfonos, ping anti-pausa y último respaldo ----------
-- Errores: carga.js manda cada error de JavaScript (agrupado por mensaje + lugar). Se guardan hasta 300 distintos y 30 días.
create table if not exists public.cfx_errores (
  id bigint generated always as identity primary key, firma text not null unique, mensaje text not null, donde text not null default '',
  pagina text not null default '', navegador text not null default '', version text not null default '', veces int not null default 1,
  con_cuenta boolean not null default false, creado timestamptz not null default now(), ultimo timestamptz not null default now());
-- Salud: 'ping' (lo toca GitHub Actions para que Supabase no pause la base) y 'respaldo' (lo anota el respaldo diario).
create table if not exists public.cfx_salud (clave text primary key, valor jsonb not null default '{}', cuando timestamptz not null default now());
-- B13 Carga real: cuánto demora en abrir cada página en los teléfonos (carga.js, 1 vez por página y sesión). Por día y página; 30 días.
create table if not exists public.cfx_cargas (dia date not null default current_date, pagina text not null, veces int not null default 0, ms bigint not null default 0,
  lcp bigint not null default 0, con_lcp int not null default 0, lentas int not null default 0, cache int not null default 0, primary key (dia, pagina));
alter table public.cfx_cargas enable row level security;
revoke all on public.cfx_cargas from anon, authenticated;
alter table public.cfx_errores enable row level security;
alter table public.cfx_salud enable row level security;
revoke all on public.cfx_errores, public.cfx_salud from anon, authenticated;

-- Sin cuenta también (el error puede pasar antes de entrar). Sin captcha: no crea cuentas ni avisa a nadie,
-- se agrupa por firma, tiene tope de filas y de veces, y se borra solo a los 30 días.
create or replace function public.cfx_error_anotar(p_mensaje text, p_donde text default '', p_pagina text default '', p_navegador text default '', p_version text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare m text := left(coalesce(p_mensaje, ''), 300); d text := left(coalesce(p_donde, ''), 600); f text;
begin
  if m = '' then return; end if;
  f := md5(m || '|' || split_part(d, E'\n', 1));
  update public.cfx_errores set veces = least(veces + 1, 1000000), ultimo = now(), pagina = left(coalesce(p_pagina, ''), 200),
    navegador = left(coalesce(p_navegador, ''), 120), version = left(coalesce(p_version, ''), 20), con_cuenta = con_cuenta or auth.uid() is not null
    where firma = f and ultimo < now() - interval '2 seconds';
  if found or exists (select 1 from public.cfx_errores where firma = f) then return; end if;
  delete from public.cfx_errores where ultimo < now() - interval '30 days';
  if (select count(*) from public.cfx_errores) >= 300 then return; end if;
  insert into public.cfx_errores (firma, mensaje, donde, pagina, navegador, version, con_cuenta)
    values (f, m, d, left(coalesce(p_pagina, ''), 200), left(coalesce(p_navegador, ''), 120), left(coalesce(p_version, ''), 20), auth.uid() is not null)
    on conflict (firma) do nothing;
end $$;
grant execute on function public.cfx_error_anotar(text, text, text, text, text) to anon, authenticated;

-- B13: sin cuenta también (la vitrina la abren clientes sin cuenta). Valores acotados, máximo 40 páginas por día y 1 fila por día y página.
create or replace function public.cfx_carga_anotar(p_pagina text, p_ms int, p_lcp int default null, p_cache boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare pg text := left(regexp_replace(lower(coalesce(p_pagina, '')), '[^a-z0-9/_.-]', '', 'g'), 60); m int := least(greatest(coalesce(p_ms, 0), 0), 60000);
  l int := least(greatest(coalesce(p_lcp, 0), 0), 60000);
begin
  if pg = '' or m = 0 then return; end if;
  if not exists (select 1 from public.cfx_cargas where dia = current_date and pagina = pg) then
    if (select count(*) from public.cfx_cargas where dia = current_date) >= 40 then return; end if;
    delete from public.cfx_cargas where dia < current_date - 30;
  end if;
  insert into public.cfx_cargas as c (dia, pagina, veces, ms, lcp, con_lcp, lentas, cache)
    values (current_date, pg, 1, m, l, (l > 0)::int, (m > 3000)::int, coalesce(p_cache, false)::int)
    on conflict (dia, pagina) do update set veces = c.veces + 1, ms = c.ms + excluded.ms, lcp = c.lcp + excluded.lcp, con_lcp = c.con_lcp + excluded.con_lcp,
      lentas = c.lentas + excluded.lentas, cache = c.cache + excluded.cache
    where c.veces < 100000;
end $$;
revoke all on function public.cfx_carga_anotar(text, int, int, boolean) from public;
grant execute on function public.cfx_carga_anotar(text, int, int, boolean) to anon, authenticated;

-- Marca de salud (solo la base: GitHub Actions la llama con la conexión del respaldo; ping la usa por dentro).
create or replace function public.cfx_salud_marca(p_clave text, p_valor jsonb default '{}') returns void
language sql security definer set search_path = '' as $$
  insert into public.cfx_salud (clave, valor, cuando) values (left(p_clave, 40), coalesce(p_valor, '{}'), now())
  on conflict (clave) do update set valor = excluded.valor, cuando = now()
$$;
revoke all on function public.cfx_salud_marca(text, jsonb) from public, anon, authenticated;

-- Ping anti-pausa: el plan gratis de Supabase pausa la base tras 7 días sin uso. GitHub Actions (SaaS: salud.yml) lo llama cada día.
create or replace function public.cfx_ping() returns text
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce((select cuando from public.cfx_salud where clave = 'ping'), '-infinity') < now() - interval '10 minutes' then
    perform public.cfx_salud_marca('ping', '{}');
  end if;
  return 'ok';
end $$;
grant execute on function public.cfx_ping() to anon, authenticated;

-- Centro de Mando → Control → 🩺 Salud.
create or replace function public.cfx_salud() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object(
    'ping', (select cuando from public.cfx_salud where clave = 'ping'),
    'respaldo', (select valor || jsonb_build_object('cuando', cuando) from public.cfx_salud where clave = 'respaldo'),
    'analisis', (select valor || jsonb_build_object('cuando', cuando) from public.cfx_salud where clave = 'analisis'),
    'carga', coalesce((select jsonb_agg(c order by c.veces desc) from (select pagina, sum(veces)::int veces, (sum(ms) / nullif(sum(veces), 0))::int ms,
        (sum(lcp) / nullif(sum(con_lcp), 0))::int lcp, sum(lentas)::int lentas, sum(cache)::int cache
      from public.cfx_cargas where dia > current_date - 7 group by pagina order by sum(veces) desc limit 20) c), '[]'),
    'errores_24h', (select coalesce(sum(veces), 0) from public.cfx_errores where ultimo > now() - interval '24 hours'),
    'errores', coalesce((select jsonb_agg(to_jsonb(e) - 'firma' order by e.ultimo desc) from (select * from public.cfx_errores order by ultimo desc limit 100) e), '[]'));
end $$;
revoke all on function public.cfx_salud() from public, anon;
grant execute on function public.cfx_salud() to authenticated;

create or replace function public.cfx_errores_borrar(p_id bigint default null) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  perform public.cfx_es_admin();
  delete from public.cfx_errores where p_id is null or id = p_id;
  get diagnostics n = row_count;
  perform public.cfx_anotar('errores borrados', case when p_id is null then 'todos (' || n || ')' else '#' || p_id end);
  return n;
end $$;
revoke all on function public.cfx_errores_borrar(bigint) from public, anon;
grant execute on function public.cfx_errores_borrar(bigint) to authenticated;
-- ---------- Módulos enchufables (C19): se prenden y apagan desde el Centro de Mando → Mis aplicaciones → 🧩 Módulos ----------
-- Cada app dice qué módulos tiene con el gancho cfx_modulos_app() → text[] (si no lo tiene: ninguno). Por defecto quedan prendidos.
insert into public.cfx_config (clave, valor) values ('modulos', '{}') on conflict (clave) do nothing;

create or replace function public.cfx_modulos_de_app() returns text[]
language plpgsql stable security definer set search_path = '' as $$
declare r text[];
begin
  if to_regprocedure('public.cfx_modulos_app()') is null then return '{}'; end if;
  execute 'select public.cfx_modulos_app()' into r;
  return coalesce(r, '{}');
end $$;

create or replace function public.cfx_modulo(p_clave text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  return p_clave = any(public.cfx_modulos_de_app())
    and coalesce(((select valor from public.cfx_config where clave = 'modulos') ->> p_clave)::boolean, true);
end $$;

-- Para la app (esconde lo apagado): {"chat": true, ...}. Un negocio (o su equipo) ve lo que tiene activo (G19: módulos de pago).
create or replace function public.cfx_modulos() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare n uuid := public.cfx_negocio_cuenta(auth.uid());
begin
  if n is not null and coalesce((public.cfx_venta() ->> 'activo')::boolean, false) then return public.cfx_modulos_de(n); end if;
  return coalesce((select jsonb_object_agg(k, public.cfx_modulo(k)) from unnest(public.cfx_modulos_de_app()) k), '{}');
end $$;

-- Para el Centro de Mando: con nombre y para qué sirve.
create or replace function public.cfx_modulos_admin() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('clave', k, 'nombre', coalesce(c.nombre, k), 'detalle', coalesce(c.detalle, ''),
      'activo', public.cfx_modulo(k), 'precio', public.cfx_venta_precio(k),
      'negocios', (select count(*) from public.cfx_modulos_negocio m where m.modulo = k and m.hasta > now())) order by o)
    from unnest(public.cfx_modulos_de_app()) with ordinality u(k, o)
    left join public.cfx_modulos_catalogo() c on c.clave = k), '[]');
end $$;

create or replace function public.cfx_modulo_guardar(p_clave text, p_activo boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  if not coalesce(p_clave = any(public.cfx_modulos_de_app()), false) then raise exception 'Esta app no tiene ese módulo'; end if;
  insert into public.cfx_config (clave, valor) values ('modulos', jsonb_build_object(p_clave, coalesce(p_activo, true)))
  on conflict (clave) do update set valor = public.cfx_config.valor || excluded.valor;
  perform public.cfx_anotar('módulo', p_clave || case when coalesce(p_activo, true) then ' prendido' else ' apagado' end);
  return public.cfx_modulos_admin();
end $$;

revoke all on function public.cfx_modulos_de_app(), public.cfx_modulo(text) from public, anon, authenticated;
revoke all on function public.cfx_modulos(), public.cfx_modulos_admin(), public.cfx_modulo_guardar(text, boolean) from public, anon;
grant execute on function public.cfx_modulos() to anon, authenticated;
grant execute on function public.cfx_modulos_admin(), public.cfx_modulo_guardar(text, boolean) to authenticated;
-- ---------- Módulos de pago por negocio (G19) ----------
-- Cada negocio compra (o prueba 7 días) los módulos que quiere, sea Free o Premium. Se venden sueltos o en packs
-- (Básico, Crecer, Completo). Si "Vender módulos" está apagado en esta app (Centro de Mando → Apps → 🧩), todo sigue como antes:
-- el módulo prendido sirve a todos. Precio 0 = incluido gratis para todos.
-- Gancho opcional de la app: cfx_negocio_cuenta(uuid) → el negocio de esa cuenta (dueño o su equipo); null = no es negocio.
--                            cfx_es_premium(uuid) → si el negocio tiene Premium (descuento en módulos).
create table if not exists public.cfx_modulos_negocio (
  negocio uuid not null,
  modulo  text not null check (modulo ~ '^[a-z_]{2,30}$'),
  hasta   timestamptz not null,
  origen  text not null default 'pago' check (origen in ('prueba', 'pago', 'regalo')),
  avisado timestamptz,
  creado  timestamptz not null default now(),
  primary key (negocio, modulo)
);
create index if not exists cfx_modulos_negocio_hasta_idx on public.cfx_modulos_negocio (hasta);
create table if not exists public.cfx_modulos_pruebas (
  negocio uuid not null,
  item    text not null,
  creado  timestamptz not null default now(),
  primary key (negocio, item)
);
alter table public.cfx_modulos_negocio enable row level security;
alter table public.cfx_modulos_pruebas enable row level security;
revoke all on public.cfx_modulos_negocio, public.cfx_modulos_pruebas from anon, authenticated;

-- Precios en pesos al mes. Anual = 10 meses (2 de regalo). Premium paga 20 % menos en módulos y packs.
insert into public.cfx_config (clave, valor) values ('modulos_venta', jsonb_build_object(
  'activo', false, 'prueba_dias', 7, 'descuento_premium', 20, 'anual_meses', 10, 'precio', 990, 'precios', '{}'::jsonb, 'links', '{}'::jsonb,
  'packs', jsonb_build_object(
    'basico',   jsonb_build_object('nombre', '🌱 Básico',   'detalle', 'Para que vuelvan a comprarte', 'precio', 1990, 'modulos', jsonb_build_array('cupones', 'sellos', 'calificaciones')),
    'crecer',   jsonb_build_object('nombre', '🚀 Crecer',   'detalle', 'Vende más todos los días', 'precio', 2990, 'destacado', true,
                                   'modulos', jsonb_build_array('cupones', 'sellos', 'calificaciones', 'chat', 'carrito', 'redes', 'estadisticas')),
    'completo', jsonb_build_object('nombre', '💎 Completo', 'detalle', 'Todos los módulos, también los nuevos', 'precio', 3990, 'modulos', '*'))))
on conflict (clave) do nothing;

-- Nombre y para qué sirve cada módulo (lo usan el Centro de Mando y la pantalla 🧩 Módulos del negocio).
create or replace function public.cfx_modulos_catalogo() returns table (clave text, nombre text, detalle text)
language sql immutable as $$
  values ('chat', '💬 Chat', 'Conversa con tus clientes dentro de la app, con límites contra el spam.'),
         ('calificaciones', '⭐ Calificaciones', 'Tus clientes te califican y tú a ellos: más confianza para comprar.'),
         ('cupones', '🏷️ Cupones', 'Crea códigos de descuento para tus clientes.'),
         ('sellos', '🎟️ Tarjeta de sellos', 'Cada compra suma un sello; al completar la meta, premio.'),
         ('carrito', '🛒 Recordar carrito', 'Si un cliente deja productos en el carrito, al día siguiente le llega un aviso.'),
         ('analisis', '🔎 Para vender más', 'Cada noche: clientes en riesgo, productos quietos, stock que se acaba y grupos de clientes.'),
         ('estadisticas', '📈 Estadísticas', 'Ventas, productos que más dejan y gráficos en vivo.'),
         ('equipo', '🧑‍🍳 Mi equipo', 'Suma vendedores y bodega con su propia cuenta y permisos.'),
         ('campanas', '📣 Campañas automáticas', 'Ofertas por notificación y correo a tus suscriptores.'),
         ('redes', '📲 Vender en redes', 'Pedir por WhatsApp, catálogo para Google e Instagram.'),
         ('webhooks', '🔗 Avisos a tu sistema', 'Cada pedido llega firmado a tu sistema o planilla (webhooks).'),
         ('medicion', '📊 Medir anuncios', 'Meta Pixel y Google Analytics en tu tienda: mide qué anuncio te trae ventas.'),
         ('dominio', '🌐 Dominio propio', 'Tu tienda en tu dirección (mitienda.cl) en vez del link de Despega Pyme.'),
         ('reservas', '📅 Reservas', 'Agenda en línea para tus clientes.'),
         ('recordatorios', '⏰ Recordatorios', 'Avisos automáticos antes de cada cita o vencimiento.')
$$;

create or replace function public.cfx_venta() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select valor from public.cfx_config where clave = 'modulos_venta'), '{}'::jsonb)
$$;
-- Precio al mes de un módulo o pack (0 = incluido gratis).
create or replace function public.cfx_venta_precio(p_item text) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce((v #>> array['packs', p_item, 'precio'])::int, (v #>> array['precios', p_item])::int, (v ->> 'precio')::int, 0)
  from (select public.cfx_venta() v) x
$$;
-- ¿Está prendida la venta de módulos en esta app? (si no, todo funciona como antes del G19)
create or replace function public.cfx_venta_on() returns boolean
language sql stable security definer set search_path = '' as $$ select coalesce((public.cfx_venta() ->> 'activo')::boolean, false) $$;
-- ¿Este módulo se vende aparte en esta app? (venta prendida y precio > 0)
create or replace function public.cfx_venta_activa(p_modulo text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.cfx_venta_on() and p_modulo = any(public.cfx_modulos_de_app()) and public.cfx_venta_precio(p_modulo) > 0
$$;
-- Módulos que trae un pack ('*' = todos los de la app) o el módulo mismo.
create or replace function public.cfx_venta_modulos(p_item text) returns text[]
language plpgsql stable security definer set search_path = '' as $$
declare p jsonb := public.cfx_venta() #> array['packs', p_item];
begin
  if p is null then return case when p_item = any(public.cfx_modulos_de_app()) then array[p_item] else '{}'::text[] end; end if;
  if p ->> 'modulos' = '*' then return public.cfx_modulos_de_app(); end if;
  return array(select x from jsonb_array_elements_text(coalesce(p -> 'modulos', '[]')) x where x = any(public.cfx_modulos_de_app()));
end $$;

create or replace function public.cfx_negocio_cuenta(p_cuenta uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare n uuid;
begin
  if p_cuenta is null then return null; end if;
  if to_regprocedure('public.cfx_negocio_de_cuenta(uuid)') is not null then execute 'select public.cfx_negocio_de_cuenta($1)' into n using p_cuenta;
  elsif to_regprocedure('public.cfx_analisis_negocio(uuid)') is not null then execute 'select public.cfx_analisis_negocio($1)' into n using p_cuenta;
  else n := p_cuenta; end if;
  return n;
end $$;
create or replace function public.cfx_negocio_premium(p_negocio uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare r boolean;
begin
  if p_negocio is null or to_regprocedure('public.cfx_es_premium(uuid)') is null then return false; end if;
  execute 'select public.cfx_es_premium($1)' into r using p_negocio;
  return coalesce(r, false);
end $$;

-- ¿El negocio puede usar el módulo ahora? (prendido en la app + comprado, en prueba, regalado o incluido gratis)
create or replace function public.cfx_modulo_de(p_modulo text, p_negocio uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.cfx_modulo(p_modulo) and (not public.cfx_venta_activa(p_modulo)
    or exists (select 1 from public.cfx_modulos_negocio m where m.negocio = p_negocio and m.modulo = p_modulo and m.hasta > now()))
$$;
create or replace function public.cfx_modulo_mio(p_modulo text) returns boolean
language sql stable security definer set search_path = '' as $$ select public.cfx_modulo_de(p_modulo, public.cfx_negocio_cuenta(auth.uid())) $$;

-- Lo que puede usar cada negocio: {"chat": true, ...}. Para una tienda que ve un cliente.
create or replace function public.cfx_modulos_de(p_negocio uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_object_agg(k, public.cfx_modulo_de(k, p_negocio)) from unnest(public.cfx_modulos_de_app()) k), '{}')
$$;

-- Activa (o alarga) los módulos de un item por N días; N <= 0 los quita. Devuelve hasta cuándo.
create or replace function public.cfx_modulos_dar(p_negocio uuid, p_item text, p_dias int, p_origen text default 'pago') returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare k text; h timestamptz; mx timestamptz;
begin
  if p_negocio is null or cardinality(public.cfx_venta_modulos(p_item)) = 0 then raise exception 'Módulo no válido'; end if;
  foreach k in array public.cfx_venta_modulos(p_item) loop
    if coalesce(p_dias, 0) <= 0 then delete from public.cfx_modulos_negocio where negocio = p_negocio and modulo = k; continue; end if;
    insert into public.cfx_modulos_negocio as m (negocio, modulo, hasta, origen) values (p_negocio, k, now() + make_interval(days => p_dias), p_origen)
    on conflict (negocio, modulo) do update set hasta = greatest(m.hasta, now()) + make_interval(days => p_dias),
      origen = case when excluded.origen = 'prueba' then m.origen else excluded.origen end, avisado = null
    returning hasta into h;
    mx := greatest(mx, h);
  end loop;
  return mx;
end $$;

-- Pantalla 🧩 Módulos del negocio: catálogo, precios (con su descuento Premium), lo que tiene y hasta cuándo.
create or replace function public.cfx_modulos_tienda() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v jsonb := public.cfx_venta(); n uuid := public.cfx_negocio_cuenta(auth.uid()); pre boolean; d int; am int;
begin
  if n is null then raise exception 'Solo para negocios'; end if;
  pre := public.cfx_negocio_premium(n);
  d := case when pre then greatest(0, least(90, coalesce((v ->> 'descuento_premium')::int, 0))) else 0 end;
  am := greatest(1, least(12, coalesce((v ->> 'anual_meses')::int, 10)));
  return jsonb_build_object('activo', coalesce((v ->> 'activo')::boolean, false), 'premium', pre, 'descuento', d, 'anual_meses', am,
    'descuento_pro', case when pre then 0 else greatest(0, least(90, coalesce((v ->> 'descuento_premium')::int, 0))) end,
    'prueba_dias', coalesce((v ->> 'prueba_dias')::int, 7), 'dueno', n = auth.uid(),
    'prueba_pack', exists (select 1 from public.cfx_modulos_pruebas p where p.negocio = n and p.item like 'pack:%'),
    'modulos', coalesce((select jsonb_agg(jsonb_build_object('clave', k, 'nombre', coalesce(c.nombre, k), 'detalle', coalesce(c.detalle, ''),
        'precio', round(public.cfx_venta_precio(k) * (100 - d) / 100.0)::int, 'lista', public.cfx_venta_precio(k),
        'vende', public.cfx_venta_activa(k), 'activo', public.cfx_modulo_de(k, n),
        'hasta', m.hasta, 'origen', m.origen, 'prueba_usada', exists (select 1 from public.cfx_modulos_pruebas p where p.negocio = n and p.item = k),
        'links', v #> array['links', k]) order by o)
      from unnest(public.cfx_modulos_de_app()) with ordinality u(k, o)
      left join public.cfx_modulos_catalogo() c on c.clave = k
      left join public.cfx_modulos_negocio m on m.negocio = n and m.modulo = k
      where public.cfx_modulo(k)), '[]'),
    'packs', coalesce((select jsonb_agg(jsonb_build_object('clave', p.key, 'nombre', p.value ->> 'nombre', 'detalle', coalesce(p.value ->> 'detalle', ''),
        'destacado', coalesce((p.value ->> 'destacado')::boolean, false), 'modulos', to_jsonb(public.cfx_venta_modulos(p.key)),
        'precio', round(coalesce((p.value ->> 'precio')::int, 0) * (100 - d) / 100.0)::int, 'lista', coalesce((p.value ->> 'precio')::int, 0),
        'suelto', (select coalesce(sum(public.cfx_venta_precio(x)), 0) from unnest(public.cfx_venta_modulos(p.key)) x),
        'links', v #> array['links', p.key]) order by coalesce((p.value ->> 'precio')::int, 0))
      from jsonb_each(coalesce(v -> 'packs', '{}')) p where cardinality(public.cfx_venta_modulos(p.key)) > 0), '[]'));
end $$;

-- Probar gratis: cada módulo una vez, y un solo pack por negocio. Solo el dueño.
create or replace function public.cfx_modulo_probar(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := public.cfx_venta(); n uuid := public.cfx_negocio_cuenta(auth.uid()); pack boolean := (public.cfx_venta() #> array['packs', p_item]) is not null;
        dias int := greatest(1, least(30, coalesce((v ->> 'prueba_dias')::int, 7))); h timestamptz;
begin
  if n is null or n <> auth.uid() then raise exception 'Solo el dueño del negocio'; end if;
  if not coalesce((v ->> 'activo')::boolean, false) or cardinality(public.cfx_venta_modulos(p_item)) = 0 then raise exception 'Módulo no válido'; end if;
  if pack and exists (select 1 from public.cfx_modulos_pruebas where negocio = n and item like 'pack:%') then raise exception 'Ya usaste la prueba gratis de un pack'; end if;
  if not pack and exists (select 1 from public.cfx_modulos_pruebas where negocio = n and item = p_item) then raise exception 'Ya usaste la prueba gratis de este módulo'; end if;
  if not pack and public.cfx_modulo_de(p_item, n) then raise exception 'Ya tienes este módulo activo'; end if;
  insert into public.cfx_modulos_pruebas (negocio, item) values (n, case when pack then 'pack:' || p_item else p_item end);
  -- La prueba no alarga lo que ya está pagado: solo prende lo que no tiene.
  insert into public.cfx_modulos_negocio as m (negocio, modulo, hasta, origen)
  select n, k, now() + make_interval(days => dias), 'prueba' from unnest(public.cfx_venta_modulos(p_item)) k
  on conflict (negocio, modulo) do update set hasta = greatest(m.hasta, excluded.hasta), origen = case when m.hasta > now() then m.origen else 'prueba' end, avisado = null;
  select max(hasta) into h from public.cfx_modulos_negocio where negocio = n and modulo = any(public.cfx_venta_modulos(p_item));
  perform public.cfx_anotar('módulo', 'prueba ' || p_item || ' · ' || n);
  return jsonb_build_object('ok', true, 'hasta', h);
end $$;

-- Aviso 3 días antes de que venza (una vez por vencimiento). Lo corre el cron diario.
create or replace function public.cfx_modulos_avisar() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; c int := 0;
begin
  for r in select m.negocio, min(m.hasta) hasta, string_agg(coalesce(k.nombre, m.modulo), ', ' order by m.modulo) nombres
           from public.cfx_modulos_negocio m left join public.cfx_modulos_catalogo() k on k.clave = m.modulo
           where m.avisado is null and m.hasta between now() and now() + interval '3 days' group by m.negocio limit 500 loop
    perform public.cfx_avisar(r.negocio, '🧩 Tus módulos vencen pronto', left(r.nombres, 120) || ' · vence el ' ||
      to_char(r.hasta at time zone 'America/Santiago', 'DD/MM') || '. Renuévalos en Ajustes → 🧩 Módulos y no pierdes nada.');
    update public.cfx_modulos_negocio set avisado = now() where negocio = r.negocio and avisado is null and hasta between now() and now() + interval '3 days';
    c := c + 1;
  end loop;
  return c;
end $$;

-- Al borrar un negocio (lo llama la app): sus módulos y sus pruebas.
create or replace function public.cfx_modulos_borrar(p_negocio uuid) returns void
language sql security definer set search_path = '' as $$
  delete from public.cfx_modulos_negocio where negocio = p_negocio;
  delete from public.cfx_modulos_pruebas where negocio = p_negocio;
$$;

-- ---------- Centro de Mando ----------
create or replace function public.cfx_venta_admin() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object('config', public.cfx_venta(), 'app', to_jsonb(public.cfx_modulos_de_app()),
    'catalogo', (select coalesce(jsonb_agg(jsonb_build_object('clave', c.clave, 'nombre', c.nombre)), '[]') from public.cfx_modulos_catalogo() c where c.clave = any(public.cfx_modulos_de_app())),
    'activos', (select count(distinct negocio) from public.cfx_modulos_negocio where hasta > now() and origen = 'pago'),
    'pruebas', (select count(distinct negocio) from public.cfx_modulos_negocio where hasta > now() and origen = 'prueba'),
    'negocios', coalesce((select jsonb_agg(x order by x.hasta) from (
      select m.negocio, coalesce((select u.email from auth.users u where u.id = m.negocio), '') email, min(m.hasta) hasta,
        jsonb_agg(jsonb_build_object('modulo', m.modulo, 'hasta', m.hasta, 'origen', m.origen) order by m.modulo) modulos
      from public.cfx_modulos_negocio m where m.hasta > now() - interval '30 days' group by m.negocio limit 300) x), '[]'));
end $$;

create or replace function public.cfx_venta_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := public.cfx_venta(); l record; u record;
begin
  perform public.cfx_es_admin();
  if jsonb_typeof(p) <> 'object' then raise exception 'Datos no válidos'; end if;
  v := v || jsonb_strip_nulls(p - 'packs' - 'precios' - 'links')
         || jsonb_build_object('precios', coalesce(p -> 'precios', v -> 'precios', '{}'),   -- llegan completos desde el CM
                               'links', coalesce(p -> 'links', v -> 'links', '{}'),
                               'packs', coalesce(p -> 'packs', v -> 'packs', '{}'));
  if coalesce((v ->> 'precio')::numeric, 0) not between 0 and 1000000 or coalesce((v ->> 'descuento_premium')::numeric, 0) not between 0 and 90
     or coalesce((v ->> 'prueba_dias')::numeric, 7) not between 0 and 30 or coalesce((v ->> 'anual_meses')::numeric, 10) not between 1 and 12 then
    raise exception 'Revisa los números: precio de 0 a 1.000.000, descuento de 0 a 90 %%, prueba de 0 a 30 días, anual de 1 a 12 meses';
  end if;
  for l in select key, value from jsonb_each(coalesce(v -> 'precios', '{}')) loop
    if jsonb_typeof(l.value) <> 'number' or l.value::numeric not between 0 and 1000000 then raise exception 'Precio no válido: %', l.key; end if;
  end loop;
  for l in select key, value from jsonb_each(coalesce(v -> 'links', '{}')) loop
    for u in select key, value from jsonb_each_text(case when jsonb_typeof(l.value) = 'object' then l.value else '{}' end) loop
      if coalesce(u.value, '') <> '' and u.value !~ '^https://[^ ]+$' then raise exception 'El link de % debe empezar con https://', l.key; end if;
    end loop;
  end loop;
  update public.cfx_config set valor = v where clave = 'modulos_venta';
  perform public.cfx_anotar('módulos', 'venta ' || case when coalesce((v ->> 'activo')::boolean, false) then 'prendida' else 'apagada' end);
  return public.cfx_venta_admin();
end $$;

-- Regalar o quitar (p_dias = 0) un módulo o pack a un negocio por su correo.
create or replace function public.cfx_modulo_regalar(p_email text, p_item text, p_dias int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid; n uuid; h timestamptz;
begin
  perform public.cfx_es_admin();
  select id into u from auth.users where lower(email) = lower(trim(coalesce(p_email, '')));
  if u is null then raise exception 'No hay una cuenta con ese correo en esta app'; end if;
  n := public.cfx_negocio_cuenta(u);
  if n is null then raise exception 'Esa cuenta no es un negocio'; end if;
  if coalesce(p_dias, 0) not between 0 and 3660 then raise exception 'De 0 a 3660 días'; end if;
  h := public.cfx_modulos_dar(n, p_item, p_dias, 'regalo');
  if h is not null then perform public.cfx_avisar(n, '🎁 Te regalamos un módulo', coalesce((select c.nombre from public.cfx_modulos_catalogo() c where c.clave = p_item), public.cfx_venta() #>> array['packs', p_item, 'nombre'], p_item) ||
    ' activo hasta el ' || to_char(h at time zone 'America/Santiago', 'DD/MM/YYYY') || '.'); end if;
  perform public.cfx_anotar('módulo', case when h is null then 'quitó ' else 'regaló ' || p_dias || ' días de ' end || p_item || ' a ' || lower(trim(p_email)));
  return public.cfx_venta_admin();
end $$;

revoke all on function public.cfx_modulos_catalogo(), public.cfx_venta(), public.cfx_venta_on(), public.cfx_venta_precio(text), public.cfx_venta_activa(text), public.cfx_venta_modulos(text),
  public.cfx_negocio_cuenta(uuid), public.cfx_negocio_premium(uuid), public.cfx_modulo_de(text, uuid), public.cfx_modulo_mio(text),
  public.cfx_modulos_dar(uuid, text, int, text), public.cfx_modulos_avisar(), public.cfx_modulos_borrar(uuid) from public, anon, authenticated;
revoke all on function public.cfx_modulos_de(uuid), public.cfx_modulos_tienda(), public.cfx_modulo_probar(text), public.cfx_venta_admin(),
  public.cfx_venta_guardar(jsonb), public.cfx_modulo_regalar(text, text, int) from public, anon;
grant execute on function public.cfx_modulos_de(uuid) to anon, authenticated;
grant execute on function public.cfx_modulos_tienda(), public.cfx_modulo_probar(text), public.cfx_venta_admin(), public.cfx_venta_guardar(jsonb),
  public.cfx_modulo_regalar(text, text, int) to authenticated;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'cfx-modulos';
  perform cron.schedule('cfx-modulos', '17 13 * * *', 'select public.cfx_modulos_avisar()');
exception when others then
  raise notice 'Aviso de módulos por vencer no programado (%).', sqlerrm;
end $$;
-- ---------- Chat entre personas (C14): las mismas reglas en todas las apps (módulo 'chat') ----------
-- Reglas: hasta N mensajes seguidos sin respuesta (el gancho decide N; null = sin límite, p. ej. el admin), 100 al día,
-- bloquear (ninguno de los dos escribe), reportar (le llega al admin) y borrar la conversación (para los dos).
-- Ganchos que pone cada app que usa el chat (y 'chat' en cfx_modulos_app()):
--   cfx_chat_puede(a, b) boolean         ¿a puede escribirle a b?
--   cfx_chat_seguidos(a, b) int          mensajes seguidos sin respuesta (null = sin límite)
--   cfx_chat_quien(u) jsonb              {"nombre": ..., "rol": ...} para la lista y los reportes
--   cfx_chat_aviso(para, de, texto) void push al que recibe (con el link a la conversación)
--   cfx_chat_suspender(u) void           el admin suspende una cuenta reportada
create table if not exists public.cfx_mensajes (
  id      uuid primary key default gen_random_uuid(),
  de      uuid not null references auth.users (id) on delete cascade,
  para    uuid not null references auth.users (id) on delete cascade,
  texto   text not null check (char_length(texto) between 1 and 1000),
  creado  timestamptz not null default now(),
  leido   timestamptz
);
create index if not exists cfx_mensajes_par_idx on public.cfx_mensajes (least(de, para), greatest(de, para), creado desc);
create index if not exists cfx_mensajes_para_idx on public.cfx_mensajes (para) where leido is null;
create index if not exists cfx_mensajes_de_idx on public.cfx_mensajes (de, creado);
create index if not exists cfx_mensajes_creado_idx on public.cfx_mensajes (creado);
create table if not exists public.cfx_bloqueos (
  quien   uuid not null references auth.users (id) on delete cascade,
  a       uuid not null references auth.users (id) on delete cascade,
  creado  timestamptz not null default now(),
  primary key (quien, a)
);
create table if not exists public.cfx_reportes (
  id        uuid primary key default gen_random_uuid(),
  quien     uuid not null references auth.users (id) on delete cascade,
  a         uuid not null references auth.users (id) on delete cascade,
  mensaje   uuid references public.cfx_mensajes (id) on delete set null,
  motivo    text not null,
  extracto  text not null default '',
  resuelto  boolean not null default false,
  creado    timestamptz not null default now()
);
alter table public.cfx_mensajes enable row level security;
alter table public.cfx_bloqueos enable row level security;
alter table public.cfx_reportes enable row level security;
revoke all on public.cfx_mensajes, public.cfx_bloqueos, public.cfx_reportes from anon, authenticated;

create or replace function public.cfx_msg_listo() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Inicia sesión primero'; end if;
  if not public.cfx_modulo('chat') then raise exception 'El chat no está disponible en esta app'; end if;
  return auth.uid();
end $$;

create or replace function public.cfx_msg_bloqueado(p_uno uuid, p_otro uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  return exists (select 1 from public.cfx_bloqueos x where (x.quien = p_uno and x.a = p_otro) or (x.quien = p_otro and x.a = p_uno));
end $$;

-- Cuántos me quedan seguidos con "otro": {"restantes": n, "limite": n} (null = sin límite).
create or replace function public.cfx_msg_restantes(p_otro uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo(); lim int := public.cfx_chat_seguidos(u, p_otro); n int;
begin
  if lim is null then return jsonb_build_object('restantes', null, 'limite', null); end if;
  select count(*) into n from public.cfx_mensajes m where m.de = u and m.para = p_otro
    and m.creado > coalesce((select max(x.creado) from public.cfx_mensajes x where x.de = p_otro and x.para = u), '-infinity');
  return jsonb_build_object('restantes', greatest(0, lim - n), 'limite', lim);
end $$;

-- Enviar: {"ok": true, "id", "restantes"} o {"ok": false, "error"}.
create or replace function public.cfx_msg_enviar(p_para uuid, p_texto text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo(); t text := trim(coalesce(p_texto, '')); lim int; r jsonb; i uuid;
begin
  if t = '' then return jsonb_build_object('ok', false, 'error', 'Escribe un mensaje'); end if;
  if char_length(t) > 1000 then return jsonb_build_object('ok', false, 'error', 'Máximo 1000 caracteres por mensaje'); end if;
  if p_para is null or not coalesce(public.cfx_chat_puede(u, p_para), false) then
    return jsonb_build_object('ok', false, 'error', 'No puedes escribirle a esta cuenta');
  end if;
  lim := public.cfx_chat_seguidos(u, p_para);
  -- G19: con el chat a la venta, el negocio de la conversación debe tenerlo (con soporte siempre se puede).
  if lim is not null and public.cfx_chat_seguidos(p_para, u) is not null and public.cfx_venta_activa('chat') then
    if public.cfx_negocio_cuenta(u) is not null and not public.cfx_modulo_de('chat', public.cfx_negocio_cuenta(u)) then
      return jsonb_build_object('ok', false, 'error', 'El chat es un módulo. Actívalo en Ajustes → 🧩 Módulos');
    end if;
    if public.cfx_negocio_cuenta(p_para) is not null and not public.cfx_modulo_de('chat', public.cfx_negocio_cuenta(p_para)) then
      return jsonb_build_object('ok', false, 'error', 'Esta tienda no tiene chat. Escríbele por WhatsApp');
    end if;
  end if;
  if lim is not null then
    if public.cfx_msg_bloqueado(u, p_para) then return jsonb_build_object('ok', false, 'error', 'La conversación está bloqueada'); end if;
    if (public.cfx_msg_restantes(p_para) ->> 'restantes')::int <= 0 then
      return jsonb_build_object('ok', false, 'error', case when lim = 1
        then 'Envías 1 mensaje a la vez. Espera la respuesta para escribir de nuevo.'
        else 'Ya enviaste ' || lim || ' mensajes seguidos. Espera la respuesta para escribir de nuevo.' end);
    end if;
    if (select count(*) from public.cfx_mensajes where de = u and creado > now() - interval '1 day') >= 100 then
      return jsonb_build_object('ok', false, 'error', 'Llegaste al máximo de 100 mensajes por día');
    end if;
  end if;
  insert into public.cfx_mensajes (de, para, texto) values (u, p_para, t) returning id into i;
  perform public.cfx_chat_aviso(p_para, u, t);
  r := public.cfx_msg_restantes(p_para);
  return jsonb_build_object('ok', true, 'id', i, 'restantes', r -> 'restantes');
end $$;

-- Mis conversaciones: [{otro, nombre, rol, ultimo, ultimo_at, mio, no_leidos, bloqueado}] (las 100 más recientes).
create or replace function public.cfx_msg_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo();
begin
  return coalesce((with z as (select case when m.de = u then m.para else m.de end as otro, m.texto, m.creado, m.de = u as mio
                               from public.cfx_mensajes m where m.de = u or m.para = u),
                          l as (select distinct on (otro) * from z order by otro, creado desc),
                          t as (select * from l order by creado desc limit 100)
    select jsonb_agg(jsonb_build_object('otro', t.otro, 'nombre', coalesce(q.v ->> 'nombre', 'Cuenta'), 'rol', coalesce(q.v ->> 'rol', ''),
      'ultimo', t.texto, 'ultimo_at', t.creado, 'mio', t.mio,
      'no_leidos', (select count(*) from public.cfx_mensajes x where x.de = t.otro and x.para = u and x.leido is null),
      'bloqueado', exists (select 1 from public.cfx_bloqueos b where b.quien = u and b.a = t.otro)) order by t.creado desc)
    from t cross join lateral (select public.cfx_chat_quien(t.otro) as v) q), '[]');
end $$;

create or replace function public.cfx_msg_sin_leer() returns int
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.cfx_modulo('chat') then return 0; end if;
  return (select count(*)::int from public.cfx_mensajes where para = auth.uid() and leido is null);
end $$;

-- Una conversación (las últimas 200; marca como leídos los recibidos): [{id, mio, texto, creado, leido}].
create or replace function public.cfx_msg_hilo(p_otro uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo();
begin
  update public.cfx_mensajes set leido = now() where de = p_otro and para = u and leido is null;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'mio', m.de = u, 'texto', m.texto, 'creado', m.creado, 'leido', m.leido) order by m.creado)
    from (select * from public.cfx_mensajes x where (x.de = u and x.para = p_otro) or (x.de = p_otro and x.para = u)
          order by x.creado desc limit 200) m), '[]');
end $$;

create or replace function public.cfx_msg_bloquear(p_otro uuid, p_bloquear boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo();
begin
  if p_otro is null or p_otro = u then raise exception 'Cuenta no válida'; end if;
  if p_bloquear then insert into public.cfx_bloqueos (quien, a) values (u, p_otro) on conflict do nothing;
  else delete from public.cfx_bloqueos where quien = u and a = p_otro; end if;
end $$;

create or replace function public.cfx_msg_reportar(p_mensaje uuid, p_motivo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo(); m public.cfx_mensajes;
begin
  select * into m from public.cfx_mensajes where id = p_mensaje and para = u;
  if m.id is null then return jsonb_build_object('ok', false, 'error', 'Mensaje no encontrado'); end if;
  if (select count(*) from public.cfx_reportes where quien = u and creado > now() - interval '1 day') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'Máximo 10 reportes por día');
  end if;
  insert into public.cfx_reportes (quien, a, mensaje, motivo, extracto)
  values (u, m.de, m.id, left(coalesce(nullif(trim(p_motivo), ''), 'Sin motivo'), 300), left(m.texto, 300));
  perform public.cfx_avisar_admin('🚩 Nuevo reporte en el chat', left(m.texto, 100));
  return jsonb_build_object('ok', true);
end $$;

-- Borra la conversación completa (para los dos).
create or replace function public.cfx_msg_borrar(p_otro uuid) returns int
language plpgsql security definer set search_path = '' as $$
declare u uuid := public.cfx_msg_listo(); n int;
begin
  delete from public.cfx_mensajes where (de = u and para = p_otro) or (de = p_otro and para = u);
  get diagnostics n = row_count;
  return n;
end $$;

-- Administrador: reportes sin resolver y resolverlos (descartar o suspender a la cuenta reportada).
create or replace function public.cfx_msg_reportes() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'motivo', r.motivo, 'extracto', r.extracto, 'creado', r.creado,
      'quien', coalesce(public.cfx_chat_quien(r.quien) ->> 'nombre', ''), 'a', coalesce(public.cfx_chat_quien(r.a) ->> 'nombre', ''),
      'quien_email', (select email from auth.users where id = r.quien), 'a_email', (select email from auth.users where id = r.a)) order by r.creado desc)
    from public.cfx_reportes r where not r.resuelto), '[]');
end $$;

create or replace function public.cfx_msg_resolver(p_id uuid, p_suspender boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.cfx_reportes;
begin
  perform public.cfx_es_admin();
  update public.cfx_reportes set resuelto = true where id = p_id and not resuelto returning * into r;
  if r.id is null then raise exception 'El reporte ya fue atendido'; end if;
  if p_suspender then perform public.cfx_chat_suspender(r.a); end if;
  perform public.cfx_anotar('reporte chat', case when p_suspender then 'suspendida ' else 'descartado ' end || coalesce((select email from auth.users where id = r.a), ''));
end $$;

revoke all on function public.cfx_msg_listo(), public.cfx_msg_bloqueado(uuid, uuid) from public, anon, authenticated;
revoke all on function public.cfx_msg_restantes(uuid), public.cfx_msg_enviar(uuid, text), public.cfx_msg_lista(), public.cfx_msg_sin_leer(),
  public.cfx_msg_hilo(uuid), public.cfx_msg_bloquear(uuid, boolean), public.cfx_msg_reportar(uuid, text), public.cfx_msg_borrar(uuid),
  public.cfx_msg_reportes(), public.cfx_msg_resolver(uuid, boolean) from public, anon;
grant execute on function public.cfx_msg_restantes(uuid), public.cfx_msg_enviar(uuid, text), public.cfx_msg_lista(), public.cfx_msg_sin_leer(),
  public.cfx_msg_hilo(uuid), public.cfx_msg_bloquear(uuid, boolean), public.cfx_msg_reportar(uuid, text), public.cfx_msg_borrar(uuid),
  public.cfx_msg_reportes(), public.cfx_msg_resolver(uuid, boolean) to authenticated;
-- ---------- Calificaciones en dos direcciones (C15): el cliente califica al negocio y el negocio al cliente (módulo 'calificaciones') ----------
-- Una calificación por "ref" (pedido, reserva, arriendo…) y por lado. Estrellas 1-5 y comentario opcional (300).
-- Gancho que pone cada app que las usa (y 'calificaciones' en cfx_modulos_app()):
--   cfx_calif_ref(ref, u) jsonb   quién califica esa ref: {"ref": text, "negocio": uuid, "cliente": uuid|null, "cliente_ref": text|null, "de_negocio": bool}
--                                 ("ref" = la referencia de verdad, p. ej. el id del pedido cuando llega su token)
--                                 o {"error": "..."} (no existe, aún no se puede, no es tuyo). u puede ser null (invitado con token).
-- Para mostrar: cfx_calif_negocio(n) y cfx_calif_cliente(c, ref) → {"promedio", "total"}; cfx_calif_hecha(ref, de_negocio).
-- Si el módulo está apagado no se califica, los promedios vuelven null y cfx_calif_hecha dice true (no aparece "Califica").
create table if not exists public.cfx_calificaciones (
  ref          text not null,
  de_negocio   boolean not null,
  negocio_id   uuid not null,
  cliente_id   uuid references auth.users (id) on delete set null,
  cliente_ref  text,
  estrellas    int not null check (estrellas between 1 and 5),
  comentario   text not null default '' check (char_length(comentario) <= 300),
  creado       timestamptz not null default now(),
  primary key (ref, de_negocio)
);
create index if not exists cfx_calif_negocio_idx on public.cfx_calificaciones (negocio_id) where not de_negocio;
create index if not exists cfx_calif_cliente_idx on public.cfx_calificaciones (cliente_id) where de_negocio;
create index if not exists cfx_calif_cref_idx on public.cfx_calificaciones (cliente_ref) where de_negocio and cliente_ref is not null;
alter table public.cfx_calificaciones enable row level security;
revoke all on public.cfx_calificaciones from anon, authenticated;

-- Calificar: {"ok": true} o {"ok": false, "error"}.
create or replace function public.cfx_calificar(p_ref text, p_estrellas int, p_comentario text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb;
begin
  if not public.cfx_modulo('calificaciones') then return jsonb_build_object('ok', false, 'error', 'Las calificaciones no están disponibles'); end if;
  if p_estrellas is null or p_estrellas < 1 or p_estrellas > 5 then return jsonb_build_object('ok', false, 'error', 'Elige de 1 a 5 estrellas'); end if;
  if coalesce(trim(p_ref), '') = '' then return jsonb_build_object('ok', false, 'error', 'No encontrado'); end if;
  r := public.cfx_calif_ref(p_ref, auth.uid());
  if r is null or r ? 'error' or r ->> 'negocio' is null then return jsonb_build_object('ok', false, 'error', coalesce(r ->> 'error', 'No encontrado')); end if;
  if not public.cfx_modulo_de('calificaciones', (r ->> 'negocio')::uuid) then return jsonb_build_object('ok', false, 'error', 'Las calificaciones no están disponibles'); end if;
  insert into public.cfx_calificaciones (ref, de_negocio, negocio_id, cliente_id, cliente_ref, estrellas, comentario)
  values (coalesce(r ->> 'ref', p_ref), coalesce((r ->> 'de_negocio')::boolean, false), (r ->> 'negocio')::uuid, (r ->> 'cliente')::uuid,
          nullif(left(r ->> 'cliente_ref', 60), ''), p_estrellas, left(trim(coalesce(p_comentario, '')), 300))
  on conflict (ref, de_negocio) do nothing;
  if not found then return jsonb_build_object('ok', false, 'error', 'Ya fue calificado'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- ¿Ya calificó ese lado? (con el módulo apagado: true, para no pedirlo)
create or replace function public.cfx_calif_hecha(p_ref text, p_de_negocio boolean) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.cfx_modulo('calificaciones') then return true; end if;
  if public.cfx_venta_activa('calificaciones') and not coalesce(public.cfx_modulo_de('calificaciones', (public.cfx_calif_ref(p_ref, auth.uid()) ->> 'negocio')::uuid), false) then return true; end if;
  return exists (select 1 from public.cfx_calificaciones where ref = p_ref and de_negocio = p_de_negocio);
end $$;

-- Lo que los clientes dicen del negocio.
create or replace function public.cfx_calif_negocio(p_negocio uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.cfx_modulo_de('calificaciones', p_negocio) then return null; end if;
  return (select jsonb_build_object('promedio', round(avg(estrellas), 1), 'total', count(*))
          from public.cfx_calificaciones where negocio_id = p_negocio and not de_negocio);
end $$;

-- Lo que los negocios dicen del cliente (por su cuenta o, si es invitado, por su referencia: teléfono…).
create or replace function public.cfx_calif_cliente(p_cliente uuid, p_cliente_ref text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.cfx_modulo_mio('calificaciones') or (p_cliente is null and coalesce(p_cliente_ref, '') = '') then return null; end if;
  return (select jsonb_build_object('promedio', round(avg(estrellas), 1), 'total', count(*))
          from public.cfx_calificaciones where de_negocio
            and ((p_cliente is not null and cliente_id = p_cliente) or (p_cliente is null and cliente_ref = p_cliente_ref)));
end $$;

-- Al borrar un negocio o una ref (lo llama la app).
create or replace function public.cfx_calif_borrar(p_negocio uuid, p_ref text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.cfx_calificaciones where negocio_id = p_negocio and (p_ref is null or ref = p_ref);
end $$;

revoke all on function public.cfx_calif_hecha(text, boolean), public.cfx_calif_negocio(uuid), public.cfx_calif_cliente(uuid, text),
  public.cfx_calif_borrar(uuid, text) from public, anon, authenticated;
revoke all on function public.cfx_calificar(text, int, text) from public;
grant execute on function public.cfx_calificar(text, int, text) to anon, authenticated;
-- ---------- Cupones del negocio y tarjeta de sellos (C16): módulos 'cupones' y 'sellos' ----------
-- OJO: no son los cupones del Premium (cfx_cupones / cfx_cupon_ver, los crea el admin). Estos los crea cada negocio para SUS clientes.
-- Ganchos que pone cada app que los usa (y 'cupones' / 'sellos' en cfx_modulos_app()):
--   cfx_fid_dueno(u) uuid                  negocio que administra la cuenta u (null = no es negocio)
--   cfx_fid_activo(negocio, modulo) bool   ¿el plan del negocio incluye ese módulo? (p. ej. solo Pro)
--   cfx_fid_cliente(u, negocio) bool       ¿u es cliente de ese negocio? (ve sus sellos y prueba cupones)
--   cfx_sellos_aviso(negocio, cliente, premio) void   push al cliente que completó la tarjeta
-- La app usa, dentro de sus funciones: cfx_desc_pct + cfx_desc_usar (al crear el pedido), cfx_sello_sumar (al entregar)
-- y cfx_sellos_cfg_de (para mostrar la tarjeta). cfx_fid_borrar al borrar un negocio.
create table if not exists public.cfx_descuentos (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null,
  codigo      text not null check (codigo ~ '^[A-Z0-9]{3,20}$'),
  porcentaje  int not null check (porcentaje between 1 and 90),
  hasta       date,
  activo      boolean not null default true,
  usos        int not null default 0,
  creado      timestamptz not null default now(),
  unique (owner_id, codigo)
);
create table if not exists public.cfx_sellos_cfg (
  owner_id  uuid primary key,
  meta      int not null check (meta between 2 and 30),
  premio    text check (char_length(premio) <= 80),
  creado    timestamptz not null default now()
);
create table if not exists public.cfx_sellos (
  negocio_id  uuid not null,
  cliente_id  uuid not null references auth.users (id) on delete cascade,
  cantidad    int not null default 0,
  premios     int not null default 0,
  actualizado timestamptz not null default now(),
  primary key (negocio_id, cliente_id)
);
create index if not exists cfx_sellos_cliente_idx on public.cfx_sellos (cliente_id);
alter table public.cfx_descuentos enable row level security;
alter table public.cfx_sellos_cfg enable row level security;
alter table public.cfx_sellos enable row level security;
revoke all on public.cfx_descuentos, public.cfx_sellos_cfg, public.cfx_sellos from anon, authenticated;

create or replace function public.cfx_desc_codigo(p_codigo text) returns text
language sql immutable set search_path = '' as $$ select upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g')) $$;

-- El negocio de la cuenta, si el módulo está prendido y su plan lo incluye.
create or replace function public.cfx_fid_mio(p_modulo text) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare n uuid;
begin
  if not public.cfx_modulo(p_modulo) then
    raise exception '% no está disponible en esta app', case p_modulo when 'cupones' then 'Los cupones' else 'La tarjeta de sellos' end;
  end if;
  n := public.cfx_fid_dueno(auth.uid());
  if n is null then raise exception 'Solo el negocio'; end if;
  if public.cfx_venta_on() then
    if not public.cfx_modulo_de(p_modulo, n) then
      raise exception '% Actívalo en Ajustes → 🧩 Módulos', case p_modulo when 'cupones' then 'Los cupones son un módulo.' else 'La tarjeta de sellos es un módulo.' end;
    end if;
  elsif not coalesce(public.cfx_fid_activo(n, p_modulo), false) then
    raise exception '% de la versión Pro', case p_modulo when 'cupones' then 'Los cupones son' else 'La tarjeta de sellos es' end;
  end if;
  return n;
end $$;

-- ¿El negocio puede usar el módulo ahora? (prendido + su plan)
create or replace function public.cfx_fid_ok(p_negocio uuid, p_modulo text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_negocio is null or not public.cfx_modulo(p_modulo) then return false; end if;
  if public.cfx_venta_on() then return public.cfx_modulo_de(p_modulo, p_negocio); end if;
  return coalesce(public.cfx_fid_activo(p_negocio, p_modulo), false);
end $$;

-- ---------- Cupones ----------
create or replace function public.cfx_desc_guardar(p_codigo text, p_porcentaje int, p_hasta date) returns void
language plpgsql security definer set search_path = '' as $$
declare n uuid := public.cfx_fid_mio('cupones'); c text := public.cfx_desc_codigo(p_codigo);
begin
  if length(c) < 3 or length(c) > 20 then raise exception 'El código debe tener entre 3 y 20 letras o números'; end if;
  if p_porcentaje is null or p_porcentaje < 1 or p_porcentaje > 90 then raise exception 'El descuento debe ser entre 1 y 90 por ciento'; end if;
  if (select count(*) from public.cfx_descuentos where owner_id = n) >= 50
     and not exists (select 1 from public.cfx_descuentos where owner_id = n and codigo = c) then raise exception 'Máximo 50 cupones'; end if;
  insert into public.cfx_descuentos (owner_id, codigo, porcentaje, hasta) values (n, c, p_porcentaje, p_hasta)
  on conflict (owner_id, codigo) do update set porcentaje = excluded.porcentaje, hasta = excluded.hasta, activo = true;
end $$;

create or replace function public.cfx_desc_borrar(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.cfx_descuentos where id = p_id and owner_id = public.cfx_fid_dueno(auth.uid());
end $$;

-- Mis cupones: [{id, codigo, porcentaje, hasta, activo, usos}]
create or replace function public.cfx_desc_lista() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare n uuid := public.cfx_fid_mio('cupones');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'codigo', c.codigo, 'porcentaje', c.porcentaje, 'hasta', c.hasta,
    'activo', c.activo, 'usos', c.usos) order by c.creado desc) from public.cfx_descuentos c where c.owner_id = n), '[]');
end $$;

-- Porcentaje de un cupón vigente (null = no sirve). Interna: la app la usa al armar el pedido.
create or replace function public.cfx_desc_pct(p_negocio uuid, p_codigo text) returns int
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.cfx_fid_ok(p_negocio, 'cupones') then return null; end if;
  return (select c.porcentaje from public.cfx_descuentos c
          where c.owner_id = p_negocio and c.codigo = public.cfx_desc_codigo(p_codigo) and c.activo and (c.hasta is null or c.hasta >= current_date));
end $$;

-- Suma un uso (la app la llama cuando el pedido ya quedó guardado).
create or replace function public.cfx_desc_usar(p_negocio uuid, p_codigo text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.cfx_descuentos set usos = usos + 1 where owner_id = p_negocio and codigo = public.cfx_desc_codigo(p_codigo);
end $$;

-- El cliente prueba un cupón: devuelve el porcentaje o avisa que no sirve.
create or replace function public.cfx_desc_validar(p_negocio uuid, p_codigo text) returns int
language plpgsql stable security definer set search_path = '' as $$
declare pct int;
begin
  if not public.cfx_modulo('cupones') then raise exception 'Cupón no válido o vencido'; end if;
  if not coalesce(public.cfx_fid_cliente(auth.uid(), p_negocio), false) then raise exception 'Sin permiso'; end if;
  pct := public.cfx_desc_pct(p_negocio, p_codigo);
  if pct is null then raise exception 'Cupón no válido o vencido'; end if;
  return pct;
end $$;

-- ---------- Tarjeta de sellos ----------
-- El negocio la arma (meta 2-30 y premio) o la apaga (meta null).
create or replace function public.cfx_sellos_guardar(p_meta int, p_premio text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare n uuid;
begin
  if p_meta is null then
    n := public.cfx_fid_dueno(auth.uid());
    if n is null then raise exception 'Solo el negocio'; end if;
    delete from public.cfx_sellos_cfg where owner_id = n;
    return null;
  end if;
  n := public.cfx_fid_mio('sellos');
  if p_meta < 2 or p_meta > 30 then raise exception 'La tarjeta debe tener entre 2 y 30 sellos'; end if;
  insert into public.cfx_sellos_cfg (owner_id, meta, premio) values (n, p_meta, nullif(left(trim(coalesce(p_premio, '')), 80), ''))
  on conflict (owner_id) do update set meta = excluded.meta, premio = excluded.premio;
  return public.cfx_sellos_cfg_de(n);
end $$;

-- La tarjeta del negocio {meta, premio} (null = no tiene, módulo apagado o su plan no la incluye).
create or replace function public.cfx_sellos_cfg_de(p_negocio uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.cfx_fid_ok(p_negocio, 'sellos') then return null; end if;
  return (select jsonb_build_object('meta', c.meta, 'premio', c.premio) from public.cfx_sellos_cfg c where c.owner_id = p_negocio);
end $$;

-- Mis sellos en un negocio: {cantidad, premios, meta, premio} o null.
create or replace function public.cfx_sellos_mios(p_negocio uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare c jsonb := public.cfx_sellos_cfg_de(p_negocio);
begin
  if c is null then return null; end if;
  if not coalesce(public.cfx_fid_cliente(auth.uid(), p_negocio), false) then return null; end if;
  return c || coalesce((select jsonb_build_object('cantidad', s.cantidad, 'premios', s.premios) from public.cfx_sellos s
                        where s.negocio_id = p_negocio and s.cliente_id = auth.uid()), jsonb_build_object('cantidad', 0, 'premios', 0));
end $$;

-- Suma un sello (al entregar una compra). Al llegar a la meta: vuelve a 0, suma un premio y avisa. Devuelve {cantidad, premio} o null.
create or replace function public.cfx_sello_sumar(p_negocio uuid, p_cliente uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := public.cfx_sellos_cfg_de(p_negocio); s public.cfx_sellos;
begin
  if c is null or p_cliente is null then return null; end if;
  insert into public.cfx_sellos (negocio_id, cliente_id, cantidad) values (p_negocio, p_cliente, 1)
  on conflict (negocio_id, cliente_id) do update set cantidad = public.cfx_sellos.cantidad + 1, actualizado = now() returning * into s;
  if s.cantidad >= (c ->> 'meta')::int then
    update public.cfx_sellos set cantidad = 0, premios = premios + 1 where negocio_id = p_negocio and cliente_id = p_cliente;
    perform public.cfx_sellos_aviso(p_negocio, p_cliente, c ->> 'premio');
    return jsonb_build_object('cantidad', 0, 'premio', true);
  end if;
  return jsonb_build_object('cantidad', s.cantidad, 'premio', false);
end $$;

-- Al borrar un negocio (lo llama la app): sus cupones, su tarjeta y los sellos de sus clientes.
create or replace function public.cfx_fid_borrar(p_negocio uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.cfx_descuentos where owner_id = p_negocio;
  delete from public.cfx_sellos_cfg where owner_id = p_negocio;
  delete from public.cfx_sellos where negocio_id = p_negocio;
end $$;

revoke all on function public.cfx_desc_codigo(text), public.cfx_fid_mio(text), public.cfx_fid_ok(uuid, text), public.cfx_desc_pct(uuid, text),
  public.cfx_desc_usar(uuid, text), public.cfx_sellos_cfg_de(uuid), public.cfx_sello_sumar(uuid, uuid), public.cfx_fid_borrar(uuid)
  from public, anon, authenticated;
revoke all on function public.cfx_desc_guardar(text, int, date), public.cfx_desc_borrar(uuid), public.cfx_desc_lista(), public.cfx_desc_validar(uuid, text),
  public.cfx_sellos_guardar(int, text), public.cfx_sellos_mios(uuid) from public, anon;
grant execute on function public.cfx_desc_guardar(text, int, date), public.cfx_desc_borrar(uuid), public.cfx_desc_lista(), public.cfx_desc_validar(uuid, text),
  public.cfx_sellos_guardar(int, text), public.cfx_sellos_mios(uuid) to authenticated;
-- ---------- 🛒 Carrito y 🚚 despacho (C17) ----------
-- Carrito guardado en la nube (para recordarle al cliente lo que dejó) y el cálculo del despacho por comuna y al resto de Chile (2.58).
-- Ganchos que pone cada app que lo usa (y 'carrito' en cfx_modulos_app() para el recordatorio):
--   cfx_carrito_puede(u, negocio) bool           ¿u puede guardar carrito en ese negocio? (es su cliente, puede comprar)
--   cfx_carrito_aviso(cliente, negocio, n) bool  manda el recordatorio (push); false = no corresponde (plan, vacaciones…)
-- La app usa: cfx_carrito_vaciar (al crear el pedido), cfx_carritos_recordar (pg_cron, cada hora), cfx_carrito_borrar (al borrar una cuenta).
-- Despacho (sin tabla: cada app guarda su { retiro, gratis_desde, zonas: [{comuna, precio}] } donde quiera):
--   cfx_despacho_limpio(p) → la misma config revisada (o error claro) · cfx_despacho_costo(cfg, entrega, direccion, monto) → {costo, comuna} o {error}
create table if not exists public.cfx_carritos (
  cliente     uuid not null references auth.users (id) on delete cascade,
  negocio     uuid not null,
  items       jsonb not null default '[]'::jsonb,
  actualizado timestamptz not null default now(),
  avisado     timestamptz,
  primary key (cliente, negocio)
);
create index if not exists cfx_carritos_negocio_idx on public.cfx_carritos (negocio);
create index if not exists cfx_carritos_aviso_idx on public.cfx_carritos (actualizado) where avisado is null;
alter table public.cfx_carritos enable row level security;
revoke all on public.cfx_carritos from anon, authenticated;

-- El cliente guarda su carrito (hasta 50 productos). Vacío = se borra.
create or replace function public.cfx_carrito_guardar(p_negocio uuid, p_items jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare l jsonb := '[]'::jsonb; it jsonb; ok boolean := false;
begin
  if auth.uid() is null or p_negocio is null or to_regprocedure('public.cfx_carrito_puede(uuid,uuid)') is null then return; end if;
  execute 'select public.cfx_carrito_puede($1, $2)' into ok using auth.uid(), p_negocio;
  if not coalesce(ok, false) or jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then return; end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) limit 50 loop
    continue when jsonb_typeof(it) <> 'object' or coalesce(it ->> 'clave', '') = '';
    l := l || jsonb_build_object('clave', left(it ->> 'clave', 60), 'cant', least(greatest(coalesce((it ->> 'cant')::int, 1), 1), 99), 'nombre', left(it ->> 'nombre', 80));
  end loop;
  if jsonb_array_length(l) = 0 then
    delete from public.cfx_carritos where cliente = auth.uid() and negocio = p_negocio;
  else
    insert into public.cfx_carritos (cliente, negocio, items) values (auth.uid(), p_negocio, l)
    on conflict (cliente, negocio) do update set items = excluded.items, actualizado = now(), avisado = null
      where public.cfx_carritos.items is distinct from excluded.items;
  end if;
end $$;

create or replace function public.cfx_carrito_vaciar(p_cliente uuid, p_negocio uuid) returns void
language sql security definer set search_path = '' as $$ delete from public.cfx_carritos where cliente = p_cliente and negocio = p_negocio $$;
create or replace function public.cfx_carrito_borrar(p_cuenta uuid) returns void
language sql security definer set search_path = '' as $$ delete from public.cfx_carritos where cliente = p_cuenta or negocio = p_cuenta $$;

-- Cada hora: carritos sin pedir de hace más de 20 horas (y menos de 4 días) reciben UN aviso, de 10 a 20 h de Chile.
create or replace function public.cfx_carritos_recordar() returns int
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0; ok boolean; h int := extract(hour from now() at time zone 'America/Santiago');
begin
  if h < 10 or h > 20 or not public.cfx_modulo('carrito') or to_regprocedure('public.cfx_carrito_aviso(uuid,uuid,integer)') is null then return 0; end if;
  for r in select * from public.cfx_carritos where avisado is null and actualizado < now() - interval '20 hours' and actualizado > now() - interval '4 days' limit 500 loop
    if not public.cfx_modulo_de('carrito', r.negocio) then  -- G19: la tienda no tiene el módulo (no se vuelve a revisar)
      update public.cfx_carritos set avisado = now() where cliente = r.cliente and negocio = r.negocio; continue;
    end if;
    execute 'select public.cfx_carrito_aviso($1, $2, $3)' into ok using r.cliente, r.negocio, jsonb_array_length(r.items);
    update public.cfx_carritos set avisado = now() where cliente = r.cliente and negocio = r.negocio;
    if coalesce(ok, false) then n := n + 1; end if;
  end loop;
  return n;
end $$;

-- ---------- Despacho por comuna ----------
create or replace function public.cfx_comuna_norm(t text) returns text
language sql immutable set search_path = '' as $$ select lower(trim(translate(coalesce(t, ''), 'ÁÉÍÓÚÜÑáéíóúüñ', 'AEIOUUNaeiouun'))) $$;

create or replace function public.cfx_despacho_limpio(p jsonb) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare z jsonb; l jsonb := '[]'::jsonb; vistas text[] := '{}'; rm text;
begin
  if jsonb_typeof(p) is distinct from 'object' then raise exception 'Datos no válidos'; end if;
  for z in select * from jsonb_array_elements(case when jsonb_typeof(p -> 'zonas') = 'array' then p -> 'zonas' else '[]'::jsonb end) loop
    if coalesce(trim(z ->> 'comuna'), '') = '' then continue; end if;
    if length(z ->> 'comuna') > 40 then raise exception 'Nombre de comuna muy largo'; end if;
    if coalesce((z ->> 'precio')::numeric, -1) not between 0 and 200000 then raise exception 'El despacho a % debe costar entre $0 y $200.000', z ->> 'comuna'; end if;
    if public.cfx_comuna_norm(z ->> 'comuna') = any (vistas) then raise exception 'La comuna % está repetida', z ->> 'comuna'; end if;
    vistas := vistas || public.cfx_comuna_norm(z ->> 'comuna');
    l := l || jsonb_build_object('comuna', trim(z ->> 'comuna'), 'precio', round((z ->> 'precio')::numeric));
  end loop;
  if jsonb_array_length(l) > 80 then raise exception 'Máximo 80 comunas'; end if;
  -- Resto de Chile (regiones y comunas que no están en la lista): 'no' | 'fijo' (un precio) | 'por_pagar' (lo paga quien recibe al courier).
  rm := coalesce(nullif(p #>> '{resto,modo}', ''), 'no');
  if rm not in ('no', 'fijo', 'por_pagar') then raise exception 'Elige cómo despachas al resto de Chile'; end if;
  if rm = 'fijo' and coalesce((p #>> '{resto,precio}')::numeric, -1) not between 0 and 200000 then raise exception 'El despacho al resto de Chile debe costar entre $0 y $200.000'; end if;
  if not coalesce((p ->> 'retiro')::boolean, true) and jsonb_array_length(l) = 0 and rm = 'no' then raise exception 'Activa el retiro en tienda o agrega al menos una comuna de despacho'; end if;
  if coalesce((p ->> 'gratis_desde')::numeric, 0) not between 0 and 10000000 then raise exception 'Monto de despacho gratis no válido'; end if;
  return jsonb_build_object('retiro', coalesce((p ->> 'retiro')::boolean, true), 'gratis_desde', round(coalesce((p ->> 'gratis_desde')::numeric, 0)), 'zonas', l,
    'resto', jsonb_build_object('modo', rm, 'precio', case when rm = 'fijo' then round((p #>> '{resto,precio}')::numeric) else 0 end));
end $$;

-- La comuna va al final de la dirección ("…, Ñuñoa"). Sin zonas ni resto de Chile: se coordina con el negocio ($0 aquí).
-- Comuna fuera de la lista: con resto 'fijo' cobra ese precio; con 'por_pagar' $0 y por_pagar = true (lo paga quien recibe).
create or replace function public.cfx_despacho_costo(p_cfg jsonb, p_entrega text, p_direccion text, p_monto numeric) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare c jsonb := coalesce(p_cfg, '{}'::jsonb); com text; z jsonb; rm text := coalesce(nullif(p_cfg #>> '{resto,modo}', ''), 'no'); orig text;
  gratis boolean := coalesce((p_cfg ->> 'gratis_desde')::numeric, 0) > 0 and p_monto >= (p_cfg ->> 'gratis_desde')::numeric;
begin
  if p_entrega is distinct from 'despacho' or (jsonb_array_length(coalesce(c -> 'zonas', '[]'::jsonb)) = 0 and rm = 'no') then return jsonb_build_object('costo', 0, 'comuna', null); end if;
  orig := left(trim(regexp_replace(coalesce(p_direccion, ''), '^.*,', '')), 60);
  com := public.cfx_comuna_norm(orig);
  select e into z from jsonb_array_elements(coalesce(c -> 'zonas', '[]'::jsonb)) e where public.cfx_comuna_norm(e ->> 'comuna') = com limit 1;
  if z is null then
    if com = '' or position(',' in coalesce(p_direccion, '')) = 0 then return jsonb_build_object('error', 'Escribe la dirección y la comuna de despacho'); end if;
    if rm = 'fijo' then return jsonb_build_object('comuna', orig, 'costo', case when gratis then 0 else greatest(0, coalesce((c #>> '{resto,precio}')::numeric, 0)) end); end if;
    if rm = 'por_pagar' then return jsonb_build_object('comuna', orig, 'costo', 0, 'por_pagar', true); end if;
    return jsonb_build_object('error', 'Esta tienda no despacha a esa comuna. Elige otra comuna o retiro en tienda.');
  end if;
  return jsonb_build_object('comuna', z ->> 'comuna', 'costo', case when gratis then 0 else greatest(0, coalesce((z ->> 'precio')::numeric, 0)) end);
end $$;

revoke all on function public.cfx_carrito_vaciar(uuid, uuid), public.cfx_carrito_borrar(uuid), public.cfx_carritos_recordar(), public.cfx_comuna_norm(text),
  public.cfx_despacho_limpio(jsonb), public.cfx_despacho_costo(jsonb, text, text, numeric) from public, anon, authenticated;
revoke all on function public.cfx_carrito_guardar(uuid, jsonb) from public, anon;
grant execute on function public.cfx_carrito_guardar(uuid, jsonb) to authenticated;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'cfx-carritos';
  perform cron.schedule('cfx-carritos', '23 * * * *', 'select public.cfx_carritos_recordar()');
exception when others then
  raise notice 'Recordatorio de carritos no programado (%).', sqlerrm;
end $$;
-- ---------- 🧹 Limpieza (C18): una sola lista para el Centro de Mando → Mis aplicaciones → ↻ → 🧹 Respaldo y limpieza ----------
-- Lo del núcleo (claves "n_…") se borra solo cada noche si la limpieza automática está prendida (por defecto sí).
-- Lo propio de cada app viene del gancho cfx_limpieza_app() → [{clave, titulo, detalle, filas}] y cfx_limpiar_app(clave) → int
-- (la app ya lo borra sola con su propio horario; aquí se puede borrar a mano).
create index if not exists cfx_registro_creado_idx on public.cfx_registro (creado);
create index if not exists cfx_errores_ultimo_idx on public.cfx_errores (ultimo);
insert into public.cfx_config (clave, valor) values ('limpieza_auto', 'true') on conflict (clave) do nothing;

create or replace function public.cfx_limpieza_nucleo() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  return jsonb_build_array(
    jsonb_build_object('clave', 'n_registro', 'titulo', 'Registro de cambios', 'detalle', 'Más de 180 días.', 'auto', true,
      'filas', (select count(*) from public.cfx_registro where creado < now() - interval '180 days')),
    jsonb_build_object('clave', 'n_errores', 'titulo', 'Errores de la app', 'detalle', 'Sin repetirse hace más de 30 días.', 'auto', true,
      'filas', (select count(*) from public.cfx_errores where ultimo < now() - interval '30 days')),
    jsonb_build_object('clave', 'n_reportes', 'titulo', 'Reportes del chat ya revisados', 'detalle', 'Más de 90 días.', 'auto', true,
      'filas', (select count(*) from public.cfx_reportes where resuelto and creado < now() - interval '90 days')),
    jsonb_build_object('clave', 'n_carritos', 'titulo', 'Carritos abandonados', 'detalle', 'Sin tocar hace más de 30 días.', 'auto', true,
      'filas', (select count(*) from public.cfx_carritos where actualizado < now() - interval '30 days')));
end $$;

create or replace function public.cfx_limpiar_nucleo(p_clave text) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0;
begin
  if p_clave = 'n_registro' then delete from public.cfx_registro where creado < now() - interval '180 days';
  elsif p_clave = 'n_errores' then delete from public.cfx_errores where ultimo < now() - interval '30 days';
  elsif p_clave = 'n_reportes' then delete from public.cfx_reportes where resuelto and creado < now() - interval '90 days';
  elsif p_clave = 'n_carritos' then delete from public.cfx_carritos where actualizado < now() - interval '30 days';
  else return 0; end if;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.cfx_limpieza() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a jsonb := '[]';
begin
  perform public.cfx_es_admin();
  if to_regprocedure('public.cfx_limpieza_app()') is not null then
    execute 'select public.cfx_limpieza_app()' into a;
  end if;
  return public.cfx_limpieza_nucleo() || coalesce(a, '[]');
end $$;

create or replace function public.cfx_limpiar(p_clave text) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0;
begin
  perform public.cfx_es_admin();
  if p_clave like 'n\_%' then
    if not exists (select 1 from jsonb_array_elements(public.cfx_limpieza_nucleo()) x where x ->> 'clave' = p_clave) then raise exception 'Opción no válida'; end if;
    n := public.cfx_limpiar_nucleo(p_clave);
  elsif to_regprocedure('public.cfx_limpiar_app(text)') is not null then
    execute 'select public.cfx_limpiar_app($1)' into n using p_clave;
  else raise exception 'Opción no válida'; end if;
  perform public.cfx_anotar('limpieza', p_clave || ': ' || coalesce(n, 0) || ' borrados');
  return coalesce(n, 0);
end $$;

-- Cada noche (pg_cron 'cfx-limpieza'): borra lo del núcleo marcado "auto" y anota cuánto.
create or replace function public.cfx_limpieza_auto() returns int
language plpgsql security definer set search_path = '' as $$
declare x jsonb; n int := 0;
begin
  if not coalesce(((select valor from public.cfx_config where clave = 'limpieza_auto') #>> '{}')::boolean, true) then return 0; end if;
  for x in select * from jsonb_array_elements(public.cfx_limpieza_nucleo()) loop
    if (x ->> 'auto')::boolean and (x ->> 'filas')::int > 0 then n := n + public.cfx_limpiar_nucleo(x ->> 'clave'); end if;
  end loop;
  insert into public.cfx_salud (clave, valor, cuando) values ('limpieza', jsonb_build_object('filas', n), now())
  on conflict (clave) do update set valor = excluded.valor, cuando = excluded.cuando;
  if n > 0 then perform public.cfx_anotar('limpieza automática', n || ' filas viejas borradas'); end if;
  return n;
end $$;

-- Interruptor del Centro de Mando: { activo, ultima, filas }.
create or replace function public.cfx_limpieza_auto_ver() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object('activo', coalesce(((select valor from public.cfx_config where clave = 'limpieza_auto') #>> '{}')::boolean, true),
    'ultima', (select cuando from public.cfx_salud where clave = 'limpieza'), 'filas', (select (valor ->> 'filas')::int from public.cfx_salud where clave = 'limpieza'));
end $$;
create or replace function public.cfx_limpieza_auto_guardar(p_activo boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  insert into public.cfx_config (clave, valor) values ('limpieza_auto', to_jsonb(coalesce(p_activo, true)))
  on conflict (clave) do update set valor = excluded.valor;
  perform public.cfx_anotar('limpieza automática', case when coalesce(p_activo, true) then 'prendida' else 'apagada' end);
  return public.cfx_limpieza_auto_ver();
end $$;

revoke all on function public.cfx_limpieza_nucleo(), public.cfx_limpiar_nucleo(text), public.cfx_limpieza_auto() from public, anon, authenticated;
revoke all on function public.cfx_limpieza(), public.cfx_limpiar(text), public.cfx_limpieza_auto_ver(), public.cfx_limpieza_auto_guardar(boolean) from public, anon;
grant execute on function public.cfx_limpieza(), public.cfx_limpiar(text), public.cfx_limpieza_auto_ver(), public.cfx_limpieza_auto_guardar(boolean) to authenticated;
do $$
begin
  if to_regprocedure('public.cfx_limpieza_app()') is not null then revoke all on function public.cfx_limpieza_app() from public, anon, authenticated; end if;
  if to_regprocedure('public.cfx_limpiar_app(text)') is not null then revoke all on function public.cfx_limpiar_app(text) from public, anon, authenticated; end if;
end $$;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'cfx-limpieza';
  perform cron.schedule('cfx-limpieza', '40 7 * * *', 'select public.cfx_limpieza_auto()');
exception when others then
  raise notice 'Limpieza automática no programada (%).', sqlerrm;
end $$;

-- ---------- Analítica (E24 · E25 · E27): el análisis nocturno lo hace Python en GitHub Actions (SaaS: analisis.yml + analisis/analisis.py) ----------
-- 1) Python lee cfx_analisis_datos() con la conexión del respaldo (solo la base: nadie con cuenta puede llamarla).
-- 2) Calcula tendencias de la app (CM → 📊 Analítica) y, por negocio, clientes que dejaron de comprar y productos quietos (E27).
-- 3) Lo devuelve con cfx_analisis_guardar(): una fila 'app' y una por negocio en cfx_analisis.
-- Ganchos de cada app (opcionales; sin ellos hay solo números generales):
--   cfx_analisis_datos_app() → {ventas: [{n, c, f, m, l: [[clave, cant]]}], clientes: {c: {nombre, tel}}, productos: [{n, k, nombre, stock, creado}],
--                               negocios: [{id, nombre, creado, ingreso}]}
--   cfx_analisis_negocio(u) → uuid del negocio que ve ese usuario (null: ninguno). Módulo 'analisis' (🧩 en el CM).
create table if not exists public.cfx_analisis (clave text primary key, datos jsonb not null default '{}', calculado timestamptz not null default now());
alter table public.cfx_analisis enable row level security;
revoke all on public.cfx_analisis from anon, authenticated;

create or replace function public.cfx_analisis_datos() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a jsonb; d date := (now() at time zone 'America/Santiago')::date;
begin
  if to_regprocedure('public.cfx_analisis_datos_app()') is not null then execute 'select public.cfx_analisis_datos_app()' into a; end if;
  return jsonb_build_object('hoy', d, 'modulo', public.cfx_modulo('analisis'),
    'usuarios', (select jsonb_build_object('total', count(*),
        'activos7', count(*) filter (where last_sign_in_at > now() - interval '7 days'),
        'activos30', count(*) filter (where last_sign_in_at > now() - interval '30 days'),
        'dias', coalesce((select jsonb_object_agg(x.f, x.n) from (select (created_at at time zone 'America/Santiago')::date f, count(*) n from auth.users
          where created_at > now() - interval '61 days' and deleted_at is null group by 1) x), '{}'))
      from auth.users where deleted_at is null),
    'ingresos', coalesce((select jsonb_object_agg(x.f, x.m) from (select (coalesce(resuelto, creado) at time zone 'America/Santiago')::date f, sum(monto) m
      from public.cfx_pagos where estado = 'aprobado' and coalesce(resuelto, creado) > now() - interval '61 days' group by 1) x), '{}'),
    'premium', (select count(distinct cuenta) from public.cfx_pagos where estado = 'aprobado' and coalesce(resuelto, creado) > now() - interval '30 days'),
    'previo', coalesce((select jsonb_object_agg(clave, datos -> 'mov') from public.cfx_analisis where clave <> 'app' and datos ? 'mov'), '{}'),
    'app', a);
end $$;

create or replace function public.cfx_analisis_guardar(p jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare n int := 0; k text; v jsonb;
begin
  if jsonb_typeof(p -> 'app') = 'object' then
    insert into public.cfx_analisis (clave, datos, calculado) values ('app', p -> 'app', now())
    on conflict (clave) do update set datos = excluded.datos, calculado = now();
  end if;
  delete from public.cfx_analisis where clave <> 'app' and not (coalesce(p -> 'negocios', '{}') ? clave);
  for k, v in select * from jsonb_each(coalesce(p -> 'negocios', '{}')) loop
    insert into public.cfx_analisis (clave, datos, calculado) values (k, v, now())
    on conflict (clave) do update set datos = excluded.datos, calculado = now();
    n := n + 1;
  end loop;
  perform public.cfx_salud_marca('analisis', jsonb_build_object('negocios', n, 'run', coalesce(p ->> 'run', '')));
  return n;
end $$;
revoke all on function public.cfx_analisis_datos(), public.cfx_analisis_guardar(jsonb) from public, anon, authenticated;

-- Centro de Mando → 📊 Analítica.
create or replace function public.cfx_analisis_app() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return (select datos || jsonb_build_object('calculado', calculado) from public.cfx_analisis where clave = 'app');
end $$;
revoke all on function public.cfx_analisis_app() from public, anon;
grant execute on function public.cfx_analisis_app() to authenticated;

-- Para el negocio (E27): sus clientes en riesgo y productos quietos (sin la foto interna del stock).
create or replace function public.cfx_analisis_mio() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare n uuid;
begin
  if auth.uid() is null or not public.cfx_modulo('analisis') or to_regprocedure('public.cfx_analisis_negocio(uuid)') is null then return null; end if;
  execute 'select public.cfx_analisis_negocio($1)' into n using auth.uid();
  if n is null or not public.cfx_modulo_de('analisis', n) then return null; end if;
  return (select (datos - 'mov') || jsonb_build_object('calculado', calculado) from public.cfx_analisis where clave = n::text);
end $$;
revoke all on function public.cfx_analisis_mio() from public, anon;
grant execute on function public.cfx_analisis_mio() to authenticated;

-- ---------- G32 d · 🔑 Entrar con QR (núcleo): el celular con sesión aprueba y el computador entra sin escribir la clave ----------
-- 1) El computador (sin cuenta) pide un código: cfx_qr_crear → { token (va en el QR), codigo (6 letras para escribir), secreto (solo el PC) }.
-- 2) El celular con sesión lo abre o lo escribe: cfx_qr_ver muestra qué computador es → "Sí, entrar" = cfx_qr_aprobar.
-- 3) El computador pregunta cada 2 s (cfx_qr_estado). Aprobado → la Edge Function (clave de servidor) canjea UNA vez (cfx_qr_canjear)
--    y devuelve un enlace mágico de un solo uso; el computador lo usa y queda con sesión. Vence a los 2 minutos.
create table if not exists public.cfx_login_qr (
  token       text primary key,
  codigo      text not null,
  secreto     text not null,              -- sha256 del secreto (el secreto real solo lo tiene el computador)
  equipo      text,
  user_id     uuid references auth.users(id) on delete cascade,
  aprobado_at timestamptz,
  usado_at    timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists cfx_login_qr_codigo on public.cfx_login_qr (codigo);
alter table public.cfx_login_qr enable row level security;
revoke all on public.cfx_login_qr from anon, authenticated;

create or replace function public.cfx_qr_crear(p_equipo text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t text; c text; s text; L text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; b bytea; i int;
begin
  delete from public.cfx_login_qr where created_at < now() - interval '10 minutes';
  if (select count(*) from public.cfx_login_qr where created_at > now() - interval '2 minutes') > 300 then
    return jsonb_build_object('ok', false, 'error', 'Muchos intentos. Espera un minuto.');
  end if;
  t := encode(extensions.gen_random_bytes(18), 'hex');
  s := encode(extensions.gen_random_bytes(24), 'hex');
  loop
    b := extensions.gen_random_bytes(6); c := '';
    for i in 0..5 loop c := c || substr(L, 1 + get_byte(b, i) % length(L), 1); end loop;
    exit when not exists (select 1 from public.cfx_login_qr where codigo = c and usado_at is null);
  end loop;
  insert into public.cfx_login_qr (token, codigo, secreto, equipo)
  values (t, c, encode(extensions.digest(s, 'sha256'), 'hex'), left(nullif(regexp_replace(coalesce(p_equipo, ''), '[^[:alnum:] ·.()-]', '', 'g'), ''), 60));
  return jsonb_build_object('ok', true, 'token', t, 'codigo', c, 'secreto', s, 'vence', 120);
end $$;
grant execute on function public.cfx_qr_crear(text) to anon, authenticated;

-- p = token del QR o el código de 6 letras. Solo códigos de menos de 2 minutos, sin aprobar.
create or replace function public.cfx_qr_buscar(p text) returns public.cfx_login_qr
language sql stable security definer set search_path = '' as $$
  select * from public.cfx_login_qr
  where (token = lower(trim(p)) or codigo = upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')))
    and created_at > now() - interval '2 minutes' and aprobado_at is null and usado_at is null
  order by created_at desc limit 1 $$;
revoke all on function public.cfx_qr_buscar(text) from public, anon, authenticated;

create or replace function public.cfx_qr_ver(p text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare q public.cfx_login_qr := public.cfx_qr_buscar(p);
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'Primero inicia sesión en este celular'); end if;
  if q.token is null then return jsonb_build_object('ok', false, 'error', 'El código venció o no existe. En el computador toca "Otro código".'); end if;
  return jsonb_build_object('ok', true, 'equipo', coalesce(q.equipo, 'Computador'),
    'segundos', greatest(0, 120 - extract(epoch from now() - q.created_at)::int));
end $$;
revoke all on function public.cfx_qr_ver(text) from public, anon;
grant execute on function public.cfx_qr_ver(text) to authenticated;

-- El computador pregunta: esperando | aprobado | vencido (con su secreto: nadie más puede preguntar).
create or replace function public.cfx_qr_estado(p_token text, p_secreto text) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select case when usado_at is not null then 'vencido'
                               when aprobado_at is not null and aprobado_at > now() - interval '2 minutes' then 'aprobado'
                               when aprobado_at is null and created_at > now() - interval '2 minutes' then 'esperando'
                               else 'vencido' end
    from public.cfx_login_qr where token = p_token and secreto = encode(extensions.digest(coalesce(p_secreto, ''), 'sha256'), 'hex')), 'vencido') $$;
grant execute on function public.cfx_qr_estado(text, text) to anon, authenticated;


-- ---------- G32 f · 🔒 3 claves malas: no se bloquea la cuenta, solo la clave y el QR; se entra con el enlace al correo (gratis) ----------
-- Se cuenta por correo (exista o no la cuenta: no revela nada). Al entrar con el enlace (amr otp/magiclink) se desbloquea.
create table if not exists public.cfx_login_fallos (
  email      text primary key,
  fallos     int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.cfx_login_fallos enable row level security;
revoke all on public.cfx_login_fallos from anon, authenticated;

create or replace function public.cfx_login_bloqueado(p_email text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select fallos >= 3 from public.cfx_login_fallos where email = lower(trim(coalesce(p_email, '')))), false) $$;
grant execute on function public.cfx_login_bloqueado(text) to anon, authenticated;

-- Clave mala → suma 1 y responde si quedó bloqueada (y cuántos intentos quedan).
create or replace function public.cfx_login_fallo(p_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare e text := lower(trim(coalesce(p_email, ''))); n int;
begin
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return jsonb_build_object('ok', false); end if;
  delete from public.cfx_login_fallos where updated_at < now() - interval '30 days';
  insert into public.cfx_login_fallos (email, fallos) values (e, 1)
  on conflict (email) do update set fallos = least(public.cfx_login_fallos.fallos + 1, 99), updated_at = now()
  returning fallos into n;
  return jsonb_build_object('ok', true, 'bloqueado', n >= 3, 'quedan', greatest(0, 3 - n));
end $$;
grant execute on function public.cfx_login_fallo(text) to anon, authenticated;

-- Con sesión: clave correcta (sin bloqueo) o entró por el enlace del correo → contador a cero. 'estaba' = venía bloqueada (ofrecer cambiar la clave).
create or replace function public.cfx_login_desbloquear() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare e text := lower(coalesce(auth.jwt() ->> 'email', '')); f int; enlace boolean;
begin
  if auth.uid() is null or e = '' then return jsonb_build_object('ok', false); end if;
  enlace := exists (select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a where a ->> 'method' in ('otp', 'magiclink', 'email/signup', 'recovery'));
  select fallos into f from public.cfx_login_fallos where email = e;
  if f is null then return jsonb_build_object('ok', true, 'estaba', false); end if;
  if f >= 3 and not enlace then return jsonb_build_object('ok', false, 'bloqueado', true); end if;
  delete from public.cfx_login_fallos where email = e;
  return jsonb_build_object('ok', true, 'estaba', f >= 3);
end $$;
revoke all on function public.cfx_login_desbloquear() from public, anon;
grant execute on function public.cfx_login_desbloquear() to authenticated;

-- Aprobar (celular) y canjear (solo la Edge Function, clave de servidor: marca el código usado UNA vez y entrega el correo).
-- El QR también queda cerrado mientras la cuenta esté protegida.
create or replace function public.cfx_qr_aprobar(p text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare q public.cfx_login_qr := public.cfx_qr_buscar(p);
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'Primero inicia sesión en este celular'); end if;
  if public.cfx_login_bloqueado(auth.jwt() ->> 'email') then return jsonb_build_object('ok', false, 'error', '🔒 Tu cuenta está protegida por 3 claves malas. Entra en el computador con el enlace de tu correo.'); end if;
  if q.token is null then return jsonb_build_object('ok', false, 'error', 'El código venció o no existe. En el computador toca "Otro código".'); end if;
  update public.cfx_login_qr set user_id = auth.uid(), aprobado_at = now() where token = q.token and aprobado_at is null;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.cfx_qr_aprobar(text) from public, anon;
grant execute on function public.cfx_qr_aprobar(text) to authenticated;

create or replace function public.cfx_qr_canjear(p_token text, p_secreto text) returns text
language plpgsql security definer set search_path = '' as $$
declare u uuid; m text;
begin
  update public.cfx_login_qr set usado_at = now()
  where token = p_token and secreto = encode(extensions.digest(coalesce(p_secreto, ''), 'sha256'), 'hex')
    and aprobado_at is not null and aprobado_at > now() - interval '2 minutes' and usado_at is null
  returning user_id into u;
  if u is null then return null; end if;
  m := (select email from auth.users where id = u);
  if public.cfx_login_bloqueado(m) then return null; end if;
  return m;
end $$;
revoke all on function public.cfx_qr_canjear(text, text) from public, anon, authenticated;
grant execute on function public.cfx_qr_canjear(text, text) to service_role;

-- ---------- Seguridad (A7): lo que puede hacer alguien sin cuenta (anon) y los buckets de archivos ----------
-- Va al final del núcleo: así alcanza a todas las funciones de la app.
-- 1) En Supabase anon recibe permiso para TODA función nueva ("revoke ... from public" no se lo quita). Las que lo primero que hacen es
--    exigir ser admin igual fallarían: se les quita el permiso a anon (no cambia nada para quien tiene cuenta).
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as fn from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute')
      and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
      and substring(lower(p.prosrc) from '\mbegin\M(.*)$') ~ ('^\s*perform\s+' || regexp_replace(lower('public.cfx_es_admin()'), '([().])', '\\\1', 'g') || '\s*;')
  loop
    execute 'revoke execute on function ' || f.fn || ' from public, anon';
  end loop;
end $$;
revoke execute on function public.cfx_anotar(text, text) from public, anon;

-- 2) Buckets públicos (se ven con su dirección): solo fotos y de hasta 5 MB, si la app no puso otro límite.
update storage.buckets set file_size_limit = 5242880 where public and file_size_limit is null;
update storage.buckets set allowed_mime_types = array['image/webp', 'image/jpeg', 'image/png'] where public and allowed_mime_types is null;

-- 3) Revisión para el Centro de Mando → Control → 🛡️ Seguridad.
create or replace function public.cfx_seguridad() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.cfx_es_admin();
  return jsonb_build_object(
    'sin_rls', coalesce((select jsonb_agg(c.relname order by c.relname) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
        and (has_table_privilege('anon', c.oid, 'select') or has_table_privilege('anon', c.oid, 'insert,update,delete'))), '[]'),
    'anon_escribe', coalesce((select jsonb_agg(p.tablename || ' · ' || lower(p.cmd) order by p.tablename) from pg_policies p
      where p.schemaname = 'public' and p.cmd <> 'SELECT' and (p.roles @> '{anon}' or p.roles @> '{public}')), '[]'),
    'anon_lee', coalesce((select jsonb_agg(distinct p.tablename) from pg_policies p
      where p.schemaname = 'public' and p.cmd in ('SELECT', 'ALL') and (p.roles @> '{anon}' or p.roles @> '{public}')), '[]'),
    'funciones_anon', coalesce((select jsonb_agg(p.proname order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')), '[]'),
    'buckets', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'publico', b.public, 'mb', round(b.file_size_limit / 1048576.0, 1),
        'tipos', b.allowed_mime_types,
        'anon_lista', exists (select 1 from pg_policies p where p.schemaname = 'storage' and p.tablename = 'objects'
          and p.cmd in ('SELECT', 'ALL') and (p.roles @> '{anon}' or p.roles @> '{public}'))) order by b.id) from storage.buckets b), '[]'),
    'humano', public.cfx_humano() - 'site_key' || jsonb_build_object('activo', coalesce(public.cfx_humano() ->> 'site_key', '') <> ''));
end $$;
revoke all on function public.cfx_seguridad() from public, anon;
grant execute on function public.cfx_seguridad() to authenticated;
-- ---------- G33 🌐 Dominio de CodeFix (núcleo 2.69, se puede volver a correr) ----------
-- El CM (Control → 🌐 Dominio) arma los dominios en Cloudflare y le guarda a cada app su dirección: ej. https://despega.codefix.cl/
-- "activo" = Cloudflare ya lo sirve. Mientras no esté activo (o vacío) todo sigue en workers.dev como hoy.
-- Público (no es secreto): las apps lo usan para armar links, QR y correos.
insert into public.cfx_config (clave, valor) values ('sitio', '{"dominio": "", "url": "", "activo": false}') on conflict (clave) do nothing;
create or replace function public.cfx_sitio() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select valor from public.cfx_config where clave = 'sitio'), '{"dominio": "", "url": "", "activo": false}'::jsonb) $$;
revoke all on function public.cfx_sitio() from public;
grant execute on function public.cfx_sitio() to anon, authenticated;
-- Dirección de la app para correos y links del servidor: null si no hay dominio activo (se usa la de siempre).
create or replace function public.cfx_sitio_url() returns text
language sql stable security definer set search_path = '' as $$
  select case when (valor->>'activo')::boolean and coalesce(valor->>'url', '') <> '' then valor->>'url' end
  from public.cfx_config where clave = 'sitio' $$;
revoke all on function public.cfx_sitio_url() from public;
grant execute on function public.cfx_sitio_url() to anon, authenticated;
create or replace function public.cfx_sitio_guardar(p_dominio text, p_url text, p_activo boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare d text := nullif(lower(trim(regexp_replace(coalesce(p_dominio, ''), '^https?://|/.*$|\.$', '', 'gi'))), '');
        u text := nullif(lower(trim(coalesce(p_url, ''))), '');
begin
  perform public.cfx_es_admin();
  if d is not null and (d !~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$' or length(d) > 80) then raise exception 'Escribe solo el dominio, ej: codefix.cl'; end if;
  if u is not null and (u !~ '^https://([a-z0-9-]+\.)+[a-z]{2,24}/$' or d is null or right(u, length(d) + 1) <> d || '/') then raise exception 'Dirección no válida'; end if;
  insert into public.cfx_config (clave, valor) values ('sitio', jsonb_build_object('dominio', coalesce(d, ''), 'url', coalesce(u, ''), 'activo', d is not null and u is not null and coalesce(p_activo, false)))
    on conflict (clave) do update set valor = excluded.valor;
  return public.cfx_sitio();
end $$;
revoke all on function public.cfx_sitio_guardar(text, text, boolean) from public, anon;
grant execute on function public.cfx_sitio_guardar(text, text, boolean) to authenticated;
-- <<< CFX núcleo

-- =====================================================================
-- Actualización automática (núcleo CodeFix): cada 10 minutos la base revisa GitHub (rama main).
--   · Si hay una base nueva (version.json), descarga y ejecuta este mismo instalar.sql (no borra datos).
--   · La app la liberas tú cuando la pruebes (panel de la app o Centro de Mando → Liberar).
--   Si algo falla no cambia nada y lo reintenta en la siguiente vuelta. Hay que correr este archivo UNA vez.
-- =====================================================================
create or replace function public.auto_actualizar() returns text
language plpgsql security definer set search_path = '' as $f$
declare
  base constant text := 'https://raw.githubusercontent.com/CodeFixService/Estacionamiento/main/';
  marca text := '?t=' || extract(epoch from now())::bigint; j jsonb; v_bd text; v_app text; codigo text; lib text;
  re constant text := '^[0-9]+(\.[0-9]+)*$';
begin
  execute 'select content from extensions.http_get($1)' into codigo using base || 'version.json' || marca;
  j := codigo::jsonb; v_bd := j ->> 'bd'; v_app := j ->> 'version';
  if v_bd ~ re and coalesce(((select valor #>> '{}' from public.config where clave = 'version_bd'))::text, '0') ~ re and string_to_array(v_bd, '.')::int[] > string_to_array(coalesce(((select valor #>> '{}' from public.config where clave = 'version_bd'))::text, '0'), '.')::int[] then
    execute 'select content from extensions.http_get($1)' into codigo using base || 'supabase/instalar.sql' || marca;
    if codigo is null or length(codigo) < 1000 then return 'instalar.sql no disponible'; end if;
    execute codigo;
    return 'base actualizada a ' || ((select valor #>> '{}' from public.config where clave = 'version_bd'))::text;
  end if;
  -- La app NO se libera sola: la liberas tú desde el panel o el Centro de Mando después de probarla.
  return 'al día';
exception when others then
  return 'sin cambios: ' || sqlerrm;
end $f$;
revoke execute on function public.auto_actualizar() from public, anon, authenticated;
do $$
begin
  create extension if not exists http with schema extensions;
  perform cron.unschedule(jobid) from cron.job where jobname = 'cfx-auto';
  perform cron.schedule('cfx-auto', '*/10 * * * *', 'select public.auto_actualizar()');
exception when others then
  raise notice 'Actualización automática no activada (%). Activa pg_cron en Supabase y vuelve a correr este archivo.', sqlerrm;
end $$;

select 'Estaciona v4 instalada ✅' as resultado;
