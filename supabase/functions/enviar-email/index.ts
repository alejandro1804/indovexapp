// supabase/functions/enviar-email/index.ts
//
// Función central de envío de emails vía ZeptoMail REST API.
// Todas las demás funciones que necesiten mandar mail llaman a esta,
// en vez de repetir el bloque de ZeptoMail (URL, token, fetch).
//
// Ventaja: la URL correcta (/v1.1/email), el formato del payload y el
// manejo del token viven en UN SOLO lugar. Si algo cambia, se toca acá.
//
// Se despliega con --no-verify-jwt (se invoca server-to-server desde otras
// Edge Functions), pero se protege con un secreto interno compartido:
// solo quien envíe el header x-internal-secret correcto puede usarla.
//
//   supabase functions deploy enviar-email --no-verify-jwt

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-internal-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface EmailRequest {
  to: string            // destinatario (obligatorio)
  subject: string       // asunto (obligatorio)
  html: string          // cuerpo HTML (obligatorio)
  toName?: string       // nombre del destinatario (opcional)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Validar el secreto interno (candado para que no la llame cualquiera)
    const secretoRecibido = req.headers.get('x-internal-secret')
    const secretoEsperado = Deno.env.get('INTERNAL_FUNCTION_SECRET')
    if (!secretoEsperado || secretoRecibido !== secretoEsperado) {
      return new Response(JSON.stringify({ error: 'No autorizado' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 2. Leer y validar el cuerpo
    const { to, subject, html, toName } = await req.json() as EmailRequest
    if (!to || !subject || !html) {
      return new Response(JSON.stringify({ error: 'Faltan campos: to, subject, html' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 3. Config de ZeptoMail (un solo lugar en todo el sistema)
    const token = Deno.env.get('ZEPTOMAIL_TOKEN')!
    const url = Deno.env.get('ZEPTOMAIL_URL')!   // https://api.zeptomail.com/v1.1/email
    const from = Deno.env.get('ZEPTOMAIL_FROM')! // soporte@indovexapp.com

    // 4. Enviar vía REST API
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        from: { address: from, name: 'IndovexApp' },
        to: [{ email_address: { address: to, name: toName ?? to } }],
        subject,
        htmlbody: html,
      }),
    })

    if (!resp.ok) {
      const txt = await resp.text()
      console.error('>>> [ENVIAR-EMAIL] ZeptoMail error:', resp.status, txt)
      return new Response(JSON.stringify({ error: `ZeptoMail respondió ${resp.status}: ${txt}` }), {
        status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    console.error('>>> [ENVIAR-EMAIL] Excepción:', String(e))
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})