-- ─────────────────────────────────────────────────────────────
-- 20260927_plan_pro_limites_150_600.sql
--
-- Nuevos límites del plan Pro (decisión sept 2026):
--   antes: 20 usuarios / 200 activos / 800 MB
--   ahora: 20 usuarios / 150 activos / 600 MB
--
-- fn_limites_plan() es la fuente única de los límites por tier.
-- trg_aplicar_limites_plan solo los aplica cuando CAMBIA el plan
-- (fn_aplicar_limites_plan corta si new.plan = old.plan), así que
-- las empresas que ya están en Pro se recalculan explícitamente.
--
-- Al momento de aplicar no hay empresas en Pro; el recálculo queda
-- por consistencia y solo toca empresas con los límites por defecto
-- anteriores (respeta ajustes manuales por empresa).
-- ─────────────────────────────────────────────────────────────

begin;

-- 1. Límites por tier (solo cambia 'pro')
create or replace function public.fn_limites_plan(p_plan text)
returns table(max_usuarios integer, max_maquinas integer, storage_mb integer)
language sql
immutable
as $function$
  select t.max_usuarios, t.max_maquinas, t.storage_mb
  from (values
    ('trial',    5,   30,  100),
    ('starter',  10,  50,  200),
    ('pro',      20,  150, 600),
    ('interno',  50,  500, 2000)
  ) as t(plan, max_usuarios, max_maquinas, storage_mb)
  where t.plan = p_plan;
$function$;

-- 2. Recalcular empresas Pro existentes con los límites por defecto anteriores
update public.empresas e
set max_usuarios     = l.max_usuarios,
    max_maquinas     = l.max_maquinas,
    storage_mb_limit = l.storage_mb
from public.fn_limites_plan('pro') l
where e.plan = 'pro'
  and e.max_usuarios     = 20
  and e.max_maquinas     = 200
  and e.storage_mb_limit = 800;

commit;