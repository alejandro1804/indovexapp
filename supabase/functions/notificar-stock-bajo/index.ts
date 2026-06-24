Deno.serve(async (req) => {
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

    // 1. Buscar destinatarios activos de esta empresa con su teléfono vía join.
    //    NO filtramos el teléfono en la URL: el filtro sobre una columna embebida
    //    (usuarios.telefono) tiene comportamiento inconsistente en PostgREST.
    //    En su lugar traemos todo y filtramos en código, que es predecible.
    const destRes = await fetch(
      `${SUPABASE_URL}/rest/v1/whatsapp_destinatarios` +
        `?empresa_id=eq.${empresa_id}` +
        `&activo=eq.true` +
        `&select=usuario_id,usuarios!inner(nombre,telefono,estado)`,
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

    type DestinatarioRow = {
      usuario_id: string
      usuarios: { nombre: string; telefono: string | null; estado: string | null }
    }
    const filasRaw: DestinatarioRow[] = await destRes.json()

    // 2. Filtrar en código: solo usuarios activos con teléfono no vacío.
    const filas = filasRaw.filter(
      (f) =>
        f.usuarios &&
        f.usuarios.telefono != null &&
        f.usuarios.telefono.trim() !== '' &&
        (f.usuarios.estado == null || f.usuarios.estado === 'activo')
    )

    if (filas.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          info: 'No hay destinatarios activos con teléfono configurado para esta empresa',
          // Diagnóstico: cuántas filas vinieron antes de filtrar
          destinatarios_brutos: filasRaw.length,
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    const mensaje = `⚠️ Stock bajo: ${repuesto}. Actual: ${stock_actual} | Mínimo: ${stock_minimo}`

    // 3. Enviar el mensaje a cada destinatario en paralelo
    const resultados = await Promise.all(
      filas.map(async (f) => {
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
              To: `whatsapp:${f.usuarios.telefono!.trim()}`,
              Body: mensaje,
            }),
          }
        )
        return {
          usuario: f.usuarios.nombre,
          telefono: f.usuarios.telefono,
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