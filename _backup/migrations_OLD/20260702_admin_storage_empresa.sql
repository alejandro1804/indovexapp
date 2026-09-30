-- supabase/migrations/20260702_admin_storage_empresa.sql
--
-- RPC para el tab "Almacenamiento" del panel de super admin.
-- Depende de que todos los paths en el bucket 'documentos' sigan el patrón
-- unificado: {empresa_id}/{categoria}/{entidad_id}/{portada|adjuntos}/{archivo}
--
-- Devuelve un breakdown por categoría (maquina / repuesto / ticket / usuario)
-- para que la UI pueda mostrar tanto el total como el desglose.

CREATE OR REPLACE FUNCTION admin_storage_empresa(p_empresa_id uuid)
RETURNS TABLE (
  categoria text,
  cantidad_archivos bigint,
  bytes_total bigint
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Doble candado: solo super admin puede ejecutar esta función,
  -- mismo patrón que el resto de los RPCs admin_*_empresa.
  IF NOT es_super_admin() THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  RETURN QUERY
  SELECT
    coalesce((storage.foldername(o.name))[2], 'otros') AS categoria,
    count(*)::bigint AS cantidad_archivos,
    coalesce(sum((o.metadata->>'size')::bigint), 0)::bigint AS bytes_total
  FROM storage.objects o
  WHERE o.bucket_id = 'documentos'
    AND (storage.foldername(o.name))[1] = p_empresa_id::text
  GROUP BY coalesce((storage.foldername(o.name))[2], 'otros')
  ORDER BY bytes_total DESC;
END;
$$;

-- Restringir ejecución: cualquier usuario autenticado puede llamarla,
-- pero la función misma rechaza si no es super admin (chequeo interno arriba).
REVOKE ALL ON FUNCTION admin_storage_empresa(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_storage_empresa(uuid) TO authenticated;