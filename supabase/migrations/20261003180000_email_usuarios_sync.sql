-- ============================================================
-- Email de usuarios: auth.users como fuente de verdad
--
-- 1. proteger_campos_usuario: usuarios.email solo puede tomar
--    el valor que tiene auth.users para ese id. Vale para
--    todos, super admin incluido.
-- 2. fn_sync_email_usuario + trg_sync_email_usuario: cuando
--    cambia auth.users.email, se replica a usuarios.email.
--
-- Resultado: el unico camino para cambiar un mail es Auth.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Regla de email en el trigger de proteccion existente
--    (el resto de la funcion queda igual que antes)
-- ------------------------------------------------------------
create or replace function public.proteger_campos_usuario()
 returns trigger
 language plpgsql
 security definer
as $function$
begin
  -- El email no se edita directo: solo puede igualar al de auth.users
  if new.email is distinct from old.email then
    if not exists (
      select 1
      from auth.users a
      where a.id = new.id
        and lower(a.email) = lower(new.email)
    ) then
      raise exception 'No autorizado: el email solo se cambia desde Auth';
    end if;
  end if;

  -- Super admin puede cambiar todo lo demas
  if es_super_admin() then
    return new;
  end if;

  -- Bloquear es_super_admin para todos los demas
  if new.es_super_admin is distinct from old.es_super_admin then
    raise exception 'No autorizado: no se puede modificar es_super_admin';
  end if;

  -- Bloquear empresa_id para todos los demas
  if new.empresa_id is distinct from old.empresa_id then
    raise exception 'No autorizado: no se puede modificar empresa_id';
  end if;

  -- Bloquear cambio de rol_id SOLO sobre el propio usuario (auto-promocion)
  if new.rol_id is distinct from old.rol_id and old.id = auth.uid() then
    raise exception 'No autorizado: no se puede cambiar el rol propio';
  end if;

  return new;
end;
$function$;


-- ------------------------------------------------------------
-- 2. Sincronizacion auth.users.email -> usuarios.email
--
--    search_path fijo en public: Auth se conecta con otro
--    search_path, y los triggers de usuarios (proteccion,
--    auditoria, updated_at) llaman funciones de public sin
--    calificar. Sin esto fallarian al dispararse desde aca.
-- ------------------------------------------------------------
create or replace function public.fn_sync_email_usuario()
 returns trigger
 language plpgsql
 security definer
 set search_path = public, extensions
as $function$
begin
  update public.usuarios
     set email = new.email
   where id = new.id
     and email is distinct from new.email;

  return new;
end;
$function$;


drop trigger if exists trg_sync_email_usuario on auth.users;

create trigger trg_sync_email_usuario
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.fn_sync_email_usuario();