-- Migration: 20260626_vw_mtbf_maquinas.sql
-- Vista y RPC para cálculo de MTBF (Tiempo Medio Entre Fallas) por máquina.
-- El MTBF aparece automáticamente cuando una máquina acumula su segundo
-- ticket correctivo cerrado (se necesitan 2 fallas para medir el intervalo).

-- =====================================================================
-- 1. Vista: vw_mtbf_maquinas
-- =====================================================================
CREATE OR REPLACE VIEW vw_mtbf_maquinas AS
WITH tickets_correctivos AS (
  SELECT
    t.empresa_id,
    t.maquina_id,
    t.created_at,
    LAG(t.created_at) OVER (
      PARTITION BY t.empresa_id, t.maquina_id
      ORDER BY t.created_at
    ) AS created_at_anterior
  FROM tickets t
  WHERE t.tipo = 'correctivo'
    AND t.estado = 'cerrado'
),
intervalos AS (
  SELECT
    empresa_id,
    maquina_id,
    EXTRACT(EPOCH FROM (created_at - created_at_anterior)) / 86400 AS dias_entre_fallas
  FROM tickets_correctivos
  WHERE created_at_anterior IS NOT NULL
),
conteo AS (
  SELECT
    empresa_id,
    maquina_id,
    COUNT(*) AS intervalos_calculados,
    ROUND(AVG(dias_entre_fallas)::numeric, 1) AS mtbf_dias
  FROM intervalos
  GROUP BY empresa_id, maquina_id
)
SELECT
  c.empresa_id,
  c.maquina_id,
  m.nombre AS maquina_nombre,
  s.nombre AS sector_nombre,
  c.mtbf_dias,
  c.intervalos_calculados,
  c.intervalos_calculados + 1 AS total_tickets_correctivos
FROM conteo c
JOIN maquinas m ON m.id = c.maquina_id
JOIN sectores s ON s.id = m.sector_id;

-- =====================================================================
-- 2. RPC: get_mtbf_empresa
-- =====================================================================
-- Filtra por la empresa del usuario autenticado (get_empresa_id()) y
-- clasifica la confiabilidad del cálculo según la cantidad de fallas.
CREATE OR REPLACE FUNCTION get_mtbf_empresa()
RETURNS TABLE (
  maquina_id uuid,
  maquina_nombre text,
  sector_nombre text,
  mtbf_dias numeric,
  total_tickets_correctivos integer,
  confiabilidad text
)
LANGUAGE sql
SECURITY DEFINER
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
