-- ============================================================
-- Stock: atribucion real y aislamiento por empresa.
-- Funciones internas: sin acceso desde afuera.
--
-- 1. es_llamada_backend(): distingue una llamada del servidor
--    (SQL Editor, cron, service role) de una de la app.
-- 2. registrar_ingreso_stock / registrar_salida_stock:
--    - Desde la app el movimiento SIEMPRE queda a nombre del
--      usuario de la sesion. p_registrado_por solo se acepta si
--      coincide con ese usuario, o si llama el servidor.
--    - El repuesto, el proveedor y el ticket deben ser de la
--      empresa de quien llama.
--    - Sin acceso anonimo.
-- 3. Funciones internas (push, cron de purga, cron de storage):
--    se les quita el permiso de ejecucion desde la API. Los
--    triggers y las tareas programadas las siguen usando.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Llamada del servidor o de la app?
--    Mismo criterio que fn_proteger_columnas_empresa:
--    - session_user distinto de 'authenticator' = conexion
--      directa (SQL Editor, pg_cron, migraciones).
--    - rol 'service_role' en el JWT = Edge Function de confianza.
--    app.simular_cliente = 'on' fuerza "no es backend": sirve
--    para probar desde el SQL Editor y solo puede quitar
--    privilegios, nunca darlos.
-- ------------------------------------------------------------
create or replace function public.es_llamada_backend()
 returns boolean
 language sql
 stable
as $function$
  select
    coalesce(current_setting('app.simular_cliente', true), '') <> 'on'
    and (
      session_user <> 'authenticator'
      or coalesce(
           nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
           ''
         ) = 'service_role'
    );
$function$;

comment on function public.es_llamada_backend() is
  'true si la llamada viene del servidor (SQL Editor, cron, service role) y no de un usuario de la app.';


-- ------------------------------------------------------------
-- 2.a registrar_ingreso_stock
-- ------------------------------------------------------------
create or replace function public.registrar_ingreso_stock(
  p_repuesto_id uuid,
  p_cantidad integer,
  p_proveedor_id uuid default null::uuid,
  p_descripcion text default null::text,
  p_registrado_por uuid default null::uuid
)
 returns void
 language plpgsql
 security definer
 set search_path = public
as $function$
DECLARE
  v_usuario uuid;
  v_empresa_id uuid;
  v_backend boolean := es_llamada_backend();
BEGIN
  -- Quien registra el movimiento
  IF v_backend THEN
    -- Servidor (SQL Editor, service role): se acepta el usuario indicado
    v_usuario := COALESCE(p_registrado_por, auth.uid());
  ELSE
    -- App: siempre el usuario de la sesion
    v_usuario := auth.uid();
    IF v_usuario IS NOT NULL
       AND p_registrado_por IS NOT NULL
       AND p_registrado_por <> v_usuario THEN
      RAISE EXCEPTION 'No autorizado: no se puede registrar un movimiento a nombre de otro usuario';
    END IF;
  END IF;

  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'No hay usuario autenticado para registrar el ingreso';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a cero. Recibido: %', p_cantidad;
  END IF;

  -- Resolver empresa desde el repuesto (y bloquear la fila)
  SELECT empresa_id INTO v_empresa_id
  FROM repuestos
  WHERE id = p_repuesto_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Repuesto no encontrado';
  END IF;

  -- Desde la app, el repuesto debe ser de la empresa del usuario.
  -- Mismo mensaje que "no existe": no se revela que el id es de otra empresa.
  IF NOT v_backend AND v_empresa_id IS DISTINCT FROM get_empresa_id() THEN
    RAISE EXCEPTION 'Repuesto no encontrado';
  END IF;

  -- El proveedor, si se indica, debe ser de la misma empresa que el repuesto
  IF p_proveedor_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM proveedores
    WHERE id = p_proveedor_id AND empresa_id = v_empresa_id
  ) THEN
    RAISE EXCEPTION 'Proveedor no encontrado';
  END IF;

  INSERT INTO ingreso_repuestos (
    repuesto_id, cantidad, proveedor_id,
    descripcion, fecha, registrado_por, empresa_id
  ) VALUES (
    p_repuesto_id, p_cantidad, p_proveedor_id,
    p_descripcion, CURRENT_DATE, v_usuario, v_empresa_id
  );

  UPDATE repuestos
  SET stock_actual = stock_actual + p_cantidad,
      updated_at = now()
  WHERE id = p_repuesto_id;
END;
$function$;


-- ------------------------------------------------------------
-- 2.b registrar_salida_stock
-- ------------------------------------------------------------
create or replace function public.registrar_salida_stock(
  p_repuesto_id uuid,
  p_cantidad integer,
  p_ticket_id uuid default null::uuid,
  p_observacion text default null::text,
  p_registrado_por uuid default null::uuid
)
 returns void
 language plpgsql
 security definer
 set search_path = public
as $function$
DECLARE
  v_stock_actual int;
  v_stock_nuevo  int;
  v_stock_minimo int;
  v_empresa_id   uuid;
  v_usuario      uuid;
  v_backend      boolean := es_llamada_backend();
BEGIN
  -- Quien registra el movimiento
  IF v_backend THEN
    -- Servidor (SQL Editor, service role): se acepta el usuario indicado
    v_usuario := COALESCE(p_registrado_por, auth.uid());
  ELSE
    -- App: siempre el usuario de la sesion
    v_usuario := auth.uid();
    IF v_usuario IS NOT NULL
       AND p_registrado_por IS NOT NULL
       AND p_registrado_por <> v_usuario THEN
      RAISE EXCEPTION 'No autorizado: no se puede registrar un movimiento a nombre de otro usuario';
    END IF;
  END IF;

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

  -- Desde la app, el repuesto debe ser de la empresa del usuario.
  -- Mismo mensaje que "no existe": no se revela que el id es de otra empresa.
  IF NOT v_backend AND v_empresa_id IS DISTINCT FROM get_empresa_id() THEN
    RAISE EXCEPTION 'Repuesto no encontrado';
  END IF;

  -- El ticket, si se indica, debe ser de la misma empresa que el repuesto
  IF p_ticket_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM tickets
    WHERE id = p_ticket_id AND empresa_id = v_empresa_id
  ) THEN
    RAISE EXCEPTION 'Ticket no encontrado';
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


-- Las dos de stock: solo usuarios con sesion y el servidor. Sin anonimo.
revoke execute on function public.registrar_ingreso_stock(uuid, integer, uuid, text, uuid) from public, anon;
revoke execute on function public.registrar_salida_stock(uuid, integer, uuid, text, uuid) from public, anon;


-- ------------------------------------------------------------
-- 3. Funciones internas: fuera de la API.
--    Las usan triggers y pg_cron, que corren como dueño y no
--    dependen de estos permisos.
-- ------------------------------------------------------------
revoke execute on function public.fn_disparar_push(uuid, text, uuid) from public, anon, authenticated;
revoke execute on function public.fn_marcar_empresas_a_purgar() from public, anon, authenticated;
revoke execute on function public.fn_check_storage_todas_empresas() from public, anon, authenticated;
revoke execute on function public.fn_check_storage_empresa(uuid, numeric) from public, anon, authenticated;