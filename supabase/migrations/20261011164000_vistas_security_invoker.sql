-- ============================================================
-- 20261011164000_vistas_security_invoker.sql
--
-- Las vistas repuestos_bajo_stock y vw_mtbf_maquinas corrían con
-- los permisos del dueño y se saltaban la RLS: al consultarlas
-- directo devolvían filas de todas las empresas, incluso sin
-- sesión iniciada (rol anon).
--
-- Con security_invoker se evalúan con los permisos y la RLS de
-- quien consulta, así que cada usuario ve solo su empresa.
--
-- Idempotente: se puede correr más de una vez.
-- Para revertir: alter view ... reset (security_invoker);
-- ============================================================

alter view public.repuestos_bajo_stock set (security_invoker = true);
alter view public.vw_mtbf_maquinas     set (security_invoker = true);

-- Ninguna de las dos se usa sin sesión iniciada.
revoke all on public.repuestos_bajo_stock from anon;
revoke all on public.vw_mtbf_maquinas     from anon;