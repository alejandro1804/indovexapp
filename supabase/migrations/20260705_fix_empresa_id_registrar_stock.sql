CREATE OR REPLACE FUNCTION public.registrar_salida_stock(
  p_repuesto_id uuid,
  p_cantidad integer,
  p_ticket_id uuid DEFAULT NULL::uuid,
  p_observacion text DEFAULT NULL::text,
  p_registrado_por uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_stock_actual int;
  v_stock_nuevo  int;
  v_stock_minimo int;
  v_empresa_id   uuid;
  v_usuario      uuid;
BEGIN
  v_usuario := COALESCE(p_registrado_por, auth.uid());
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'No hay usuario autenticado para registrar la salida';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a cero. Recibido: %', p_cantidad;
  END IF;

  SELECT stock_actual, empresa_id
  INTO v_stock_actual, v_empresa_id
  FROM repuestos
  WHERE id = p_repuesto_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Repuesto no encontrado';
  END IF;

  IF v_stock_actual < p_cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente. Disponible: %, Solicitado: %', v_stock_actual, p_cantidad;
  END IF;

  INSERT INTO salida_repuestos (
    repuesto_id, cantidad, ticket_id,
    observacion, registrado_por, fecha, empresa_id
  ) VALUES (
    p_repuesto_id, p_cantidad, p_ticket_id,
    p_observacion, v_usuario, CURRENT_DATE, v_empresa_id
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
      v_usuario
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
$function$;