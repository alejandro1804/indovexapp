-- =====================================================================
-- Aceptaciones legales (T&C / Política de Privacidad)
-- Registra qué versión de cada documento aceptó cada empresa,
-- a través de qué usuario y cuándo. Append-only (ALCOA+).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catálogo de versiones publicadas
--    Sin empresa_id a propósito: una versión de los T&C es un hecho
--    único, igual para todos los clientes. El hecho por empresa vive
--    en aceptaciones_legales.
-- ---------------------------------------------------------------------
create table if not exists public.documentos_legales (
  id                  uuid primary key default gen_random_uuid(),
  documento           text not null check (documento in ('tyc', 'privacidad')),
  version             text not null,
  fecha_publicacion   date not null,
  fecha_vigencia      date not null,
  url                 text not null,
  resumen_cambios     text,
  requiere_aceptacion boolean not null default true,
  vigente             boolean not null default false,
  creado_en           timestamptz not null default now(),
  constraint uq_documento_version unique (documento, version),
  constraint chk_vigencia_posterior check (fecha_vigencia >= fecha_publicacion)
);

comment on table public.documentos_legales is
  'Catálogo de versiones de documentos legales publicados. fecha_vigencia = publicacion + 15 dias (preaviso comprometido en T&C cl. 13).';
comment on column public.documentos_legales.vigente is
  'Solo una version por documento puede estar vigente. Garantizado por indice parcial.';
comment on column public.documentos_legales.requiere_aceptacion is
  'true = modal bloqueante al admin. false = solo banner informativo.';

-- Solo una versión vigente por documento
create unique index if not exists uq_documento_vigente
  on public.documentos_legales (documento)
  where vigente = true;

-- ---------------------------------------------------------------------
-- 2. Registro de aceptaciones (append-only)
-- ---------------------------------------------------------------------
create table if not exists public.aceptaciones_legales (
  id                  uuid primary key default gen_random_uuid(),
  empresa_id          uuid not null references public.empresas(id) on delete cascade,
  documento_legal_id  uuid not null references public.documentos_legales(id),
  usuario_id          uuid not null references public.usuarios(id),
  aceptado_en         timestamptz not null default now(),
  ip_origen           inet,
  user_agent          text,
  constraint uq_aceptacion_empresa_documento unique (empresa_id, documento_legal_id)
);

comment on table public.aceptaciones_legales is
  'Append-only. Una aceptacion por empresa+version. La acepta el admin en representacion de la persona juridica (T&C cl. 1).';

create index if not exists idx_aceptaciones_empresa
  on public.aceptaciones_legales (empresa_id);
create index if not exists idx_aceptaciones_documento
  on public.aceptaciones_legales (documento_legal_id);

-- ---------------------------------------------------------------------
-- 3. Inmutabilidad: sin UPDATE ni DELETE
-- ---------------------------------------------------------------------
create or replace function public.fn_proteger_aceptaciones()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Las aceptaciones legales son inmutables (operacion: %)', tg_op;
end;
$$;

drop trigger if exists trg_proteger_aceptaciones on public.aceptaciones_legales;
create trigger trg_proteger_aceptaciones
  before update or delete on public.aceptaciones_legales
  for each row execute function public.fn_proteger_aceptaciones();

comment on function public.fn_proteger_aceptaciones() is
  'Impide modificar o borrar aceptaciones. Trazabilidad ALCOA+.';