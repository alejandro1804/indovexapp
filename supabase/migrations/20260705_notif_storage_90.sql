-- =====================================================================
-- Migración: Notificación in-app al alcanzar el 90% de la cuota de storage
-- Fecha: 2026-07-05
-- Autor: Literal E — IndovexApp
--
-- Contexto:
--   La RPC uso_storage_empresa(p_empresa_id) ya devuelve
--   { usado_mb, limite_mb, porcentaje, desglose }.
--   Esta migración agrega el AVISO AUTOMÁTICO al 90%, escribiendo en la
--   tabla notificaciones existente (in-app), dirigido al usuario con
--   rol 'admin' de cada empresa cliente.
--
-- Patrón replicado de fn_check_stock_bajo() / fn_marcar_empresas_a_purgar():
--   - Función SECURITY DEFINER (la inserción en notificaciones para otro
--     usuario no pasa por RLS normal; el patrón stock_bajo hace lo mismo).
--   - Cron diario que la ejecuta para todas las empresas activas.
--   - Anti-duplicado: no repite si ya existe una notificación NO leída
--     del mismo tipo para ese admin en el día de hoy.
--
-- ALCOA+: no borra ni modifica datos operativos; solo inserta avisos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Función principal: evalúa el storage de UNA empresa y notifica al
--    admin si el uso cruzó el umbral (default 90%).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_storage_empresa(
    p_empresa_id  uuid,
    p_umbral      numeric DEFAULT 90
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uso           jsonb;
    v_porcentaje    numeric;
    v_usado_mb      numeric;
    v_limite_mb     numeric;
    v_admin_id      uuid;
    v_mensaje       text;
    v_ya_existe     boolean;
BEGIN
    -- Uso actual de storage (reutiliza la RPC existente)
    v_uso := uso_storage_empresa(p_empresa_id);

    IF v_uso IS NULL THEN
        RETURN;
    END IF;

    v_porcentaje := COALESCE((v_uso->>'porcentaje')::numeric, 0);
    v_usado_mb   := COALESCE((v_uso->>'usado_mb')::numeric, 0);
    v_limite_mb  := COALESCE((v_uso->>'limite_mb')::numeric, 0);

    -- Debajo del umbral: nada que hacer
    IF v_porcentaje < p_umbral THEN
        RETURN;
    END IF;

    -- Admin de la empresa (rol 'admin', usuario activo)
    SELECT u.id
      INTO v_admin_id
      FROM usuarios u
      JOIN roles r ON r.id = u.rol_id
     WHERE u.empresa_id = p_empresa_id
       AND u.estado = 'activo'
       AND lower(r.nombre) = 'admin'
     ORDER BY u.created_at
     LIMIT 1;

    -- Sin admin activo: no hay a quién avisar
    IF v_admin_id IS NULL THEN
        RETURN;
    END IF;

    -- Anti-duplicado: ¿ya hay un aviso NO leído de storage hoy para este admin?
    SELECT EXISTS (
        SELECT 1
          FROM notificaciones n
         WHERE n.empresa_id = p_empresa_id
           AND n.para_usuario_id = v_admin_id
           AND n.tipo = 'storage_alto'
           AND n.leida = false
           AND n.created_at >= date_trunc('day', now())
    ) INTO v_ya_existe;

    IF v_ya_existe THEN
        RETURN;
    END IF;

    v_mensaje := format(
        'Tu almacenamiento está al %s%% (%s MB de %s MB). Al 100%% se bloquearán nuevas subidas. Podés liberar espacio, adquirir GB adicionales o cambiar de plan.',
        round(v_porcentaje)::text,
        round(v_usado_mb)::text,
        round(v_limite_mb)::text
    );

    INSERT INTO notificaciones (
        tipo,
        mensaje,
        para_usuario_id,
        de_usuario_id,
        empresa_id
    ) VALUES (
        'storage_alto',
        v_mensaje,
        v_admin_id,
        NULL,           -- notificación de sistema (sin usuario emisor)
        p_empresa_id
    );
END;
$$;

COMMENT ON FUNCTION fn_check_storage_empresa(uuid, numeric)
    IS 'Evalúa el uso de storage de una empresa y, si supera el umbral (default 90%), notifica in-app al admin. Anti-duplicado diario. SECURITY DEFINER.';


-- ---------------------------------------------------------------------
-- 2) Barrido de todas las empresas activas (lo llama el cron).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_storage_todas_empresas()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_emp record;
BEGIN
    FOR v_emp IN
        SELECT id
          FROM empresas
         WHERE estado = 'activa'
    LOOP
        BEGIN
            PERFORM fn_check_storage_empresa(v_emp.id, 90);
        EXCEPTION WHEN OTHERS THEN
            -- No abortar el barrido completo por una empresa con error
            RAISE WARNING 'fn_check_storage_empresa falló para empresa %: %',
                v_emp.id, SQLERRM;
        END;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_check_storage_todas_empresas()
    IS 'Recorre todas las empresas activas y dispara fn_check_storage_empresa(). Ejecutada por cron diario.';


-- ---------------------------------------------------------------------
-- 3) Cron diario (pg_cron). 08:00 UTC ≈ 05:00 Montevideo.
--    Se ejecuta después del cron de purga (07:00 UTC) para no solaparse.
-- ---------------------------------------------------------------------
-- Nota: si ya existe un job con este nombre, lo reemplaza.
SELECT cron.unschedule('check-storage-empresas')
 WHERE EXISTS (
     SELECT 1 FROM cron.job WHERE jobname = 'check-storage-empresas'
 );

SELECT cron.schedule(
    'check-storage-empresas',
    '0 8 * * *',
    $cron$ SELECT fn_check_storage_todas_empresas(); $cron$
);
