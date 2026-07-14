import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Genera una contraseña temporal aleatoria de 10 caracteres.
// Alfabeto sin caracteres ambiguos (0/O, 1/l/I) para evitar errores de tipeo.
function generarTemporal(): string {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  let pass = ''
  const arr = new Uint32Array(10)
  crypto.getRandomValues(arr)
  for (let i = 0; i < 10; i++) {
    pass += chars[arr[i] % chars.length]
  }
  return pass
}

// Envía las credenciales al usuario nuevo vía la función central enviar-email.
async function enviarCredenciales(
  supabaseUrl: string,
  emailDestino: string,
  nombreUsuario: string,
  nombreEmpresa: string,
  temporal: string,
) {
  const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  const html = `
    <div style="max-width:600px;margin:0 auto;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
      <div style="background:#1e3a5f;padding:24px;text-align:center;border-radius:8px 8px 0 0;">
        <h1 style="color:#ffffff;margin:0;font-size:32px;">IndovexApp</h1>
      </div>
      <div style="padding:24px;background:#ffffff;">
        <p style="font-size:16px;">Hola <strong>${nombreUsuario}</strong>,</p>
        <p style="font-size:16px;">Se creó tu cuenta en IndovexApp para <strong>${nombreEmpresa}</strong>.</p>
        <p style="font-size:16px;">Ingresá en <a href="https://app.indovexapp.com" style="color:#2a6fb0;">app.indovexapp.com</a> con estos datos:</p>
        <table style="font-size:15px;border-collapse:collapse;margin:16px 0;background:#f4f7fa;border-radius:6px;">
          <tr><td style="padding:10px 16px;color:#555;">Usuario:</td><td style="padding:10px 16px;"><strong>${emailDestino}</strong></td></tr>
          <tr><td style="padding:10px 16px;color:#555;">Contraseña temporal:</td><td style="padding:10px 16px;"><strong style="font-family:monospace;font-size:17px;letter-spacing:1px;">${temporal}</strong></td></tr>
        </table>
        <p style="font-size:15px;background:#fff4e5;padding:12px;border-radius:6px;border-left:4px solid #e69500;">
          Por seguridad, el sistema te va a pedir que cambies esta contraseña la primera vez que ingreses.
          No la compartas con nadie.
        </p>
        <p style="font-size:16px;">Ante cualquier duda, escribinos a <a href="mailto:soporte@indovexapp.com" style="color:#2a6fb0;">soporte@indovexapp.com</a>.</p>
        <div style="background:#1e3a5f;color:#ffffff;padding:16px;border-radius:6px;margin-top:24px;text-align:center;">
          <strong>IndovexApp — Victor Alejandro Rios | Uruguay</strong><br>
          <span style="color:#b8cbe0;">indovexapp.com</span>
        </div>
      </div>
    </div>
  `

  const resp = await fetch(`${supabaseUrl}/functions/v1/enviar-email`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${anonKey}`,
      'x-internal-secret': internalSecret,
    },
    body: JSON.stringify({
      to: emailDestino,
      toName: nombreUsuario,
      subject: `Tu acceso a IndovexApp — ${nombreEmpresa}`,
      html,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`enviar-email respondió ${resp.status}: ${txt}`)
  }
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
    //    NOTA: ya NO se recibe 'password'. La contraseña temporal la genera
    //    el sistema y se envía por email directamente al usuario nuevo.
    const { email: emailRaw, nombre, rol_id } = await req.json()
    const email = (emailRaw ?? '').trim().toLowerCase()
    if (!email || !nombre || !rol_id) {
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

    // 4.2 Generar la contraseña temporal (el admin nunca la ve)
    const temporal = generarTemporal()

    // 5. Crear el usuario en Auth (sin tocar la sesión del admin)
    const { data: nuevoAuth, error: errAuth } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: temporal,
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

    // 8. Enviar las credenciales por email al usuario nuevo.
    //    Si el email falla, el usuario YA quedó creado: no se revierte.
    //    El admin puede usar "Resetear contraseña" como vía de escape.
    let emailEnviado = false
    let emailError: string | null = null
    try {
      const { data: empresa } = await supabaseAdmin
        .from('empresas')
        .select('nombre')
        .eq('id', perfilCaller.empresa_id)
        .single()

      await enviarCredenciales(
        Deno.env.get('SUPABASE_URL')!,
        email,
        nombreNormalizado,
        empresa?.nombre ?? 'tu empresa',
        temporal,
      )
      emailEnviado = true
    } catch (e) {
      emailError = String(e)
      console.error('>>> [CREAR-USUARIO] Error enviando credenciales:', emailError)
    }

    // Éxito. NOTA: la contraseña temporal NO se devuelve al admin a propósito.
    // Si el email no llegó, el admin usa "Resetear contraseña" para obtener una
    // nueva y comunicarla por otro medio.
    return new Response(JSON.stringify({
      success: true,
      user_id: nuevoAuth.user.id,
      email_enviado: emailEnviado,
      email_error: emailError,
    }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})