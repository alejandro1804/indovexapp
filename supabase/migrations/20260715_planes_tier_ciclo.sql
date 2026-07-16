-- =====================================================================
-- La tabla planes pasa a modelar tier x ciclo, no solo ciclo.
--
-- Antes: 'Plan Mensual' / 'Plan Anual' con precio y mp_plan_id, sin
-- distincion de tier. Una suscripcion no decia si el cliente era
-- Starter o Pro, y el webhook seteaba plan='pago' (que ya no existe
-- como tier valido).
--
-- Ahora: cada fila es una combinacion tier + ciclo con su propio
-- preapproval_plan de MercadoPago. El webhook resuelve el tier de la
-- empresa via planes.tier.
--
-- Ademas: se elimina planes.storage_mb_limit. Los limites son derivados
-- del tier por fn_limites_plan() y aplicados por trg_aplicar_limites_plan.
-- Tener la cuota tambien aca creaba una segunda verdad que nadie leia.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Nueva columna tier
-- ---------------------------------------------------------------------
alter table public.planes
  add column if not exists tier text;

comment on column public.planes.tier is
  'Tier comercial del plan. Debe existir en fn_limites_plan(). El webhook lo usa para setear empresas.plan.';

-- ---------------------------------------------------------------------
-- 2. Limpiar las filas de sandbox.
--    'Plan Mensual' ($15) y 'Plan Anual' ($10) eran de prueba, con
--    mp_plan_id de sandbox. No sirven en produccion.
-- ---------------------------------------------------------------------
delete from public.planes
where mp_plan_id in (
  'ba8a441efee64a08893157d62e468874',   -- Plan Mensual sandbox
  'dc7c9ac029da4c42862b8d5a882915e0'    -- Plan Anual sandbox
);

-- ---------------------------------------------------------------------
-- 3. Filas reales. mp_plan_id queda null hasta crear los
--    preapproval_plan en MercadoPago produccion.
--    crear-suscripcion ya rechaza planes sin mp_plan_id, asi que no
--    hay riesgo de que alguien intente pagar antes de tiempo.
-- ---------------------------------------------------------------------
insert into public.planes (nombre, descripcion, precio, ciclo, tier, mp_plan_id, activo, orden)
values
  ('Starter mensual', 'Hasta 50 maquinas, 10 usuarios y 200 MB de almacenamiento.',
   550.00, 'mensual', 'starter', null, true, 1),
  ('Pro mensual', 'Hasta 200 maquinas, 20 usuarios y 800 MB de almacenamiento.',
   1100.00, 'mensual', 'pro', null, true, 2)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 4. Restricciones
-- ---------------------------------------------------------------------
alter table public.planes
  alter column tier set not null;

alter table public.planes
  drop constraint if exists chk_planes_tier;
alter table public.planes
  add constraint chk_planes_tier
  check (tier in ('starter', 'pro'));

alter table public.planes
  drop constraint if exists chk_planes_ciclo;
alter table public.planes
  add constraint chk_planes_ciclo
  check (ciclo in ('mensual', 'anual'));

-- Una sola combinacion activa por tier + ciclo
drop index if exists uq_planes_tier_ciclo_activo;
create unique index uq_planes_tier_ciclo_activo
  on public.planes (tier, ciclo)
  where activo = true;

-- ---------------------------------------------------------------------
-- 5. Eliminar la cuota duplicada.
--    fn_limites_plan() es la fuente unica de limites.
-- ---------------------------------------------------------------------
alter table public.planes
  drop column if exists storage_mb_limit;

comment on table public.planes is
  'Catalogo comercial: una fila por combinacion tier x ciclo, con su preapproval_plan de MercadoPago. Los limites de uso NO viven aca: se derivan del tier via fn_limites_plan().';