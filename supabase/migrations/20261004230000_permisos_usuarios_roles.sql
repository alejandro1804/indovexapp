-- ============================================================
-- Permisos reales en la base para usuarios y roles
--
-- Hasta ahora los permisos gestionar_usuarios y gestionar_roles
-- se controlaban solo en la app. Esta migracion los hace valer
-- en la base:
--
-- 1. tiene_permiso(codigo): helper para politicas y funciones.
-- 2. proteger_campos_usuario: nadie cambia su propio estado y
--    un usuario comun no modifica la fila de un super admin.
-- 3. usuarios: modificar a otros exige gestionar_usuarios.
--    El alta directa se elimina (va solo por crear_usuario).
-- 4. roles / rol_permisos: lectura abierta a la empresa;
--    escritura solo con gestionar_roles.
-- 5. usuario_sector: lectura abierta; escritura solo con
--    gestionar_usuarios.
-- 6. crear_rol, renombrar_rol, eliminar_rol y
--    establecer_permisos_rol chequean gestionar_roles.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Helper: el usuario actual, activo, tiene el permiso?
-- ------------------------------------------------------------
create or replace function public.tiene_permiso(p_codigo text)
 returns boolean
 language sql
 stable
 security definer
 set search_path = public
as $function$
  select exists (
    select 1
    from public.usuarios u
    join public.rol_permisos rp on rp.rol_id = u.rol_id
    join public.permisos p on p.id = rp.permiso_id
    where u.id = auth.uid()
      and u.estado = 'activo'
      and p.codigo = p_codigo
  );
$function$;

comment on function public.tiene_permiso(text) is
  'true si el usuario actual esta activo y su rol tiene el permiso indicado.';


-- ------------------------------------------------------------
-- 2. proteger_campos_usuario
--    Se agregan dos reglas; el resto queda igual.
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

  -- NUEVO: un usuario de la app no puede modificar la fila de un super admin.
  -- (auth.uid() nulo = backend: Edge Functions, Auth, SQL Editor)
  if old.es_super_admin is true and auth.uid() is not null then
    raise exception 'No autorizado: no se puede modificar a un super admin';
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

  -- NUEVO: nadie cambia su propio estado (un desactivado no se reactiva solo)
  if new.estado is distinct from old.estado and old.id = auth.uid() then
    raise exception 'No autorizado: no se puede cambiar el estado propio';
  end if;

  return new;
end;
$function$;


-- ------------------------------------------------------------
-- 3. usuarios
--    - usuarios_actualizar_propio no se toca (cada uno edita lo suyo).
--    - Modificar a otros exige gestionar_usuarios.
--    - Se elimina el INSERT directo: el alta va por la Edge
--      Function crear_usuario (service role).
-- ------------------------------------------------------------
drop policy if exists usuarios_admin_insertar on public.usuarios;
drop policy if exists usuarios_admin_actualizar on public.usuarios;

create policy usuarios_admin_actualizar on public.usuarios
  for update to authenticated
  using (
    (empresa_id = public.get_empresa_id() and public.tiene_permiso('gestionar_usuarios'))
    or public.es_super_admin()
  )
  with check (
    (empresa_id = public.get_empresa_id() and public.tiene_permiso('gestionar_usuarios'))
    or public.es_super_admin()
  );


-- ------------------------------------------------------------
-- 4. roles y rol_permisos
--    - Leer: toda la empresa (igual que antes).
--    - roles: UPDATE directo solo con gestionar_roles (lo usa el
--      interruptor "restringe por ubicacion"). Crear, renombrar y
--      eliminar van por las funciones del punto 6.
--    - rol_permisos: sin escritura directa; va por
--      establecer_permisos_rol.
-- ------------------------------------------------------------
drop policy if exists roles_mi_empresa on public.roles;

create policy roles_ver_mi_empresa on public.roles
  for select
  using (empresa_id = public.get_empresa_id());

create policy roles_actualizar_mi_empresa on public.roles
  for update to authenticated
  using (
    empresa_id = public.get_empresa_id()
    and (public.tiene_permiso('gestionar_roles') or public.es_super_admin())
  )
  with check (
    empresa_id = public.get_empresa_id()
    and (public.tiene_permiso('gestionar_roles') or public.es_super_admin())
  );

drop policy if exists rol_permisos_mi_empresa on public.rol_permisos;

create policy rol_permisos_ver_mi_empresa on public.rol_permisos
  for select
  using (
    rol_id in (
      select roles.id
      from public.roles
      where roles.empresa_id = public.get_empresa_id()
    )
  );


-- ------------------------------------------------------------
-- 5. usuario_sector
--    - Leer: toda la empresa (igual que antes).
--    - Asignar o quitar ubicaciones: solo con gestionar_usuarios.
-- ------------------------------------------------------------
drop policy if exists usuario_sector_mi_empresa on public.usuario_sector;

create policy usuario_sector_ver_mi_empresa on public.usuario_sector
  for select
  using (empresa_id = public.get_empresa_id());

create policy usuario_sector_gestionar on public.usuario_sector
  for all to authenticated
  using (
    empresa_id = public.get_empresa_id()
    and (public.tiene_permiso('gestionar_usuarios') or public.es_super_admin())
  )
  with check (
    empresa_id = public.get_empresa_id()
    and (public.tiene_permiso('gestionar_usuarios') or public.es_super_admin())
  );


-- ------------------------------------------------------------
-- 6. Funciones de roles: chequeo de permiso al entrar.
--    El cuerpo de cada una queda igual que antes.
-- ------------------------------------------------------------
create or replace function public.crear_rol(p_nombre text)
 returns uuid
 language plpgsql
 security definer
 set search_path = public
as $function$
declare
  v_empresa_id uuid;
  v_nuevo_id uuid;
begin
  if not (tiene_permiso('gestionar_roles') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para gestionar roles';
  end if;

  v_empresa_id := get_empresa_id();
  if v_empresa_id is null then
    raise exception 'No se pudo determinar la empresa';
  end if;

  insert into public.roles (empresa_id, nombre)
  values (v_empresa_id, lower(trim(p_nombre)))
  returning id into v_nuevo_id;

  return v_nuevo_id;
end;
$function$;


create or replace function public.renombrar_rol(p_rol_id uuid, p_nombre text)
 returns void
 language plpgsql
 security definer
 set search_path = public
as $function$
declare
  v_empresa_id uuid;
  v_nombre_actual text;
begin
  if not (tiene_permiso('gestionar_roles') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para gestionar roles';
  end if;

  v_empresa_id := get_empresa_id();

  select nombre into v_nombre_actual
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre_actual is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  if v_nombre_actual in ('admin', 'encargado', 'tecnico') then
    raise exception 'El rol "%" es un rol del sistema y no se puede renombrar', v_nombre_actual;
  end if;

  update public.roles
  set nombre = lower(trim(p_nombre))
  where id = p_rol_id and empresa_id = v_empresa_id;
end;
$function$;


create or replace function public.eliminar_rol(p_rol_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path = public
as $function$
declare
  v_empresa_id uuid;
  v_nombre text;
  v_usuarios int;
begin
  if not (tiene_permiso('gestionar_roles') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para gestionar roles';
  end if;

  v_empresa_id := get_empresa_id();

  select nombre into v_nombre
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  if v_nombre in ('admin', 'encargado', 'tecnico') then
    raise exception 'El rol "%" es un rol del sistema y no se puede eliminar', v_nombre;
  end if;

  select count(*) into v_usuarios
  from public.usuarios
  where rol_id = p_rol_id;

  if v_usuarios > 0 then
    raise exception 'El rol tiene % usuario(s) asignado(s). Reasignalos antes de eliminar.', v_usuarios;
  end if;

  delete from public.rol_permisos where rol_id = p_rol_id;
  delete from public.roles where id = p_rol_id and empresa_id = v_empresa_id;
end;
$function$;


create or replace function public.establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[])
 returns void
 language plpgsql
 security definer
 set search_path = public
as $function$
declare
  v_empresa_id uuid;
  v_nombre text;
  v_final uuid[];
begin
  if not (tiene_permiso('gestionar_roles') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para gestionar roles';
  end if;

  v_empresa_id := get_empresa_id();

  select nombre into v_nombre
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  v_final := p_permiso_ids;

  -- Si es el rol admin, forzar que conserve los permisos de gestion
  if v_nombre = 'admin' then
    select array(
      select distinct unnest(
        v_final || array(
          select id from public.permisos
          where codigo in ('gestionar_roles', 'gestionar_usuarios')
        )
      )
    ) into v_final;
  end if;

  -- Reemplazar todos los permisos del rol
  delete from public.rol_permisos where rol_id = p_rol_id;

  insert into public.rol_permisos (rol_id, permiso_id)
  select p_rol_id, unnest(v_final);
end;
$function$;