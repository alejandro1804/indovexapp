// Barre todos los archivos de una empresa en Storage.
//
// Desde la unificación de paths (empresa_id siempre como primer segmento,
// tanto para adjuntos como para fotos de portada de máquinas/repuestos),
// una sola pasada recursiva sobre el prefijo {empresa_id}/ cubre TODO:
//   {empresa_id}/maquina/{id}/adjuntos/...
//   {empresa_id}/maquina/{id}/portada/...
//   {empresa_id}/repuesto/{id}/adjuntos/...
//   {empresa_id}/repuesto/{id}/portada/...
//   {empresa_id}/ticket/{id}/adjuntos/...
//   {empresa_id}/usuario/{id}/portada/...   (avatares, a futuro)
//
// Ya no hace falta enumerar rutas por tipo — si mañana se agrega una entidad
// nueva bajo el mismo patrón, queda cubierta automáticamente sin tocar esta función.
async function borrarStorage(admin: any, empresaId: string) {
  const aBorrar: string[] = [];

  await listarRecursivo(admin, empresaId, aBorrar);

  if (aBorrar.length === 0) {
    return { borrados: 0, errores: [] };
  }

  const errores: string[] = [];
  // Borrar en lotes de 100 (límite razonable de la API).
  for (let i = 0; i < aBorrar.length; i += 100) {
    const lote = aBorrar.slice(i, i + 100);
    const { error } = await admin.storage.from(BUCKET).remove(lote);
    if (error) errores.push(error.message);
  }

  return { borrados: aBorrar.length, errores };
}

// Lista recursivamente todos los objetos bajo un prefijo y los acumula.
// (sin cambios respecto al original)
async function listarRecursivo(admin: any, prefijo: string, acc: string[]) {
  const { data, error } = await admin.storage
    .from(BUCKET)
    .list(prefijo, { limit: 1000 });

  if (error || !data) return;

  for (const item of data) {
    const fullPath = prefijo ? `${prefijo}/${item.name}` : item.name;
    if (item.id === null) {
      // Es una carpeta -> recursión.
      await listarRecursivo(admin, fullPath, acc);
    } else {
      // Es un archivo.
      acc.push(fullPath);
    }
  }
}