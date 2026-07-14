import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// --- Envío de email vía ZeptoMail REST API (reemplaza denomailer/SMTP) ---
async function enviarEmailBienvenida(
  emailDestino: string,
  nombreEmpresa: string,
  nombreContacto: string | null,
) {
  const token = Deno.env.get('ZEPTOMAIL_TOKEN')!
  const url = Deno.env.get('ZEPTOMAIL_URL')!
  const from = Deno.env.get('ZEPTOMAIL_FROM')!

  const saludo = nombreContacto ? `Hola <strong>${nombreContacto}</strong>,` : 'Hola,'

  const html = `
    <div style="max-width:600px;margin:0 auto;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
      <div style="background:#1e3a5f;padding:24px;text-align:center;border-radius:8px 8px 0 0;">
        <h1 style="color:#ffffff;margin:0;font-size:32px;">IndovexApp</h1>
      </div>
      <div style="padding:24px;background:#ffffff;">
        <p style="font-size:16px;">${saludo}</p>
        <p style="font-size:16px;">Tu empresa <strong>${nombreEmpresa}</strong> fue aprobada y ya podés comenzar a usar IndovexApp.</p>
        <p style="font-size:16px;">Ingresá con el email y la contraseña que usaste al registrarte en <a href="https://app.indovexapp.com" style="color:#2a6fb0;">app.indovexapp.com</a>.</p>
        <p style="font-size:16px;">Ante cualquier duda, escribinos a <a href="mailto:soporte@indovexapp.com" style="color:#2a6fb0;">soporte@indovexapp.com</a>.</p>
        <div style="background:#1e3a5f;color:#ffffff;padding:16px;border-radius:6px;margin-top:24px;text-align:center;">
          <strong>IndovexApp — Victor Alejandro Rios | Uruguay</strong><br>
          <span style="color:#b8cbe0;">indovexapp.com</span>
        </div>
      </div>
    </div>
  `

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': token,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({
      from: { address: from, name: 'IndovexApp' },
      to: [{ email_address: { address: emailDestino, name: nombreContacto ?? nombreEmpresa } }],
      subject: `Tu empresa ${nombreEmpresa} fue aprobada — IndovexApp`,
      htmlbody: html,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`ZeptoMail respondió ${resp.status}: ${txt}`)
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