-- Migration: whatsapp_destinatarios
-- Permite a cada empresa configurar múltiples números de WhatsApp
-- que reciben alertas de stock bajo (antes hardcodeado a un único
-- número vía la variable de entorno ADMIN_WHATSAPP_NUMBER)

-- 1. Tabla de destinatarios -------------------------------------------------

CREATE TABLE public.whatsapp_destinatarios (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id uuid NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    usuario_id uuid REFERENCES usuarios(id) ON DELETE SET NULL,
    numero_whatsapp text NOT NULL,
    nombre_referencia text,
    activo boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.whatsapp_destinatarios IS
  'Números de WhatsApp configurados por cada empresa para recibir alertas (ej. stock bajo)';
COMMENT ON COLUMN public.whatsapp_destinatarios.numero_whatsapp IS
  'Formato E.164, ej: +598XXXXXXXX (sin el prefijo whatsapp:)';

-- 2. updated_at automático (mismo patrón que el resto de las tablas) -------

CREATE TRIGGER whatsapp_destinatarios_updated_at
    BEFORE UPDATE ON public.whatsapp_destinatarios
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 3. Auditoría (mismo patrón ALCOA+ que repuestos, maquinas, etc.) --------

CREATE TRIGGER trg_audit_whatsapp_destinatarios
    AFTER INSERT OR UPDATE OR DELETE ON public.whatsapp_destinatarios
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- 4. RLS ---------------------------------------------------------------

ALTER TABLE public.whatsapp_destinatarios ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_destinatarios_select ON public.whatsapp_destinatarios
    FOR SELECT
    USING (empresa_id = get_empresa_id());

CREATE POLICY whatsapp_destinatarios_insert ON public.whatsapp_destinatarios
    FOR INSERT
    WITH CHECK (empresa_id = get_empresa_id());

CREATE POLICY whatsapp_destinatarios_update ON public.whatsapp_destinatarios
    FOR UPDATE
    USING (empresa_id = get_empresa_id());

CREATE POLICY whatsapp_destinatarios_delete ON public.whatsapp_destinatarios
    FOR DELETE
    USING (empresa_id = get_empresa_id());

-- 5. Actualizar fn_check_stock_bajo para incluir empresa_id en el payload --
--    (sin esto, la Edge Function no tiene forma de saber qué empresa
--    consultar para buscar destinatarios)

CREATE OR REPLACE FUNCTION public.fn_check_stock_bajo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
END; $function$;