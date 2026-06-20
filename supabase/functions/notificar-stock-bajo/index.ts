import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  try {
    const { repuesto, stock_actual, stock_minimo, empresa_id } = await req.json()

    if (!empresa_id) {
      return new Response(
        JSON.stringify({ ok: false, error: 'empresa_id faltante en el payload' }),
        { status: 400 }
      )
    }

    const SID = Deno.env.get('TWILIO_ACCOUNT_SID')!
    const TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN')!
    const FROM = Deno.env.get('TWILIO_FROM')!
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // 1. Buscar destinatarios activos de esta empresa
    const destRes = await fetch(
      `${SUPABASE_URL}/rest/v1/whatsapp_destinatarios?empresa_id=eq.${empresa_id}&activo=eq.true&select=numero_whatsapp,nombre_referencia`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
      }
    )

    if (!destRes.ok) {
      const errText = await destRes.text()
      return new Response(
        JSON.stringify({ ok: false, error: 'Error consultando destinatarios', detail: errText }),
        { status: 500 }
      )
    }

    const destinatarios: { numero_whatsapp: string; nombre_referencia: string | null }[] =
      await destRes.json()

    if (destinatarios.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, info: 'No hay destinatarios activos configurados para esta empresa' }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    const mensaje = `⚠️ Stock bajo: ${repuesto}. Actual: ${stock_actual} | Mínimo: ${stock_minimo}`

    // 2. Enviar el mensaje a cada destinatario en paralelo
    const resultados = await Promise.all(
      destinatarios.map(async (d) => {
        const res = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${SID}/Messages.json`,
          {
            method: 'POST',
            headers: {
              Authorization: 'Basic ' + btoa(`${SID}:${TOKEN}`),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
              From: FROM,
              To: `whatsapp:${d.numero_whatsapp}`,
              Body: mensaje,
            }),
          }
        )
        return {
          destinatario: d.numero_whatsapp,
          referencia: d.nombre_referencia,
          ok: res.ok,
          status: res.status,
        }
      })
    )

    return new Response(JSON.stringify({ ok: true, enviados: resultados }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500 })
  }
})