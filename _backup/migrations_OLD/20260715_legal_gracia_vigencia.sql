-- =====================================================================
-- Opción B: preaviso de 15 días
--   publicacion <= hoy < vigencia  -> aviso no bloqueante (banner)
--   hoy >= vigencia                -> bloqueante (modal)
-- =====================================================================

drop function if exists public.legal_estado_pendiente();

create or replace function public.legal_estado_pendiente()
returns table (
  documento_legal_id  uuid,
  documento           text,
  version             text,
  fecha_publicacion   date,
  fecha_vigencia      date,
  url                 text,
  resumen_cambios     text,
  bloqueante          boolean,
  en_preaviso         boolean,
  dias_restantes      int
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
    -- Bloquea solo si: requiere aceptación
    --                  Y el usuario es admin
    --                  Y ya venció el preaviso
    (
      dl.requiere_aceptacion
      and v_es_admin
      and current_date >= dl.fecha_vigencia
    ) as bloqueante,
    -- En preaviso: publicado pero aún no vigente
    (current_date < dl.fecha_vigencia) as en_preaviso,
    greatest(dl.fecha_vigencia - current_date, 0)::int as dias_restantes
  from public.documentos_legales dl
  left join public.aceptaciones_legales al
    on al.documento_legal_id = dl.id
   and al.empresa_id = v_empresa_id
  where dl.vigente = true
    and al.id is null
    and current_date >= dl.fecha_publicacion   -- no anunciar antes de publicar
  order by dl.documento;
end;
$$;

comment on function public.legal_estado_pendiente() is
  'Documentos vigentes pendientes de aceptar por la empresa del usuario. Durante el preaviso (publicacion..vigencia) devuelve en_preaviso=true y bloqueante=false; vencido el preaviso, bloqueante=true para admins.';

revoke all on function public.legal_estado_pendiente() from public;
grant execute on function public.legal_estado_pendiente() to authenticated;