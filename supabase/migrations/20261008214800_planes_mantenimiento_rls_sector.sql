-- ============================================================
-- Planes de mantenimiento: restricción por ubicación asignada
-- Destino: supabase/migrations/20261008214800_planes_mantenimiento_rls_sector.sql
--
-- Regla:
--   Un usuario cuyo rol tiene restringe_por_sector = true solo accede
--   (ver, crear, editar, borrar) a los planes de los activos que están
--   en sus ubicaciones asignadas (usuario_sector).
--   Si no tiene ubicaciones asignadas, no ve ningún plan (fail-closed).
--   Los roles que no restringen (admin, etc.) quedan igual que hoy.
--
-- Implementación:
--   Policy RESTRICTIVE: se suma con AND a las policies que ya tiene la
--   tabla. No reemplaza ninguna y no puede ampliar accesos, solo acotar.
--   Reutiliza los helpers que ya usan maquinas y tickets:
--     fn_usuario_restringido_sector()  y  fn_sectores_usuario()
-- ============================================================

DROP POLICY IF EXISTS planes_mantenimiento_restringe_sector ON planes_mantenimiento;

CREATE POLICY planes_mantenimiento_restringe_sector
ON planes_mantenimiento
AS RESTRICTIVE
FOR ALL
USING (
  NOT fn_usuario_restringido_sector()
  OR maquina_id IN (
    SELECT id FROM maquinas WHERE sector_id = ANY(fn_sectores_usuario())
  )
);