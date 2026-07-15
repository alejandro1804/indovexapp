import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Envía el email de bienvenida llamando a la función central enviar-email.
// Solo arma el CONTENIDO: el marco (viewport responsive, header, firma) lo
// pone enviar-email, que es la dueña del layout.
async function enviarEmailBienvenida(
  supabaseUrl: string,
  emailDestino: string,
  nombreEmpresa: string,
  nombreContacto: string | null,
) {
  const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  const saludo = nombreContacto ? `Hola <strong>${nombreContacto}</strong>,` : 'Hola,'

  const contenido = `
    <p>${saludo}</p>
    <p>Tu empresa <strong>${nombreEmpresa}</strong> fue aprobada y ya podés comenzar a usar IndovexApp.</p>
    <p>Ingresá con el email y la contraseña que usaste al registrarte en <a href="https://app.indovexapp.com">app.indovexapp.com</a>.</p>
    <p>Ante cualquier duda, escribinos a <a href="mailto:soporte@indovexapp.com">soporte@indovexapp.com</a>.</p>
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
      toName: nombreContacto ?? nombreEmpresa,
      subject: `Tu empresa ${nombreEmpresa} fue aprobada — IndovexApp`,
      contenido,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`enviar-email respondió ${resp.status}: ${txt}`)
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')!
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const body = await req.json()
    const { empresa_id } = body

    if (!empresa_id) {
      return new Response(JSON.stringify({ error: 'Falta empresa_id' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Ejecutar el RPC con el JWT del super admin (valida permisos correctamente)
    const { error: errRpc } = await supabaseUser.rpc('aprobar_empresa', {
      p_empresa_id: empresa_id
    })

    if (errRpc) {
      return new Response(JSON.stringify({ error: 'Error al aprobar empresa: ' + errRpc.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // --- Envío del email de bienvenida (no bloquea la aprobación si falla) ---
    let emailEnviado = false
    let emailError: string | null = null
    try {
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      )

      // Datos de la empresa
      const { data: empresa } = await supabaseAdmin
        .from('empresas')
        .select('nombre, email_contacto')
        .eq('id', empresa_id)
        .single()

      // Usuario admin de la empresa: su email es el destinatario real,
      // y su nombre se usa para el saludo.
      const { data: admin } = await supabaseAdmin
        .from('usuarios')
        .select('nombre, email, roles!inner(nombre)')
        .eq('empresa_id', empresa_id)
        .eq('roles.nombre', 'admin')
        .maybeSingle()

      // Destinatario: email del admin; si no, el email_contacto como fallback.
      const emailDestino = (admin as any)?.email ?? empresa?.email_contacto ?? null

      if (emailDestino) {
        await enviarEmailBienvenida(
          Deno.env.get('SUPABASE_URL')!,
          emailDestino,
          empresa?.nombre ?? 'tu empresa',
          (admin as any)?.nombre ?? null,
        )
        emailEnviado = true
      } else {
        emailError = 'No se encontró email del admin ni email_contacto'
      }
    } catch (e) {
      // El email falló pero la empresa YA quedó aprobada. No revertimos.
      emailError = String(e)
      console.error('>>> [APROBAR-EMPRESA] Error enviando email:', emailError)
    }

    return new Response(JSON.stringify({ success: true, email_enviado: emailEnviado, email_error: emailError }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})