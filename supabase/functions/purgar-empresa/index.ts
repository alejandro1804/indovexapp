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

// Barre todos los archivos de una empresa en sus dos rutas de Storage.
async function borrarStorage(admin: any, empresaId: string) {
  const aBorrar: string[] = [];

  // Ruta A: {empresa_id}/... (adjuntos de repuestos y tickets)
  await listarRecursivo(admin, empresaId, aBorrar);

  // Ruta B: imagenes/maquinas/{empresa_id}/... (fotos de máquinas)
  await listarRecursivo(admin, `imagenes/maquinas/${empresaId}`, aBorrar);

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

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}