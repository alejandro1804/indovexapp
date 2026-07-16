-- =====================================================================
-- Enforcement de límites de usuarios y máquinas por plan.
-- Hasta ahora max_usuarios/max_maquinas existían pero nadie las leía.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Usuarios: cuenta solo los activos (los inactivos no ocupan cupo,
-- coherente con el borrado lógico del sistema).
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_limite_usuarios()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actuales int;
  v_limite   int;
  v_plan     text;
begin
  select max_usuarios, plan
    into v_limite, v_plan
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;  -- sin límite definido: no bloquear
  end if;

  select count(*) into v_actuales
  from public.usuarios
  where empresa_id = new.empresa_id
    and estado = 'activo';

  if v_actuales >= v_limite then
    raise exception
      'Límite de usuarios alcanzado (% de %). Tu plan % permite hasta % usuarios activos. Podés desactivar un usuario o cambiar de plan.',
      v_actuales, v_limite, v_plan, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_limite_usuarios on public.usuarios;
create trigger trg_validar_limite_usuarios
  before insert on public.usuarios
  for each row execute function public.fn_validar_limite_usuarios();

comment on function public.fn_validar_limite_usuarios() is
  'Bloquea el alta de usuarios al alcanzar empresas.max_usuarios. Cuenta solo activos.';

-- ---------------------------------------------------------------------
-- Reactivación: pasar de inactivo a activo también consume cupo.
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_limite_usuarios_reactivar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actuales int;
  v_limite   int;
begin
  if not (old.estado <> 'activo' and new.estado = 'activo') then
    return new;
  end if;

  select max_usuarios into v_limite
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;
  end if;

  select count(*) into v_actuales
  from public.usuarios
  where empresa_id = new.empresa_id
    and estado = 'activo'
    and id <> new.id;

  if v_actuales >= v_limite then
    raise exception
      'Límite de usuarios alcanzado (% de %). No podés reactivar este usuario sin desactivar otro o cambiar de plan.',
      v_actuales, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_limite_usuarios_reactivar on public.usuarios;
create trigger trg_validar_limite_usuarios_reactivar
  before update of estado on public.usuarios
  for each row execute function public.fn_validar_limite_usuarios_reactivar();

comment on function public.fn_validar_limite_usuarios_reactivar() is
  'Bloquea la reactivacion de usuarios si la empresa ya llego a su cupo.';

-- ---------------------------------------------------------------------
-- Máquinas
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_limite_maquinas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actuales int;
  v_limite   int;
  v_plan     text;
begin
  select max_maquinas, plan
    into v_limite, v_plan
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;
  end if;

  select count(*) into v_actuales
  from public.maquinas
  where empresa_id = new.empresa_id;

  if v_actuales >= v_limite then
    raise exception
      'Límite de máquinas alcanzado (% de %). Tu plan % permite hasta % máquinas. Podés cambiar de plan para ampliarlo.',
      v_actuales, v_limite, v_plan, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_limite_maquinas on public.maquinas;
create trigger trg_validar_limite_maquinas
  before insert on public.maquinas
  for each row execute function public.fn_validar_limite_maquinas();

comment on function public.fn_validar_limite_maquinas() is
  'Bloquea el alta de maquinas al alcanzar empresas.max_maquinas.';

-- ---------------------------------------------------------------------
-- Consulta de cupos, para mostrar en la app antes de que el usuario
-- se choque con el error.
-- ---------------------------------------------------------------------
create or replace function public.uso_cupos_empresa(p_empresa_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_empresa_id uuid;
  v_emp        record;
  v_usuarios   int;
  v_maquinas   int;
begin
  v_empresa_id := coalesce(p_empresa_id, get_empresa_id());

  if v_empresa_id is null then
    return null;
  end if;

  if v_empresa_id <> coalesce(get_empresa_id(), '00000000-0000-0000-0000-000000000000'::uuid)
     and not es_super_admin() then
    raise exception 'Acceso denegado';
  end if;

  select plan, max_usuarios, max_maquinas
    into v_emp
  from public.empresas
  where id = v_empresa_id;

  select count(*) into v_usuarios
  from public.usuarios
  where empresa_id = v_empresa_id and estado = 'activo';

  select count(*) into v_maquinas
  from public.maquinas
  where empresa_id = v_empresa_id;

  return jsonb_build_object(
    'plan', v_emp.plan,
    'usuarios', jsonb_build_object(
      'usados', v_usuarios,
      'limite', v_emp.max_usuarios,
      'porcentaje', round(v_usuarios::numeric / nullif(v_emp.max_usuarios, 0) * 100, 1)
    ),
    'maquinas', jsonb_build_object(
      'usados', v_maquinas,
      'limite', v_emp.max_maquinas,
      'porcentaje', round(v_maquinas::numeric / nullif(v_emp.max_maquinas, 0) * 100, 1)
    )
  );
end;
$$;

comment on function public.uso_cupos_empresa(uuid) is
  'Uso vs limite de usuarios y maquinas. Para mostrar en la app antes de chocar con el trigger.';

revoke all on function public.uso_cupos_empresa(uuid) from public;
grant execute on function public.uso_cupos_empresa(uuid) to authenticated;