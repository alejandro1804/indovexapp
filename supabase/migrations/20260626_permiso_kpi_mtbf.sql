-- Migration: 20260626_permiso_kpi_mtbf.sql
-- Permiso para el KPI MTBF y propagación a los roles admin existentes.
-- Reejecutable sin error (ON CONFLICT + NOT EXISTS).

-- =====================================================================
-- 1. Catálogo global de permisos
-- =====================================================================
INSERT INTO permisos (codigo, nombre, modulo)
VALUES ('ver_kpi_mtbf', 'Ver KPI MTBF', 'dashboard')
ON CONFLICT (codigo) DO NOTHING;

-- =====================================================================
-- 2. Asignar el permiso a todos los roles admin que aún no lo tengan
-- =====================================================================
-- Cubre las empresas existentes. Las empresas nuevas lo heredan vía la
-- plantilla Demo en aprobar_empresa, ya que Demo ya tiene el permiso.
INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permisos p
WHERE r.nombre ILIKE '%admin%'
  AND p.codigo = 'ver_kpi_mtbf'
  AND NOT EXISTS (
    SELECT 1 FROM rol_permisos rp
    WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
  );
