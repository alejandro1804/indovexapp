-- supabase/migrations/20260703_purgar_valida_estado.sql
--
-- Fix: sa_purgar_datos_empresa no validaba el estado de la empresa antes de
-- borrar. Esto permitía purgar una empresa en estado 'en_baja' o 'suspendida'
-- aunque su plazo de conservación (fecha_purga_programada) todavía no venciera.
--
-- Regla del sistema (definida en fn_marcar_empresas_a_purgar): una empresa solo
-- queda habilitada para purga cuando el cron la pasa a estado 'a_purgar', lo
-- cual ocurre cuando fecha_purga_programada <= CURRENT_DATE.
--
-- Se agrega esa guarda al inicio del RPC. Validamos por estado (no recalculando
-- la fecha) para tener una sola fuente de verdad: el estado 'a_purgar' que
-- mantiene el cron.

CREATE OR REPLACE FUNCTION public.sa_purgar_datos_empresa(p_empresa_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_nombre text;
  v_estado text;
  v_anonimizados int;
BEGIN
  SELECT nombre, estado INTO v_nombre, v_estado
  FROM empresas WHERE id = p_empresa_id;

  IF v_nombre IS NULL THEN
    RAISE EXCEPTION 'Empresa no encontrada';
  END IF;

  -- ── GUARDA: solo se puede purgar una empresa cuyo plazo ya venció ──
  -- (estado 'a_purgar', que asigna fn_marcar_empresas_a_purgar por cron).
  IF v_estado <> 'a_purgar' THEN
    RAISE EXCEPTION 'La empresa "%" está en estado "%". Solo se puede purgar una empresa en estado "a_purgar" (plazo de conservación cumplido).',
      v_nombre, v_estado;
  END IF;

  -- ── 1. ANONIMIZAR audit_log ──
  ALTER TABLE audit_log DISABLE TRIGGER trg_proteger_audit_log;

  UPDATE audit_log
  SET datos_antes = NULL,
      datos_despues = jsonb_build_object('_anonimizado', true),
      ip = NULL,
      usuario_id = NULL
  WHERE empresa_id = p_empresa_id;

  GET DIAGNOSTICS v_anonimizados = ROW_COUNT;

  ALTER TABLE audit_log ENABLE TRIGGER trg_proteger_audit_log;

  -- ── 2. BORRAR datos en orden seguro ──
  DELETE FROM salida_repuestos       WHERE empresa_id = p_empresa_id;
  DELETE FROM ingreso_repuestos      WHERE empresa_id = p_empresa_id;
  DELETE FROM repuestos_maquinas     WHERE empresa_id = p_empresa_id;
  DELETE FROM lecturas_maquina       WHERE empresa_id = p_empresa_id;
  DELETE FROM ticket_fotos           WHERE empresa_id = p_empresa_id;
  DELETE FROM ticket_historial       WHERE empresa_id = p_empresa_id;
  DELETE FROM tickets                WHERE empresa_id = p_empresa_id;
  DELETE FROM planes_mantenimiento   WHERE empresa_id = p_empresa_id;
  DELETE FROM maquina_documentos     WHERE empresa_id = p_empresa_id;
  DELETE FROM maquinas               WHERE empresa_id = p_empresa_id;
  DELETE FROM repuestos              WHERE empresa_id = p_empresa_id;
  DELETE FROM categorias_repuestos   WHERE empresa_id = p_empresa_id;
  DELETE FROM proveedores            WHERE empresa_id = p_empresa_id;
  DELETE FROM adjuntos               WHERE empresa_id = p_empresa_id;
  DELETE FROM notificaciones         WHERE empresa_id = p_empresa_id;
  DELETE FROM whatsapp_destinatarios WHERE empresa_id = p_empresa_id;
  DELETE FROM encargado_sector       WHERE empresa_id = p_empresa_id;
  DELETE FROM sectores               WHERE empresa_id = p_empresa_id;
  DELETE FROM tipos_intervalo        WHERE empresa_id = p_empresa_id;
  -- usuarios ANTES que roles (usuarios.rol_id referencia a roles)
  DELETE FROM usuarios               WHERE empresa_id = p_empresa_id;
  DELETE FROM roles                  WHERE empresa_id = p_empresa_id;
  DELETE FROM empresas               WHERE id = p_empresa_id;

  RETURN jsonb_build_object(
    'ok', true,
    'empresa', v_nombre,
    'audit_log_anonimizados', v_anonimizados
  );
END;
$function$;