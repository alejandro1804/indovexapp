-- ═════════════════════════════════════════════════════════════
-- Migración: pagos_suscripcion
-- Fecha: 2026-07-10
-- Descripción: Registro del historial de pagos de suscripciones
--              MercadoPago por empresa, para gestión administrativa
--              y facturación. Escenario A: panel interno super admin.
-- ═════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABLA
-- Append-only: los pagos son evidencia contable, no se borran.
-- ─────────────────────────────────────────────────────────────
create table if not exists pagos_suscripcion (
  id                 uuid primary key default gen_random_uuid(),
  empresa_id         uuid not null references empresas(id),

  -- Identificadores MercadoPago
  mp_payment_id      text unique,          -- ID del pago en MP; evita duplicados por reintentos del webhook
  mp_suscripcion_id  text,                 -- preapproval al que pertenece el cobro
  mp_plan_id         text,                 -- preapproval_plan (respaldo para identificar tier)

  -- Datos del cobro (fuente de verdad para facturar)
  monto              numeric(12,2) not null,
  moneda             text not null default 'UYU',
  estado             text not null,        -- approved | rejected | refunded | charged_back | pending
  fecha_pago         timestamptz,          -- cuándo cobró MP

  -- Gestión administrativa / facturación
  facturado          boolean not null default false,
  factura_numero     text,
  factura_fecha      timestamptz,

  -- Auditoría
  creado             timestamptz not null default now(),
  actualizado        timestamptz not null default now()
);

-- Índices para consultas administrativas
create index if not exists idx_pagos_empresa      on pagos_suscripcion(empresa_id);
create index if not exists idx_pagos_estado       on pagos_suscripcion(estado);
create index if not exists idx_pagos_sin_facturar on pagos_suscripcion(facturado) where facturado = false;
create index if not exists idx_pagos_fecha        on pagos_suscripcion(fecha_pago desc);


-- ─────────────────────────────────────────────────────────────
-- 2. RLS (Escenario A — panel interno super admin)
-- Lectura: solo super admin (visibilidad global, intencional).
-- Escritura: nadie desde la app; los INSERT vienen del webhook
--            vía SERVICE_ROLE_KEY (ignora RLS); los UPDATE de
--            facturación van por la RPC de más abajo.
-- ─────────────────────────────────────────────────────────────
alter table pagos_suscripcion enable row level security;

drop policy if exists pagos_select_super_admin on pagos_suscripcion;
create policy pagos_select_super_admin
  on pagos_suscripcion
  for select
  using ( es_super_admin() );


-- ─────────────────────────────────────────────────────────────
-- 3. RPC: marcar_pago_facturado
-- Marca (o desmarca) un pago como facturado. Solo super admin.
-- SECURITY DEFINER para saltar la RLS de escritura, con chequeo
-- explícito de rol adentro. Fecha de factura opcional (default now()).
-- ─────────────────────────────────────────────────────────────
create or replace function marcar_pago_facturado(
  p_pago_id        uuid,
  p_facturado      boolean default true,
  p_factura_numero text default null,
  p_factura_fecha  timestamptz default null
)
returns pagos_suscripcion
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row pagos_suscripcion;
begin
  -- 1. Solo super admin puede facturar
  if not es_super_admin() then
    raise exception 'No autorizado: se requiere super admin';
  end if;

  -- 2. Marcar o desmarcar
  if p_facturado then
    update pagos_suscripcion
    set facturado      = true,
        factura_numero = p_factura_numero,
        factura_fecha  = coalesce(p_factura_fecha, now()),
        actualizado    = now()
    where id = p_pago_id
    returning * into v_row;
  else
    update pagos_suscripcion
    set facturado      = false,
        factura_numero = null,
        factura_fecha  = null,
        actualizado    = now()
    where id = p_pago_id
    returning * into v_row;
  end if;

  -- 3. Validar que el pago exista
  if v_row.id is null then
    raise exception 'Pago no encontrado: %', p_pago_id;
  end if;

  return v_row;
end;
$$;