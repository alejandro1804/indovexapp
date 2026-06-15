import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  try {
    const { repuesto, stock_actual, stock_minimo } = await req.json()

    const SID = Deno.env.get('TWILIO_ACCOUNT_SID')!
    const TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN')!
    const FROM = Deno.env.get('TWILIO_FROM')!
    const TO = Deno.env.get('ADMIN_WHATSAPP_NUMBER')!

    const body = `⚠️ IndovexApp — Stock bajo\nRepuesto: ${repuesto}\nStock actual: ${stock_actual} | Mínimo: ${stock_minimo}`

    const url = `https://api.twilio.com/2010-04-01/Accounts/${SID}/Messages.json`

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + btoa(`${SID}:${TOKEN}`),
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({ From: FROM, To: TO, Body: body })
    })

    const data = await res.json()
    return new Response(JSON.stringify({ ok: res.ok, data }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})