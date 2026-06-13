import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Manejo de CORS (necesario para que la app web pueda llamar)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Cliente con el token del usuario que llama (para verificar quién es)
    const authHeader = req.headers.get('Authorization')!
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    // Obtener el usuario que está haciendo la llamada
    const { data: { user: caller } } = await supabaseUser.auth.getUser()
    if (!caller) {
      return new Response(JSON.stringify({ error: 'No autenticado' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 2. Cliente con service role (permisos de servidor, se saltea RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 3. Verificar que el que llama es admin o super admin de su empresa
    const { data: perfilCaller, error: errPerfil } = await supabaseAdmin
      .from('usuarios')
      .select('empresa_id, es_super_admin, roles(nombre)')
      .eq('id', caller.id)
      .single()

    if (errPerfil || !perfilCaller) {
      return new Response(JSON.stringify({ error: 'No se encontró tu perfil' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const esAdmin = perfilCaller.es_super_admin === true ||
                    (perfilCaller.roles as any)?.nombre === 'admin'

    if (!esAdmin) {
      return new Response(JSON.stringify({ error: 'No tenés permisos para crear usuarios' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 4. Leer los datos del nuevo usuario
    const { email: emailRaw, password, nombre, rol_id } = await req.json()
    const email = (emailRaw ?? '').trim().toLowerCase()
    if (!email || !password || !nombre || !rol_id) {
      return new Response(JSON.stringify({ error: 'Faltan datos obligatorios' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 4.1 Validar duplicado de nombre ANTES de crear el usuario en Auth
    // (evita crear un usuario huérfano en Auth si el nombre ya existe)
    const nombreNormalizado = nombre.trim().replace(/\s+/g, ' ')
    const { data: existente } = await supabaseAdmin
      .from('usuarios')
      .select('id')
      .eq('empresa_id', perfilCaller.empresa_id)
      .ilike('nombre', nombreNormalizado)
      .maybeSingle()

    if (existente) {
      return new Response(JSON.stringify({ error: 'Ya existe un usuario con ese nombre en tu empresa. Probá con otro nombre.' }), {
        status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 5. Crear el usuario en Auth (sin tocar la sesión del admin)
    const { data: nuevoAuth, error: errAuth } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })

    if (errAuth || !nuevoAuth.user) {
      const msg = errAuth?.message ?? ''
      if (msg.toLowerCase().includes('already registered') || msg.toLowerCase().includes('already exists')) {
        return new Response(JSON.stringify({
          error: 'Este email ya está registrado en el sistema (posiblemente en otra empresa). ' +
                 'Si es la misma persona trabajando para otra empresa, usá una variante del email (ej. nombre+empresa@dominio.com).'
        }), {
          status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({ error: msg || 'Error al crear en Auth' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 6. Insertar en la tabla usuarios (con la empresa del admin que llama)
    const { error: errInsert } = await supabaseAdmin
      .from('usuarios')
      .insert({
        id: nuevoAuth.user.id,
        empresa_id: perfilCaller.empresa_id,
        rol_id,
        nombre: nombreNormalizado,
        email,
        estado: 'activo',
        primer_login: true,
      })

    // 7. Si falla el insert, borrar el usuario de Auth para no dejar huérfanos
    if (errInsert) {
      await supabaseAdmin.auth.admin.deleteUser(nuevoAuth.user.id)
      if (errInsert.code === '23505') {
        return new Response(JSON.stringify({ error: 'Ya existe un usuario con ese nombre o email en tu empresa.' }), {
          status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({ error: 'Error al guardar el perfil: ' + errInsert.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Éxito
    return new Response(JSON.stringify({ success: true, user_id: nuevoAuth.user.id }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})