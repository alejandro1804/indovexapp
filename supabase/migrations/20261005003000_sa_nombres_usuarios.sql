-- ============================================================
-- Auditoria: nombres de usuarios para el super admin
--
-- El super admin ve la auditoria de todas las empresas, pero
-- por RLS solo puede leer los usuarios de la suya. La pantalla
-- no encontraba el nombre y mostraba "Sistema".
--
-- Esta funcion devuelve id y nombre de los usuarios pedidos,
-- SOLO si quien llama es super admin. Para cualquier otro
-- usuario devuelve vacio.
-- ============================================================

create or replace function public.sa_nombres_usuarios(p_ids uuid[])
 returns table(id uuid, nombre text)
 language sql
 stable
 security definer
 set search_path = public
as $function$
  select u.id, u.nombre
  from public.usuarios u
  where public.es_super_admin()
    and u.id = any(p_ids);
$function$;

comment on function public.sa_nombres_usuarios(uuid[]) is
  'Nombres de usuarios por id, de cualquier empresa. Solo super admin; para el resto devuelve vacio.';