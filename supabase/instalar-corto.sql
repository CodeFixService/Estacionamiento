-- Instalación corta (para pegar desde el celular): descarga y ejecuta supabase/instalar.sql desde GitHub.
create extension if not exists http with schema extensions;
do $$ begin
  execute (select content from extensions.http_get('https://raw.githubusercontent.com/CodeFixService/Estacionamiento/main/supabase/instalar.sql'));
end $$;
