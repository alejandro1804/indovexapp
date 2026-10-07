-- ============================================================
-- Repuestos: baja logica
--
-- La columna repuestos.activo ya existe. Esta migracion hace
-- valer la baja en la base:
--
-- 1. Permiso nuevo dar_baja_repuestos, asignado a los roles que
--    hoy tienen gestionar_repuestos (nadie pierde capacidad).
-- 2. Politicas de repuestos: se reemplaza la politica ALL por
--    SELECT / INSERT / UPDATE. Sin DELETE: un repuesto no se
--    borra fisicamente desde la app.
-- 3. trg_proteger_baja_repuesto: cambiar activo (dar de baja o
--    reactivar) exige dar_baja_repuestos.
-- 4. registrar_ingreso_stock / registrar_salida_stock:
--    - Rechazan movimientos sobre un repuesto dado de baja.
--    - Desde la app exigen el permiso registrar_ingreso /
--      registrar_salida (antes solo lo controlaba la app).
--    El resto del cuerpo queda igual.
-- 5. fn_check_stock_bajo: no avisa por repuestos dados de baja.
--
-- No se tocan: la vista repuestos_bajo_stock (ya filtra activo)
-- ni los indices unicos de codigo y descripcion (un repuesto
-- dado de baja sigue reservando su codigo y su descripcion: se
-- reactiva, no se duplica).
-- ============================================================


-- ------------------------------------------------------------
-- 1. Permiso nuevo y asignacion inicial
-- ------------------------------------------------------------
insert into public.permisos (codigo, nombre, modulo)
select 'dar_baja_repuestos', 'Dar de baja/reactivar repuestos', 'repuestos'
where not exists (
  select 1 from public.permisos where codigo = 'dar_baja_repuestos'
);

-- Todo rol que hoy tiene gestionar_repuestos recibe el permiso nuevo.
-- Incluye los roles de la empresa Demo, de donde copian las empresas nuevas.
insert into public.rol_permisos (rol_id, permiso_id)
select rp.rol_id, nuevo.id
from public.rol_permisos rp
join public.permisos viejo
  on viejo.id = rp.permiso_id
 and viejo.codigo = 'gestionar_repuestos'
cross join (
  select id from public.permisos where codigo = 'dar_baja_repuestos'
) nuevo
where not exists (
  select 1
  from public.rol_permisos x
  where x.rol_id = rp.rol_id
    and x.permiso_id = nuevo.id
);


-- ------------------------------------------------------------
-- 2. Politicas de repuestos
--    Misma regla de empresa que antes, separada por operacion.
--    No se crea politica DELETE: el borrado fisico queda cerrado
--    para la app. (El backend y el ON DELETE CASCADE de empresas
--    no dependen de estas politicas.)
-- ------------------------------------------------------------
drop policy if exists repuestos_mi_empresa on public.repuestos;
drop policy if exists repuestos_ver_mi_empresa on public.repuestos;
drop policy if exists repuestos_insertar_mi_empresa on public.repuestos;
drop policy if exists repuestos_actualizar_mi_empresa on public.repuestos;

create policy repuestos_ver_mi_empresa on public.repuestos
  for select
  using (empresa_id = public.get_empresa_id());

create policy repuestos_insertar_mi_empresa on public.repuestos
  for insert to authenticated
  with check (empresa_id = public.get_empresa_id());

create policy repuestos_actualizar_mi_empresa on public.repuestos
  for update to authenticated
  using (empresa_id = public.get_empresa_id())
  with check (empresa_id = public.get_empresa_id());


-- ------------------------------------------------------------
-- 3. Dar de baja / reactivar exige dar_baja_repuestos
--    Solo corre cuando activo cambia de valor.
--    El servidor (SQL Editor, cron, service role) pasa siempre.
-- ------------------------------------------------------------
create or replace function public.fn_proteger_baja_repuesto()
 returns trigger
 language plpgsql
 security definer
 set search_path = public
as $function$
begin
  if es_llamada_backend() then
    return new;
  end if;

  if not (tiene_permiso('dar_baja_repuestos') or es_super_admin()) then
    raise exception 'No autorizado: no tenes permiso para dar de baja o reactivar repuestos';
  end if;

  return new;
end;
$function$;

comment on function public.fn_proteger_baja_repuesto() is
  'Bloquea el cambio de repuestos.activo si el usuario no tiene dar_baja_repuestos.';

drop trigger if exists trg_proteger_baja_repuesto on public.repuestos;

create trigger trg_proteger_baja_repuesto
  before update on public.repuestos
  for each row
  when (old.activo is distinct from new.activo)
  execute function public.fn_proteger_baja_repuesto();


-- ------------------------------------------------------------
-- 4.a registrar_ingreso_stock
--     Cambios: exige registrar_ingreso desde la app; se lee
--     activo y se rechaza si esta dado de baja.
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
  v_activo boolean;
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

  -- NUEVO: desde la app, el permiso se exige tambien en la base
  IF NOT v_backend AND NOT (tiene_permiso('registrar_ingreso') OR es_super_admin()) THEN
    RAISE EXCEPTION 'No autorizado: no tenes permiso para registrar ingresos de stock';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a cero. Recibido: %', p_cantidad;
  END IF;

  -- Resolver empresa desde el repuesto (y bloquear la fila)
  SELECT empresa_id, activo INTO v_empresa_id, v_activo
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

  -- NUEVO: sin movimientos sobre un repuesto dado de baja
  IF NOT v_activo THEN
    RAISE EXCEPTION 'El repuesto está dado de baja. Reactivalo para registrar movimientos.';
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
-- 4.b registrar_salida_stock
--     Cambios: exige registrar_salida desde la app; se lee
--     activo y se rechaza si esta dado de baja.
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
  v_activo       boolean;
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

  -- NUEVO: desde la app, el permiso se exige tambien en la base
  IF NOT v_backend AND NOT (tiene_permiso('registrar_salida') OR es_super_admin()) THEN
    RAISE EXCEPTION 'No autorizado: no tenes permiso para registrar salidas de stock';
  END IF;

  IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a cero. Recibido: %', p_cantidad;
  END IF;

  SELECT stock_actual, empresa_id, activo
  INTO v_stock_actual, v_empresa_id, v_activo
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

  -- NUEVO: sin movimientos sobre un repuesto dado de baja
  IF NOT v_activo THEN
    RAISE EXCEPTION 'El repuesto está dado de baja. Reactivalo para registrar movimientos.';
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


-- Se mantienen los permisos de ejecucion de la migracion anterior.
revoke execute on function public.registrar_ingreso_stock(uuid, integer, uuid, text, uuid) from public, anon;
revoke execute on function public.registrar_salida_stock(uuid, integer, uuid, text, uuid) from public, anon;


-- ------------------------------------------------------------
-- 5. fn_check_stock_bajo
--    Unico cambio: NEW.activo en la condicion. Un repuesto dado
--    de baja no dispara aviso de WhatsApp.
-- ------------------------------------------------------------
create or replace function public.fn_check_stock_bajo()
 returns trigger
 language plpgsql
 security definer
as $function$
BEGIN
  IF NEW.activo
     AND NEW.stock_actual <= NEW.stock_minimo
     AND OLD.stock_actual > OLD.stock_minimo THEN
    IF (NEW.ultima_alerta_stock_at IS NULL OR
        NOW() - NEW.ultima_alerta_stock_at > INTERVAL '12 hours') THEN
      UPDATE repuestos SET ultima_alerta_stock_at = NOW()
      WHERE id = NEW.id;
      PERFORM net.http_post(
        url := 'https://qxrhrvzvzljeavczzytz.supabase.co/functions/v1/notificar-stock-bajo',
        body := json_build_object(
          'repuesto', NEW.descripcion,
          'stock_actual', NEW.stock_actual,
          'stock_minimo', NEW.stock_minimo,
          'empresa_id', NEW.empresa_id
        )::jsonb,
        headers := '{"Content-Type": "application/json"}'::jsonb
      );
    END IF;
  END IF;
  RETURN NEW;
END; $function$;