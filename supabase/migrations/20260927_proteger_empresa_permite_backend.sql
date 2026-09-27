-- ─────────────────────────────────────────────────────────────
-- 20260927_proteger_empresa_permite_backend.sql
--
-- Problema (detectado en producción, sept 2026):
-- fn_proteger_columnas_empresa() protege los campos de plan,
-- suscripción y límites para que un administrador no los cambie
-- desde el perfil de empresa. Pero solo exceptuaba al super admin
-- (por auth.uid()) y al bypass explícito. Las Edge Functions usan
-- service_role (sin auth.uid()), así que también quedaban
-- bloqueadas: webhook-mercadopago y crear-suscripcion no podían
-- activar, cambiar de plan ni suspender empresas.
--
-- Corrección: la protección aplica solo a pedidos de USUARIOS de la
-- API (roles anon / authenticated). Pasan sin restricción:
--   • service_role: Edge Functions (backend confiable).
--   • conexiones directas (session_user distinto de 'authenticator'):
--     SQL Editor, pg_cron, migraciones.
-- El resto de la lógica queda igual.
-- ─────────────────────────────────────────────────────────────

begin;

create or replace function public.fn_proteger_columnas_empresa()
returns trigger
language plpgsql
security definer
as $function$
begin
  -- Conexiones directas (SQL Editor, pg_cron, migraciones): no pasan
  -- por la API, no son usuarios de la app.
  if session_user <> 'authenticator' then
    return new;
  end if;

  -- Edge Functions con service_role: backend confiable.
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
$function$;

commit;