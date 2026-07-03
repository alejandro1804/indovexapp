// supabase/functions/purgar-empresa/index.ts
//
// Purga definitiva de una empresa. OPERACIÓN IRREVERSIBLE.
// Orquesta: validación de super admin -> borrado de Auth -> borrado de datos
// (vía RPC, que también anonimiza audit_log) -> barrido de Storage.
//
// Desplegar con verificación de JWT (sin --no-verify-jwt) para que el caller
// llegue autenticado y podamos validar que es super admin.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const BUCKET = 'documentos';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { empresa_id } = await req.json();
    if (!empresa_id) {
      return json({ error: 'Falta empresa_id' }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // 1. Cliente con el JWT del caller, para validar identidad y permisos.
    const authHeader = req.headers.get('Authorization') ?? '';
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: 'No autenticado' }, 401);
    }
    const callerId = userData.user.id;

    // Cliente admin (service role) para operaciones privilegiadas.
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    // 2. Validar que el caller es super admin (doble candado).
    const { data: perfil, error: perfilErr } = await admin
      .from('usuarios')
      .select('es_super_admin')
      .eq('id', callerId)
      .single();

    if (perfilErr || perfil?.es_super_admin !== true) {
      return json({ error: 'No autorizado' }, 403);
    }

    // 3. Evitar purgar la empresa del propio super admin.
    const { data: perfilEmpresa } = await admin
      .from('usuarios')
      .select('empresa_id')
      .eq('id', callerId)
      .single();
    if (perfilEmpresa?.empresa_id === empresa_id) {
      return json({ error: 'No se puede purgar la propia empresa' }, 400);
    }

    // 3b. Validar que la empresa esté en estado 'a_purgar' (plazo cumplido).
    // Es la misma guarda que aplica el RPC sa_purgar_datos_empresa; la
    // chequeamos también acá para cortar antes y dar un error claro sin
    // tocar Auth ni Storage si el plazo todavía no venció.
    const { data: empresaData, error: empresaErr } = await admin
      .from('empresas')
      .select('nombre, estado')
      .eq('id', empresa_id)
      .single();

    if (empresaErr || !empresaData) {
      return json({ error: 'Empresa no encontrada' }, 404);
    }
    if (empresaData.estado !== 'a_purgar') {
      return json({
        error: `La empresa "${empresaData.nombre}" está en estado "${empresaData.estado}". ` +
               `Solo se puede purgar una empresa en estado "a_purgar" (plazo de conservación cumplido).`,
      }, 409);
    }

    // 4. Obtener los IDs de usuarios de la empresa ANTES de borrar (para Auth).
    const { data: usuarios } = await admin
      .from('usuarios')
      .select('id')
      .eq('empresa_id', empresa_id);
    const userIds: string[] = (usuarios ?? []).map((u: any) => u.id);

    // 5. Barrer Storage (antes de borrar la BD; los paths salen del esquema).
    const storageResult = await borrarStorage(admin, empresa_id);

    // 6. Borrar datos en la BD + anonimizar audit_log (vía RPC).
    const { data: rpcData, error: rpcErr } = await admin.rpc(
      'sa_purgar_datos_empresa',
      { p_empresa_id: empresa_id },
    );
    if (rpcErr) {
      return json(
        { error: 'Error al borrar datos: ' + rpcErr.message, storageResult },
        500,
      );
    }

    // 7. Borrar las cuentas de Auth (después de borrar el perfil en usuarios).
    let authBorrados = 0;
    const authErrores: string[] = [];
    for (const uid of userIds) {
      const { error } = await admin.auth.admin.deleteUser(uid);
      if (error) {
        authErrores.push(`${uid}: ${error.message}`);
      } else {
        authBorrados++;
      }
    }

    return json({
      ok: true,
      empresa: rpcData?.empresa,
      audit_log_anonimizados: rpcData?.audit_log_anonimizados,
      auth_borrados: authBorrados,
      auth_errores: authErrores,
      storage: storageResult,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// ─────────────────────────────────────────────────────────────
// Barrido de Storage
// ─────────────────────────────────────────────────────────────

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
async function borrarStorage(admin: any, empresaId: string) {
  const aBorrar: string[] = [];

  await listarRecursivo(admin, empresaId, aBorrar, 0, new Set<string>());

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

// Profundidad máxima de recursión. El patrón real es
// {empresa}/{tipo}/{id}/{portada|adjuntos}/archivo → 5 niveles.
// 8 da margen de sobra y corta cualquier recursión descontrolada.
const MAX_PROFUNDIDAD = 8;

// Lista recursivamente todos los objetos bajo un prefijo y los acumula en `acc`.
// Endurecida contra los casos que colgaban la Edge Function:
//  - ignora el placeholder de carpeta vacía de Supabase (.emptyFolderPlaceholder)
//  - corta a MAX_PROFUNDIDAD niveles
//  - no reprocesa un prefijo ya visitado (evita ciclos)
async function listarRecursivo(
  admin: any,
  prefijo: string,
  acc: string[],
  profundidad: number,
  visitados: Set<string>,
) {
  // Protección 1: límite de profundidad.
  if (profundidad > MAX_PROFUNDIDAD) return;

  // Protección 2: no volver a listar un prefijo ya recorrido.
  if (visitados.has(prefijo)) return;
  visitados.add(prefijo);

  const { data, error } = await admin.storage
    .from(BUCKET)
    .list(prefijo, { limit: 1000 });

  if (error || !data) return;

  for (const item of data) {
    // Protección 3: saltar el placeholder que Supabase crea en carpetas vacías.
    if (item.name === '.emptyFolderPlaceholder') continue;

    // Protección 4: saltar entradas sin nombre (defensivo).
    if (!item.name) continue;

    const fullPath = prefijo ? `${prefijo}/${item.name}` : item.name;

    // Una entrada es "carpeta" cuando no trae metadata de archivo.
    // Usamos `metadata == null` además de `id === null`: es más confiable
    // entre versiones de la Storage API (las carpetas no tienen metadata).
    const esCarpeta = item.id === null || item.metadata == null;

    if (esCarpeta) {
      await listarRecursivo(admin, fullPath, acc, profundidad + 1, visitados);
    } else {
      acc.push(fullPath);
    }
  }
}

// ─────────────────────────────────────────────────────────────
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
