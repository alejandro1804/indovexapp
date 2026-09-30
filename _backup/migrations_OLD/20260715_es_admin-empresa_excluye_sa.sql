-- =====================================================================
-- Fix: es_admin_empresa() debe excluir al super admin.
--
-- Contexto: la cuenta de super admin tiene rol 'admin' en una empresa
-- (Demo), y ese rol tiene gestionar_usuarios + gestionar_roles. Sin este
-- filtro, es_admin_empresa() devolvia true para el super admin operando
-- en modo cliente, habilitandolo a aceptar documentos legales en nombre
-- de una empresa que no representa (T&C cl. 1: el Cliente es la persona
-- juridica).
--
-- Espeja Usuario.esAdminEmpresa en Flutter, que aplica la misma
-- exclusion.
-- =====================================================================

create or replace function public.es_admin_empresa()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    -- El super admin no obliga contractualmente a ninguna empresa,
    -- aunque su rol tenga los permisos operativos.
    not coalesce(
      (select es_super_admin from public.usuarios where id = auth.uid()),
      false
    )
    and exists (select 1 from mis_permisos() p where p = 'gestionar_usuarios')
    and exists (select 1 from mis_permisos() p where p = 'gestionar_roles');
$$;

comment on function public.es_admin_empresa() is
  'true si el usuario actual puede obligar contractualmente a su empresa (T&C cl. 1). Exige gestionar_usuarios AND gestionar_roles, y excluye al super admin.';

revoke all on function public.es_admin_empresa() from public;
grant execute on function public.es_admin_empresa() to authenticated;