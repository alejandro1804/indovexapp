// supabase/functions/enviar-email/index.ts
//
// Función central de envío de emails vía ZeptoMail REST API.
// Además del envío, es DUEÑA DEL LAYOUT: las funciones que la llaman mandan
// solo el contenido (los párrafos), y acá se le pone el marco completo
// (viewport responsive, header azul, firma). Así el diseño vive en un solo
// lugar y se corrige una vez para todos los emails.
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
  to: string             // destinatario (obligatorio)
  subject: string        // asunto (obligatorio)
  contenido?: string     // HTML del cuerpo (sin marco). Se le aplica el layout.
  html?: string          // HTML completo, sin layout. Escape para casos especiales.
  toName?: string        // nombre del destinatario (opcional)
  titulo?: string        // título del header. Por defecto 'IndovexApp'.
}

// Marco responsive común a todos los emails.
// Claves de la adaptación a pantalla:
//  - meta viewport: evita que el cliente móvil haga zoom-out sobre 600px fijos
//  - width:100% + max-width: el contenedor se encoge en pantallas angostas
//  - media query: baja tamaños y padding por debajo de 600px
//  - font-size en px con line-height holgado: legible sin zoom
function armarLayout(contenido: string, titulo: string): string {
  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${titulo}</title>
<style>
  body { margin:0; padding:0; width:100% !important; background:#f4f6f8; }
  .ix-wrap { width:100%; max-width:600px; margin:0 auto; }
  .ix-header { background:#1e3a5f; padding:24px 16px; text-align:center; border-radius:8px 8px 0 0; }
  .ix-header h1 { color:#ffffff; margin:0; font-size:30px; line-height:1.2; }
  .ix-body { padding:24px; background:#ffffff; }
  .ix-body p { font-size:16px; line-height:1.55; margin:0 0 14px 0; }
  .ix-body a { color:#2a6fb0; word-break:break-word; }
  .ix-datos { width:100%; border-collapse:collapse; background:#f4f7fa; border-radius:6px; margin:16px 0; }
  .ix-datos td { padding:10px 14px; font-size:15px; line-height:1.5; vertical-align:top; }
  .ix-datos .ix-label { color:#555555; white-space:nowrap; }
  .ix-aviso { font-size:15px; line-height:1.5; background:#fff4e5; padding:12px; border-radius:6px; border-left:4px solid #e69500; margin:16px 0; }
  .ix-mono { font-family:'Courier New',Courier,monospace; font-size:17px; letter-spacing:1px; word-break:break-all; }
  .ix-firma { background:#1e3a5f; color:#ffffff; padding:16px; border-radius:6px; margin-top:24px; text-align:center; font-size:14px; line-height:1.5; }
  .ix-firma span { color:#b8cbe0; }
  @media only screen and (max-width:600px) {
    .ix-header { padding:18px 12px; }
    .ix-header h1 { font-size:24px; }
    .ix-body { padding:16px; }
    .ix-body p { font-size:15px; }
    .ix-datos td { padding:8px 10px; font-size:14px; display:block; }
    .ix-datos .ix-label { padding-bottom:0; }
    .ix-mono { font-size:16px; }
    .ix-firma { font-size:13px; padding:12px; }
  }
</style>
</head>
<body>
  <div class="ix-wrap">
    <div class="ix-header">
      <h1>${titulo}</h1>
    </div>
    <div class="ix-body">
      ${contenido}
      <div class="ix-firma">
        <strong>IndovexApp — Victor Alejandro Rios | Uruguay</strong><br>
        <span>indovexapp.com</span>
      </div>
    </div>
  </div>
</body>
</html>`
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
    const { to, subject, contenido, html, toName, titulo } = await req.json() as EmailRequest
    if (!to || !subject || (!contenido && !html)) {
      return new Response(JSON.stringify({ error: 'Faltan campos: to, subject, y contenido (o html)' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 3. Armar el HTML final.
    //    - Si viene 'contenido': se le aplica el layout responsive de la casa.
    //    - Si viene 'html': se manda tal cual (escape para casos especiales).
    const htmlFinal = contenido
      ? armarLayout(contenido, titulo ?? 'IndovexApp')
      : html!

    // 4. Config de ZeptoMail (un solo lugar en todo el sistema)
    const token = Deno.env.get('ZEPTOMAIL_TOKEN')!
    const url = Deno.env.get('ZEPTOMAIL_URL')!   // https://api.zeptomail.com/v1.1/email
    const from = Deno.env.get('ZEPTOMAIL_FROM')! // soporte@indovexapp.com

    // 5. Enviar vía REST API
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
        htmlbody: htmlFinal,
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