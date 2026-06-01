import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Cliente con el token del que llama
    const authHeader = req.headers.get('Authorization')!
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user: caller } } = await supabaseUser.auth.getUser()
    if (!caller) {
      return new Response(JSON.stringify({ error: 'No autenticado' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 2. Cliente con service role
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 3. Verificar que el que llama es admin o super admin
    const { data: perfilCaller, error: errPerfil } = await supabaseAdmin
      .from('usuarios')
      .select('empresa_id, es_super_admin, roles(nombre)')
      .eq('id', caller.id)
      .single()

    if (errPerfil || !perfilCaller) {
      return new Response(JSON.stringify({ error: 'No se encontro tu perfil' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const esAdmin = perfilCaller.es_super_admin === true ||
                    (perfilCaller.roles as any)?.nombre === 'admin'

    if (!esAdmin) {
      return new Response(JSON.stringify({ error: 'No tenes permisos para resetear contrasenas' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 4. Leer el id del usuario a resetear
    const { usuario_id } = await req.json()
    if (!usuario_id) {
      return new Response(JSON.stringify({ error: 'Falta el usuario_id' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 5. Buscar el usuario objetivo y validar que es de la misma empresa
    //    (salvo que el que llama sea super admin, que puede cualquiera)
    const { data: objetivo, error: errObjetivo } = await supabaseAdmin
      .from('usuarios')
      .select('id, empresa_id, es_super_admin')
      .eq('id', usuario_id)
      .single()

    if (errObjetivo || !objetivo) {
      return new Response(JSON.stringify({ error: 'Usuario no encontrado' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Un admin normal solo puede resetear usuarios de SU empresa
    if (!perfilCaller.es_super_admin && objetivo.empresa_id !== perfilCaller.empresa_id) {
      return new Response(JSON.stringify({ error: 'No podes resetear usuarios de otra empresa' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Nadie (salvo super admin) puede resetear a un super admin
    if (objetivo.es_super_admin && !perfilCaller.es_super_admin) {
      return new Response(JSON.stringify({ error: 'No autorizado' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 6. Generar contrasena temporal aleatoria
    const generarTemporal = () => {
      const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
      let pass = ''
      const arr = new Uint32Array(10)
      crypto.getRandomValues(arr)
      for (let i = 0; i < 10; i++) {
        pass += chars[arr[i] % chars.length]
      }
      return pass
    }
    const temporal = generarTemporal()

    // 7. Cambiar la contrasena en Auth
    const { error: errAuth } = await supabaseAdmin.auth.admin.updateUserById(
      usuario_id, { password: temporal }
    )
    if (errAuth) {
      return new Response(JSON.stringify({ error: 'Error al cambiar la contrasena: ' + errAuth.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 8. Marcar primer_login = true para forzar el cambio
    const { error: errUpdate } = await supabaseAdmin
      .from('usuarios')
      .update({ primer_login: true })
      .eq('id', usuario_id)

    if (errUpdate) {
      return new Response(JSON.stringify({ error: 'Error al marcar primer_login: ' + errUpdate.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Exito: devolver la contrasena temporal para mostrarla al admin
    return new Response(JSON.stringify({ success: true, temporal }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})