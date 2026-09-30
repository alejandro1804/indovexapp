-- supabase/migrations/YYYYMMDD_get_empresa_id_valida_estado.sql
-- Refuerzo de seguridad: get_empresa_id() devuelve NULL si el usuario
-- no está activo. Como casi todas las policies validan
-- (... = get_empresa_id()), un usuario desactivado deja de tener acceso
-- aunque tenga una sesión abierta — la comparación contra NULL da falso.

CREATE OR REPLACE FUNCTION public.get_empresa_id()
RETURNS uuid
LANGUAGE sql
STABLE SECURITY DEFINER
AS $function$
  select empresa_id
  from public.usuarios
  where id = auth.uid()
    and estado = 'activo'   -- usuario desactivado => no devuelve empresa
  limit 1;
$function$;

-- También reforzamos es_super_admin(): un super admin desactivado
-- (caso poco probable pero posible) tampoco debe conservar privilegios.
CREATE OR REPLACE FUNCTION public.es_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
AS $function$
  select coalesce(
    (select es_super_admin
     from public.usuarios
     where id = auth.uid()
       and estado = 'activo'),
    false
  );
$function$;