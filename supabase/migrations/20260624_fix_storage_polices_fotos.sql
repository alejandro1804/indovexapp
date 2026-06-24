-- supabase/migrations/YYYYMMDD_fix_storage_policies_fotos.sql
-- El path de fotos es: imagenes/{tipo}/{empresa_id}/{entidad_id}.webp
-- foldername(name)[1] = 'imagenes'  ← incorrecto, no aísla por empresa
-- foldername(name)[3] = empresa_id  ← correcto para maquinas/repuestos
--
-- Estructura de paths:
--   imagenes/maquinas/{empresa_id}/{entidad_id}.webp  → segmento [3] = empresa_id
--   imagenes/repuestos/{empresa_id}/{entidad_id}.webp → segmento [3] = empresa_id
--   imagenes/avatares/{user_id}.webp                  → sin empresa_id en path
--
-- Solución: política permisiva para 'imagenes/' + validación de empresa en [3],
-- o más simple: cambiar a path {empresa_id}/... y validar [1].
-- Optamos por corregir la política para que funcione con el path actual.

-- DROP y recrear las 3 políticas del bucket documentos

DROP POLICY IF EXISTS documentos_select ON storage.objects;
DROP POLICY IF EXISTS documentos_insert ON storage.objects;
DROP POLICY IF EXISTS documentos_delete ON storage.objects;

-- SELECT: adjuntos (empresa en [1]) O fotos (empresa en [3]) O super admin
CREATE POLICY documentos_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'documentos'
    AND (
      -- Adjuntos: {empresa_id}/adjuntos/...  → segmento [1] = empresa_id
      (storage.foldername(name))[1] = (get_empresa_id())::text
      OR
      -- Fotos: imagenes/{tipo}/{empresa_id}/... → segmento [3] = empresa_id
      (storage.foldername(name))[3] = (get_empresa_id())::text
      OR
      es_super_admin()
    )
  );

-- INSERT: misma lógica en WITH CHECK
CREATE POLICY documentos_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'documentos'
    AND (
      (storage.foldername(name))[1] = (get_empresa_id())::text
      OR
      (storage.foldername(name))[3] = (get_empresa_id())::text
      OR
      es_super_admin()
    )
  );

-- DELETE: misma lógica en USING
CREATE POLICY documentos_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'documentos'
    AND (
      (storage.foldername(name))[1] = (get_empresa_id())::text
      OR
      (storage.foldername(name))[3] = (get_empresa_id())::text
      OR
      es_super_admin()
    )
  );

-- UPDATE (para upsert): necesaria también
DROP POLICY IF EXISTS documentos_update ON storage.objects;
CREATE POLICY documentos_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'documentos'
    AND (
      (storage.foldername(name))[1] = (get_empresa_id())::text
      OR
      (storage.foldername(name))[3] = (get_empresa_id())::text
      OR
      es_super_admin()
    )
  )
  WITH CHECK (
    bucket_id = 'documentos'
    AND (
      (storage.foldername(name))[1] = (get_empresa_id())::text
      OR
      (storage.foldername(name))[3] = (get_empresa_id())::text
      OR
      es_super_admin()
    )
  );