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
language sql stable security definer set search_path = public as $$
  select coalesce((select es_admin from public.perfiles where id = auth.uid()), false)
$$;

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
    'comuna', p.comuna, 'bio', p.bio, 'verificado', p.verificado, 'premium', public._premium(p), 'admin', p.es_admin,
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
    perform public._notificar(p_id, 'Verificación rechazada', coalesce(nullif(trim(p_motivo), ''), 'Fotos poco claras') || '. Vuelve a enviarla.', '#/verificar');
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
  perform public._notificar(d.autor, 'Revisamos tu denuncia', case when p_accion = 'descartar' then 'No encontramos una falta. Gracias por avisar.'
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
insert into public.config (clave, valor) values ('version_bd', '4') on conflict (clave) do update set valor = excluded.valor;
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
    perform public._notificar(r.dueno, 'Reserva liberada', 'Una reserva no se pagó a tiempo y se liberó', '#/reservas');
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
        perform public._notificar(o.arrendatario, 'Solicitud no aceptada', '"' || e.titulo || '" ya fue arrendado', '#/reservas');
      end loop;
    end if;
  else
    update public.arriendos set estado = 'rechazado', motivo = left(nullif(trim(p_motivo), ''), 300), expira_at = null,
      pago_estado = case when a.saldo_aplicado > 0 then 'saldo' when a.pago_estado = 'en_revision' then 'rechazado' else a.pago_estado end,
      saldo_monto = a.saldo_aplicado,
      saldo_hasta = case when a.saldo_aplicado > 0 then now() + make_interval(days => public._cfg('dias_saldo')) end,
      actualizado = now() where id = p_id;
    perform public._notificar(a.arrendatario, 'Reserva no aceptada', coalesce(nullif(trim(p_motivo), ''), 'El dueño de "' || e.titulo || '" no aceptó tu reserva'), '#/reservas');
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
    perform public._notificar(otro, 'Reserva cancelada', yo.nombre || ' canceló la reserva de "' || t || '"', '#/reservas');
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
    perform public._notificar(otro, 'Reserva cancelada', yo.nombre || ' canceló "' || t || '". ' || txt, '#/reservas');
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
    perform public._notificar(g.usuario, 'Pago no aprobado', coalesce(nullif(trim(p_motivo), ''), 'No encontramos tu pago') || '. Escríbenos a soporte.', '#/premium');
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

-- =====================================================================
-- Actualización automática (núcleo CodeFix): cada 10 minutos la base revisa GitHub (rama main).
--   · Si hay una base nueva (version.json), descarga y ejecuta este mismo instalar.sql (no borra datos).
--   · Si solo cambió la app, la libera para que los celulares se actualicen solos.
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
  -- Solo cambió la app (la base ya está al día): se libera para que los celulares se actualicen solos.
  if v_app ~ re and v_bd = ((select valor #>> '{}' from public.config where clave = 'version_bd'))::text then
    lib := (select valor from public.textos where clave = 'version_liberada');
    if lib is null or lib !~ re or string_to_array(v_app, '.')::int[] > string_to_array(lib, '.')::int[] then
      insert into public.textos (clave, valor) values ('version_liberada', v_app) on conflict (clave) do update set valor = excluded.valor;
      return 'app liberada ' || v_app;
    end if;
  end if;
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
