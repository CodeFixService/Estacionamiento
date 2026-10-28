-- Instalación corta (para pegar desde el celular): descarga y ejecuta supabase/instalar.sql desde GitHub.
-- Siempre la última (rama main). Basta con correrla UNA vez: después la base se actualiza sola cada 10 minutos.
create extension if not exists http with schema extensions;
do $$ begin
  execute (select content from extensions.http_get('https://raw.githubusercontent.com/CodeFixService/Estacionamiento/main/supabase/instalar.sql?t=' || extract(epoch from now())::bigint));
end $$;
select 'Estaciona instalada v' || (select valor #>> '{}' from public.config where clave = 'version_bd') as resultado;
