-- ============================================================
-- Seguridad: nadie puede INSERTAR un usuario con
-- es_super_admin = true (salvo un super admin).
--
-- proteger_campos_usuario solo corre en UPDATE, y la politica
-- usuarios_admin_insertar solo valida empresa_id. Sin este
-- trigger, un usuario de cualquier empresa podia insertar una
-- fila marcada como super admin.
--
-- Por orden alfabetico, este trigger corre antes que
-- trg_validar_empresa_usuario_rol y trg_validar_limite_usuarios.
-- ============================================================

create or replace function public.fn_proteger_insert_usuario()
 returns trigger
 language plpgsql
 security definer
 set search_path = public
as $function$
begin
  if new.es_super_admin is true and not es_super_admin() then
    raise exception 'No autorizado: no se puede crear un super admin';
  end if;

  return new;
end;
$function$;


drop trigger if exists trg_proteger_insert_usuario on public.usuarios;

create trigger trg_proteger_insert_usuario
  before insert on public.usuarios
  for each row
  execute function public.fn_proteger_insert_usuario();