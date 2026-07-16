-- planes_mantenimiento
CREATE TABLE IF NOT EXISTS planes_mantenimiento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id uuid NOT NULL REFERENCES empresas(id),
  maquina_id uuid NOT NULL REFERENCES maquinas(id),
  descripcion_tarea text NOT NULL,
  tipo_intervalo text NOT NULL,
  intervalo_valor numeric NOT NULL,
  ultimo_valor_ejecutado numeric,
  proximo_valor numeric,
  activo boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE planes_mantenimiento ENABLE ROW LEVEL SECURITY;

CREATE POLICY planes_mantenimiento_mi_empresa
  ON planes_mantenimiento FOR ALL
  USING (empresa_id = get_empresa_id());

CREATE TRIGGER trg_audit_planes_mantenimiento
  AFTER INSERT OR UPDATE OR DELETE ON planes_mantenimiento
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER planes_mantenimiento_updated_at
  BEFORE UPDATE ON planes_mantenimiento
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- lecturas_maquina
CREATE TABLE IF NOT EXISTS lecturas_maquina (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id uuid NOT NULL REFERENCES empresas(id),
  maquina_id uuid NOT NULL REFERENCES maquinas(id),
  tipo text NOT NULL,
  valor numeric NOT NULL,
  fecha_lectura date NOT NULL DEFAULT CURRENT_DATE,
  registrado_por uuid NOT NULL REFERENCES usuarios(id),
  observacion text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE lecturas_maquina ENABLE ROW LEVEL SECURITY;

CREATE POLICY lecturas_maquina_mi_empresa
  ON lecturas_maquina FOR ALL
  USING (empresa_id = get_empresa_id());

CREATE TRIGGER trg_audit_lecturas_maquina
  AFTER INSERT OR UPDATE OR DELETE ON lecturas_maquina
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- tickets: nuevos campos
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS tipo text NOT NULL DEFAULT 'correctivo',
  ADD COLUMN IF NOT EXISTS prioridad text NOT NULL DEFAULT 'media',
  ADD COLUMN IF NOT EXISTS fecha_programada date,
  ADD COLUMN IF NOT EXISTS fecha_cierre timestamptz,
  ADD COLUMN IF NOT EXISTS plan_id uuid REFERENCES planes_mantenimiento(id);