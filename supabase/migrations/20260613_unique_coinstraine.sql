-- ============================================================
-- Migración: Restricciones de unicidad por empresa
-- Fecha: 2026-06-13
-- Objetivo:
--   1. Evitar nombres/descripciones duplicados dentro de la
--      misma empresa para: sectores, usuarios, maquinas, repuestos.
--   2. Evitar empresas duplicadas por RUT.
-- ============================================================

-- ------------------------------------------------------------
-- 0. Resolver datos existentes en conflicto
-- ------------------------------------------------------------
-- Dos empresas de prueba ("Barizo" y "test") comparten el mismo
-- RUT 123456789012. Se les asigna un RUT placeholder distinto a
-- la empresa "test" para no chocar con el nuevo UNIQUE de empresas.
UPDATE empresas
SET rut = '123456789012-TEST'
WHERE id = '92f0c740-661e-4335-a5e2-c4f80521ffe5'
  AND rut = '123456789012';

-- ------------------------------------------------------------
-- 1. Empresas: RUT único (permite múltiples NULL)
-- ------------------------------------------------------------
ALTER TABLE empresas
ADD CONSTRAINT uq_empresas_rut UNIQUE (rut);

-- ------------------------------------------------------------
-- 2. Sectores: nombre único por empresa
-- ------------------------------------------------------------
ALTER TABLE sectores
ADD CONSTRAINT uq_sectores_empresa_nombre UNIQUE (empresa_id, nombre);

-- ------------------------------------------------------------
-- 3. Máquinas: nombre único por empresa
-- ------------------------------------------------------------
ALTER TABLE maquinas
ADD CONSTRAINT uq_maquinas_empresa_nombre UNIQUE (empresa_id, nombre);

-- ------------------------------------------------------------
-- 4. Repuestos: descripción única por empresa
-- ------------------------------------------------------------
ALTER TABLE repuestos
ADD CONSTRAINT uq_repuestos_empresa_descripcion UNIQUE (empresa_id, descripcion);

-- ------------------------------------------------------------
-- 5. Usuarios: nombre único por empresa
-- ------------------------------------------------------------
ALTER TABLE usuarios
ADD CONSTRAINT uq_usuarios_empresa_nombre UNIQUE (empresa_id, nombre);

-- ============================================================
-- Notas:
-- - roles, proveedores y categorias_repuestos quedan PENDIENTES
--   de definición (no se incluyeron en este alcance, a confirmar).
-- - Si en el futuro se requiere unicidad case/accent-insensitive
--   (ej. "Deposito" vs "Depósito"), reemplazar estos UNIQUE por
--   índices únicos sobre lower(unaccent(columna)), requiriendo
--   la extensión "unaccent".
-- ============================================================