-- =====================================================================
-- RLS y RPCs para documentos_legales / aceptaciones_legales
-- =====================================================================

alter table public.documentos_legales   enable row level security;
alter table public.aceptaciones_legales enable row level security;

-- ---------------------------------------------------------------------
-- documentos_legales: catálogo global
-- ---------------------------------------------------------------------
drop policy if exists pol_documentos_legales_select on public.documentos_legales;
create policy pol_documentos_legales_select
  on public.documentos_legales
  for select
  to authenticated
  using (true);

drop policy if exists pol_documentos_legales_all_sa on public.documentos_legales;
create policy pol_documentos_legales_all_sa
  on public.documentos_legales
  for all
  to authenticated
  using (es_super_admin())
  with check (es_super_admin());

-- ---------------------------------------------------------------------
-- aceptaciones_legales: multi-tenant
-- ---------------------------------------------------------------------
drop policy if exists pol_aceptaciones_select on public.aceptaciones_legales;
create policy pol_aceptaciones_select
  on public.aceptaciones_legales
  for select
  to authenticated
  using (empresa_id = get_empresa_id());

-- Sin policy de INSERT: se inserta solo vía RPC (SECURITY DEFINER).

-- ---------------------------------------------------------------------
-- Helper: ¿el usuario actual es admin de su empresa?
--   Requiere gestionar_usuarios AND gestionar_roles.
-- ---------------------------------------------------------------------
create or replace function public.es_admin_empresa()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (select 1 from mis_permisos() p where p = 'gestionar_usuarios')
    and
    exists (select 1 from mis_permisos() p where p = 'gestionar_roles');
$$;

comment on function public.es_admin_empresa() is
  'true si el usuario actual puede obligar contractualmente a su empresa (T&C cl. 1). Exige gestionar_usuarios AND gestionar_roles.';

revoke all on function public.es_admin_empresa() from public;
grant execute on function public.es_admin_empresa() to authenticated;

-- ---------------------------------------------------------------------
-- RPC 1: documentos vigentes pendientes de aceptar
-- ---------------------------------------------------------------------
create or replace function public.legal_estado_pendiente()
returns table (
  documento_legal_id  uuid,
  documento           text,
  version             text,
  fecha_publicacion   date,
  fecha_vigencia      date,
  url                 text,
  resumen_cambios     text,
  bloqueante          boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_empresa_id uuid;
  v_es_admin   boolean;
begin
  v_empresa_id := get_empresa_id();

  if v_empresa_id is null then
    return;  -- super admin en consola: sin empresa, sin pendientes
  end if;

  v_es_admin := es_admin_empresa();

  return query
  select
    dl.id,
    dl.documento,
    dl.version,
    dl.fecha_publicacion,
    dl.fecha_vigencia,
    dl.url,
    dl.resumen_cambios,
    (dl.requiere_aceptacion and v_es_admin) as bloqueante
  from public.documentos_legales dl
  left join public.aceptaciones_legales al
    on al.documento_legal_id = dl.id
   and al.empresa_id = v_empresa_id
  where dl.vigente = true
    and al.id is null
  order by dl.documento;
end;
$$;

comment on function public.legal_estado_pendiente() is
  'Documentos vigentes que la empresa del usuario aun no acepto. bloqueante=true solo para admins.';

revoke all on function public.legal_estado_pendiente() from public;
grant execute on function public.legal_estado_pendiente() to authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: registrar aceptación
-- ---------------------------------------------------------------------
create or replace function public.legal_aceptar(
  p_documento_legal_id uuid,
  p_user_agent         text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empresa_id uuid;
  v_usuario_id uuid;
  v_vigente    boolean;
  v_ip         text;
  v_id         uuid;
begin
  v_empresa_id := get_empresa_id();
  if v_empresa_id is null then
    raise exception 'Usuario sin empresa asignada';
  end if;

  select id into v_usuario_id
  from public.usuarios
  where id = auth.uid()
    and estado = 'activo';

  if v_usuario_id is null then
    raise exception 'Usuario no encontrado o inactivo';
  end if;

  if not es_admin_empresa() then
    raise exception 'Solo el administrador de la empresa puede aceptar documentos legales';
  end if;

  select vigente into v_vigente
  from public.documentos_legales
  where id = p_documento_legal_id;

  if v_vigente is null then
    raise exception 'Documento legal inexistente';
  end if;
  if not v_vigente then
    raise exception 'El documento no se encuentra vigente';
  end if;

  -- IP de origen (Cloudflare la propaga en cf-connecting-ip)
  begin
    v_ip := nullif(
      current_setting('request.headers', true)::json ->> 'cf-connecting-ip',
      ''
    );
  exception when others then
    v_ip := null;
  end;

  insert into public.aceptaciones_legales (
    empresa_id, documento_legal_id, usuario_id, ip_origen, user_agent
  ) values (
    v_empresa_id, p_documento_legal_id, v_usuario_id, v_ip::inet, p_user_agent
  )
  on conflict (empresa_id, documento_legal_id) do nothing
  returning id into v_id;

  -- Idempotente: si ya existía, devolver la previa
  if v_id is null then
    select id into v_id
    from public.aceptaciones_legales
    where empresa_id = v_empresa_id
      and documento_legal_id = p_documento_legal_id;
  end if;

  return v_id;
end;
$$;

comment on function public.legal_aceptar(uuid, text) is
  'Registra aceptacion de un documento vigente. Solo admin de empresa. Idempotente.';

revoke all on function public.legal_aceptar(uuid, text) from public;
grant execute on function public.legal_aceptar(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: super admin — cobertura por empresa
-- ---------------------------------------------------------------------
create or replace function public.sa_legal_cobertura()
returns table (
  empresa_id         uuid,
  empresa_nombre     text,
  documento          text,
  version            text,
  fecha_vigencia     date,
  aceptado           boolean,
  aceptado_en        timestamptz,
  aceptado_por       text,
  dias_para_vigencia int
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not es_super_admin() then
    raise exception 'Acceso denegado';
  end if;

  return query
  select
    e.id,
    e.nombre,
    dl.documento,
    dl.version,
    dl.fecha_vigencia,
    (al.id is not null),
    al.aceptado_en,
    u.nombre,
    (dl.fecha_vigencia - current_date)::int
  from public.empresas e
  cross join public.documentos_legales dl
  left join public.aceptaciones_legales al
    on al.empresa_id = e.id
   and al.documento_legal_id = dl.id
  left join public.usuarios u
    on u.id = al.usuario_id
  where dl.vigente = true
    and e.activa = true
  order by (al.id is not null), e.nombre, dl.documento;
end;
$$;

comment on function public.sa_legal_cobertura() is
  'Estado de aceptacion de documentos vigentes por empresa. Solo super admin.';

revoke all on function public.sa_legal_cobertura() from public;
grant execute on function public.sa_legal_cobertura() to authenticated;