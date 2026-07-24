// supabase/functions/recuperar-password/index.ts
//
// Recuperación de contraseña iniciada por el propio usuario ("olvidé mi
// contraseña"). Reemplaza a resetPasswordForEmail de Supabase Auth, cuyo
// mail sale con el remitente y el diseño por defecto de Supabase.
//
// Sigue el mismo modelo que resetear_password (el que usa el admin):
// genera una contraseña temporal, la setea en Auth y marca primer_login,
// de modo que la app obliga a cambiarla al ingresar. La diferencia es que
// acá la temporal NO se devuelve en la respuesta: viaja solo por email,
// porque quien llama no está autenticado.
//
// Se despliega SIN verificación de JWT (el usuario que olvidó la clave no
// tiene sesión):
//
//   supabase functions deploy recuperar-password --no-verify-jwt
//
// SEGURIDAD
//  - Respuesta constante: siempre { success: true } con el mismo mensaje,
//    exista el email o no. No revela qué cuentas están registradas.
//  - Rate limit por email (tabla intentos_recuperacion): evita que alguien
//    le rompa el acceso a un usuario disparando resets en loop.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Máximo de recuperaciones por email en la ventana de tiempo.
const MAX_INTENTOS = 3
const VENTANA_HORAS = 1

// Mismo alfabeto que crear_usuario y resetear_password: sin caracteres
// ambiguos (0/O, 1/l/I) para evitar errores de tipeo al copiar del mail.
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

// Envía la contraseña temporal vía la función central enviar-email.
// Solo arma el CONTENIDO; el marco responsive lo pone enviar-email.
// Las clases (ix-datos, ix-label, ix-mono, ix-aviso) están definidas allá.
async function enviarTemporal(
  supabaseUrl: string,
  emailDestino: string,
  nombreUsuario: string,
  temporal: string,
) {
  const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  const contenido = `
    <p>Hola <strong>${nombreUsuario}</strong>,</p>
    <p>Recibimos un pedido para restablecer la contraseña de tu cuenta en IndovexApp.</p>
    <p>Ingresá en <a href="https://app.indovexapp.com">app.indovexapp.com</a> con esta contraseña temporal:</p>
    <table class="ix-datos">
      <tr><td class="ix-label">Usuario:</td><td><strong>${emailDestino}</strong></td></tr>
      <tr><td class="ix-label">Contraseña temporal:</td><td><strong class="ix-mono">${temporal}</strong></td></tr>
    </table>
    <div class="ix-aviso">
      Por seguridad, el sistema te va a pedir que definas una contraseña nueva apenas ingreses.
      No compartas esta contraseña con nadie.
    </div>
    <p>Si vos no pediste este cambio, escribinos cuanto antes a
       <a href="mailto:soporte@indovexapp.com">soporte@indovexapp.com</a>.</p>
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
      subject: 'Recuperación de contraseña — IndovexApp',
      contenido,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`enviar-email respondió ${resp.status}: ${txt}`)
  }
}

// Respuesta única para todos los caminos: email inexistente, usuario
// inactivo, rate limit superado o éxito real. Que sea siempre igual es
// justamente el punto: desde afuera no se puede distinguir el caso.
function respuestaGenerica() {
  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email: emailRaw } = await req.json()
    const email = (emailRaw ?? '').trim().toLowerCase()

    // Validación mínima de formato. No es un chequeo de existencia.
    if (!email || !email.includes('@')) {
      return new Response(JSON.stringify({ error: 'Email inválido' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // El cliente admin debe operar SOLO con el service role. Si la llamada
    // llega desde la app con un JWT de sesión (vencido o de otro usuario),
    // el SDK podría tomarlo del contexto y fallar con "invalid JWT" al
    // operar sobre Auth. Por eso se fuerza el header y se desactiva toda
    // persistencia de sesión.
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUrl: false,
        },
        global: {
          headers: { Authorization: `Bearer ${serviceRoleKey}` },
        },
      },
    )

    // 1. Rate limit ANTES de cualquier otra cosa.
    const desde = new Date(Date.now() - VENTANA_HORAS * 60 * 60 * 1000).toISOString()
    const { count } = await supabaseAdmin
      .from('intentos_recuperacion')
      .select('id', { count: 'exact', head: true })
      .eq('email', email)
      .gte('created_at', desde)

    if ((count ?? 0) >= MAX_INTENTOS) {
      console.warn(`>>> [RECUPERAR-PASSWORD] Rate limit para ${email}`)
      return respuestaGenerica()
    }

    // Registrar el intento (aunque después no exista el usuario: si no,
    // el contador no serviría para frenar el sondeo de emails).
    await supabaseAdmin.from('intentos_recuperacion').insert({ email })

    // 2. Buscar el usuario. Si no existe o está inactivo, cortamos acá
    //    sin avisar nada: la respuesta es la misma que si hubiera salido bien.
    const { data: usuario } = await supabaseAdmin
      .from('usuarios')
      .select('id, nombre, estado')
      .eq('email', email)
      .maybeSingle()

    if (!usuario || usuario.estado !== 'activo') {
      return respuestaGenerica()
    }

    // 3. Generar y aplicar la contraseña temporal.
    const temporal = generarTemporal()

    const { error: errAuth } = await supabaseAdmin.auth.admin.updateUserById(
      usuario.id,
      { password: temporal },
    )
    if (errAuth) {
      console.error('>>> [RECUPERAR-PASSWORD] Error en Auth:', errAuth.message)
      return respuestaGenerica()
    }

    // 4. Forzar el cambio de contraseña en el próximo ingreso.
    await supabaseAdmin
      .from('usuarios')
      .update({ primer_login: true })
      .eq('id', usuario.id)

    // 5. Enviar la temporal por email. Si falla el envío, el usuario ya
    //    quedó con la contraseña cambiada: queda el reset del admin como
    //    vía de escape (igual que en crear_usuario).
    try {
      await enviarTemporal(
        Deno.env.get('SUPABASE_URL')!,
        email,
        usuario.nombre,
        temporal,
      )
    } catch (e) {
      console.error('>>> [RECUPERAR-PASSWORD] Error enviando email:', String(e))
    }

    return respuestaGenerica()

  } catch (e) {
    console.error('>>> [RECUPERAR-PASSWORD] Excepción:', String(e))
    // Incluso ante un error interno devolvemos lo mismo, para no dar
    // señales distintas según el caso.
    return respuestaGenerica()
  }
})