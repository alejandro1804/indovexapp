-- ============================================================
-- Migración: generalización de encargado_sector → usuario_sector
-- Fecha: 2026-07-03
-- ============================================================

-- 1. RENOMBRAR TABLA
-- ------------------------------------------------------------
ALTER TABLE encargado_sector RENAME TO usuario_sector;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'usuario_sector'::regclass
      AND conname LIKE 'encargado_sector_%'
  LOOP
    EXECUTE format('ALTER TABLE usuario_sector RENAME CONSTRAINT %I TO %I',
      r.conname, replace(r.conname, 'encargado_sector', 'usuario_sector'));
  END LOOP;
END $$;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT indexname FROM pg_indexes
    WHERE tablename = 'usuario_sector'
      AND indexname LIKE 'encargado_sector_%'
  LOOP
    EXECUTE format('ALTER INDEX %I RENAME TO %I',
      r.indexname, replace(r.indexname, 'encargado_sector', 'usuario_sector'));
  END LOOP;
END $$;

ALTER POLICY "encargado_sector_mi_empresa" ON usuario_sector
  RENAME TO "usuario_sector_mi_empresa";

ALTER TRIGGER trg_audit_encargado_sector ON usuario_sector
  RENAME TO trg_audit_usuario_sector;

ALTER FUNCTION fn_set_empresa_encargado_sector()
  RENAME TO fn_set_empresa_usuario_sector;


-- 2. COLUMNA + CHECK EN ROLES
-- ------------------------------------------------------------
ALTER TABLE roles
  ADD COLUMN restringe_por_sector boolean NOT NULL DEFAULT false;

-- El rol 'admin' nunca puede restringirse por sector.
-- Los roles de sistema se guardan en minúscula (crear_rol usa lower(trim())).
ALTER TABLE roles
  ADD CONSTRAINT chk_admin_no_restringido
  CHECK (NOT (lower(nombre) = 'admin' AND restringe_por_sector = true));


-- 3. HELPERS SQL
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sectores_usuario()
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(sector_id), ARRAY[]::uuid[])
  FROM usuario_sector
  WHERE usuario_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION fn_usuario_restringido_sector()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(r.restringe_por_sector, false)
  FROM usuarios u
  JOIN roles r ON r.id = u.rol_id
  WHERE u.id = auth.uid();
$$;


-- 4. RLS ACTUALIZADA: MAQUINAS Y TICKETS
-- ------------------------------------------------------------
DROP POLICY IF EXISTS maquinas_mi_empresa ON maquinas;
CREATE POLICY maquinas_mi_empresa ON maquinas
FOR ALL
USING (
  empresa_id = get_empresa_id()
  AND (
    NOT fn_usuario_restringido_sector()
    OR sector_id = ANY(fn_sectores_usuario())
  )
);

DROP POLICY IF EXISTS tickets_mi_empresa ON tickets;
CREATE POLICY tickets_mi_empresa ON tickets
FOR ALL
USING (
  empresa_id = get_empresa_id()
  AND (
    NOT fn_usuario_restringido_sector()
    OR maquina_id IN (
      SELECT id FROM maquinas WHERE sector_id = ANY(fn_sectores_usuario())
    )
  )
);