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
    // Esta funcion es PUBLICA: no requiere estar logueado (es auto-registro)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 1. Leer los datos del formulario
    const body = await req.json()
    const {
      empresa_nombre, rut, direccion, telefono, email_contacto,
      admin_nombre, admin_email, admin_password,
    } = body

    // 2. Validar datos obligatorios
    if (!empresa_nombre || !admin_nombre || !admin_email || !admin_password) {
      return new Response(JSON.stringify({ error: 'Faltan datos obligatorios' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (admin_password.length < 6) {
      return new Response(JSON.stringify({ error: 'La contrasena debe tener al menos 6 caracteres' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 3. Crear el usuario admin en Auth
    const { data: nuevoAuth, error: errAuth } = await supabaseAdmin.auth.admin.createUser({
      email: admin_email,
      password: admin_password,
      email_confirm: true,
    })

    if (errAuth || !nuevoAuth.user) {
      return new Response(JSON.stringify({ error: errAuth?.message ?? 'Error al crear el usuario' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const nuevoUserId = nuevoAuth.user.id

    // 4. Crear la empresa en estado pendiente
    const { data: nuevaEmpresa, error: errEmpresa } = await supabaseAdmin
      .from('empresas')
      .insert({
        nombre: empresa_nombre,
        rut: rut ?? null,
        direccion: direccion ?? null,
        telefono: telefono ?? null,
        email_contacto: email_contacto ?? null,
        estado: 'pendiente',
      })
      .select('id')
      .single()

    // Si falla crear la empresa, borrar el usuario de Auth
    if (errEmpresa || !nuevaEmpresa) {
      await supabaseAdmin.auth.admin.deleteUser(nuevoUserId)
      return new Response(JSON.stringify({ error: 'Error al crear la empresa: ' + (errEmpresa?.message ?? '') }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 5. Crear el usuario en la tabla usuarios, SIN rol (rol_id null hasta aprobar)
    const { error: errUsuario } = await supabaseAdmin
      .from('usuarios')
      .insert({
        id: nuevoUserId,
        empresa_id: nuevaEmpresa.id,
        rol_id: null,
        nombre: admin_nombre,
        email: admin_email,
        estado: 'activo',
        primer_login: false,
      })

    // Si falla, deshacer todo: borrar empresa y usuario de Auth
    if (errUsuario) {
      await supabaseAdmin.from('empresas').delete().eq('id', nuevaEmpresa.id)
      await supabaseAdmin.auth.admin.deleteUser(nuevoUserId)
      return new Response(JSON.stringify({ error: 'Error al crear el usuario admin: ' + errUsuario.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Exito
    return new Response(JSON.stringify({ success: true, empresa_id: nuevaEmpresa.id }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})