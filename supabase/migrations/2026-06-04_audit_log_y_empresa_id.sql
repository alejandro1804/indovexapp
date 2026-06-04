-- ============================================================
-- Indovex — Migración 2026-06-04
-- Audit log + empresa_id en movimientos de stock + RLS
-- ============================================================
-- Ejecutar en orden en el SQL Editor de Supabase.
-- La tabla audit_log ya existía de una sesión anterior; se
-- incluye su definición de referencia comentada al final.
-- ============================================================


-- ------------------------------------------------------------
-- 1. FUNCIÓN GENÉRICA DE AUDITORÍA
-- ------------------------------------------------------------
-- Versión defensiva: lee los campos vía jsonb para no fallar
-- en tablas que no tengan la columna empresa_id directa.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_registro jsonb;
BEGIN
  v_registro := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;

  INSERT INTO audit_log (
    tabla, operacion, registro_id,
    empresa_id, usuario_id,
    datos_antes, datos_despues
  ) VALUES (
    TG_TABLE_NAME,
    TG_OP,
    (v_registro->>'id'),
    (v_registro->>'empresa_id')::uuid,
    auth.uid(),
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;


-- ------------------------------------------------------------
-- 2. TRIGGERS DE AUDITORÍA POR TABLA
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audit_tickets
  AFTER INSERT OR UPDATE OR DELETE ON tickets
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_ticket_historial
  AFTER INSERT OR UPDATE OR DELETE ON ticket_historial
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_repuestos
  AFTER INSERT OR UPDATE OR DELETE ON repuestos
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_ingreso_repuestos
  AFTER INSERT OR UPDATE OR DELETE ON ingreso_repuestos
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_salida_repuestos
  AFTER INSERT OR UPDATE OR DELETE ON salida_repuestos
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_maquinas
  AFTER INSERT OR UPDATE OR DELETE ON maquinas
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_usuarios
  AFTER INSERT OR UPDATE OR DELETE ON usuarios
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE OR REPLACE TRIGGER trg_audit_empresas
  AFTER INSERT OR UPDATE OR DELETE ON empresas
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();


-- ------------------------------------------------------------
-- 3. INMUTABILIDAD DEL AUDIT LOG
-- ------------------------------------------------------------
-- Bloquea UPDATE y DELETE. Solo se permite INSERT (vía triggers).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_proteger_audit_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'El audit log es inmutable. No se permiten modificaciones ni eliminaciones.';
END;
$$;

CREATE OR REPLACE TRIGGER trg_proteger_audit_log
  BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION fn_proteger_audit_log();


-- ------------------------------------------------------------
-- 4. RLS DEL AUDIT LOG
-- ------------------------------------------------------------
-- Cada empresa ve solo su audit log; super admin ve todo.
-- No se crean políticas de INSERT/UPDATE/DELETE a propósito:
--   - INSERT lo hace el trigger (SECURITY DEFINER, saltea RLS)
--   - UPDATE/DELETE bloqueados por trg_proteger_audit_log
-- ------------------------------------------------------------
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_log_select"
ON audit_log
FOR SELECT
USING (
  empresa_id = get_empresa_id()
  OR es_super_admin()
);


-- ------------------------------------------------------------
-- 5. empresa_id EN TABLAS DE MOVIMIENTOS
-- ------------------------------------------------------------
ALTER TABLE ingreso_repuestos ADD COLUMN empresa_id uuid REFERENCES empresas(id);
ALTER TABLE salida_repuestos ADD COLUMN empresa_id uuid REFERENCES empresas(id);

-- Poblar registros existentes a partir del repuesto
UPDATE ingreso_repuestos ir
SET empresa_id = r.empresa_id
FROM repuestos r
WHERE ir.repuesto_id = r.id;

UPDATE salida_repuestos sr
SET empresa_id = r.empresa_id
FROM repuestos r
WHERE sr.repuesto_id = r.id;


-- ------------------------------------------------------------
-- 6. FUNCIÓN registrar_ingreso_stock (con empresa_id)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION registrar_ingreso_stock(
  p_repuesto_id    uuid,
  p_cantidad       int,
  p_proveedor_id   uuid DEFAULT NULL,
  p_descripcion    text DEFAULT NULL,
  p_registrado_por uuid DEFAULT auth.uid()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_empresa_id uuid;
BEGIN
  SELECT empresa_id INTO v_empresa_id
  FROM repuestos
  WHERE id = p_repuesto_id;

  INSERT INTO ingreso_repuestos (
    repuesto_id, cantidad, proveedor_id,
    descripcion, fecha, registrado_por, empresa_id
  ) VALUES (
    p_repuesto_id, p_cantidad, p_proveedor_id,
    p_descripcion, CURRENT_DATE, p_registrado_por, v_empresa_id
  );

  UPDATE repuestos
  SET stock_actual = stock_actual + p_cantidad,
      updated_at = now()
  WHERE id = p_repuesto_id;
END;
$$;


-- ------------------------------------------------------------
-- 7. FUNCIÓN registrar_salida_stock (con empresa_id)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION registrar_salida_stock(
  p_repuesto_id    uuid,
  p_cantidad       int,
  p_ticket_id      uuid DEFAULT NULL,
  p_observacion    text DEFAULT NULL,
  p_registrado_por uuid DEFAULT auth.uid()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stock_actual int;
  v_stock_nuevo  int;
  v_stock_minimo int;
  v_empresa_id   uuid;
BEGIN
  SELECT stock_actual, empresa_id
  INTO v_stock_actual, v_empresa_id
  FROM repuestos
  WHERE id = p_repuesto_id
  FOR UPDATE;

  IF v_stock_actual < p_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente. Disponible: %, Solicitado: %', v_stock_actual, p_cantidad;
  END IF;

  INSERT INTO salida_repuestos (
    repuesto_id, cantidad, ticket_id,
    observacion, registrado_por, fecha, empresa_id
  ) VALUES (
    p_repuesto_id, p_cantidad, p_ticket_id,
    p_observacion, p_registrado_por, CURRENT_DATE, v_empresa_id
  );

  UPDATE repuestos
  SET stock_actual = stock_actual - p_cantidad,
      updated_at = now()
  WHERE id = p_repuesto_id;

  SELECT stock_actual, stock_minimo
  INTO v_stock_nuevo, v_stock_minimo
  FROM repuestos
  WHERE id = p_repuesto_id;

  IF v_stock_nuevo <= v_stock_minimo THEN
    INSERT INTO notificaciones (
      tipo, mensaje, para_usuario_id, de_usuario_id
    )
    SELECT
      'stock_minimo',
      'Stock mínimo alcanzado: ' || r.descripcion || ' (' || v_stock_nuevo || ' unidades)',
      u.id,
      auth.uid()
    FROM repuestos r
    CROSS JOIN usuarios u
    WHERE r.id = p_repuesto_id
      AND u.empresa_id = r.empresa_id
      AND u.rol_id IN (
        SELECT id FROM roles
        WHERE nombre IN ('admin', 'encargado', 'shopper')
      );
  END IF;
END;
$$;


-- ============================================================
-- REFERENCIA: definición de la tabla audit_log (ya existente)
-- ============================================================
-- CREATE TABLE audit_log (
--   id            bigserial PRIMARY KEY,
--   tabla         text NOT NULL,
--   operacion     text NOT NULL,
--   registro_id   text NOT NULL,
--   empresa_id    uuid,
--   usuario_id    uuid,
--   datos_antes   jsonb,
--   datos_despues jsonb,
--   ip            text,
--   created_at    timestamptz NOT NULL DEFAULT now()
-- );
-- ============================================================