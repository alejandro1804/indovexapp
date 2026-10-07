-- ============================================================
-- Activos (maquinas): baja logica como estado
--
-- Se agrega el estado 'dada_de_baja'. Un activo dado de baja no
-- se borra: conserva tickets, planes, lecturas y documentos, y
-- deja de participar (sin tickets nuevos, sin ocupar cupo).
--
-- 1. chk_maquinas_estado admite 'dada_de_baja'.
-- 2. Permiso nuevo dar_baja_maquinas, asignado a los roles que
--    hoy tienen gestionar_maquinas.
-- 3. trg_proteger_baja_maquina: dar de baja o reactivar exige el
--    permiso, y no se da de baja con tickets sin cerrar.
-- 4. trg_bloquear_borrado_maquina: desde la app un activo no se
--    borra fisicamente (tampoco en cascada al borrar su
--    ubicacion).
-- 5. Limite del plan: los dados de baja no ocupan cupo
--    (fn_validar_limite_maquinas, uso_cupos_empresa). Reactivar
--    valida el limite.
-- 6. Indices unicos de nombre y codigo: solo entre activos que
--    no estan dados de baja. El nombre y el codigo quedan libres
--    para el equipo que lo reemplaza.
-- 7. trg_validar_maquina_no_baja_ticket: no se crean tickets
--    sobre un activo dado de baja (app o generacion automatica).
--
-- No se tocan las politicas de maquinas: el borrado se bloquea
-- con trigger para que falle con mensaje, en vez de no hacer
-- nada en silencio en las versiones de la app ya instaladas.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Estado nuevo
-- ------------------------------------------------------------
alter table public.maquinas
  drop constraint if exists chk_maquinas_estado,
  add constraint chk_maquinas_estado
    check (estado = any (array[
      'operativa'::text,
      'en_mantenimiento'::text,
      'fuera_de_servicio'::text,
      'dada_de_baja'::text
    ]));


-- ------------------------------------------------------------
-- 2. Permiso nuevo y asignacion inicial
--    Mismo modulo que gestionar_maquinas.
-- ------------------------------------------------------------
insert into public.permisos (codigo, nombre, modulo)
select 'dar_baja_maquinas', 'Dar de baja/reactivar activos', p.modulo
from public.permisos p
where p.codigo = 'gestionar_maquinas'
  and not exists (
    select 1 from public.permisos where codigo = 'dar_baja_maquinas'
  );

-- Todo rol que hoy tiene gestionar_maquinas recibe el permiso nuevo.
-- Incluye los roles de la empresa Demo, de donde copian las empresas nuevas.
insert into public.rol_permisos (rol_id, permiso_id)
select rp.rol_id, nuevo.id
from public.rol_permisos rp
join public.permisos viejo
  on viejo.id = rp.permiso_id
 and viejo.codigo = 'gestionar_maquinas'
cross join (
  select id from public.permisos where codigo = 'dar_baja_maquinas'
) nuevo
where not exists (
  select 1
  from public.rol_permisos x
  where x.rol_id = rp.rol_id
    and x.permiso_id = nuevo.id
);


-- ------------------------------------------------------------
-- 3. Dar de baja / reactivar
--    Solo corre cuando el estado entra o sale de 'dada_de_baja'.
--    - Exige dar_baja_maquinas (el servidor pasa siempre).
--    - No se da de baja con tickets sin cerrar. Se toman como
--      abiertos los mismos estados que el backlog del tablero.
-- ------------------------------------------------------------
create or replace function public.fn_proteger_baja_maquina()
 returns trigger
 language plpgsql
 security definer
 set search_path = public
as $function$
declare
  v_abiertos int;
begin
  if not es_llamada_backend()
     and not (tiene_permiso('dar_baja_maquinas') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para dar de baja o reactivar activos';
  end if;

  if new.estado = 'dada_de_baja' then
    select count(*) into v_abiertos
    from public.tickets
    where maquina_id = new.id
      and estado in ('abierto', 'asignado', 'en_proceso', 'resuelto');

    if v_abiertos > 0 then
      raise exception 'No se puede dar de baja: el activo tiene % ticket(s) sin cerrar', v_abiertos;
    end if;
  end if;

  return new;
end;
$function$;

comment on function public.fn_proteger_baja_maquina() is
  'Controla la entrada y salida del estado dada_de_baja: permiso dar_baja_maquinas y sin tickets abiertos.';

drop trigger if exists trg_proteger_baja_maquina on public.maquinas;

create trigger trg_proteger_baja_maquina
  before update on public.maquinas
  for each row
  when (
    old.estado is distinct from new.estado
    and (old.estado = 'dada_de_baja' or new.estado = 'dada_de_baja')
  )
  execute function public.fn_proteger_baja_maquina();


-- ------------------------------------------------------------
-- 4. Sin borrado fisico desde la app
--    Pasan el servidor (SQL Editor, cron, service role) y el
--    super admin (purga de datos de una empresa).
--    Tambien frena el borrado en cascada desde sectores.
-- ------------------------------------------------------------
create or replace function public.fn_bloquear_borrado_maquina()
 returns trigger
 language plpgsql
 security definer
 set search_path = public
as $function$
begin
  if es_llamada_backend() or es_super_admin() then
    return old;
  end if;

  raise exception 'Los activos no se eliminan: se dan de baja';
end;
$function$;

comment on function public.fn_bloquear_borrado_maquina() is
  'Impide el DELETE de maquinas desde la app. Los activos se dan de baja (estado dada_de_baja).';

drop trigger if exists trg_bloquear_borrado_maquina on public.maquinas;

create trigger trg_bloquear_borrado_maquina
  before delete on public.maquinas
  for each row
  execute function public.fn_bloquear_borrado_maquina();


-- ------------------------------------------------------------
-- 5.a Limite del plan
--     Cambios: no cuenta los dados de baja; ademas del alta,
--     valida la reactivacion (salir de 'dada_de_baja').
-- ------------------------------------------------------------
create or replace function public.fn_validar_limite_maquinas()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_actuales int;
  v_limite   int;
  v_plan     text;
begin
  -- En UPDATE solo interesa la reactivacion
  if tg_op = 'UPDATE' then
    if not (old.estado = 'dada_de_baja' and new.estado <> 'dada_de_baja') then
      return new;
    end if;
  end if;

  -- Un activo dado de baja no ocupa cupo
  if new.estado = 'dada_de_baja' then
    return new;
  end if;

  select max_maquinas, plan
    into v_limite, v_plan
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;
  end if;

  select count(*) into v_actuales
  from public.maquinas
  where empresa_id = new.empresa_id
    and estado <> 'dada_de_baja';

  if v_actuales >= v_limite then
    raise exception
      'Límite de máquinas alcanzado (% de %). Tu plan % permite hasta % máquinas. Podés cambiar de plan para ampliarlo.',
      v_actuales, v_limite, v_plan, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_validar_limite_maquinas on public.maquinas;

create trigger trg_validar_limite_maquinas
  before insert or update of estado on public.maquinas
  for each row
  execute function public.fn_validar_limite_maquinas();


-- ------------------------------------------------------------
-- 5.b uso_cupos_empresa
--     Unico cambio: el conteo de maquinas no incluye las dadas
--     de baja.
-- ------------------------------------------------------------
create or replace function public.uso_cupos_empresa(p_empresa_id uuid default null::uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
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
  where empresa_id = v_empresa_id
    and estado <> 'dada_de_baja';

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
$function$;


-- ------------------------------------------------------------
-- 6. Indices unicos: solo entre activos no dados de baja
--    Mismas columnas y nombres que antes; se agrega la condicion.
--    Reactivar un activo cuyo nombre o codigo ya usa otro falla
--    por estos indices: hay que renombrarlo antes.
-- ------------------------------------------------------------
drop index if exists public.uq_maquinas_empresa_nombre_norm;
create unique index uq_maquinas_empresa_nombre_norm
  on public.maquinas using btree (empresa_id, lower(unaccent_immutable(nombre)))
  where (estado <> 'dada_de_baja');

drop index if exists public.uq_maquinas_empresa_codigo_norm;
create unique index uq_maquinas_empresa_codigo_norm
  on public.maquinas using btree (empresa_id, lower(unaccent_immutable(codigo)))
  where (estado <> 'dada_de_baja');

drop index if exists public.uq_maquinas_codigo_empresa;
create unique index uq_maquinas_codigo_empresa
  on public.maquinas using btree (empresa_id, codigo)
  where (codigo is not null and estado <> 'dada_de_baja');


-- ------------------------------------------------------------
-- 7. Sin tickets nuevos sobre un activo dado de baja
--    Vale para la app y para la Edge Function
--    generar-tickets-preventivos (que ademas los saltea).
-- ------------------------------------------------------------
create or replace function public.fn_validar_maquina_no_baja_ticket()
 returns trigger
 language plpgsql
 security definer
 set search_path = public
as $function$
begin
  if exists (
    select 1
    from public.maquinas
    where id = new.maquina_id
      and estado = 'dada_de_baja'
  ) then
    raise exception 'No se pueden crear tickets sobre un activo dado de baja';
  end if;

  return new;
end;
$function$;

comment on function public.fn_validar_maquina_no_baja_ticket() is
  'Rechaza el alta de tickets cuya maquina esta en estado dada_de_baja.';

drop trigger if exists trg_validar_maquina_no_baja_ticket on public.tickets;

create trigger trg_validar_maquina_no_baja_ticket
  before insert on public.tickets
  for each row
  execute function public.fn_validar_maquina_no_baja_ticket();
