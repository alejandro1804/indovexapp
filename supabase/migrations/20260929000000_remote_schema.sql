--
-- PostgreSQL database dump
--

\restrict A6AdowTuodaYsxKMiq0bb9ehc7Pfbe1yaBlmjTd17v6n6F2d6CgBPMAbDsgd6Or

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: _dias_plazo(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._dias_plazo(p_clave text) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT dias FROM config_plazos WHERE clave = p_clave;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categorias_repuestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias_repuestos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_categorias_repuestos_descripcion_len CHECK (((descripcion IS NULL) OR (char_length(descripcion) <= 500))),
    CONSTRAINT chk_categorias_repuestos_nombre_len CHECK ((char_length(nombre) <= 100))
);


--
-- Name: admin_categorias_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_categorias_empresa(p_empresa_id uuid) RETURNS SETOF public.categorias_repuestos
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT * FROM categorias_repuestos
  WHERE es_super_admin() AND empresa_id = p_empresa_id
  ORDER BY nombre;
$$;


--
-- Name: maquinas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maquinas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    sector_id uuid NOT NULL,
    nombre text NOT NULL,
    codigo text,
    estado text DEFAULT 'operativa'::text NOT NULL,
    descripcion text,
    imagen_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    tamanio_bytes bigint,
    CONSTRAINT chk_maquinas_codigo_len CHECK ((char_length(codigo) <= 30)),
    CONSTRAINT chk_maquinas_descripcion_len CHECK (((descripcion IS NULL) OR (char_length(descripcion) <= 500))),
    CONSTRAINT chk_maquinas_estado CHECK ((estado = ANY (ARRAY['operativa'::text, 'en_mantenimiento'::text, 'fuera_de_servicio'::text]))),
    CONSTRAINT chk_maquinas_nombre_len CHECK ((char_length(nombre) <= 100))
);


--
-- Name: admin_maquinas_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_maquinas_empresa(p_empresa_id uuid) RETURNS SETOF public.maquinas
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT * FROM maquinas
  WHERE es_super_admin() AND empresa_id = p_empresa_id
  ORDER BY nombre;
$$;


--
-- Name: repuestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repuestos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    categoria_id uuid,
    codigo text,
    descripcion text NOT NULL,
    stock_actual integer DEFAULT 0 NOT NULL,
    stock_minimo integer DEFAULT 0 NOT NULL,
    ubicacion text,
    unidad_medida text DEFAULT 'unidad'::text NOT NULL,
    notas text,
    imagen_url text,
    activo boolean DEFAULT true NOT NULL,
    ref integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    ultima_alerta_stock_at timestamp with time zone,
    tamanio_bytes bigint,
    CONSTRAINT chk_repuestos_codigo_len CHECK (((codigo IS NULL) OR (char_length(codigo) <= 30))),
    CONSTRAINT chk_repuestos_descripcion_len CHECK ((char_length(descripcion) <= 500)),
    CONSTRAINT chk_repuestos_notas_len CHECK (((notas IS NULL) OR (char_length(notas) <= 500))),
    CONSTRAINT chk_repuestos_ubicacion_len CHECK (((ubicacion IS NULL) OR (char_length(ubicacion) <= 100))),
    CONSTRAINT chk_repuestos_unidad_medida CHECK ((unidad_medida = ANY (ARRAY['unidad'::text, 'metro'::text, 'litro'::text, 'kg'::text, 'caja'::text, 'par'::text, 'juego'::text])))
);


--
-- Name: admin_repuestos_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_repuestos_empresa(p_empresa_id uuid) RETURNS SETOF public.repuestos
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT * FROM repuestos
  WHERE es_super_admin() AND empresa_id = p_empresa_id AND activo = true
  ORDER BY descripcion;
$$;


--
-- Name: sectores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sectores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_sectores_descripcion_len CHECK (((descripcion IS NULL) OR (char_length(descripcion) <= 500))),
    CONSTRAINT chk_sectores_nombre_len CHECK ((char_length(nombre) <= 100))
);


--
-- Name: admin_sectores_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_sectores_empresa(p_empresa_id uuid) RETURNS SETOF public.sectores
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT * FROM sectores
  WHERE es_super_admin() AND empresa_id = p_empresa_id
  ORDER BY nombre;
$$;


--
-- Name: admin_tickets_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_tickets_empresa(p_empresa_id uuid) RETURNS TABLE(id uuid, numero text, estado text, descripcion_desperfecto text, created_at timestamp with time zone, maquina_nombre text, sector_nombre text, tecnico_nombre text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT
    t.id, t.numero, t.estado, t.descripcion_desperfecto, t.created_at,
    m.nombre AS maquina_nombre,
    s.nombre AS sector_nombre,
    u.nombre AS tecnico_nombre
  FROM tickets t
  LEFT JOIN maquinas m ON m.id = t.maquina_id
  LEFT JOIN sectores s ON s.id = m.sector_id
  LEFT JOIN usuarios u ON u.id = t.tecnico_id
  WHERE es_super_admin() AND t.empresa_id = p_empresa_id
  ORDER BY t.created_at DESC;
$$;


--
-- Name: admin_usuarios_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_usuarios_empresa(p_empresa_id uuid) RETURNS TABLE(id uuid, nombre text, email text, estado text, rol_nombre text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT u.id, u.nombre, u.email, u.estado, r.nombre AS rol_nombre
  FROM usuarios u
  LEFT JOIN roles r ON r.id = u.rol_id
  WHERE es_super_admin() AND u.empresa_id = p_empresa_id
  ORDER BY u.nombre;
$$;


--
-- Name: aprobar_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aprobar_empresa(p_empresa_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_empresa_plantilla uuid := '3470bac5-45a4-4b9e-837b-d747c7446da3';
  v_rol record;
  v_nuevo_rol_id uuid;
  v_rol_admin_id uuid;
begin
  if not es_super_admin() then
    raise exception 'No autorizado: solo el super admin puede aprobar empresas';
  end if;

  if not exists (
    select 1 from public.empresas
    where id = p_empresa_id and estado = 'pendiente'
  ) then
    raise exception 'La empresa no existe o no está pendiente';
  end if;

  update public.empresas
  set estado = 'activa'
  where id = p_empresa_id;

  for v_rol in
    select id, nombre from public.roles
    where empresa_id = v_empresa_plantilla
  loop
    insert into public.roles (empresa_id, nombre)
    values (p_empresa_id, v_rol.nombre)
    returning id into v_nuevo_rol_id;

    if v_rol.nombre = 'admin' then
      v_rol_admin_id := v_nuevo_rol_id;
    end if;

    insert into public.rol_permisos (rol_id, permiso_id)
    select v_nuevo_rol_id, rp.permiso_id
    from public.rol_permisos rp
    where rp.rol_id = v_rol.id;
  end loop;

  -- Clonar tipos de intervalo desde Demo
  insert into public.tipos_intervalo (empresa_id, nombre, codigo, es_default)
  select p_empresa_id, nombre, codigo, es_default
  from public.tipos_intervalo
  where empresa_id = v_empresa_plantilla;

  update public.usuarios
  set rol_id = v_rol_admin_id
  where empresa_id = p_empresa_id
    and rol_id is null;

end;
$$;


--
-- Name: crear_rol(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_rol(p_nombre text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_empresa_id uuid;
  v_nuevo_id uuid;
begin
  v_empresa_id := get_empresa_id();
  if v_empresa_id is null then
    raise exception 'No se pudo determinar la empresa';
  end if;

  insert into public.roles (empresa_id, nombre)
  values (v_empresa_id, lower(trim(p_nombre)))
  returning id into v_nuevo_id;

  return v_nuevo_id;
end;
$$;


--
-- Name: crear_ticket(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_ticket(p_maquina_id uuid, p_descripcion text, p_foto_url text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_empresa_id uuid;
  v_numero text;
  v_ticket_id uuid;
BEGIN
  -- Obtiene la empresa del usuario actual
  SELECT empresa_id INTO v_empresa_id
  FROM usuarios
  WHERE id = auth.uid();

  -- Genera el número
  v_numero := generar_numero_ticket(v_empresa_id);

  -- Inserta el ticket
  INSERT INTO tickets (
    empresa_id, maquina_id, creado_por,
    numero, estado, descripcion_desperfecto, foto_url
  ) VALUES (
    v_empresa_id, p_maquina_id, auth.uid(),
    v_numero, 'abierto', p_descripcion, p_foto_url
  )
  RETURNING id INTO v_ticket_id;

  RETURN v_ticket_id;
END;
$$;


--
-- Name: dashboard_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dashboard_kpis() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_empresa_id uuid := get_empresa_id();
  v_ratio       jsonb;
  v_mttr        jsonb;
  v_backlog     jsonb;
begin
  -- Si no hay empresa en sesión, devolver vacío
  if v_empresa_id is null then
    return jsonb_build_object('error', 'sin_empresa');
  end if;

  -- ============================================
  -- KPI 1: RATIO PREVENTIVO / CORRECTIVO
  -- ============================================
  select jsonb_build_object(
    'preventivo', coalesce(sum(case when tipo = 'preventivo' then 1 else 0 end), 0),
    'correctivo', coalesce(sum(case when tipo = 'correctivo' then 1 else 0 end), 0),
    'total',      count(*)
  )
  into v_ratio
  from public.tickets
  where empresa_id = v_empresa_id;

  -- ============================================
  -- KPI 2: MTTR (solo correctivos cerrados)
  -- ============================================
  select jsonb_build_object(
    'tickets_considerados', count(*),
    'mttr_horas', case
                    when count(*) = 0 then null
                    else round(avg(extract(epoch from (fecha_cierre - created_at)) / 3600)::numeric, 1)
                  end
  )
  into v_mttr
  from public.tickets
  where empresa_id = v_empresa_id
    and tipo = 'correctivo'
    and estado = 'cerrado'
    and fecha_cierre is not null;

  -- ============================================
  -- KPI 3: BACKLOG por prioridad y antigüedad
  -- ============================================
  select coalesce(jsonb_agg(fila order by orden), '[]'::jsonb)
  into v_backlog
  from (
    select
      jsonb_build_object(
        'prioridad',   prioridad,
        'rango_0_3',   count(*) filter (where now() - created_at <  interval '3 days'),
        'rango_4_7',   count(*) filter (where now() - created_at >= interval '3 days' and now() - created_at < interval '7 days'),
        'rango_mas_7', count(*) filter (where now() - created_at >= interval '7 days'),
        'total',       count(*)
      ) as fila,
      case prioridad
        when 'critica' then 1 when 'alta' then 2 when 'media' then 3 when 'baja' then 4 else 5
      end as orden
    from public.tickets
    where empresa_id = v_empresa_id
      and estado in ('abierto', 'asignado', 'en_proceso', 'resuelto')
    group by prioridad
  ) sub;

  -- ============================================
  -- Resultado combinado
  -- ============================================
  return jsonb_build_object(
    'ratio',   v_ratio,
    'mttr',    v_mttr,
    'backlog', v_backlog
  );
end;
$$;


--
-- Name: egress_todas_empresas(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.egress_todas_empresas(p_periodo date DEFAULT NULL::date) RETURNS TABLE(empresa_id uuid, empresa_nom text, total_bytes bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    e.id,
    e.nombre,
    coalesce(sum(a.bytes), 0) as total_bytes
  from public.empresas e
  left join public.egress_mensual_agg a
    on a.empresa_id = e.id
   and a.periodo = date_trunc('month', coalesce(p_periodo, now()))::date
  where es_super_admin()          -- solo super admin ve el panorama global
  group by e.id, e.nombre
  order by total_bytes desc;
$$;


--
-- Name: eliminar_rol(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.eliminar_rol(p_rol_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_empresa_id uuid;
  v_nombre text;
  v_usuarios int;
begin
  v_empresa_id := get_empresa_id();

  select nombre into v_nombre
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  if v_nombre in ('admin', 'encargado', 'tecnico') then
    raise exception 'El rol "%" es un rol del sistema y no se puede eliminar', v_nombre;
  end if;

  select count(*) into v_usuarios
  from public.usuarios
  where rol_id = p_rol_id;

  if v_usuarios > 0 then
    raise exception 'El rol tiene % usuario(s) asignado(s). Reasignalos antes de eliminar.', v_usuarios;
  end if;

  delete from public.rol_permisos where rol_id = p_rol_id;
  delete from public.roles where id = p_rol_id and empresa_id = v_empresa_id;
end;
$$;


--
-- Name: es_admin_empresa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_admin_empresa() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    -- El super admin no obliga contractualmente a ninguna empresa,
    -- aunque su rol tenga los permisos operativos.
    not coalesce(
      (select es_super_admin from public.usuarios where id = auth.uid()),
      false
    )
    and exists (select 1 from mis_permisos() p where p = 'gestionar_usuarios')
    and exists (select 1 from mis_permisos() p where p = 'gestionar_roles');
$$;


--
-- Name: FUNCTION es_admin_empresa(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.es_admin_empresa() IS 'true si el usuario actual puede obligar contractualmente a su empresa (T&C cl. 1). Exige gestionar_usuarios AND gestionar_roles, y excluye al super admin.';


--
-- Name: es_super_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_super_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select coalesce(
    (select es_super_admin
     from public.usuarios
     where id = auth.uid()
       and estado = 'activo'),
    false
  );
$$;


--
-- Name: establecer_permisos_rol(uuid, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_empresa_id uuid;
  v_nombre text;
  v_final uuid[];
begin
  v_empresa_id := get_empresa_id();

  select nombre into v_nombre
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  v_final := p_permiso_ids;

  -- Si es el rol admin, forzar que conserve los permisos de gestion
  if v_nombre = 'admin' then
    select array(
      select distinct unnest(
        v_final || array(
          select id from public.permisos
          where codigo in ('gestionar_roles', 'gestionar_usuarios')
        )
      )
    ) into v_final;
  end if;

  -- Reemplazar todos los permisos del rol
  delete from public.rol_permisos where rol_id = p_rol_id;

  insert into public.rol_permisos (rol_id, permiso_id)
  select p_rol_id, unnest(v_final);
end;
$$;


--
-- Name: estado_mi_empresa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.estado_mi_empresa() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select e.estado
  from public.usuarios u
  join public.empresas e on e.id = u.empresa_id
  where u.id = auth.uid()
  limit 1;
$$;


--
-- Name: fn_aplicar_limites_plan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_aplicar_limites_plan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_lim record;
begin
  if tg_op = 'UPDATE' and new.plan is not distinct from old.plan then
    return new;
  end if;

  select * into v_lim from public.fn_limites_plan(new.plan);

  if v_lim.max_usuarios is null then
    raise exception 'Plan sin limites definidos: %', new.plan;
  end if;

  new.max_usuarios     := v_lim.max_usuarios;
  new.max_maquinas     := v_lim.max_maquinas;
  new.storage_mb_limit := v_lim.storage_mb;

  return new;
end;
$$;


--
-- Name: FUNCTION fn_aplicar_limites_plan(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_aplicar_limites_plan() IS 'Deriva max_usuarios/max_maquinas/storage_mb_limit del tier de plan.';


--
-- Name: fn_asignar_numero_ticket(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_asignar_numero_ticket() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_max int;
begin
  -- Lock por empresa: serializa inserts simultáneos de la misma empresa,
  -- evitando que dos lean el mismo "último" número.
  perform pg_advisory_xact_lock(hashtext(new.empresa_id::text));

  select coalesce(max( (regexp_replace(numero, '\D', '', 'g'))::int ), 0)
    into v_max
  from public.tickets
  where empresa_id = new.empresa_id
    and numero ~ '^TK-\d+$';

  new.numero := 'TK-' || lpad((v_max + 1)::text, 4, '0');
  return new;
end;
$_$;


--
-- Name: fn_audit_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_audit_log() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
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


--
-- Name: fn_check_stock_bajo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_check_stock_bajo() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.stock_actual <= NEW.stock_minimo
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
END; $$;


--
-- Name: fn_check_storage_empresa(uuid, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric DEFAULT 90) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: FUNCTION fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric) IS 'Evalúa el uso de storage de una empresa y, si supera el umbral (default 90%), notifica in-app al admin. Anti-duplicado diario. SECURITY DEFINER.';


--
-- Name: fn_check_storage_todas_empresas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_check_storage_todas_empresas() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: FUNCTION fn_check_storage_todas_empresas(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_check_storage_todas_empresas() IS 'Recorre todas las empresas activas y dispara fn_check_storage_empresa(). Ejecutada por cron diario.';


--
-- Name: fn_disparar_push(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_disparar_push(p_para_usuario_id uuid, p_mensaje text, p_ticket_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_key text;
  v_url text := 'https://qxrhrvzvzljeavczzytz.supabase.co/functions/v1/enviar-push';
begin
  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'service_key'
  limit 1;

  if v_key is null then
    return;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'record', jsonb_build_object(
        'para_usuario_id', p_para_usuario_id,
        'mensaje', p_mensaje,
        'ticket_id', p_ticket_id
      )
    ),
    timeout_milliseconds := 15000   -- 15s en vez de los 5s por defecto
  );
end;
$$;


--
-- Name: fn_empresa_tiene_espacio(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_empresa_tiene_espacio() RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_empresa_id  uuid;
    v_uso         jsonb;
    v_usado_mb    numeric;
    v_limite_mb   numeric;
BEGIN
    -- Super admin nunca se bloquea
    IF es_super_admin() THEN
        RETURN true;
    END IF;

    v_empresa_id := get_empresa_id();

    -- Sin empresa resoluble: no bloquear por cuota (otras policies deciden)
    IF v_empresa_id IS NULL THEN
        RETURN true;
    END IF;

    -- Cálculo de uso vía RPC existente. Fail-safe ante error de ejecución.
    BEGIN
        v_uso := uso_storage_empresa(v_empresa_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'fn_empresa_tiene_espacio: uso_storage_empresa falló para %: %',
            v_empresa_id, SQLERRM;
        RETURN true;  -- no bloquear operación por un error de cálculo
    END;

    IF v_uso IS NULL THEN
        RETURN true;
    END IF;

    v_usado_mb  := COALESCE((v_uso->>'usado_mb')::numeric, 0);
    v_limite_mb := COALESCE((v_uso->>'limite_mb')::numeric, 0);

    -- Límite 0 o negativo = sin cuota disponible → bloquear
    IF v_limite_mb <= 0 THEN
        RETURN false;
    END IF;

    -- Hay espacio solo si el uso está por debajo del límite (100%)
    RETURN v_usado_mb < v_limite_mb;
END;
$$;


--
-- Name: FUNCTION fn_empresa_tiene_espacio(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_empresa_tiene_espacio() IS 'TRUE si usado_mb < limite_mb para la empresa del usuario actual. limite_mb<=0 → FALSE (sin cuota). Super admin siempre TRUE. Fail-safe ante error de cálculo. No depende del campo porcentaje (frágil ante división por cero). Usada por RLS de storage.objects.';


--
-- Name: fn_limites_plan(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_limites_plan(p_plan text) RETURNS TABLE(max_usuarios integer, max_maquinas integer, storage_mb integer)
    LANGUAGE sql IMMUTABLE
    AS $$
  select t.max_usuarios, t.max_maquinas, t.storage_mb
  from (values
    ('trial',    5,   30,  100),
    ('starter',  10,  50,  200),
    ('pro',      20,  150, 600),
    ('interno',  50,  500, 2000)
  ) as t(plan, max_usuarios, max_maquinas, storage_mb)
  where t.plan = p_plan;
$$;


--
-- Name: fn_marcar_empresas_a_purgar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_marcar_empresas_a_purgar() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  PERFORM set_config('app.bypass_proteccion_empresa', 'on', true);

  UPDATE empresas
  SET estado = 'a_purgar'
  WHERE estado IN ('suspendida', 'en_baja')
    AND fecha_purga_programada IS NOT NULL
    AND fecha_purga_programada <= CURRENT_DATE;
END;
$$;


--
-- Name: fn_notificar_involucrados_ticket(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_notificar_involucrados_ticket() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_actor       uuid := auth.uid();
  v_mensaje     text;
  v_tipo        text;
  v_numero      text := new.numero;
  v_es_insert   boolean := (tg_op = 'INSERT');
  v_nombre_actor text;
  v_dest        record;
begin
  if tg_op = 'UPDATE' and new.estado is not distinct from old.estado then
    return new;
  end if;

  if v_actor is not null then
    select nombre into v_nombre_actor from public.usuarios where id = v_actor;
  end if;

  if v_es_insert then
    v_tipo := 'ticket_nuevo';
    v_mensaje := 'Nuevo ticket ' || v_numero ||
                 coalesce(' creado por ' || v_nombre_actor, '');
  else
    v_tipo := 'ticket_' || new.estado;
    v_mensaje := case new.estado
      when 'asignado'   then 'Ticket ' || v_numero || ' fue asignado'
      when 'en_proceso' then 'Ticket ' || v_numero || ' está en proceso'
      when 'pausado'    then 'Ticket ' || v_numero || ' fue pausado'
      when 'resuelto'   then 'Ticket ' || v_numero || ' fue resuelto'
      when 'cerrado'    then 'Ticket ' || v_numero || ' fue cerrado'
      when 'rechazado'  then 'Ticket ' || v_numero || ' fue rechazado'
      when 'abierto'    then 'Ticket ' || v_numero || ' fue reabierto'
      else 'Ticket ' || v_numero || ' cambió de estado'
    end;
  end if;

  -- Insertar notificación in-app + disparar push para cada involucrado único.
  for v_dest in
    select distinct d.usuario_id
    from (
      select new.creado_por as usuario_id where new.creado_por is not null
      union
      select new.tecnico_id where new.tecnico_id is not null
      union
      select u.id
      from public.usuarios u
      join public.rol_permisos rp on rp.rol_id = u.rol_id
      join public.permisos p on p.id = rp.permiso_id
      where u.empresa_id = new.empresa_id
        and u.estado = 'activo'
        and p.codigo = 'recibir_notificaciones_tickets'
    ) d
    where d.usuario_id is not null
      and d.usuario_id is distinct from v_actor
  loop
    -- 1) notificación in-app
    insert into public.notificaciones
      (tipo, mensaje, ticket_id, para_usuario_id, de_usuario_id, empresa_id, leida)
    values
      (v_tipo, v_mensaje, new.id, v_dest.usuario_id, v_actor, new.empresa_id, false);

    -- 2) push
    perform public.fn_disparar_push(v_dest.usuario_id, v_mensaje, new.id);
  end loop;

  return new;
end;
$$;


--
-- Name: fn_pagos_suscripcion_inmutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_pagos_suscripcion_inmutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if tg_op = 'DELETE' then
    raise exception 'pagos_suscripcion es append-only: DELETE no permitido (id=%)', old.id;
  end if;

  if new.id                is distinct from old.id
     or new.empresa_id        is distinct from old.empresa_id
     or new.mp_payment_id     is distinct from old.mp_payment_id
     or new.mp_suscripcion_id is distinct from old.mp_suscripcion_id
     or new.mp_plan_id        is distinct from old.mp_plan_id
     or new.monto             is distinct from old.monto
     or new.moneda            is distinct from old.moneda
     or new.fecha_pago        is distinct from old.fecha_pago
     or new.cuota_numero      is distinct from old.cuota_numero
     or new.comision_mp       is distinct from old.comision_mp
     or new.monto_neto        is distinct from old.monto_neto
     or new.creado            is distinct from old.creado
  then
    raise exception 'pagos_suscripcion: solo se pueden modificar los campos de facturación (id=%)', old.id;
  end if;

  if new.mp_cuota_id is distinct from old.mp_cuota_id
     and old.mp_cuota_id is not null then
    raise exception 'pagos_suscripcion: mp_cuota_id ya asignado, no se puede cambiar (id=%)', old.id;
  end if;

  if new.estado is distinct from old.estado
     and not (old.estado = 'approved' and new.estado in ('refunded', 'charged_back')) then
    raise exception 'pagos_suscripcion: transición de estado no permitida % → % (id=%)',
      old.estado, new.estado, old.id;
  end if;

  return new;
end;
$$;


--
-- Name: fn_proteger_aceptaciones(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_proteger_aceptaciones() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'Las aceptaciones legales son inmutables (operacion: %)', tg_op;
end;
$$;


--
-- Name: FUNCTION fn_proteger_aceptaciones(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_proteger_aceptaciones() IS 'Impide modificar o borrar aceptaciones. Trazabilidad ALCOA+.';


--
-- Name: fn_proteger_audit_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_proteger_audit_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'El audit log es inmutable. No se permiten modificaciones ni eliminaciones.';
END;
$$;


--
-- Name: fn_proteger_columnas_empresa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_proteger_columnas_empresa() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  -- Conexiones directas (SQL Editor, pg_cron, migraciones)
  if session_user <> 'authenticator' then
    return new;
  end if;

  -- Edge Functions con service_role: backend confiable
  if coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '') = 'service_role' then
    return new;
  end if;

  if es_super_admin() then
    return new;
  end if;

  if current_setting('app.bypass_proteccion_empresa', true) = 'on' then
    return new;
  end if;

  if new.plan                      is distinct from old.plan
     or new.activa                 is distinct from old.activa
     or new.max_usuarios           is distinct from old.max_usuarios
     or new.max_maquinas           is distinct from old.max_maquinas
     or new.storage_mb_limit       is distinct from old.storage_mb_limit
     or new.estado                 is distinct from old.estado
     or new.trial_vence            is distinct from old.trial_vence
     or new.mp_plan_id             is distinct from old.mp_plan_id
     or new.mp_suscripcion_id      is distinct from old.mp_suscripcion_id
     or new.suscripcion_estado     is distinct from old.suscripcion_estado
     or new.suscripcion_actualizada is distinct from old.suscripcion_actualizada
     or new.fecha_suspension       is distinct from old.fecha_suspension
     or new.fecha_baja_solicitada  is distinct from old.fecha_baja_solicitada
     or new.fecha_purga_programada is distinct from old.fecha_purga_programada
     or new.created_at             is distinct from old.created_at
  then
    raise exception 'No está permitido modificar campos de plan, suscripción o límites desde el perfil de empresa.';
  end if;

  return new;
end;
$$;


--
-- Name: fn_proteger_ticket_comentarios(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_proteger_ticket_comentarios() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'Los comentarios de ticket son inmutables (append-only)';
end;
$$;


--
-- Name: fn_sectores_usuario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_sectores_usuario() RETURNS uuid[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(array_agg(sector_id), ARRAY[]::uuid[])
  FROM usuario_sector
  WHERE usuario_id = auth.uid();
$$;


--
-- Name: fn_set_empresa_dispositivo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_dispositivo() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.empresa_id is null then
    select empresa_id into new.empresa_id
    from public.usuarios where id = new.usuario_id;
  end if;
  return new;
end;
$$;


--
-- Name: fn_set_empresa_maquina_documentos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_maquina_documentos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM maquinas WHERE id = NEW.maquina_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_set_empresa_notificaciones(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_notificaciones() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM usuarios WHERE id = NEW.para_usuario_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_set_empresa_repuestos_maquinas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_repuestos_maquinas() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM repuestos WHERE id = NEW.repuesto_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_set_empresa_ticket_comentario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_ticket_comentario() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.empresa_id is null then
    select t.empresa_id into new.empresa_id
    from public.tickets t where t.id = new.ticket_id;
  end if;
  return new;
end;
$$;


--
-- Name: fn_set_empresa_ticket_fotos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_ticket_fotos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM tickets WHERE id = NEW.ticket_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_set_empresa_ticket_historial(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_ticket_historial() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM tickets WHERE id = NEW.ticket_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_set_empresa_usuario_sector(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_set_empresa_usuario_sector() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.empresa_id IS NULL THEN
    SELECT empresa_id INTO NEW.empresa_id FROM sectores WHERE id = NEW.sector_id;
  END IF;
  RETURN NEW;
END; $$;


--
-- Name: fn_usuario_restringido_sector(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_usuario_restringido_sector() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(r.restringe_por_sector, false)
  FROM usuarios u
  JOIN roles r ON r.id = u.rol_id
  WHERE u.id = auth.uid();
$$;


--
-- Name: fn_validar_empresa_maquina_sector(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_empresa_maquina_sector() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_empresa_sector uuid;
BEGIN
  SELECT empresa_id INTO v_empresa_sector
  FROM sectores WHERE id = NEW.sector_id;

  IF v_empresa_sector IS NULL THEN
    RAISE EXCEPTION 'El sector indicado no existe';
  END IF;

  IF v_empresa_sector <> NEW.empresa_id THEN
    RAISE EXCEPTION 'El sector pertenece a otra empresa';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fn_validar_empresa_repuesto_categoria(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_empresa_repuesto_categoria() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_empresa_categoria uuid;
BEGIN
  -- categoria_id es opcional
  IF NEW.categoria_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT empresa_id INTO v_empresa_categoria
  FROM categorias_repuestos WHERE id = NEW.categoria_id;

  IF v_empresa_categoria IS NULL THEN
    RAISE EXCEPTION 'La categoría indicada no existe';
  END IF;

  IF v_empresa_categoria <> NEW.empresa_id THEN
    RAISE EXCEPTION 'La categoría pertenece a otra empresa';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fn_validar_empresa_usuario_rol(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_empresa_usuario_rol() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_empresa_rol uuid;
  v_existe boolean;
BEGIN
  -- rol_id es opcional
  IF NEW.rol_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT empresa_id, true INTO v_empresa_rol, v_existe
  FROM roles WHERE id = NEW.rol_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El rol indicado no existe';
  END IF;

  -- Roles globales (empresa_id NULL) son válidos para cualquier empresa
  IF v_empresa_rol IS NOT NULL AND v_empresa_rol <> NEW.empresa_id THEN
    RAISE EXCEPTION 'El rol pertenece a otra empresa';
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: fn_validar_limite_maquinas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_limite_maquinas() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_actuales int;
  v_limite   int;
  v_plan     text;
begin
  select max_maquinas, plan
    into v_limite, v_plan
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;
  end if;

  select count(*) into v_actuales
  from public.maquinas
  where empresa_id = new.empresa_id;

  if v_actuales >= v_limite then
    raise exception
      'Límite de máquinas alcanzado (% de %). Tu plan % permite hasta % máquinas. Podés cambiar de plan para ampliarlo.',
      v_actuales, v_limite, v_plan, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;


--
-- Name: FUNCTION fn_validar_limite_maquinas(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_validar_limite_maquinas() IS 'Bloquea el alta de maquinas al alcanzar empresas.max_maquinas.';


--
-- Name: fn_validar_limite_usuarios(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_limite_usuarios() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_actuales int;
  v_limite   int;
  v_plan     text;
begin
  select max_usuarios, plan
    into v_limite, v_plan
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;  -- sin límite definido: no bloquear
  end if;

  select count(*) into v_actuales
  from public.usuarios
  where empresa_id = new.empresa_id
    and estado = 'activo';

  if v_actuales >= v_limite then
    raise exception
      'Límite de usuarios alcanzado (% de %). Tu plan % permite hasta % usuarios activos. Podés desactivar un usuario o cambiar de plan.',
      v_actuales, v_limite, v_plan, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;


--
-- Name: FUNCTION fn_validar_limite_usuarios(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_validar_limite_usuarios() IS 'Bloquea el alta de usuarios al alcanzar empresas.max_usuarios. Cuenta solo activos.';


--
-- Name: fn_validar_limite_usuarios_reactivar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_limite_usuarios_reactivar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_actuales int;
  v_limite   int;
begin
  if not (old.estado <> 'activo' and new.estado = 'activo') then
    return new;
  end if;

  select max_usuarios into v_limite
  from public.empresas
  where id = new.empresa_id;

  if v_limite is null then
    return new;
  end if;

  select count(*) into v_actuales
  from public.usuarios
  where empresa_id = new.empresa_id
    and estado = 'activo'
    and id <> new.id;

  if v_actuales >= v_limite then
    raise exception
      'Límite de usuarios alcanzado (% de %). No podés reactivar este usuario sin desactivar otro o cambiar de plan.',
      v_actuales, v_limite
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;


--
-- Name: FUNCTION fn_validar_limite_usuarios_reactivar(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_validar_limite_usuarios_reactivar() IS 'Bloquea la reactivacion de usuarios si la empresa ya llego a su cupo.';


--
-- Name: generar_numero_ticket(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generar_numero_ticket(p_empresa_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_año text := to_char(now(), 'YY');
  v_numero int;
  v_resultado text;
BEGIN
  -- Cuenta los tickets de esta empresa en el año actual y suma 1
  SELECT COUNT(*) + 1 INTO v_numero
  FROM tickets
  WHERE empresa_id = p_empresa_id
    AND to_char(created_at, 'YY') = v_año;

  -- Formato: TK-25-00001
  v_resultado := 'TK-' || v_año || '-' || LPAD(v_numero::text, 5, '0');

  RETURN v_resultado;
END;
$$;


--
-- Name: config_plazos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.config_plazos (
    clave text NOT NULL,
    dias integer NOT NULL,
    descripcion text
);


--
-- Name: get_config_plazos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_config_plazos() RETURNS SETOF public.config_plazos
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT * FROM config_plazos ORDER BY clave;
$$;


--
-- Name: get_empresa_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_empresa_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select empresa_id
  from public.usuarios
  where id = auth.uid()
    and estado = 'activo'   -- usuario desactivado => no devuelve empresa
  limit 1;
$$;


--
-- Name: get_mtbf_empresa(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_mtbf_empresa() RETURNS TABLE(maquina_id uuid, maquina_nombre text, sector_nombre text, mtbf_dias numeric, total_tickets_correctivos integer, confiabilidad text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT
    v.maquina_id,
    v.maquina_nombre,
    v.sector_nombre,
    v.mtbf_dias,
    v.total_tickets_correctivos::integer,
    CASE
      WHEN v.total_tickets_correctivos < 3 THEN 'baja'
      WHEN v.total_tickets_correctivos < 6 THEN 'media'
      ELSE 'alta'
    END AS confiabilidad
  FROM vw_mtbf_maquinas v
  WHERE v.empresa_id = get_empresa_id()
  ORDER BY v.mtbf_dias ASC;
$$;


--
-- Name: legal_aceptar(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_empresa_id uuid;
  v_usuario_id uuid;
  v_vigente    boolean;
  v_ip         text;
  v_id         uuid;
begin
  v_empresa_id := get_empresa_id();
  if v_empresa_id is null then
    raise exception 'Usuario sin empresa asignada';
  end if;

  select id into v_usuario_id
  from public.usuarios
  where id = auth.uid()
    and estado = 'activo';

  if v_usuario_id is null then
    raise exception 'Usuario no encontrado o inactivo';
  end if;

  if not es_admin_empresa() then
    raise exception 'Solo el administrador de la empresa puede aceptar documentos legales';
  end if;

  select vigente into v_vigente
  from public.documentos_legales
  where id = p_documento_legal_id;

  if v_vigente is null then
    raise exception 'Documento legal inexistente';
  end if;
  if not v_vigente then
    raise exception 'El documento no se encuentra vigente';
  end if;

  -- IP de origen (Cloudflare la propaga en cf-connecting-ip).
  -- Envuelto: request.headers no existe fuera de PostgREST.
  begin
    v_ip := nullif(
      current_setting('request.headers', true)::json ->> 'cf-connecting-ip',
      ''
    );
  exception when others then
    v_ip := null;
  end;

  insert into public.aceptaciones_legales (
    empresa_id, documento_legal_id, usuario_id, ip_origen, user_agent
  ) values (
    v_empresa_id, p_documento_legal_id, v_usuario_id, v_ip::inet, p_user_agent
  )
  on conflict (empresa_id, documento_legal_id) do nothing
  returning id into v_id;

  -- Idempotente: si ya existía, devolver la previa
  if v_id is null then
    select id into v_id
    from public.aceptaciones_legales
    where empresa_id = v_empresa_id
      and documento_legal_id = p_documento_legal_id;
  end if;

  return v_id;
end;
$$;


--
-- Name: FUNCTION legal_aceptar(p_documento_legal_id uuid, p_user_agent text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text) IS 'Registra aceptacion de un documento vigente. Solo admin de empresa. Idempotente.';


--
-- Name: legal_estado_pendiente(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.legal_estado_pendiente() RETURNS TABLE(documento_legal_id uuid, documento text, version text, fecha_publicacion date, fecha_vigencia date, url text, resumen_cambios text, bloqueante boolean, en_preaviso boolean, dias_restantes integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_empresa_id uuid;
  v_es_admin   boolean;
begin
  v_empresa_id := get_empresa_id();

  if v_empresa_id is null then
    return;  -- super admin en consola: sin empresa, sin pendientes
  end if;

  v_es_admin := es_admin_empresa();

  return query
  select
    dl.id,
    dl.documento,
    dl.version,
    dl.fecha_publicacion,
    dl.fecha_vigencia,
    dl.url,
    dl.resumen_cambios,
    -- Bloquea solo si: requiere aceptación
    --                  Y el usuario es admin
    --                  Y ya venció el preaviso
    (
      dl.requiere_aceptacion
      and v_es_admin
      and current_date >= dl.fecha_vigencia
    ) as bloqueante,
    -- En preaviso: publicado pero aún no vigente
    (current_date < dl.fecha_vigencia) as en_preaviso,
    greatest(dl.fecha_vigencia - current_date, 0)::int as dias_restantes
  from public.documentos_legales dl
  left join public.aceptaciones_legales al
    on al.documento_legal_id = dl.id
   and al.empresa_id = v_empresa_id
  where dl.vigente = true
    and al.id is null
    and current_date >= dl.fecha_publicacion   -- no anunciar antes de publicar
  order by dl.documento;
end;
$$;


--
-- Name: FUNCTION legal_estado_pendiente(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.legal_estado_pendiente() IS 'Documentos vigentes pendientes de aceptar por la empresa del usuario. Durante el preaviso (publicacion..vigencia) devuelve en_preaviso=true y bloqueante=false; vencido el preaviso, bloqueante=true para admins.';


--
-- Name: listar_empresas_pendientes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.listar_empresas_pendientes() RETURNS TABLE(empresa_id uuid, empresa_nombre text, rut text, direccion text, telefono text, email_contacto text, created_at timestamp with time zone, admin_nombre text, admin_email text)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select
    e.id, e.nombre, e.rut, e.direccion, e.telefono, e.email_contacto, e.created_at,
    u.nombre, u.email
  from public.empresas e
  left join public.usuarios u on u.empresa_id = e.id
  where e.estado = 'pendiente'
    and es_super_admin()
  order by e.created_at desc;
$$;


--
-- Name: listar_todas_empresas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.listar_todas_empresas() RETURNS TABLE(empresa_id uuid, empresa_nombre text, rut text, email_contacto text, created_at timestamp with time zone, estado text, plan text, activa boolean, trial_vence timestamp with time zone, tiene_suscripcion boolean, storage_mb_limit integer, fecha_suspension timestamp with time zone, fecha_baja_solicitada timestamp with time zone, fecha_purga_programada date)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT
    e.id, e.nombre, e.rut, e.email_contacto, e.created_at,
    e.estado, e.plan, e.activa, e.trial_vence,
    (e.mp_suscripcion_id IS NOT NULL) AS tiene_suscripcion,
    e.storage_mb_limit,
    e.fecha_suspension, e.fecha_baja_solicitada, e.fecha_purga_programada
  FROM public.empresas e
  WHERE es_super_admin()
  ORDER BY e.created_at DESC;
$$;


--
-- Name: pagos_suscripcion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pagos_suscripcion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    mp_payment_id text NOT NULL,
    mp_suscripcion_id text,
    mp_plan_id text,
    monto numeric(12,2) NOT NULL,
    moneda text DEFAULT 'UYU'::text NOT NULL,
    estado text NOT NULL,
    fecha_pago timestamp with time zone,
    facturado boolean DEFAULT false NOT NULL,
    factura_numero text,
    factura_fecha timestamp with time zone,
    creado timestamp with time zone DEFAULT now() NOT NULL,
    actualizado timestamp with time zone DEFAULT now() NOT NULL,
    mp_cuota_id text,
    cuota_numero integer,
    comision_mp numeric,
    monto_neto numeric,
    CONSTRAINT pagos_suscripcion_estado_check CHECK ((estado = ANY (ARRAY['approved'::text, 'rejected'::text, 'refunded'::text, 'cancelled'::text, 'charged_back'::text])))
);


--
-- Name: COLUMN pagos_suscripcion.mp_payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pagos_suscripcion.mp_payment_id IS 'Id del pago real de MercadoPago (/v1/payments). Clave de idempotencia.';


--
-- Name: COLUMN pagos_suscripcion.mp_cuota_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pagos_suscripcion.mp_cuota_id IS 'Id del authorized_payment (cuota de la suscripción), si se conoce.';


--
-- Name: COLUMN pagos_suscripcion.cuota_numero; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pagos_suscripcion.cuota_numero IS 'Número de cuota de la suscripción (subscription_sequence.number).';


--
-- Name: COLUMN pagos_suscripcion.comision_mp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pagos_suscripcion.comision_mp IS 'Comisión cobrada por MercadoPago al vendedor.';


--
-- Name: COLUMN pagos_suscripcion.monto_neto; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pagos_suscripcion.monto_neto IS 'Monto neto acreditado (monto - comisión).';


--
-- Name: marcar_pago_facturado(uuid, boolean, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.marcar_pago_facturado(p_pago_id uuid, p_facturado boolean DEFAULT true, p_factura_numero text DEFAULT NULL::text, p_factura_fecha timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS public.pagos_suscripcion
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_row pagos_suscripcion;
begin
  -- 1. Solo super admin puede facturar
  if not es_super_admin() then
    raise exception 'No autorizado: se requiere super admin';
  end if;

  -- 2. Marcar o desmarcar
  if p_facturado then
    -- Marcar como facturado (usa la fecha pasada, o now() si es null)
    update pagos_suscripcion
    set facturado      = true,
        factura_numero = p_factura_numero,
        factura_fecha  = coalesce(p_factura_fecha, now()),
        actualizado    = now()
    where id = p_pago_id
    returning * into v_row;
  else
    -- Desmarcar: revertir y limpiar datos de la factura anulada
    update pagos_suscripcion
    set facturado      = false,
        factura_numero = null,
        factura_fecha  = null,
        actualizado    = now()
    where id = p_pago_id
    returning * into v_row;
  end if;

  -- 3. Validar que el pago exista
  if v_row.id is null then
    raise exception 'Pago no encontrado: %', p_pago_id;
  end if;

  return v_row;
end;
$$;


--
-- Name: mis_permisos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mis_permisos() RETURNS SETOF text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  select p.codigo
  from public.usuarios u
  join public.rol_permisos rp on rp.rol_id = u.rol_id
  join public.permisos p on p.id = rp.permiso_id
  where u.id = auth.uid();
$$;


--
-- Name: proteger_campos_usuario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.proteger_campos_usuario() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  -- Super admin puede cambiar todo
  if es_super_admin() then
    return new;
  end if;

  -- Bloquear es_super_admin para todos los demás
  if new.es_super_admin is distinct from old.es_super_admin then
    raise exception 'No autorizado: no se puede modificar es_super_admin';
  end if;

  -- Bloquear empresa_id para todos los demás
  if new.empresa_id is distinct from old.empresa_id then
    raise exception 'No autorizado: no se puede modificar empresa_id';
  end if;

  -- Bloquear cambio de rol_id SOLO sobre el propio usuario (auto-promoción)
  if new.rol_id is distinct from old.rol_id and old.id = auth.uid() then
    raise exception 'No autorizado: no se puede cambiar el rol propio';
  end if;

  return new;
end;
$$;


--
-- Name: puede_comentar_ticket(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.puede_comentar_ticket(p_ticket_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_uid       uuid := auth.uid();
  v_tiene     boolean;
  v_ticket    public.tickets%rowtype;
  v_vinculado boolean;
begin
  select * into v_ticket from public.tickets where id = p_ticket_id;
  if not found then return false; end if;

  -- estado terminal: nadie comenta
  if v_ticket.estado in ('cerrado', 'rechazado') then
    return false;
  end if;

  -- 1) permiso
  select exists (
    select 1
    from public.usuarios u
    join public.rol_permisos rp on rp.rol_id = u.rol_id
    join public.permisos pe on pe.id = rp.permiso_id
    where u.id = v_uid and u.estado = 'activo'
      and pe.codigo = 'comentar_ticket'
  ) into v_tiene;
  if not v_tiene then return false; end if;

  -- 2) pertenencia: creador OR técnico asignado OR encargado del sector
  v_vinculado :=
       (v_ticket.creado_por = v_uid)
    or (v_ticket.tecnico_id = v_uid)
    or exists (
         select 1
         from public.maquinas m
         join public.usuario_sector us on us.sector_id = m.sector_id
         where m.id = v_ticket.maquina_id
           and us.usuario_id = v_uid
       );

  return v_vinculado;
end;
$$;


--
-- Name: registrar_egress(text, bigint, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_egress(p_origen text, p_bytes bigint, p_empresa_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_empresa_id uuid;
  v_es_sa      boolean;
begin
  -- Validación de origen (ahora incluye 'adjunto')
  if p_origen not in ('imagen', 'pdf', 'export', 'adjunto') then
    raise exception 'origen inválido: %', p_origen;
  end if;

  if p_bytes is null or p_bytes <= 0 then
    return;
  end if;

  v_es_sa := es_super_admin();

  if v_es_sa then
    if p_empresa_id is null then
      return;
    end if;
    v_empresa_id := p_empresa_id;
  else
    v_empresa_id := get_empresa_id();
    if v_empresa_id is null then
      return;
    end if;
  end if;

  insert into public.egress_mensual_agg (empresa_id, periodo, origen, bytes, actualizado)
  values (v_empresa_id, date_trunc('month', now())::date, p_origen, p_bytes, now())
  on conflict (empresa_id, periodo, origen)
  do update set
    bytes       = public.egress_mensual_agg.bytes + excluded.bytes,
    actualizado = now();
end;
$$;


--
-- Name: registrar_ingreso_stock(uuid, integer, uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_ingreso_stock(p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid DEFAULT NULL::uuid, p_descripcion text DEFAULT NULL::text, p_registrado_por uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_usuario uuid;
  v_empresa_id uuid;
BEGIN
  v_usuario := COALESCE(p_registrado_por, auth.uid());
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
$$;


--
-- Name: registrar_salida_stock(uuid, integer, uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar_salida_stock(p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid DEFAULT NULL::uuid, p_observacion text DEFAULT NULL::text, p_registrado_por uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


--
-- Name: renombrar_rol(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.renombrar_rol(p_rol_id uuid, p_nombre text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_empresa_id uuid;
  v_nombre_actual text;
begin
  v_empresa_id := get_empresa_id();

  select nombre into v_nombre_actual
  from public.roles
  where id = p_rol_id and empresa_id = v_empresa_id;

  if v_nombre_actual is null then
    raise exception 'Rol no encontrado en tu empresa';
  end if;

  if v_nombre_actual in ('admin', 'encargado', 'tecnico') then
    raise exception 'El rol "%" es un rol del sistema y no se puede renombrar', v_nombre_actual;
  end if;

  update public.roles
  set nombre = lower(trim(p_nombre))
  where id = p_rol_id and empresa_id = v_empresa_id;
end;
$$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: rut_uy_valido(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rut_uy_valido(rut text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
DECLARE
  pesos int[] := ARRAY[4,3,2,9,8,7,6,5,4,3,2];
  suma int := 0;
  resto int;
  verificador int;
  digito_real int;
  i int;
BEGIN
  IF rut IS NULL OR rut !~ '^[0-9]{12}$' THEN
    RETURN false;
  END IF;

  FOR i IN 1..11 LOOP
    suma := suma + (substring(rut, i, 1)::int * pesos[i]);
  END LOOP;

  resto := suma % 11;
  verificador := (11 - resto) % 11;

  digito_real := substring(rut, 12, 1)::int;

  RETURN digito_real = verificador;
END;
$_$;


--
-- Name: sa_export_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_export_empresa(p_empresa_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT jsonb_build_object(
    'empresa', (SELECT to_jsonb(e) FROM empresas e WHERE e.id = p_empresa_id),
    'sectores', COALESCE((SELECT jsonb_agg(to_jsonb(s)) FROM sectores s WHERE s.empresa_id = p_empresa_id), '[]'::jsonb),
    'maquinas', COALESCE((SELECT jsonb_agg(to_jsonb(m)) FROM maquinas m WHERE m.empresa_id = p_empresa_id), '[]'::jsonb),
    'repuestos', COALESCE((SELECT jsonb_agg(to_jsonb(r)) FROM repuestos r WHERE r.empresa_id = p_empresa_id), '[]'::jsonb),
    'categorias_repuestos', COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM categorias_repuestos c WHERE c.empresa_id = p_empresa_id), '[]'::jsonb),
    'proveedores', COALESCE((SELECT jsonb_agg(to_jsonb(p)) FROM proveedores p WHERE p.empresa_id = p_empresa_id), '[]'::jsonb),
    'planes_mantenimiento', COALESCE((SELECT jsonb_agg(to_jsonb(pl)) FROM planes_mantenimiento pl WHERE pl.empresa_id = p_empresa_id), '[]'::jsonb),
    'tickets', COALESCE((SELECT jsonb_agg(to_jsonb(t)) FROM tickets t WHERE t.empresa_id = p_empresa_id), '[]'::jsonb),
    'ticket_historial', COALESCE((SELECT jsonb_agg(to_jsonb(th)) FROM ticket_historial th WHERE th.empresa_id = p_empresa_id), '[]'::jsonb),
    'usuarios', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', u.id, 'nombre', u.nombre, 'email', u.email,
        'telefono', u.telefono, 'estado', u.estado, 'rol_id', u.rol_id,
        'primer_login', u.primer_login, 'ultimo_acceso', u.ultimo_acceso,
        'created_at', u.created_at
      )) FROM usuarios u WHERE u.empresa_id = p_empresa_id
    ), '[]'::jsonb),
    'audit_log', COALESCE((SELECT jsonb_agg(to_jsonb(a)) FROM audit_log a WHERE a.empresa_id = p_empresa_id), '[]'::jsonb),
    'ticket_fotos', COALESCE((SELECT jsonb_agg(to_jsonb(tf)) FROM ticket_fotos tf WHERE tf.empresa_id = p_empresa_id), '[]'::jsonb),
    'maquina_documentos', COALESCE((SELECT jsonb_agg(to_jsonb(md)) FROM maquina_documentos md WHERE md.empresa_id = p_empresa_id), '[]'::jsonb),
    'adjuntos', COALESCE((SELECT jsonb_agg(to_jsonb(adj)) FROM adjuntos adj WHERE adj.empresa_id = p_empresa_id), '[]'::jsonb)
  ) INTO v_result;

  -- Registro de auditoría: deja constancia de la exportación (ALCOA+).
  INSERT INTO audit_log (tabla, operacion, registro_id, empresa_id, usuario_id, datos_despues, created_at)
  VALUES (
    'empresas',
    'EXPORT',
    p_empresa_id::text,
    p_empresa_id,
    auth.uid(),
    jsonb_build_object(
      'evento', 'Exportación de datos de empresa',
      'maquinas', jsonb_array_length(v_result->'maquinas'),
      'tickets', jsonb_array_length(v_result->'tickets'),
      'repuestos', jsonb_array_length(v_result->'repuestos'),
      'usuarios', jsonb_array_length(v_result->'usuarios'),
      'audit_log_registros', jsonb_array_length(v_result->'audit_log')
    ),
    now()
  );

  RETURN v_result;
END;
$$;


--
-- Name: sa_generar_doc_esquema(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_generar_doc_esquema() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_catalog'
    AS $$
DECLARE
  v_md    text := '';
  v_rec   record;
  v_sub   record;
BEGIN
  IF NOT (es_super_admin() OR current_user IN ('postgres','service_role')) THEN
    RAISE EXCEPTION 'Acceso denegado: se requiere super admin';
  END IF;

  v_md := '# IndovexApp — Documentación de Esquema (auto-generada)' || E'\n\n';
  v_md := v_md || 'Generado: ' || to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC  ' || E'\n';
  v_md := v_md || 'Project: qxrhrvzvzljeavczzytz — Literal E' || E'\n\n';
  v_md := v_md || '> Fuente de verdad: DB live. No editar a mano — regenerar con `SELECT sa_generar_doc_esquema();`' || E'\n\n';

  -- ---------- RESUMEN ----------
  v_md := v_md || '## Resumen' || E'\n\n';
  v_md := v_md || '| Métrica | Valor |' || E'\n|---|---|' || E'\n';
  v_md := v_md || '| Tablas (public) | ' ||
    (SELECT count(*) FROM information_schema.tables
      WHERE table_schema='public' AND table_type='BASE TABLE') || ' |' || E'\n';
  v_md := v_md || '| Políticas RLS | ' ||
    (SELECT count(*) FROM pg_policies WHERE schemaname='public') || ' |' || E'\n';
  v_md := v_md || '| Triggers | ' ||
    (SELECT count(*) FROM information_schema.triggers WHERE trigger_schema='public') || ' |' || E'\n';
  v_md := v_md || '| Funciones | ' ||
    (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public') || ' |' || E'\n\n';

  -- ---------- TABLAS Y COLUMNAS ----------
  v_md := v_md || '## Tablas y columnas' || E'\n\n';
  FOR v_rec IN
    SELECT c.relname AS tabla,
           obj_description(c.oid) AS comentario,
           c.relrowsecurity AS rls_on
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r'
    ORDER BY c.relname
  LOOP
    v_md := v_md || '### ' || v_rec.tabla ||
            CASE WHEN v_rec.rls_on THEN '  ·  RLS ✓' ELSE '  ·  ⚠ RLS OFF' END || E'\n\n';
    IF v_rec.comentario IS NOT NULL THEN
      v_md := v_md || '*' || v_rec.comentario || '*' || E'\n\n';
    END IF;
    v_md := v_md || '| Columna | Tipo | Null | Default | Nota |' || E'\n|---|---|---|---|---|' || E'\n';
    FOR v_sub IN
      SELECT col.column_name,
             col.data_type ||
               COALESCE('('||col.character_maximum_length||')','') AS tipo,
             col.is_nullable,
             COALESCE(col.column_default,'') AS def,
             COALESCE(col_description(
               (quote_ident('public')||'.'||quote_ident(v_rec.tabla))::regclass,
               col.ordinal_position), '') AS nota
      FROM information_schema.columns col
      WHERE col.table_schema='public' AND col.table_name=v_rec.tabla
      ORDER BY col.ordinal_position
    LOOP
      v_md := v_md || '| ' || v_sub.column_name || ' | ' || v_sub.tipo || ' | ' ||
              CASE WHEN v_sub.is_nullable='NO' THEN 'NOT NULL' ELSE 'NULL' END || ' | ' ||
              replace(left(v_sub.def,60),'|','\|') || ' | ' ||
              replace(v_sub.nota,'|','\|') || ' |' || E'\n';
    END LOOP;
    v_md := v_md || E'\n';
  END LOOP;

  -- ---------- POLÍTICAS RLS ----------
  v_md := v_md || '## Políticas RLS' || E'\n\n';
  v_md := v_md || '| Tabla | Política | Cmd | USING | WITH CHECK |' || E'\n|---|---|---|---|---|' || E'\n';
  FOR v_rec IN
    SELECT tablename, policyname, cmd,
           COALESCE(qual,'') AS usng,
           COALESCE(with_check,'') AS wc
    FROM pg_policies WHERE schemaname='public'
    ORDER BY tablename, cmd, policyname
  LOOP
    v_md := v_md || '| ' || v_rec.tablename || ' | ' || v_rec.policyname || ' | ' ||
            v_rec.cmd || ' | `' || replace(left(v_rec.usng,80),'|','\|') || '` | `' ||
            replace(left(v_rec.wc,80),'|','\|') || '` |' || E'\n';
  END LOOP;
  v_md := v_md || E'\n';

  -- ---------- FUNCIONES ----------
  v_md := v_md || '## Funciones' || E'\n\n';
  v_md := v_md || '| Función | Security | Args | Retorna |' || E'\n|---|---|---|---|' || E'\n';
  FOR v_rec IN
    SELECT p.proname,
           CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END AS sec,
           pg_get_function_arguments(p.oid) AS args,
           pg_get_function_result(p.oid) AS ret
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
    ORDER BY p.proname
  LOOP
    v_md := v_md || '| ' || v_rec.proname || ' | ' || v_rec.sec || ' | ' ||
            replace(COALESCE(NULLIF(left(v_rec.args,80),''),'(sin args)'),'|','\|') || ' | ' ||
            replace(left(v_rec.ret,40),'|','\|') || ' |' || E'\n';
  END LOOP;
  v_md := v_md || E'\n';

  -- ---------- TRIGGERS ----------
  v_md := v_md || '## Triggers' || E'\n\n';
  v_md := v_md || '| Tabla | Trigger | Timing | Evento | Función |' || E'\n|---|---|---|---|---|' || E'\n';
  FOR v_rec IN
    SELECT event_object_table AS tabla, trigger_name,
           action_timing AS timing,
           string_agg(event_manipulation, ', ' ORDER BY event_manipulation) AS eventos,
           action_statement AS fn
    FROM information_schema.triggers
    WHERE trigger_schema='public'
    GROUP BY event_object_table, trigger_name, action_timing, action_statement
    ORDER BY event_object_table, trigger_name
  LOOP
    v_md := v_md || '| ' || v_rec.tabla || ' | ' || v_rec.trigger_name || ' | ' ||
            v_rec.timing || ' | ' || v_rec.eventos || ' | ' ||
            replace(regexp_replace(v_rec.fn, '^EXECUTE (PROCEDURE|FUNCTION) ', ''),'|','\|') || ' |' || E'\n';
  END LOOP;

  RETURN v_md;
END;
$$;


--
-- Name: sa_legal_cobertura(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_legal_cobertura() RETURNS TABLE(empresa_id uuid, empresa_nombre text, documento text, version text, fecha_vigencia date, aceptado boolean, aceptado_en timestamp with time zone, aceptado_por text, dias_para_vigencia integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not es_super_admin() then
    raise exception 'Acceso denegado';
  end if;

  return query
  select
    e.id,
    e.nombre,
    dl.documento,
    dl.version,
    dl.fecha_vigencia,
    (al.id is not null),
    al.aceptado_en,
    u.nombre,
    (dl.fecha_vigencia - current_date)::int
  from public.empresas e
  cross join public.documentos_legales dl
  left join public.aceptaciones_legales al
    on al.empresa_id = e.id
   and al.documento_legal_id = dl.id
  left join public.usuarios u
    on u.id = al.usuario_id
  where dl.vigente = true
    and e.activa = true
  order by (al.id is not null), e.nombre, dl.documento;
end;
$$;


--
-- Name: FUNCTION sa_legal_cobertura(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sa_legal_cobertura() IS 'Estado de aceptacion de documentos vigentes por empresa. Solo super admin.';


--
-- Name: sa_listar_pagos(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_listar_pagos(p_solo_sin_facturar boolean DEFAULT false) RETURNS TABLE(pago_id uuid, empresa_id uuid, empresa_nombre text, monto numeric, moneda text, estado text, fecha_pago timestamp with time zone, facturado boolean, factura_numero text, factura_fecha timestamp with time zone, mp_payment_id text, mp_suscripcion_id text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not es_super_admin() then
    raise exception 'No autorizado: se requiere super admin';
  end if;

  return query
  select
    p.id, p.empresa_id, e.nombre, p.monto, p.moneda, p.estado,
    p.fecha_pago, p.facturado, p.factura_numero, p.factura_fecha,
    p.mp_payment_id, p.mp_suscripcion_id
  from pagos_suscripcion p
  join empresas e on e.id = p.empresa_id
  where (not p_solo_sin_facturar)
     or (p.estado = 'approved' and p.facturado = false)
  order by p.fecha_pago desc nulls last;
end;
$$;


--
-- Name: sa_listar_pagos_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_listar_pagos_empresa(p_empresa_id uuid) RETURNS TABLE(pago_id uuid, empresa_id uuid, empresa_nombre text, monto numeric, moneda text, estado text, fecha_pago timestamp with time zone, facturado boolean, factura_numero text, factura_fecha timestamp with time zone, mp_payment_id text, mp_suscripcion_id text, total_cobrado numeric, cant_aprobados bigint, cant_sin_facturar bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not es_super_admin() then
    raise exception 'No autorizado: se requiere super admin';
  end if;

  return query
  with resumen as (
    select
      coalesce(sum(p.monto) filter (where p.estado = 'approved'), 0) as total_cobrado,
      count(*) filter (where p.estado = 'approved')                  as cant_aprobados,
      count(*) filter (where p.estado = 'approved' and p.facturado = false) as cant_sin_facturar
    from pagos_suscripcion p
    where p.empresa_id = p_empresa_id
  )
  select
    p.id, p.empresa_id, e.nombre, p.monto, p.moneda, p.estado,
    p.fecha_pago, p.facturado, p.factura_numero, p.factura_fecha,
    p.mp_payment_id, p.mp_suscripcion_id,
    r.total_cobrado, r.cant_aprobados, r.cant_sin_facturar
  from pagos_suscripcion p
  join empresas e on e.id = p.empresa_id
  cross join resumen r
  where p.empresa_id = p_empresa_id
  order by p.fecha_pago desc nulls last;
end;
$$;


--
-- Name: sa_purgar_datos_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_purgar_datos_empresa(p_empresa_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
  -- usuario_sector referencia usuarios Y sectores → borrar ANTES de ambas
  DELETE FROM usuario_sector         WHERE empresa_id = p_empresa_id;
  DELETE FROM maquinas               WHERE empresa_id = p_empresa_id;
  DELETE FROM repuestos              WHERE empresa_id = p_empresa_id;
  DELETE FROM categorias_repuestos   WHERE empresa_id = p_empresa_id;
  DELETE FROM proveedores            WHERE empresa_id = p_empresa_id;
  DELETE FROM adjuntos               WHERE empresa_id = p_empresa_id;
  DELETE FROM notificaciones         WHERE empresa_id = p_empresa_id;
  DELETE FROM whatsapp_destinatarios WHERE empresa_id = p_empresa_id;
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
$$;


--
-- Name: sa_reactivar_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_reactivar_empresa(p_empresa_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE empresas
  SET estado                 = 'activa',
      activa                 = true,
      fecha_suspension       = NULL,
      fecha_baja_solicitada  = NULL,
      fecha_purga_programada = NULL
  WHERE id = p_empresa_id
    AND estado IN ('suspendida', 'en_baja', 'a_purgar');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa no encontrada o no está en un estado reactivable';
  END IF;
END;
$$;


--
-- Name: sa_solicitar_baja(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_solicitar_baja(p_empresa_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_dias integer;
BEGIN
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  v_dias := _dias_plazo('baja_voluntaria');

  UPDATE empresas
  SET estado                 = 'en_baja',
      activa                 = false,
      fecha_baja_solicitada  = now(),
      fecha_purga_programada = (now() + (v_dias || ' days')::interval)::date
  WHERE id = p_empresa_id
    AND estado = 'activa';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa no encontrada o no está en estado activo';
  END IF;
END;
$$;


--
-- Name: sa_suspender_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sa_suspender_empresa(p_empresa_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_dias integer;
BEGIN
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  v_dias := _dias_plazo('suspension_impago');

  UPDATE empresas
  SET estado                 = 'suspendida',
      activa                 = false,
      fecha_suspension       = now(),
      fecha_purga_programada = (now() + (v_dias || ' days')::interval)::date
  WHERE id = p_empresa_id
    AND estado = 'activa';   -- solo se suspende lo que está activo

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa no encontrada o no está en estado activo';
  END IF;
END;
$$;


--
-- Name: set_config_plazo(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_config_plazo(p_clave text, p_dias integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  IF p_dias < 0 OR p_dias > 3650 THEN
    RAISE EXCEPTION 'El plazo debe estar entre 0 y 3650 días';
  END IF;

  UPDATE config_plazos SET dias = p_dias WHERE clave = p_clave;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Clave de plazo desconocida: %', p_clave;
  END IF;
END;
$$;


--
-- Name: unaccent_immutable(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unaccent_immutable(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT public.unaccent($1)
$_$;


--
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: uso_cupos_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uso_cupos_empresa(p_empresa_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_empresa_id uuid;
  v_emp        record;
  v_usuarios   int;
  v_maquinas   int;
begin
  v_empresa_id := coalesce(p_empresa_id, get_empresa_id());

  if v_empresa_id is null then
    return null;
  end if;

  if v_empresa_id <> coalesce(get_empresa_id(), '00000000-0000-0000-0000-000000000000'::uuid)
     and not es_super_admin() then
    raise exception 'Acceso denegado';
  end if;

  select plan, max_usuarios, max_maquinas
    into v_emp
  from public.empresas
  where id = v_empresa_id;

  select count(*) into v_usuarios
  from public.usuarios
  where empresa_id = v_empresa_id and estado = 'activo';

  select count(*) into v_maquinas
  from public.maquinas
  where empresa_id = v_empresa_id;

  return jsonb_build_object(
    'plan', v_emp.plan,
    'usuarios', jsonb_build_object(
      'usados', v_usuarios,
      'limite', v_emp.max_usuarios,
      'porcentaje', round(v_usuarios::numeric / nullif(v_emp.max_usuarios, 0) * 100, 1)
    ),
    'maquinas', jsonb_build_object(
      'usados', v_maquinas,
      'limite', v_emp.max_maquinas,
      'porcentaje', round(v_maquinas::numeric / nullif(v_emp.max_maquinas, 0) * 100, 1)
    )
  );
end;
$$;


--
-- Name: FUNCTION uso_cupos_empresa(p_empresa_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.uso_cupos_empresa(p_empresa_id uuid) IS 'Uso vs limite de usuarios y maquinas. Para mostrar en la app antes de chocar con el trigger.';


--
-- Name: uso_egress_empresa(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uso_egress_empresa(p_empresa_id uuid, p_periodo date DEFAULT NULL::date) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_periodo date;
  v_total   bigint;
  v_imagen  bigint;
  v_pdf     bigint;
  v_export  bigint;
  v_adjunto bigint;
begin
  if p_empresa_id <> coalesce(get_empresa_id(), '00000000-0000-0000-0000-000000000000'::uuid)
     and not es_super_admin() then
    raise exception 'Acceso denegado';
  end if;

  v_periodo := date_trunc('month', coalesce(p_periodo, now()))::date;

  select
    coalesce(sum(bytes), 0),
    coalesce(sum(bytes) filter (where origen = 'imagen'), 0),
    coalesce(sum(bytes) filter (where origen = 'pdf'), 0),
    coalesce(sum(bytes) filter (where origen = 'export'), 0),
    coalesce(sum(bytes) filter (where origen = 'adjunto'), 0)
  into v_total, v_imagen, v_pdf, v_export, v_adjunto
  from public.egress_mensual_agg
  where empresa_id = p_empresa_id
    and periodo = v_periodo;

  return jsonb_build_object(
    'periodo',  to_char(v_periodo, 'YYYY-MM'),
    'total_mb', round(v_total / 1048576.0, 2),
    'desglose', jsonb_build_object(
      'imagen',  round(v_imagen  / 1048576.0, 2),
      'pdf',     round(v_pdf     / 1048576.0, 2),
      'export',  round(v_export  / 1048576.0, 2),
      'adjunto', round(v_adjunto / 1048576.0, 2)
    )
  );
end;
$$;


--
-- Name: uso_storage_empresa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.uso_storage_empresa(p_empresa_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  WITH archivos AS (
    SELECT
      (metadata->>'size')::numeric AS size,
      name
    FROM storage.objects
    WHERE bucket_id = 'documentos'
      AND name LIKE p_empresa_id::text || '/%'
  ),
  totales AS (
    SELECT
      COALESCE(SUM(size), 0) AS total_bytes,
      COALESCE(SUM(CASE WHEN name LIKE '%/maquina/%' THEN size END), 0) AS bytes_maquina,
      COALESCE(SUM(CASE WHEN name LIKE '%/repuesto/%' THEN size END), 0) AS bytes_repuesto,
      COALESCE(SUM(CASE WHEN name LIKE '%/ticket/%' THEN size END), 0) AS bytes_ticket
    FROM archivos
  ),
  limite AS (
    SELECT storage_mb_limit FROM empresas WHERE id = p_empresa_id
  )
  SELECT jsonb_build_object(
    'usado_mb',    ROUND(t.total_bytes / 1048576.0, 2),
    'limite_mb',   l.storage_mb_limit,
    'porcentaje',  ROUND(t.total_bytes / NULLIF(l.storage_mb_limit * 1048576.0, 0) * 100, 1),
    'desglose', jsonb_build_object(
      'maquina',  ROUND(t.bytes_maquina  / 1048576.0, 2),
      'repuesto', ROUND(t.bytes_repuesto / 1048576.0, 2),
      'ticket',   ROUND(t.bytes_ticket   / 1048576.0, 2)
    )
  )
  FROM totales t, limite l;
$$;


--
-- Name: aceptaciones_legales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aceptaciones_legales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    documento_legal_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    aceptado_en timestamp with time zone DEFAULT now() NOT NULL,
    ip_origen inet,
    user_agent text
);


--
-- Name: TABLE aceptaciones_legales; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.aceptaciones_legales IS 'Append-only. Una aceptacion por empresa+version. La acepta el admin en representacion de la persona juridica (T&C cl. 1).';


--
-- Name: adjuntos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adjuntos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    entidad_tipo text NOT NULL,
    entidad_id uuid NOT NULL,
    nombre_archivo text NOT NULL,
    tipo_mime text,
    tamanio_bytes bigint,
    storage_path text NOT NULL,
    url_publica text,
    subido_por uuid,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT adjuntos_entidad_tipo_check CHECK ((entidad_tipo = ANY (ARRAY['maquina'::text, 'repuesto'::text, 'ticket'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    tabla text NOT NULL,
    operacion text NOT NULL,
    registro_id text NOT NULL,
    empresa_id uuid,
    usuario_id uuid,
    datos_antes jsonb,
    datos_despues jsonb,
    ip text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: dispositivos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dispositivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    empresa_id uuid NOT NULL,
    token text NOT NULL,
    plataforma text,
    actualizado timestamp with time zone DEFAULT now() NOT NULL,
    creado timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: documentos_legales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documentos_legales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    documento text NOT NULL,
    version text NOT NULL,
    fecha_publicacion date NOT NULL,
    fecha_vigencia date NOT NULL,
    url text NOT NULL,
    resumen_cambios text,
    requiere_aceptacion boolean DEFAULT true NOT NULL,
    vigente boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_vigencia_posterior CHECK ((fecha_vigencia >= fecha_publicacion)),
    CONSTRAINT documentos_legales_documento_check CHECK ((documento = ANY (ARRAY['tyc'::text, 'privacidad'::text])))
);


--
-- Name: TABLE documentos_legales; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.documentos_legales IS 'Catálogo de versiones de documentos legales publicados. fecha_vigencia = publicacion + 15 dias (preaviso comprometido en T&C cl. 13).';


--
-- Name: COLUMN documentos_legales.requiere_aceptacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.documentos_legales.requiere_aceptacion IS 'true = modal bloqueante al admin. false = solo banner informativo.';


--
-- Name: COLUMN documentos_legales.vigente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.documentos_legales.vigente IS 'Solo una version por documento puede estar vigente. Garantizado por indice parcial.';


--
-- Name: egress_mensual_agg; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.egress_mensual_agg (
    empresa_id uuid NOT NULL,
    periodo date NOT NULL,
    origen text NOT NULL,
    bytes bigint DEFAULT 0 NOT NULL,
    actualizado timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT egress_origen_valido CHECK ((origen = ANY (ARRAY['imagen'::text, 'pdf'::text, 'export'::text, 'adjunto'::text])))
);


--
-- Name: empresas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.empresas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    plan text DEFAULT 'trial'::text NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    max_usuarios integer DEFAULT 5 NOT NULL,
    max_maquinas integer DEFAULT 20 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    estado text DEFAULT 'pendiente'::text,
    rut text,
    direccion text,
    telefono text,
    email_contacto text,
    trial_vence timestamp with time zone,
    mp_plan_id text,
    mp_suscripcion_id text,
    storage_mb_limit integer DEFAULT 500 NOT NULL,
    suscripcion_estado text,
    suscripcion_actualizada timestamp with time zone,
    fecha_suspension timestamp with time zone,
    fecha_baja_solicitada timestamp with time zone,
    fecha_purga_programada date,
    CONSTRAINT chk_empresas_email_contacto_formato CHECK (((email_contacto IS NULL) OR (email_contacto ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_empresas_email_contacto_len CHECK (((email_contacto IS NULL) OR (char_length(email_contacto) <= 255))),
    CONSTRAINT chk_empresas_nombre_len CHECK ((char_length(nombre) <= 100)),
    CONSTRAINT chk_empresas_plan CHECK ((plan = ANY (ARRAY['trial'::text, 'starter'::text, 'pro'::text, 'interno'::text]))),
    CONSTRAINT chk_empresas_rut_valido CHECK (((rut IS NULL) OR public.rut_uy_valido(rut))),
    CONSTRAINT empresas_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'activa'::text, 'suspendida'::text, 'en_baja'::text, 'a_purgar'::text])))
);


--
-- Name: COLUMN empresas.fecha_suspension; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.fecha_suspension IS 'Cuándo pasó a suspendida (Situación 2 - falta de pago).';


--
-- Name: COLUMN empresas.fecha_baja_solicitada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.fecha_baja_solicitada IS 'Cuándo el cliente pidió baja voluntaria (Situación 1).';


--
-- Name: COLUMN empresas.fecha_purga_programada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.empresas.fecha_purga_programada IS 'Fecha desde la cual la purga queda habilitada. La calcula la RPC de transición.';


--
-- Name: ingreso_repuestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingreso_repuestos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repuesto_id uuid NOT NULL,
    proveedor_id uuid,
    registrado_por uuid NOT NULL,
    cantidad integer NOT NULL,
    quien_entrega text,
    descripcion text,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL,
    CONSTRAINT ingreso_repuestos_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: intentos_recuperacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.intentos_recuperacion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lecturas_maquina; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lecturas_maquina (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    maquina_id uuid NOT NULL,
    tipo text NOT NULL,
    valor numeric NOT NULL,
    fecha_lectura date DEFAULT CURRENT_DATE NOT NULL,
    registrado_por uuid NOT NULL,
    observacion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maquina_documentos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maquina_documentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    maquina_id uuid NOT NULL,
    subido_por uuid NOT NULL,
    nombre text NOT NULL,
    url text NOT NULL,
    tipo text DEFAULT 'manual'::text NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notificaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tipo text NOT NULL,
    mensaje text NOT NULL,
    ticket_id uuid,
    para_usuario_id uuid NOT NULL,
    de_usuario_id uuid,
    leida boolean DEFAULT false NOT NULL,
    leida_en timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: permisos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permisos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo text NOT NULL,
    nombre text NOT NULL,
    modulo text NOT NULL
);


--
-- Name: planes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    precio numeric(10,2) NOT NULL,
    ciclo text DEFAULT 'mensual'::text NOT NULL,
    mp_plan_id text,
    activo boolean DEFAULT true NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tier text NOT NULL,
    CONSTRAINT chk_planes_ciclo CHECK ((ciclo = ANY (ARRAY['mensual'::text, 'anual'::text]))),
    CONSTRAINT chk_planes_tier CHECK ((tier = ANY (ARRAY['starter'::text, 'pro'::text])))
);


--
-- Name: TABLE planes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.planes IS 'Catalogo comercial: una fila por combinacion tier x ciclo, con su preapproval_plan de MercadoPago. Los limites de uso NO viven aca: se derivan del tier via fn_limites_plan().';


--
-- Name: COLUMN planes.tier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.planes.tier IS 'Tier comercial del plan. Debe existir en fn_limites_plan(). El webhook lo usa para setear empresas.plan.';


--
-- Name: planes_mantenimiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planes_mantenimiento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    maquina_id uuid NOT NULL,
    descripcion_tarea text NOT NULL,
    tipo_intervalo text NOT NULL,
    intervalo_valor numeric NOT NULL,
    ultimo_valor_ejecutado numeric,
    proximo_valor numeric,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    procedimiento text
);


--
-- Name: proveedores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proveedores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    nombre text NOT NULL,
    rut text,
    contacto text,
    telefono text,
    email text,
    direccion text,
    notas text,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_proveedores_email_formato CHECK (((email IS NULL) OR (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_proveedores_email_len CHECK (((email IS NULL) OR (char_length(email) <= 255))),
    CONSTRAINT chk_proveedores_nombre_len CHECK ((char_length(nombre) <= 100)),
    CONSTRAINT chk_proveedores_notas_len CHECK (((notas IS NULL) OR (char_length(notas) <= 500))),
    CONSTRAINT chk_proveedores_rut_valido CHECK (((rut IS NULL) OR public.rut_uy_valido(rut)))
);


--
-- Name: repuestos_bajo_stock; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.repuestos_bajo_stock AS
 SELECT id,
    empresa_id,
    categoria_id,
    codigo,
    descripcion,
    stock_actual,
    stock_minimo,
    ubicacion,
    unidad_medida,
    notas,
    imagen_url,
    activo,
    ref,
    created_at,
    updated_at
   FROM public.repuestos
  WHERE ((activo = true) AND (stock_actual <= stock_minimo));


--
-- Name: repuestos_maquinas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repuestos_maquinas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repuesto_id uuid NOT NULL,
    maquina_id uuid NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    ubicacion_en_maquina text,
    observacion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: rol_permisos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol_permisos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rol_id uuid NOT NULL,
    permiso_id uuid NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid,
    restringe_por_sector boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_admin_no_restringido CHECK ((NOT ((lower(nombre) = 'admin'::text) AND (restringe_por_sector = true)))),
    CONSTRAINT chk_roles_nombre_len CHECK ((char_length(nombre) <= 100))
);


--
-- Name: salida_repuestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.salida_repuestos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    repuesto_id uuid NOT NULL,
    ticket_id uuid,
    registrado_por uuid NOT NULL,
    cantidad integer NOT NULL,
    quien_retira text,
    observacion text,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL,
    CONSTRAINT salida_repuestos_cantidad_check CHECK ((cantidad > 0))
);


--
-- Name: ticket_comentarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_comentarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    ticket_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    comentario text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ticket_fotos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_fotos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    subido_por uuid NOT NULL,
    foto_url text NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: ticket_historial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_historial (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    estado_anterior text,
    estado_nuevo text NOT NULL,
    comentario text,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    maquina_id uuid NOT NULL,
    creado_por uuid NOT NULL,
    tecnico_id uuid,
    numero character varying(20) NOT NULL,
    estado text DEFAULT 'abierto'::text NOT NULL,
    descripcion_desperfecto text NOT NULL,
    observacion_encargado text,
    observacion_tecnico text,
    foto_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    tipo text DEFAULT 'correctivo'::text NOT NULL,
    prioridad text DEFAULT 'media'::text NOT NULL,
    fecha_programada date,
    fecha_cierre timestamp with time zone,
    plan_id uuid
);


--
-- Name: tipos_intervalo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipos_intervalo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    nombre text NOT NULL,
    codigo text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    es_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: usuario_sector; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario_sector (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    sector_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    empresa_id uuid NOT NULL
);


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id uuid NOT NULL,
    empresa_id uuid NOT NULL,
    rol_id uuid,
    nombre text NOT NULL,
    email text NOT NULL,
    estado text DEFAULT 'activo'::text NOT NULL,
    primer_login boolean DEFAULT true NOT NULL,
    ultimo_acceso timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    es_super_admin boolean DEFAULT false,
    telefono text,
    CONSTRAINT chk_usuarios_email_formato CHECK ((email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT chk_usuarios_email_len CHECK ((char_length(email) <= 255)),
    CONSTRAINT chk_usuarios_estado CHECK ((estado = ANY (ARRAY['activo'::text, 'inactivo'::text]))),
    CONSTRAINT chk_usuarios_nombre_len CHECK ((char_length(nombre) <= 100))
);


--
-- Name: vw_mtbf_maquinas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_mtbf_maquinas AS
 WITH tickets_correctivos AS (
         SELECT t.empresa_id,
            t.maquina_id,
            t.created_at,
            lag(t.created_at) OVER (PARTITION BY t.empresa_id, t.maquina_id ORDER BY t.created_at) AS created_at_anterior
           FROM public.tickets t
          WHERE ((t.tipo = 'correctivo'::text) AND (t.estado = 'cerrado'::text))
        ), intervalos AS (
         SELECT tickets_correctivos.empresa_id,
            tickets_correctivos.maquina_id,
            (EXTRACT(epoch FROM (tickets_correctivos.created_at - tickets_correctivos.created_at_anterior)) / (86400)::numeric) AS dias_entre_fallas
           FROM tickets_correctivos
          WHERE (tickets_correctivos.created_at_anterior IS NOT NULL)
        ), conteo AS (
         SELECT intervalos.empresa_id,
            intervalos.maquina_id,
            count(*) AS intervalos_calculados,
            round(avg(intervalos.dias_entre_fallas), 1) AS mtbf_dias
           FROM intervalos
          GROUP BY intervalos.empresa_id, intervalos.maquina_id
        )
 SELECT c.empresa_id,
    c.maquina_id,
    m.nombre AS maquina_nombre,
    s.nombre AS sector_nombre,
    c.mtbf_dias,
    c.intervalos_calculados,
    (c.intervalos_calculados + 1) AS total_tickets_correctivos
   FROM ((conteo c
     JOIN public.maquinas m ON ((m.id = c.maquina_id)))
     JOIN public.sectores s ON ((s.id = m.sector_id)));


--
-- Name: whatsapp_destinatarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_destinatarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    empresa_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE whatsapp_destinatarios; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.whatsapp_destinatarios IS 'Números de WhatsApp configurados por cada empresa para recibir alertas (ej. stock bajo)';


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: aceptaciones_legales aceptaciones_legales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aceptaciones_legales
    ADD CONSTRAINT aceptaciones_legales_pkey PRIMARY KEY (id);


--
-- Name: adjuntos adjuntos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjuntos
    ADD CONSTRAINT adjuntos_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: categorias_repuestos categorias_repuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_repuestos
    ADD CONSTRAINT categorias_repuestos_pkey PRIMARY KEY (id);


--
-- Name: config_plazos config_plazos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_plazos
    ADD CONSTRAINT config_plazos_pkey PRIMARY KEY (clave);


--
-- Name: dispositivos dispositivos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos
    ADD CONSTRAINT dispositivos_pkey PRIMARY KEY (id);


--
-- Name: dispositivos dispositivos_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos
    ADD CONSTRAINT dispositivos_token_key UNIQUE (token);


--
-- Name: documentos_legales documentos_legales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentos_legales
    ADD CONSTRAINT documentos_legales_pkey PRIMARY KEY (id);


--
-- Name: egress_mensual_agg egress_mensual_agg_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egress_mensual_agg
    ADD CONSTRAINT egress_mensual_agg_pkey PRIMARY KEY (empresa_id, periodo, origen);


--
-- Name: empresas empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT empresas_pkey PRIMARY KEY (id);


--
-- Name: ingreso_repuestos ingreso_repuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso_repuestos
    ADD CONSTRAINT ingreso_repuestos_pkey PRIMARY KEY (id);


--
-- Name: intentos_recuperacion intentos_recuperacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intentos_recuperacion
    ADD CONSTRAINT intentos_recuperacion_pkey PRIMARY KEY (id);


--
-- Name: lecturas_maquina lecturas_maquina_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturas_maquina
    ADD CONSTRAINT lecturas_maquina_pkey PRIMARY KEY (id);


--
-- Name: maquina_documentos maquina_documentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquina_documentos
    ADD CONSTRAINT maquina_documentos_pkey PRIMARY KEY (id);


--
-- Name: maquinas maquinas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquinas
    ADD CONSTRAINT maquinas_pkey PRIMARY KEY (id);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);


--
-- Name: pagos_suscripcion pagos_suscripcion_mp_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_suscripcion
    ADD CONSTRAINT pagos_suscripcion_mp_payment_id_key UNIQUE (mp_payment_id);


--
-- Name: pagos_suscripcion pagos_suscripcion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_suscripcion
    ADD CONSTRAINT pagos_suscripcion_pkey PRIMARY KEY (id);


--
-- Name: permisos permisos_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_codigo_key UNIQUE (codigo);


--
-- Name: permisos permisos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_pkey PRIMARY KEY (id);


--
-- Name: planes_mantenimiento planes_mantenimiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_mantenimiento
    ADD CONSTRAINT planes_mantenimiento_pkey PRIMARY KEY (id);


--
-- Name: planes planes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes
    ADD CONSTRAINT planes_pkey PRIMARY KEY (id);


--
-- Name: proveedores proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);


--
-- Name: repuestos_maquinas repuestos_maquinas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos_maquinas
    ADD CONSTRAINT repuestos_maquinas_pkey PRIMARY KEY (id);


--
-- Name: repuestos repuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos
    ADD CONSTRAINT repuestos_pkey PRIMARY KEY (id);


--
-- Name: rol_permisos rol_permisos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_pkey PRIMARY KEY (id);


--
-- Name: rol_permisos rol_permisos_rol_id_permiso_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_rol_id_permiso_id_key UNIQUE (rol_id, permiso_id);


--
-- Name: roles roles_empresa_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_empresa_nombre_key UNIQUE (empresa_id, nombre);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: salida_repuestos salida_repuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salida_repuestos
    ADD CONSTRAINT salida_repuestos_pkey PRIMARY KEY (id);


--
-- Name: sectores sectores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sectores
    ADD CONSTRAINT sectores_pkey PRIMARY KEY (id);


--
-- Name: ticket_comentarios ticket_comentarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comentarios
    ADD CONSTRAINT ticket_comentarios_pkey PRIMARY KEY (id);


--
-- Name: ticket_fotos ticket_fotos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_fotos
    ADD CONSTRAINT ticket_fotos_pkey PRIMARY KEY (id);


--
-- Name: ticket_historial ticket_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_historial
    ADD CONSTRAINT ticket_historial_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: tipos_intervalo tipos_intervalo_empresa_id_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_intervalo
    ADD CONSTRAINT tipos_intervalo_empresa_id_codigo_key UNIQUE (empresa_id, codigo);


--
-- Name: tipos_intervalo tipos_intervalo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_intervalo
    ADD CONSTRAINT tipos_intervalo_pkey PRIMARY KEY (id);


--
-- Name: aceptaciones_legales uq_aceptacion_empresa_documento; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aceptaciones_legales
    ADD CONSTRAINT uq_aceptacion_empresa_documento UNIQUE (empresa_id, documento_legal_id);


--
-- Name: documentos_legales uq_documento_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentos_legales
    ADD CONSTRAINT uq_documento_version UNIQUE (documento, version);


--
-- Name: empresas uq_empresas_rut; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.empresas
    ADD CONSTRAINT uq_empresas_rut UNIQUE (rut);


--
-- Name: whatsapp_destinatarios uq_whatsapp_destinatarios_empresa_usuario; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_destinatarios
    ADD CONSTRAINT uq_whatsapp_destinatarios_empresa_usuario UNIQUE (empresa_id, usuario_id);


--
-- Name: usuario_sector usuario_sector_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sector
    ADD CONSTRAINT usuario_sector_pkey PRIMARY KEY (id);


--
-- Name: usuario_sector usuario_sector_usuario_id_sector_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sector
    ADD CONSTRAINT usuario_sector_usuario_id_sector_id_key UNIQUE (usuario_id, sector_id);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_destinatarios
    ADD CONSTRAINT whatsapp_destinatarios_pkey PRIMARY KEY (id);


--
-- Name: idx_aceptaciones_documento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aceptaciones_documento ON public.aceptaciones_legales USING btree (documento_legal_id);


--
-- Name: idx_aceptaciones_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aceptaciones_empresa ON public.aceptaciones_legales USING btree (empresa_id);


--
-- Name: idx_adjuntos_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_adjuntos_empresa ON public.adjuntos USING btree (empresa_id);


--
-- Name: idx_adjuntos_entidad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_adjuntos_entidad ON public.adjuntos USING btree (entidad_tipo, entidad_id);


--
-- Name: idx_categorias_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categorias_empresa ON public.categorias_repuestos USING btree (empresa_id);


--
-- Name: idx_dispositivos_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dispositivos_usuario ON public.dispositivos USING btree (usuario_id);


--
-- Name: idx_egress_empresa_periodo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_egress_empresa_periodo ON public.egress_mensual_agg USING btree (empresa_id, periodo);


--
-- Name: idx_ingreso_proveedor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ingreso_proveedor ON public.ingreso_repuestos USING btree (proveedor_id);


--
-- Name: idx_ingreso_repuesto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ingreso_repuesto ON public.ingreso_repuestos USING btree (repuesto_id);


--
-- Name: idx_intentos_recuperacion_email_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_intentos_recuperacion_email_fecha ON public.intentos_recuperacion USING btree (email, created_at DESC);


--
-- Name: idx_maquina_docs_maquina; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maquina_docs_maquina ON public.maquina_documentos USING btree (maquina_id);


--
-- Name: idx_maquinas_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maquinas_empresa ON public.maquinas USING btree (empresa_id);


--
-- Name: idx_maquinas_sector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maquinas_sector ON public.maquinas USING btree (sector_id);


--
-- Name: idx_notificaciones_para; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notificaciones_para ON public.notificaciones USING btree (para_usuario_id);


--
-- Name: idx_pagos_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagos_empresa ON public.pagos_suscripcion USING btree (empresa_id);


--
-- Name: idx_pagos_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagos_estado ON public.pagos_suscripcion USING btree (estado);


--
-- Name: idx_pagos_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagos_fecha ON public.pagos_suscripcion USING btree (fecha_pago DESC);


--
-- Name: idx_pagos_sin_facturar; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pagos_sin_facturar ON public.pagos_suscripcion USING btree (facturado) WHERE (facturado = false);


--
-- Name: idx_proveedores_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_proveedores_empresa ON public.proveedores USING btree (empresa_id);


--
-- Name: idx_repuestos_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_repuestos_categoria ON public.repuestos USING btree (categoria_id);


--
-- Name: idx_repuestos_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_repuestos_empresa ON public.repuestos USING btree (empresa_id);


--
-- Name: idx_salida_repuesto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_salida_repuesto ON public.salida_repuestos USING btree (repuesto_id);


--
-- Name: idx_sectores_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sectores_empresa ON public.sectores USING btree (empresa_id);


--
-- Name: idx_ticket_comentarios_ticket; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ticket_comentarios_ticket ON public.ticket_comentarios USING btree (ticket_id, created_at);


--
-- Name: idx_tickets_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_empresa ON public.tickets USING btree (empresa_id);


--
-- Name: idx_tickets_maquina; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_maquina ON public.tickets USING btree (maquina_id);


--
-- Name: idx_tickets_tecnico; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_tecnico ON public.tickets USING btree (tecnico_id);


--
-- Name: idx_usuarios_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_usuarios_empresa ON public.usuarios USING btree (empresa_id);


--
-- Name: uq_categorias_repuestos_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_categorias_repuestos_empresa_nombre_norm ON public.categorias_repuestos USING btree (empresa_id, lower(public.unaccent_immutable(nombre)));


--
-- Name: uq_documento_vigente; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_documento_vigente ON public.documentos_legales USING btree (documento) WHERE (vigente = true);


--
-- Name: uq_maquinas_codigo_empresa; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_maquinas_codigo_empresa ON public.maquinas USING btree (empresa_id, codigo) WHERE (codigo IS NOT NULL);


--
-- Name: uq_maquinas_empresa_codigo_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_maquinas_empresa_codigo_norm ON public.maquinas USING btree (empresa_id, lower(public.unaccent_immutable(codigo)));


--
-- Name: uq_maquinas_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_maquinas_empresa_nombre_norm ON public.maquinas USING btree (empresa_id, lower(public.unaccent_immutable(nombre)));


--
-- Name: uq_planes_tier_ciclo_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_planes_tier_ciclo_activo ON public.planes USING btree (tier, ciclo) WHERE (activo = true);


--
-- Name: uq_proveedores_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_proveedores_empresa_nombre_norm ON public.proveedores USING btree (empresa_id, lower(public.unaccent_immutable(nombre)));


--
-- Name: uq_proveedores_empresa_rut; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_proveedores_empresa_rut ON public.proveedores USING btree (empresa_id, rut) WHERE (rut IS NOT NULL);


--
-- Name: uq_repuestos_empresa_codigo_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_repuestos_empresa_codigo_norm ON public.repuestos USING btree (empresa_id, lower(public.unaccent_immutable(codigo))) WHERE (codigo IS NOT NULL);


--
-- Name: uq_repuestos_empresa_descripcion_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_repuestos_empresa_descripcion_norm ON public.repuestos USING btree (empresa_id, lower(public.unaccent_immutable(descripcion)));


--
-- Name: uq_roles_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_roles_empresa_nombre_norm ON public.roles USING btree (COALESCE(empresa_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(public.unaccent_immutable(nombre)));


--
-- Name: uq_sectores_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_sectores_empresa_nombre_norm ON public.sectores USING btree (empresa_id, lower(public.unaccent_immutable(nombre)));


--
-- Name: uq_tickets_empresa_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_tickets_empresa_numero ON public.tickets USING btree (empresa_id, numero);


--
-- Name: uq_usuarios_empresa_nombre_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_usuarios_empresa_nombre_norm ON public.usuarios USING btree (empresa_id, lower(public.unaccent_immutable(nombre)));


--
-- Name: proveedores proveedores_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER proveedores_updated_at BEFORE UPDATE ON public.proveedores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: repuestos repuestos_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER repuestos_updated_at BEFORE UPDATE ON public.repuestos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: tickets tickets_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tickets_updated_at BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: empresas trg_aplicar_limites_plan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_aplicar_limites_plan BEFORE INSERT OR UPDATE OF plan ON public.empresas FOR EACH ROW EXECUTE FUNCTION public.fn_aplicar_limites_plan();


--
-- Name: tickets trg_asignar_numero_ticket; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_asignar_numero_ticket BEFORE INSERT ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.fn_asignar_numero_ticket();


--
-- Name: categorias_repuestos trg_audit_categorias_repuestos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_categorias_repuestos AFTER INSERT OR DELETE OR UPDATE ON public.categorias_repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: empresas trg_audit_empresas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_empresas AFTER INSERT OR DELETE OR UPDATE ON public.empresas FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: ingreso_repuestos trg_audit_ingreso_repuestos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_ingreso_repuestos AFTER INSERT OR DELETE OR UPDATE ON public.ingreso_repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: lecturas_maquina trg_audit_lecturas_maquina; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_lecturas_maquina AFTER INSERT OR DELETE OR UPDATE ON public.lecturas_maquina FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: maquinas trg_audit_maquinas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_maquinas AFTER INSERT OR DELETE OR UPDATE ON public.maquinas FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: planes_mantenimiento trg_audit_planes_mantenimiento; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_planes_mantenimiento AFTER INSERT OR DELETE OR UPDATE ON public.planes_mantenimiento FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: proveedores trg_audit_proveedores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_proveedores AFTER INSERT OR DELETE OR UPDATE ON public.proveedores FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: repuestos trg_audit_repuestos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_repuestos AFTER INSERT OR DELETE OR UPDATE ON public.repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: repuestos_maquinas trg_audit_repuestos_maquinas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_repuestos_maquinas AFTER INSERT OR DELETE OR UPDATE ON public.repuestos_maquinas FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: rol_permisos trg_audit_rol_permisos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_rol_permisos AFTER INSERT OR DELETE OR UPDATE ON public.rol_permisos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: roles trg_audit_roles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_roles AFTER INSERT OR DELETE OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: salida_repuestos trg_audit_salida_repuestos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_salida_repuestos AFTER INSERT OR DELETE OR UPDATE ON public.salida_repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: sectores trg_audit_sectores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_sectores AFTER INSERT OR DELETE OR UPDATE ON public.sectores FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: ticket_historial trg_audit_ticket_historial; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_ticket_historial AFTER INSERT OR DELETE OR UPDATE ON public.ticket_historial FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: tickets trg_audit_tickets; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_tickets AFTER INSERT OR DELETE OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: tipos_intervalo trg_audit_tipos_intervalo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_tipos_intervalo AFTER INSERT OR DELETE OR UPDATE ON public.tipos_intervalo FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: usuario_sector trg_audit_usuario_sector; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_usuario_sector AFTER INSERT OR DELETE OR UPDATE ON public.usuario_sector FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: usuarios trg_audit_usuarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_usuarios AFTER INSERT OR DELETE OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: whatsapp_destinatarios trg_audit_whatsapp_destinatarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_whatsapp_destinatarios AFTER INSERT OR DELETE OR UPDATE ON public.whatsapp_destinatarios FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: tickets trg_notificar_involucrados_ticket; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notificar_involucrados_ticket AFTER INSERT OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_involucrados_ticket();


--
-- Name: pagos_suscripcion trg_pagos_suscripcion_inmutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pagos_suscripcion_inmutable BEFORE DELETE OR UPDATE ON public.pagos_suscripcion FOR EACH ROW EXECUTE FUNCTION public.fn_pagos_suscripcion_inmutable();


--
-- Name: aceptaciones_legales trg_proteger_aceptaciones; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_aceptaciones BEFORE DELETE OR UPDATE ON public.aceptaciones_legales FOR EACH ROW EXECUTE FUNCTION public.fn_proteger_aceptaciones();


--
-- Name: audit_log trg_proteger_audit_log; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_audit_log BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.fn_proteger_audit_log();


--
-- Name: usuarios trg_proteger_campos_usuario; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_campos_usuario BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.proteger_campos_usuario();


--
-- Name: empresas trg_proteger_columnas_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_columnas_empresa BEFORE UPDATE ON public.empresas FOR EACH ROW EXECUTE FUNCTION public.fn_proteger_columnas_empresa();


--
-- Name: ticket_comentarios trg_proteger_ticket_comentarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_proteger_ticket_comentarios BEFORE DELETE OR UPDATE ON public.ticket_comentarios FOR EACH ROW EXECUTE FUNCTION public.fn_proteger_ticket_comentarios();


--
-- Name: maquina_documentos trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.maquina_documentos FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_maquina_documentos();


--
-- Name: notificaciones trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.notificaciones FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_notificaciones();


--
-- Name: repuestos_maquinas trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.repuestos_maquinas FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_repuestos_maquinas();


--
-- Name: ticket_fotos trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.ticket_fotos FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_ticket_fotos();


--
-- Name: ticket_historial trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.ticket_historial FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_ticket_historial();


--
-- Name: usuario_sector trg_set_empresa; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa BEFORE INSERT ON public.usuario_sector FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_usuario_sector();


--
-- Name: dispositivos trg_set_empresa_dispositivo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa_dispositivo BEFORE INSERT ON public.dispositivos FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_dispositivo();


--
-- Name: ticket_comentarios trg_set_empresa_ticket_comentario; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_empresa_ticket_comentario BEFORE INSERT ON public.ticket_comentarios FOR EACH ROW EXECUTE FUNCTION public.fn_set_empresa_ticket_comentario();


--
-- Name: repuestos trg_stock_bajo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stock_bajo AFTER UPDATE ON public.repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_check_stock_bajo();


--
-- Name: maquinas trg_validar_empresa_maquina_sector; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_empresa_maquina_sector BEFORE INSERT OR UPDATE OF sector_id, empresa_id ON public.maquinas FOR EACH ROW EXECUTE FUNCTION public.fn_validar_empresa_maquina_sector();


--
-- Name: repuestos trg_validar_empresa_repuesto_categoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_empresa_repuesto_categoria BEFORE INSERT OR UPDATE OF categoria_id, empresa_id ON public.repuestos FOR EACH ROW EXECUTE FUNCTION public.fn_validar_empresa_repuesto_categoria();


--
-- Name: usuarios trg_validar_empresa_usuario_rol; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_empresa_usuario_rol BEFORE INSERT OR UPDATE OF rol_id, empresa_id ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_validar_empresa_usuario_rol();


--
-- Name: maquinas trg_validar_limite_maquinas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_limite_maquinas BEFORE INSERT ON public.maquinas FOR EACH ROW EXECUTE FUNCTION public.fn_validar_limite_maquinas();


--
-- Name: usuarios trg_validar_limite_usuarios; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_limite_usuarios BEFORE INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_validar_limite_usuarios();


--
-- Name: usuarios trg_validar_limite_usuarios_reactivar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validar_limite_usuarios_reactivar BEFORE UPDATE OF estado ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_validar_limite_usuarios_reactivar();


--
-- Name: usuarios usuarios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER usuarios_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER whatsapp_destinatarios_updated_at BEFORE UPDATE ON public.whatsapp_destinatarios FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: aceptaciones_legales aceptaciones_legales_documento_legal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aceptaciones_legales
    ADD CONSTRAINT aceptaciones_legales_documento_legal_id_fkey FOREIGN KEY (documento_legal_id) REFERENCES public.documentos_legales(id);


--
-- Name: aceptaciones_legales aceptaciones_legales_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aceptaciones_legales
    ADD CONSTRAINT aceptaciones_legales_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: aceptaciones_legales aceptaciones_legales_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aceptaciones_legales
    ADD CONSTRAINT aceptaciones_legales_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: adjuntos adjuntos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjuntos
    ADD CONSTRAINT adjuntos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: adjuntos adjuntos_subido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adjuntos
    ADD CONSTRAINT adjuntos_subido_por_fkey FOREIGN KEY (subido_por) REFERENCES public.usuarios(id);


--
-- Name: categorias_repuestos categorias_repuestos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias_repuestos
    ADD CONSTRAINT categorias_repuestos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: dispositivos dispositivos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos
    ADD CONSTRAINT dispositivos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: dispositivos dispositivos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dispositivos
    ADD CONSTRAINT dispositivos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: egress_mensual_agg egress_mensual_agg_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egress_mensual_agg
    ADD CONSTRAINT egress_mensual_agg_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: ingreso_repuestos ingreso_repuestos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso_repuestos
    ADD CONSTRAINT ingreso_repuestos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: ingreso_repuestos ingreso_repuestos_proveedor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso_repuestos
    ADD CONSTRAINT ingreso_repuestos_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id);


--
-- Name: ingreso_repuestos ingreso_repuestos_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso_repuestos
    ADD CONSTRAINT ingreso_repuestos_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuarios(id);


--
-- Name: ingreso_repuestos ingreso_repuestos_repuesto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso_repuestos
    ADD CONSTRAINT ingreso_repuestos_repuesto_id_fkey FOREIGN KEY (repuesto_id) REFERENCES public.repuestos(id) ON DELETE CASCADE;


--
-- Name: lecturas_maquina lecturas_maquina_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturas_maquina
    ADD CONSTRAINT lecturas_maquina_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: lecturas_maquina lecturas_maquina_maquina_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturas_maquina
    ADD CONSTRAINT lecturas_maquina_maquina_id_fkey FOREIGN KEY (maquina_id) REFERENCES public.maquinas(id);


--
-- Name: lecturas_maquina lecturas_maquina_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturas_maquina
    ADD CONSTRAINT lecturas_maquina_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuarios(id);


--
-- Name: maquina_documentos maquina_documentos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquina_documentos
    ADD CONSTRAINT maquina_documentos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: maquina_documentos maquina_documentos_maquina_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquina_documentos
    ADD CONSTRAINT maquina_documentos_maquina_id_fkey FOREIGN KEY (maquina_id) REFERENCES public.maquinas(id) ON DELETE CASCADE;


--
-- Name: maquina_documentos maquina_documentos_subido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquina_documentos
    ADD CONSTRAINT maquina_documentos_subido_por_fkey FOREIGN KEY (subido_por) REFERENCES public.usuarios(id);


--
-- Name: maquinas maquinas_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquinas
    ADD CONSTRAINT maquinas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: maquinas maquinas_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maquinas
    ADD CONSTRAINT maquinas_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sectores(id) ON DELETE CASCADE;


--
-- Name: notificaciones notificaciones_de_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_de_usuario_id_fkey FOREIGN KEY (de_usuario_id) REFERENCES public.usuarios(id);


--
-- Name: notificaciones notificaciones_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: notificaciones notificaciones_para_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_para_usuario_id_fkey FOREIGN KEY (para_usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: notificaciones notificaciones_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: pagos_suscripcion pagos_suscripcion_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagos_suscripcion
    ADD CONSTRAINT pagos_suscripcion_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: planes_mantenimiento planes_mantenimiento_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_mantenimiento
    ADD CONSTRAINT planes_mantenimiento_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: planes_mantenimiento planes_mantenimiento_maquina_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes_mantenimiento
    ADD CONSTRAINT planes_mantenimiento_maquina_id_fkey FOREIGN KEY (maquina_id) REFERENCES public.maquinas(id);


--
-- Name: proveedores proveedores_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: repuestos repuestos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos
    ADD CONSTRAINT repuestos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_repuestos(id);


--
-- Name: repuestos repuestos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos
    ADD CONSTRAINT repuestos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: repuestos_maquinas repuestos_maquinas_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos_maquinas
    ADD CONSTRAINT repuestos_maquinas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: repuestos_maquinas repuestos_maquinas_maquina_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos_maquinas
    ADD CONSTRAINT repuestos_maquinas_maquina_id_fkey FOREIGN KEY (maquina_id) REFERENCES public.maquinas(id) ON DELETE CASCADE;


--
-- Name: repuestos_maquinas repuestos_maquinas_repuesto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repuestos_maquinas
    ADD CONSTRAINT repuestos_maquinas_repuesto_id_fkey FOREIGN KEY (repuesto_id) REFERENCES public.repuestos(id) ON DELETE CASCADE;


--
-- Name: rol_permisos rol_permisos_permiso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_permiso_id_fkey FOREIGN KEY (permiso_id) REFERENCES public.permisos(id) ON DELETE CASCADE;


--
-- Name: rol_permisos rol_permisos_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol_permisos
    ADD CONSTRAINT rol_permisos_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: roles roles_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: salida_repuestos salida_repuestos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salida_repuestos
    ADD CONSTRAINT salida_repuestos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: salida_repuestos salida_repuestos_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salida_repuestos
    ADD CONSTRAINT salida_repuestos_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES public.usuarios(id);


--
-- Name: salida_repuestos salida_repuestos_repuesto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salida_repuestos
    ADD CONSTRAINT salida_repuestos_repuesto_id_fkey FOREIGN KEY (repuesto_id) REFERENCES public.repuestos(id) ON DELETE CASCADE;


--
-- Name: salida_repuestos salida_repuestos_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salida_repuestos
    ADD CONSTRAINT salida_repuestos_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id);


--
-- Name: sectores sectores_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sectores
    ADD CONSTRAINT sectores_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: ticket_comentarios ticket_comentarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comentarios
    ADD CONSTRAINT ticket_comentarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: ticket_comentarios ticket_comentarios_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comentarios
    ADD CONSTRAINT ticket_comentarios_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_comentarios ticket_comentarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comentarios
    ADD CONSTRAINT ticket_comentarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: ticket_fotos ticket_fotos_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_fotos
    ADD CONSTRAINT ticket_fotos_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: ticket_fotos ticket_fotos_subido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_fotos
    ADD CONSTRAINT ticket_fotos_subido_por_fkey FOREIGN KEY (subido_por) REFERENCES public.usuarios(id);


--
-- Name: ticket_fotos ticket_fotos_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_fotos
    ADD CONSTRAINT ticket_fotos_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_historial ticket_historial_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_historial
    ADD CONSTRAINT ticket_historial_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: ticket_historial ticket_historial_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_historial
    ADD CONSTRAINT ticket_historial_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_historial ticket_historial_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_historial
    ADD CONSTRAINT ticket_historial_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: tickets tickets_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id);


--
-- Name: tickets tickets_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: tickets tickets_maquina_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_maquina_id_fkey FOREIGN KEY (maquina_id) REFERENCES public.maquinas(id);


--
-- Name: tickets tickets_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.planes_mantenimiento(id);


--
-- Name: tickets tickets_tecnico_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_tecnico_id_fkey FOREIGN KEY (tecnico_id) REFERENCES public.usuarios(id);


--
-- Name: tipos_intervalo tipos_intervalo_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipos_intervalo
    ADD CONSTRAINT tipos_intervalo_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id);


--
-- Name: usuario_sector usuario_sector_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sector
    ADD CONSTRAINT usuario_sector_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: usuario_sector usuario_sector_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sector
    ADD CONSTRAINT usuario_sector_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sectores(id) ON DELETE CASCADE;


--
-- Name: usuario_sector usuario_sector_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario_sector
    ADD CONSTRAINT usuario_sector_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_destinatarios
    ADD CONSTRAINT whatsapp_destinatarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE;


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_destinatarios
    ADD CONSTRAINT whatsapp_destinatarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: aceptaciones_legales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aceptaciones_legales ENABLE ROW LEVEL SECURITY;

--
-- Name: adjuntos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.adjuntos ENABLE ROW LEVEL SECURITY;

--
-- Name: adjuntos adjuntos_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY adjuntos_empresa ON public.adjuntos USING ((empresa_id = public.get_empresa_id()));


--
-- Name: empresas admin_actualizar_su_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_actualizar_su_empresa ON public.empresas FOR UPDATE USING (((id = public.get_empresa_id()) AND public.es_admin_empresa())) WITH CHECK (((id = public.get_empresa_id()) AND public.es_admin_empresa()));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_log_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_select ON public.audit_log FOR SELECT USING (((empresa_id = public.get_empresa_id()) OR public.es_super_admin()));


--
-- Name: categorias_repuestos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias_repuestos ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias_repuestos categorias_repuestos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_repuestos_mi_empresa ON public.categorias_repuestos USING ((empresa_id = public.get_empresa_id()));


--
-- Name: config_plazos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.config_plazos ENABLE ROW LEVEL SECURITY;

--
-- Name: config_plazos config_plazos_super_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY config_plazos_super_admin_select ON public.config_plazos FOR SELECT USING (public.es_super_admin());


--
-- Name: config_plazos config_plazos_super_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY config_plazos_super_admin_update ON public.config_plazos FOR UPDATE USING (public.es_super_admin());


--
-- Name: dispositivos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dispositivos ENABLE ROW LEVEL SECURITY;

--
-- Name: dispositivos dispositivos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dispositivos_delete ON public.dispositivos FOR DELETE USING ((usuario_id = auth.uid()));


--
-- Name: dispositivos dispositivos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dispositivos_insert ON public.dispositivos FOR INSERT WITH CHECK ((usuario_id = auth.uid()));


--
-- Name: dispositivos dispositivos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dispositivos_select ON public.dispositivos FOR SELECT USING (((usuario_id = auth.uid()) OR public.es_super_admin()));


--
-- Name: dispositivos dispositivos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dispositivos_update ON public.dispositivos FOR UPDATE USING ((usuario_id = auth.uid()));


--
-- Name: documentos_legales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documentos_legales ENABLE ROW LEVEL SECURITY;

--
-- Name: egress_mensual_agg; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.egress_mensual_agg ENABLE ROW LEVEL SECURITY;

--
-- Name: egress_mensual_agg egress_sa_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY egress_sa_select ON public.egress_mensual_agg FOR SELECT USING (public.es_super_admin());


--
-- Name: empresas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;

--
-- Name: ingreso_repuestos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ingreso_repuestos ENABLE ROW LEVEL SECURITY;

--
-- Name: ingreso_repuestos ingreso_repuestos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ingreso_repuestos_mi_empresa ON public.ingreso_repuestos USING ((empresa_id = public.get_empresa_id()));


--
-- Name: intentos_recuperacion; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.intentos_recuperacion ENABLE ROW LEVEL SECURITY;

--
-- Name: lecturas_maquina; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lecturas_maquina ENABLE ROW LEVEL SECURITY;

--
-- Name: lecturas_maquina lecturas_maquina_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lecturas_maquina_mi_empresa ON public.lecturas_maquina USING ((empresa_id = public.get_empresa_id()));


--
-- Name: maquina_documentos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.maquina_documentos ENABLE ROW LEVEL SECURITY;

--
-- Name: maquina_documentos maquina_documentos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY maquina_documentos_mi_empresa ON public.maquina_documentos USING ((empresa_id = public.get_empresa_id())) WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: maquinas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.maquinas ENABLE ROW LEVEL SECURITY;

--
-- Name: maquinas maquinas_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY maquinas_mi_empresa ON public.maquinas USING (((empresa_id = public.get_empresa_id()) AND ((NOT public.fn_usuario_restringido_sector()) OR (sector_id = ANY (public.fn_sectores_usuario())))));


--
-- Name: notificaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: notificaciones notificaciones_actualizar_propias; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notificaciones_actualizar_propias ON public.notificaciones FOR UPDATE TO authenticated USING ((para_usuario_id = auth.uid()));


--
-- Name: notificaciones notificaciones_insertar; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notificaciones_insertar ON public.notificaciones FOR INSERT WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: notificaciones notificaciones_leer_propias; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notificaciones_leer_propias ON public.notificaciones FOR SELECT TO authenticated USING ((para_usuario_id = auth.uid()));


--
-- Name: pagos_suscripcion pagos_select_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pagos_select_super_admin ON public.pagos_suscripcion FOR SELECT USING (public.es_super_admin());


--
-- Name: pagos_suscripcion; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pagos_suscripcion ENABLE ROW LEVEL SECURITY;

--
-- Name: permisos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.permisos ENABLE ROW LEVEL SECURITY;

--
-- Name: permisos permisos_lectura_publica; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY permisos_lectura_publica ON public.permisos FOR SELECT TO authenticated USING (true);


--
-- Name: planes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.planes ENABLE ROW LEVEL SECURITY;

--
-- Name: planes planes_leer_activos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY planes_leer_activos ON public.planes FOR SELECT USING (((activo = true) OR public.es_super_admin()));


--
-- Name: planes_mantenimiento; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.planes_mantenimiento ENABLE ROW LEVEL SECURITY;

--
-- Name: planes_mantenimiento planes_mantenimiento_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY planes_mantenimiento_mi_empresa ON public.planes_mantenimiento USING ((empresa_id = public.get_empresa_id()));


--
-- Name: planes planes_super_admin_gestionar; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY planes_super_admin_gestionar ON public.planes USING (public.es_super_admin()) WITH CHECK (public.es_super_admin());


--
-- Name: aceptaciones_legales pol_aceptaciones_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_aceptaciones_select ON public.aceptaciones_legales FOR SELECT TO authenticated USING ((empresa_id = public.get_empresa_id()));


--
-- Name: documentos_legales pol_documentos_legales_all_sa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_documentos_legales_all_sa ON public.documentos_legales TO authenticated USING (public.es_super_admin()) WITH CHECK (public.es_super_admin());


--
-- Name: documentos_legales pol_documentos_legales_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pol_documentos_legales_select ON public.documentos_legales FOR SELECT TO authenticated USING (true);


--
-- Name: proveedores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.proveedores ENABLE ROW LEVEL SECURITY;

--
-- Name: proveedores proveedores_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY proveedores_mi_empresa ON public.proveedores USING ((empresa_id = public.get_empresa_id()));


--
-- Name: repuestos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.repuestos ENABLE ROW LEVEL SECURITY;

--
-- Name: repuestos_maquinas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.repuestos_maquinas ENABLE ROW LEVEL SECURITY;

--
-- Name: repuestos_maquinas repuestos_maquinas_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY repuestos_maquinas_mi_empresa ON public.repuestos_maquinas USING ((empresa_id = public.get_empresa_id())) WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: repuestos repuestos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY repuestos_mi_empresa ON public.repuestos USING ((empresa_id = public.get_empresa_id()));


--
-- Name: rol_permisos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rol_permisos ENABLE ROW LEVEL SECURITY;

--
-- Name: rol_permisos rol_permisos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rol_permisos_mi_empresa ON public.rol_permisos USING ((rol_id IN ( SELECT roles.id
   FROM public.roles
  WHERE (roles.empresa_id = public.get_empresa_id()))));


--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles roles_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_mi_empresa ON public.roles USING ((empresa_id = public.get_empresa_id()));


--
-- Name: salida_repuestos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.salida_repuestos ENABLE ROW LEVEL SECURITY;

--
-- Name: salida_repuestos salida_repuestos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY salida_repuestos_mi_empresa ON public.salida_repuestos USING ((empresa_id = public.get_empresa_id()));


--
-- Name: sectores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sectores ENABLE ROW LEVEL SECURITY;

--
-- Name: sectores sectores_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sectores_mi_empresa ON public.sectores USING ((empresa_id = public.get_empresa_id()));


--
-- Name: empresas super_admin_actualizar_empresas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY super_admin_actualizar_empresas ON public.empresas FOR UPDATE USING (public.es_super_admin()) WITH CHECK (public.es_super_admin());


--
-- Name: empresas super_admin_editar_storage_limit; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY super_admin_editar_storage_limit ON public.empresas FOR UPDATE USING (public.es_super_admin()) WITH CHECK (public.es_super_admin());


--
-- Name: empresas super_admin_ver_empresas; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY super_admin_ver_empresas ON public.empresas FOR SELECT USING (public.es_super_admin());


--
-- Name: ticket_comentarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ticket_comentarios ENABLE ROW LEVEL SECURITY;

--
-- Name: ticket_comentarios ticket_comentarios_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ticket_comentarios_insert ON public.ticket_comentarios FOR INSERT WITH CHECK (((empresa_id = public.get_empresa_id()) AND (usuario_id = auth.uid()) AND public.puede_comentar_ticket(ticket_id)));


--
-- Name: ticket_comentarios ticket_comentarios_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ticket_comentarios_select ON public.ticket_comentarios FOR SELECT USING (((empresa_id = public.get_empresa_id()) OR public.es_super_admin()));


--
-- Name: ticket_fotos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ticket_fotos ENABLE ROW LEVEL SECURITY;

--
-- Name: ticket_fotos ticket_fotos_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ticket_fotos_mi_empresa ON public.ticket_fotos USING ((empresa_id = public.get_empresa_id())) WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: ticket_historial; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ticket_historial ENABLE ROW LEVEL SECURITY;

--
-- Name: ticket_historial ticket_historial_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ticket_historial_mi_empresa ON public.ticket_historial USING ((empresa_id = public.get_empresa_id())) WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: tickets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

--
-- Name: tickets tickets_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_mi_empresa ON public.tickets USING (((empresa_id = public.get_empresa_id()) AND ((NOT public.fn_usuario_restringido_sector()) OR (maquina_id IN ( SELECT maquinas.id
   FROM public.maquinas
  WHERE (maquinas.sector_id = ANY (public.fn_sectores_usuario())))) OR (tecnico_id = auth.uid()) OR (creado_por = auth.uid()))));


--
-- Name: tipos_intervalo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tipos_intervalo ENABLE ROW LEVEL SECURITY;

--
-- Name: tipos_intervalo tipos_intervalo_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tipos_intervalo_mi_empresa ON public.tipos_intervalo USING ((empresa_id = public.get_empresa_id()));


--
-- Name: usuario_sector; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuario_sector ENABLE ROW LEVEL SECURITY;

--
-- Name: usuario_sector usuario_sector_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuario_sector_mi_empresa ON public.usuario_sector USING ((empresa_id = public.get_empresa_id())) WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: empresas usuarios pueden ver su propia empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuarios pueden ver su propia empresa" ON public.empresas FOR SELECT TO authenticated USING ((id = public.get_empresa_id()));


--
-- Name: usuarios usuarios_actualizar_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_actualizar_propio ON public.usuarios FOR UPDATE TO authenticated USING ((id = auth.uid()));


--
-- Name: usuarios usuarios_admin_actualizar; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_admin_actualizar ON public.usuarios FOR UPDATE TO authenticated USING (((empresa_id = public.get_empresa_id()) OR public.es_super_admin()));


--
-- Name: usuarios usuarios_admin_insertar; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_admin_insertar ON public.usuarios FOR INSERT TO authenticated WITH CHECK (((empresa_id = public.get_empresa_id()) OR public.es_super_admin()));


--
-- Name: usuarios usuarios_leer_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_leer_propio ON public.usuarios FOR SELECT TO authenticated USING ((id = auth.uid()));


--
-- Name: usuarios usuarios_ver_mi_empresa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY usuarios_ver_mi_empresa ON public.usuarios FOR SELECT USING ((empresa_id = public.get_empresa_id()));


--
-- Name: whatsapp_destinatarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_destinatarios ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY whatsapp_destinatarios_delete ON public.whatsapp_destinatarios FOR DELETE USING ((empresa_id = public.get_empresa_id()));


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY whatsapp_destinatarios_insert ON public.whatsapp_destinatarios FOR INSERT WITH CHECK ((empresa_id = public.get_empresa_id()));


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY whatsapp_destinatarios_select ON public.whatsapp_destinatarios FOR SELECT USING ((empresa_id = public.get_empresa_id()));


--
-- Name: whatsapp_destinatarios whatsapp_destinatarios_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY whatsapp_destinatarios_update ON public.whatsapp_destinatarios FOR UPDATE USING ((empresa_id = public.get_empresa_id()));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION _dias_plazo(p_clave text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public._dias_plazo(p_clave text) TO anon;
GRANT ALL ON FUNCTION public._dias_plazo(p_clave text) TO authenticated;
GRANT ALL ON FUNCTION public._dias_plazo(p_clave text) TO service_role;


--
-- Name: TABLE categorias_repuestos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.categorias_repuestos TO anon;
GRANT ALL ON TABLE public.categorias_repuestos TO authenticated;
GRANT ALL ON TABLE public.categorias_repuestos TO service_role;


--
-- Name: FUNCTION admin_categorias_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_categorias_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_categorias_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_categorias_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: TABLE maquinas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.maquinas TO anon;
GRANT ALL ON TABLE public.maquinas TO authenticated;
GRANT ALL ON TABLE public.maquinas TO service_role;


--
-- Name: FUNCTION admin_maquinas_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_maquinas_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_maquinas_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_maquinas_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: TABLE repuestos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.repuestos TO anon;
GRANT ALL ON TABLE public.repuestos TO authenticated;
GRANT ALL ON TABLE public.repuestos TO service_role;


--
-- Name: FUNCTION admin_repuestos_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_repuestos_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_repuestos_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_repuestos_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: TABLE sectores; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.sectores TO anon;
GRANT ALL ON TABLE public.sectores TO authenticated;
GRANT ALL ON TABLE public.sectores TO service_role;


--
-- Name: FUNCTION admin_sectores_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_sectores_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_sectores_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_sectores_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION admin_tickets_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_tickets_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_tickets_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_tickets_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION admin_usuarios_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_usuarios_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.admin_usuarios_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_usuarios_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION aprobar_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aprobar_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.aprobar_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.aprobar_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION crear_rol(p_nombre text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.crear_rol(p_nombre text) TO anon;
GRANT ALL ON FUNCTION public.crear_rol(p_nombre text) TO authenticated;
GRANT ALL ON FUNCTION public.crear_rol(p_nombre text) TO service_role;


--
-- Name: FUNCTION crear_ticket(p_maquina_id uuid, p_descripcion text, p_foto_url text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.crear_ticket(p_maquina_id uuid, p_descripcion text, p_foto_url text) TO anon;
GRANT ALL ON FUNCTION public.crear_ticket(p_maquina_id uuid, p_descripcion text, p_foto_url text) TO authenticated;
GRANT ALL ON FUNCTION public.crear_ticket(p_maquina_id uuid, p_descripcion text, p_foto_url text) TO service_role;


--
-- Name: FUNCTION dashboard_kpis(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.dashboard_kpis() TO anon;
GRANT ALL ON FUNCTION public.dashboard_kpis() TO authenticated;
GRANT ALL ON FUNCTION public.dashboard_kpis() TO service_role;


--
-- Name: FUNCTION egress_todas_empresas(p_periodo date); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.egress_todas_empresas(p_periodo date) TO anon;
GRANT ALL ON FUNCTION public.egress_todas_empresas(p_periodo date) TO authenticated;
GRANT ALL ON FUNCTION public.egress_todas_empresas(p_periodo date) TO service_role;


--
-- Name: FUNCTION eliminar_rol(p_rol_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.eliminar_rol(p_rol_id uuid) TO anon;
GRANT ALL ON FUNCTION public.eliminar_rol(p_rol_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.eliminar_rol(p_rol_id uuid) TO service_role;


--
-- Name: FUNCTION es_admin_empresa(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.es_admin_empresa() FROM PUBLIC;
GRANT ALL ON FUNCTION public.es_admin_empresa() TO anon;
GRANT ALL ON FUNCTION public.es_admin_empresa() TO authenticated;
GRANT ALL ON FUNCTION public.es_admin_empresa() TO service_role;


--
-- Name: FUNCTION es_super_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_super_admin() TO anon;
GRANT ALL ON FUNCTION public.es_super_admin() TO authenticated;
GRANT ALL ON FUNCTION public.es_super_admin() TO service_role;


--
-- Name: FUNCTION establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[]); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[]) TO anon;
GRANT ALL ON FUNCTION public.establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.establecer_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[]) TO service_role;


--
-- Name: FUNCTION estado_mi_empresa(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.estado_mi_empresa() TO anon;
GRANT ALL ON FUNCTION public.estado_mi_empresa() TO authenticated;
GRANT ALL ON FUNCTION public.estado_mi_empresa() TO service_role;


--
-- Name: FUNCTION fn_aplicar_limites_plan(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_aplicar_limites_plan() TO anon;
GRANT ALL ON FUNCTION public.fn_aplicar_limites_plan() TO authenticated;
GRANT ALL ON FUNCTION public.fn_aplicar_limites_plan() TO service_role;


--
-- Name: FUNCTION fn_asignar_numero_ticket(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_asignar_numero_ticket() TO anon;
GRANT ALL ON FUNCTION public.fn_asignar_numero_ticket() TO authenticated;
GRANT ALL ON FUNCTION public.fn_asignar_numero_ticket() TO service_role;


--
-- Name: FUNCTION fn_audit_log(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_audit_log() TO anon;
GRANT ALL ON FUNCTION public.fn_audit_log() TO authenticated;
GRANT ALL ON FUNCTION public.fn_audit_log() TO service_role;


--
-- Name: FUNCTION fn_check_stock_bajo(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_check_stock_bajo() TO anon;
GRANT ALL ON FUNCTION public.fn_check_stock_bajo() TO authenticated;
GRANT ALL ON FUNCTION public.fn_check_stock_bajo() TO service_role;


--
-- Name: FUNCTION fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric) TO anon;
GRANT ALL ON FUNCTION public.fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric) TO authenticated;
GRANT ALL ON FUNCTION public.fn_check_storage_empresa(p_empresa_id uuid, p_umbral numeric) TO service_role;


--
-- Name: FUNCTION fn_check_storage_todas_empresas(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_check_storage_todas_empresas() TO anon;
GRANT ALL ON FUNCTION public.fn_check_storage_todas_empresas() TO authenticated;
GRANT ALL ON FUNCTION public.fn_check_storage_todas_empresas() TO service_role;


--
-- Name: FUNCTION fn_disparar_push(p_para_usuario_id uuid, p_mensaje text, p_ticket_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_disparar_push(p_para_usuario_id uuid, p_mensaje text, p_ticket_id uuid) TO anon;
GRANT ALL ON FUNCTION public.fn_disparar_push(p_para_usuario_id uuid, p_mensaje text, p_ticket_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.fn_disparar_push(p_para_usuario_id uuid, p_mensaje text, p_ticket_id uuid) TO service_role;


--
-- Name: FUNCTION fn_empresa_tiene_espacio(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_empresa_tiene_espacio() TO anon;
GRANT ALL ON FUNCTION public.fn_empresa_tiene_espacio() TO authenticated;
GRANT ALL ON FUNCTION public.fn_empresa_tiene_espacio() TO service_role;


--
-- Name: FUNCTION fn_limites_plan(p_plan text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_limites_plan(p_plan text) TO anon;
GRANT ALL ON FUNCTION public.fn_limites_plan(p_plan text) TO authenticated;
GRANT ALL ON FUNCTION public.fn_limites_plan(p_plan text) TO service_role;


--
-- Name: FUNCTION fn_marcar_empresas_a_purgar(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_marcar_empresas_a_purgar() TO anon;
GRANT ALL ON FUNCTION public.fn_marcar_empresas_a_purgar() TO authenticated;
GRANT ALL ON FUNCTION public.fn_marcar_empresas_a_purgar() TO service_role;


--
-- Name: FUNCTION fn_notificar_involucrados_ticket(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_notificar_involucrados_ticket() TO anon;
GRANT ALL ON FUNCTION public.fn_notificar_involucrados_ticket() TO authenticated;
GRANT ALL ON FUNCTION public.fn_notificar_involucrados_ticket() TO service_role;


--
-- Name: FUNCTION fn_pagos_suscripcion_inmutable(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_pagos_suscripcion_inmutable() TO anon;
GRANT ALL ON FUNCTION public.fn_pagos_suscripcion_inmutable() TO authenticated;
GRANT ALL ON FUNCTION public.fn_pagos_suscripcion_inmutable() TO service_role;


--
-- Name: FUNCTION fn_proteger_aceptaciones(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_proteger_aceptaciones() TO anon;
GRANT ALL ON FUNCTION public.fn_proteger_aceptaciones() TO authenticated;
GRANT ALL ON FUNCTION public.fn_proteger_aceptaciones() TO service_role;


--
-- Name: FUNCTION fn_proteger_audit_log(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_proteger_audit_log() TO anon;
GRANT ALL ON FUNCTION public.fn_proteger_audit_log() TO authenticated;
GRANT ALL ON FUNCTION public.fn_proteger_audit_log() TO service_role;


--
-- Name: FUNCTION fn_proteger_columnas_empresa(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_proteger_columnas_empresa() TO anon;
GRANT ALL ON FUNCTION public.fn_proteger_columnas_empresa() TO authenticated;
GRANT ALL ON FUNCTION public.fn_proteger_columnas_empresa() TO service_role;


--
-- Name: FUNCTION fn_proteger_ticket_comentarios(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_proteger_ticket_comentarios() TO anon;
GRANT ALL ON FUNCTION public.fn_proteger_ticket_comentarios() TO authenticated;
GRANT ALL ON FUNCTION public.fn_proteger_ticket_comentarios() TO service_role;


--
-- Name: FUNCTION fn_sectores_usuario(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_sectores_usuario() TO anon;
GRANT ALL ON FUNCTION public.fn_sectores_usuario() TO authenticated;
GRANT ALL ON FUNCTION public.fn_sectores_usuario() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_dispositivo(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_dispositivo() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_dispositivo() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_dispositivo() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_maquina_documentos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_maquina_documentos() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_maquina_documentos() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_maquina_documentos() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_notificaciones(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_notificaciones() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_notificaciones() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_notificaciones() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_repuestos_maquinas(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_repuestos_maquinas() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_repuestos_maquinas() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_repuestos_maquinas() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_ticket_comentario(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_comentario() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_comentario() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_comentario() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_ticket_fotos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_fotos() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_fotos() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_fotos() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_ticket_historial(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_historial() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_historial() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_ticket_historial() TO service_role;


--
-- Name: FUNCTION fn_set_empresa_usuario_sector(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_set_empresa_usuario_sector() TO anon;
GRANT ALL ON FUNCTION public.fn_set_empresa_usuario_sector() TO authenticated;
GRANT ALL ON FUNCTION public.fn_set_empresa_usuario_sector() TO service_role;


--
-- Name: FUNCTION fn_usuario_restringido_sector(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_usuario_restringido_sector() TO anon;
GRANT ALL ON FUNCTION public.fn_usuario_restringido_sector() TO authenticated;
GRANT ALL ON FUNCTION public.fn_usuario_restringido_sector() TO service_role;


--
-- Name: FUNCTION fn_validar_empresa_maquina_sector(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_empresa_maquina_sector() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_empresa_maquina_sector() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_empresa_maquina_sector() TO service_role;


--
-- Name: FUNCTION fn_validar_empresa_repuesto_categoria(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_empresa_repuesto_categoria() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_empresa_repuesto_categoria() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_empresa_repuesto_categoria() TO service_role;


--
-- Name: FUNCTION fn_validar_empresa_usuario_rol(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_empresa_usuario_rol() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_empresa_usuario_rol() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_empresa_usuario_rol() TO service_role;


--
-- Name: FUNCTION fn_validar_limite_maquinas(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_limite_maquinas() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_limite_maquinas() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_limite_maquinas() TO service_role;


--
-- Name: FUNCTION fn_validar_limite_usuarios(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios() TO service_role;


--
-- Name: FUNCTION fn_validar_limite_usuarios_reactivar(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios_reactivar() TO anon;
GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios_reactivar() TO authenticated;
GRANT ALL ON FUNCTION public.fn_validar_limite_usuarios_reactivar() TO service_role;


--
-- Name: FUNCTION generar_numero_ticket(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generar_numero_ticket(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.generar_numero_ticket(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.generar_numero_ticket(p_empresa_id uuid) TO service_role;


--
-- Name: TABLE config_plazos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.config_plazos TO anon;
GRANT ALL ON TABLE public.config_plazos TO authenticated;
GRANT ALL ON TABLE public.config_plazos TO service_role;


--
-- Name: FUNCTION get_config_plazos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_config_plazos() TO anon;
GRANT ALL ON FUNCTION public.get_config_plazos() TO authenticated;
GRANT ALL ON FUNCTION public.get_config_plazos() TO service_role;


--
-- Name: FUNCTION get_empresa_id(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_empresa_id() TO anon;
GRANT ALL ON FUNCTION public.get_empresa_id() TO authenticated;
GRANT ALL ON FUNCTION public.get_empresa_id() TO service_role;


--
-- Name: FUNCTION get_mtbf_empresa(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_mtbf_empresa() TO anon;
GRANT ALL ON FUNCTION public.get_mtbf_empresa() TO authenticated;
GRANT ALL ON FUNCTION public.get_mtbf_empresa() TO service_role;


--
-- Name: FUNCTION legal_aceptar(p_documento_legal_id uuid, p_user_agent text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text) TO anon;
GRANT ALL ON FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text) TO authenticated;
GRANT ALL ON FUNCTION public.legal_aceptar(p_documento_legal_id uuid, p_user_agent text) TO service_role;


--
-- Name: FUNCTION legal_estado_pendiente(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.legal_estado_pendiente() FROM PUBLIC;
GRANT ALL ON FUNCTION public.legal_estado_pendiente() TO anon;
GRANT ALL ON FUNCTION public.legal_estado_pendiente() TO authenticated;
GRANT ALL ON FUNCTION public.legal_estado_pendiente() TO service_role;


--
-- Name: FUNCTION listar_empresas_pendientes(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.listar_empresas_pendientes() TO anon;
GRANT ALL ON FUNCTION public.listar_empresas_pendientes() TO authenticated;
GRANT ALL ON FUNCTION public.listar_empresas_pendientes() TO service_role;


--
-- Name: FUNCTION listar_todas_empresas(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.listar_todas_empresas() TO anon;
GRANT ALL ON FUNCTION public.listar_todas_empresas() TO authenticated;
GRANT ALL ON FUNCTION public.listar_todas_empresas() TO service_role;


--
-- Name: TABLE pagos_suscripcion; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.pagos_suscripcion TO anon;
GRANT ALL ON TABLE public.pagos_suscripcion TO authenticated;
GRANT ALL ON TABLE public.pagos_suscripcion TO service_role;


--
-- Name: FUNCTION marcar_pago_facturado(p_pago_id uuid, p_facturado boolean, p_factura_numero text, p_factura_fecha timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.marcar_pago_facturado(p_pago_id uuid, p_facturado boolean, p_factura_numero text, p_factura_fecha timestamp with time zone) TO anon;
GRANT ALL ON FUNCTION public.marcar_pago_facturado(p_pago_id uuid, p_facturado boolean, p_factura_numero text, p_factura_fecha timestamp with time zone) TO authenticated;
GRANT ALL ON FUNCTION public.marcar_pago_facturado(p_pago_id uuid, p_facturado boolean, p_factura_numero text, p_factura_fecha timestamp with time zone) TO service_role;


--
-- Name: FUNCTION mis_permisos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.mis_permisos() TO anon;
GRANT ALL ON FUNCTION public.mis_permisos() TO authenticated;
GRANT ALL ON FUNCTION public.mis_permisos() TO service_role;


--
-- Name: FUNCTION proteger_campos_usuario(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.proteger_campos_usuario() TO anon;
GRANT ALL ON FUNCTION public.proteger_campos_usuario() TO authenticated;
GRANT ALL ON FUNCTION public.proteger_campos_usuario() TO service_role;


--
-- Name: FUNCTION puede_comentar_ticket(p_ticket_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.puede_comentar_ticket(p_ticket_id uuid) TO anon;
GRANT ALL ON FUNCTION public.puede_comentar_ticket(p_ticket_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.puede_comentar_ticket(p_ticket_id uuid) TO service_role;


--
-- Name: FUNCTION registrar_egress(p_origen text, p_bytes bigint, p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.registrar_egress(p_origen text, p_bytes bigint, p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.registrar_egress(p_origen text, p_bytes bigint, p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.registrar_egress(p_origen text, p_bytes bigint, p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION registrar_ingreso_stock(p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid, p_descripcion text, p_registrado_por uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.registrar_ingreso_stock(p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid, p_descripcion text, p_registrado_por uuid) TO anon;
GRANT ALL ON FUNCTION public.registrar_ingreso_stock(p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid, p_descripcion text, p_registrado_por uuid) TO authenticated;
GRANT ALL ON FUNCTION public.registrar_ingreso_stock(p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid, p_descripcion text, p_registrado_por uuid) TO service_role;


--
-- Name: FUNCTION registrar_salida_stock(p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid, p_observacion text, p_registrado_por uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.registrar_salida_stock(p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid, p_observacion text, p_registrado_por uuid) TO anon;
GRANT ALL ON FUNCTION public.registrar_salida_stock(p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid, p_observacion text, p_registrado_por uuid) TO authenticated;
GRANT ALL ON FUNCTION public.registrar_salida_stock(p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid, p_observacion text, p_registrado_por uuid) TO service_role;


--
-- Name: FUNCTION renombrar_rol(p_rol_id uuid, p_nombre text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.renombrar_rol(p_rol_id uuid, p_nombre text) TO anon;
GRANT ALL ON FUNCTION public.renombrar_rol(p_rol_id uuid, p_nombre text) TO authenticated;
GRANT ALL ON FUNCTION public.renombrar_rol(p_rol_id uuid, p_nombre text) TO service_role;


--
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.rls_auto_enable() TO anon;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- Name: FUNCTION rut_uy_valido(rut text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.rut_uy_valido(rut text) TO anon;
GRANT ALL ON FUNCTION public.rut_uy_valido(rut text) TO authenticated;
GRANT ALL ON FUNCTION public.rut_uy_valido(rut text) TO service_role;


--
-- Name: FUNCTION sa_export_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_export_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.sa_export_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.sa_export_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION sa_generar_doc_esquema(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sa_generar_doc_esquema() FROM PUBLIC;
GRANT ALL ON FUNCTION public.sa_generar_doc_esquema() TO service_role;
GRANT ALL ON FUNCTION public.sa_generar_doc_esquema() TO authenticated;


--
-- Name: FUNCTION sa_legal_cobertura(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sa_legal_cobertura() FROM PUBLIC;
GRANT ALL ON FUNCTION public.sa_legal_cobertura() TO anon;
GRANT ALL ON FUNCTION public.sa_legal_cobertura() TO authenticated;
GRANT ALL ON FUNCTION public.sa_legal_cobertura() TO service_role;


--
-- Name: FUNCTION sa_listar_pagos(p_solo_sin_facturar boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_listar_pagos(p_solo_sin_facturar boolean) TO anon;
GRANT ALL ON FUNCTION public.sa_listar_pagos(p_solo_sin_facturar boolean) TO authenticated;
GRANT ALL ON FUNCTION public.sa_listar_pagos(p_solo_sin_facturar boolean) TO service_role;


--
-- Name: FUNCTION sa_listar_pagos_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_listar_pagos_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.sa_listar_pagos_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.sa_listar_pagos_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION sa_purgar_datos_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_purgar_datos_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION sa_reactivar_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_reactivar_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.sa_reactivar_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.sa_reactivar_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION sa_solicitar_baja(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_solicitar_baja(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.sa_solicitar_baja(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.sa_solicitar_baja(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION sa_suspender_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.sa_suspender_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.sa_suspender_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.sa_suspender_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION set_config_plazo(p_clave text, p_dias integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_config_plazo(p_clave text, p_dias integer) TO anon;
GRANT ALL ON FUNCTION public.set_config_plazo(p_clave text, p_dias integer) TO authenticated;
GRANT ALL ON FUNCTION public.set_config_plazo(p_clave text, p_dias integer) TO service_role;


--
-- Name: FUNCTION unaccent_immutable(text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.unaccent_immutable(text) TO anon;
GRANT ALL ON FUNCTION public.unaccent_immutable(text) TO authenticated;
GRANT ALL ON FUNCTION public.unaccent_immutable(text) TO service_role;


--
-- Name: FUNCTION update_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at() TO service_role;


--
-- Name: FUNCTION uso_cupos_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.uso_cupos_empresa(p_empresa_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.uso_cupos_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.uso_cupos_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.uso_cupos_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: FUNCTION uso_egress_empresa(p_empresa_id uuid, p_periodo date); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.uso_egress_empresa(p_empresa_id uuid, p_periodo date) TO anon;
GRANT ALL ON FUNCTION public.uso_egress_empresa(p_empresa_id uuid, p_periodo date) TO authenticated;
GRANT ALL ON FUNCTION public.uso_egress_empresa(p_empresa_id uuid, p_periodo date) TO service_role;


--
-- Name: FUNCTION uso_storage_empresa(p_empresa_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.uso_storage_empresa(p_empresa_id uuid) TO anon;
GRANT ALL ON FUNCTION public.uso_storage_empresa(p_empresa_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.uso_storage_empresa(p_empresa_id uuid) TO service_role;


--
-- Name: TABLE aceptaciones_legales; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.aceptaciones_legales TO anon;
GRANT ALL ON TABLE public.aceptaciones_legales TO authenticated;
GRANT ALL ON TABLE public.aceptaciones_legales TO service_role;


--
-- Name: TABLE adjuntos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.adjuntos TO anon;
GRANT ALL ON TABLE public.adjuntos TO authenticated;
GRANT ALL ON TABLE public.adjuntos TO service_role;


--
-- Name: TABLE audit_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.audit_log TO anon;
GRANT ALL ON TABLE public.audit_log TO authenticated;
GRANT ALL ON TABLE public.audit_log TO service_role;


--
-- Name: SEQUENCE audit_log_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.audit_log_id_seq TO anon;
GRANT ALL ON SEQUENCE public.audit_log_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.audit_log_id_seq TO service_role;


--
-- Name: TABLE dispositivos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.dispositivos TO anon;
GRANT ALL ON TABLE public.dispositivos TO authenticated;
GRANT ALL ON TABLE public.dispositivos TO service_role;


--
-- Name: TABLE documentos_legales; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.documentos_legales TO anon;
GRANT ALL ON TABLE public.documentos_legales TO authenticated;
GRANT ALL ON TABLE public.documentos_legales TO service_role;


--
-- Name: TABLE egress_mensual_agg; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.egress_mensual_agg TO anon;
GRANT ALL ON TABLE public.egress_mensual_agg TO authenticated;
GRANT ALL ON TABLE public.egress_mensual_agg TO service_role;


--
-- Name: TABLE empresas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.empresas TO anon;
GRANT ALL ON TABLE public.empresas TO authenticated;
GRANT ALL ON TABLE public.empresas TO service_role;


--
-- Name: TABLE ingreso_repuestos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ingreso_repuestos TO anon;
GRANT ALL ON TABLE public.ingreso_repuestos TO authenticated;
GRANT ALL ON TABLE public.ingreso_repuestos TO service_role;


--
-- Name: TABLE intentos_recuperacion; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.intentos_recuperacion TO anon;
GRANT ALL ON TABLE public.intentos_recuperacion TO authenticated;
GRANT ALL ON TABLE public.intentos_recuperacion TO service_role;


--
-- Name: TABLE lecturas_maquina; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.lecturas_maquina TO anon;
GRANT ALL ON TABLE public.lecturas_maquina TO authenticated;
GRANT ALL ON TABLE public.lecturas_maquina TO service_role;


--
-- Name: TABLE maquina_documentos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.maquina_documentos TO anon;
GRANT ALL ON TABLE public.maquina_documentos TO authenticated;
GRANT ALL ON TABLE public.maquina_documentos TO service_role;


--
-- Name: TABLE notificaciones; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.notificaciones TO anon;
GRANT ALL ON TABLE public.notificaciones TO authenticated;
GRANT ALL ON TABLE public.notificaciones TO service_role;


--
-- Name: TABLE permisos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.permisos TO anon;
GRANT ALL ON TABLE public.permisos TO authenticated;
GRANT ALL ON TABLE public.permisos TO service_role;


--
-- Name: TABLE planes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.planes TO anon;
GRANT ALL ON TABLE public.planes TO authenticated;
GRANT ALL ON TABLE public.planes TO service_role;


--
-- Name: TABLE planes_mantenimiento; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.planes_mantenimiento TO anon;
GRANT ALL ON TABLE public.planes_mantenimiento TO authenticated;
GRANT ALL ON TABLE public.planes_mantenimiento TO service_role;


--
-- Name: TABLE proveedores; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.proveedores TO anon;
GRANT ALL ON TABLE public.proveedores TO authenticated;
GRANT ALL ON TABLE public.proveedores TO service_role;


--
-- Name: TABLE repuestos_bajo_stock; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.repuestos_bajo_stock TO anon;
GRANT ALL ON TABLE public.repuestos_bajo_stock TO authenticated;
GRANT ALL ON TABLE public.repuestos_bajo_stock TO service_role;


--
-- Name: TABLE repuestos_maquinas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.repuestos_maquinas TO anon;
GRANT ALL ON TABLE public.repuestos_maquinas TO authenticated;
GRANT ALL ON TABLE public.repuestos_maquinas TO service_role;


--
-- Name: TABLE rol_permisos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.rol_permisos TO anon;
GRANT ALL ON TABLE public.rol_permisos TO authenticated;
GRANT ALL ON TABLE public.rol_permisos TO service_role;


--
-- Name: TABLE roles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.roles TO anon;
GRANT ALL ON TABLE public.roles TO authenticated;
GRANT ALL ON TABLE public.roles TO service_role;


--
-- Name: TABLE salida_repuestos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.salida_repuestos TO anon;
GRANT ALL ON TABLE public.salida_repuestos TO authenticated;
GRANT ALL ON TABLE public.salida_repuestos TO service_role;


--
-- Name: TABLE ticket_comentarios; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ticket_comentarios TO anon;
GRANT ALL ON TABLE public.ticket_comentarios TO authenticated;
GRANT ALL ON TABLE public.ticket_comentarios TO service_role;


--
-- Name: TABLE ticket_fotos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ticket_fotos TO anon;
GRANT ALL ON TABLE public.ticket_fotos TO authenticated;
GRANT ALL ON TABLE public.ticket_fotos TO service_role;


--
-- Name: TABLE ticket_historial; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ticket_historial TO anon;
GRANT ALL ON TABLE public.ticket_historial TO authenticated;
GRANT ALL ON TABLE public.ticket_historial TO service_role;


--
-- Name: TABLE tickets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.tickets TO anon;
GRANT ALL ON TABLE public.tickets TO authenticated;
GRANT ALL ON TABLE public.tickets TO service_role;


--
-- Name: TABLE tipos_intervalo; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.tipos_intervalo TO anon;
GRANT ALL ON TABLE public.tipos_intervalo TO authenticated;
GRANT ALL ON TABLE public.tipos_intervalo TO service_role;


--
-- Name: TABLE usuario_sector; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.usuario_sector TO anon;
GRANT ALL ON TABLE public.usuario_sector TO authenticated;
GRANT ALL ON TABLE public.usuario_sector TO service_role;


--
-- Name: TABLE usuarios; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.usuarios TO anon;
GRANT ALL ON TABLE public.usuarios TO authenticated;
GRANT ALL ON TABLE public.usuarios TO service_role;


--
-- Name: TABLE vw_mtbf_maquinas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.vw_mtbf_maquinas TO anon;
GRANT ALL ON TABLE public.vw_mtbf_maquinas TO authenticated;
GRANT ALL ON TABLE public.vw_mtbf_maquinas TO service_role;


--
-- Name: TABLE whatsapp_destinatarios; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.whatsapp_destinatarios TO anon;
GRANT ALL ON TABLE public.whatsapp_destinatarios TO authenticated;
GRANT ALL ON TABLE public.whatsapp_destinatarios TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict A6AdowTuodaYsxKMiq0bb9ehc7Pfbe1yaBlmjTd17v6n6F2d6CgBPMAbDsgd6Or

