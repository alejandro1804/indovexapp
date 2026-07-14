Deno.serve(async (req) => {
  try {
    const { repuesto, stock_actual, stock_minimo, empresa_id } = await req.json()

    if (!empresa_id) {
      return new Response(
        JSON.stringify({ ok: false, error: 'empresa_id faltante en el payload' }),
        { status: 400 }
      )
    }

    // Credenciales Meta WhatsApp Cloud API
    const META_TOKEN = Deno.env.get('META_WHATSAPP_TOKEN')!
    const PHONE_NUMBER_ID = Deno.env.get('META_PHONE_NUMBER_ID')!
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Nombre e idioma de la plantilla aprobada en Meta
    const TEMPLATE_NAME = 'alerta_stock_bajo'
    const TEMPLATE_LANG = 'es_UY' // coincide con "Spanish (URY)"

    // 1. Buscar destinatarios activos de esta empresa con su teléfono vía join.
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
          destinatarios_brutos: filasRaw.length,
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Normaliza el teléfono a formato Meta: solo dígitos, sin "+", sin espacios ni "whatsapp:"
    const normalizarTelefono = (tel: string): string =>
      tel.replace(/[^\d]/g, '')

    // 3. Enviar la plantilla a cada destinatario en paralelo
    const resultados = await Promise.all(
      filas.map(async (f) => {
        const telefono = normalizarTelefono(f.usuarios.telefono!)

        const res = await fetch(
          `https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${META_TOKEN}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              messaging_product: 'whatsapp',
              to: telefono,
              type: 'template',
              template: {
                name: TEMPLATE_NAME,
                language: { code: TEMPLATE_LANG },
                components: [
                  {
                    type: 'body',
                    parameters: [
                      { type: 'text', text: String(repuesto) },       // {{1}}
                      { type: 'text', text: String(stock_actual) },   // {{2}}
                      { type: 'text', text: String(stock_minimo) },   // {{3}}
                    ],
                  },
                ],
              },
            }),
          }
        )

        const bodyResp = await res.json().catch(() => null)

        return {
          usuario: f.usuarios.nombre,
          telefono: f.usuarios.telefono,
          ok: res.ok,
          status: res.status,
          meta: res.ok
            ? bodyResp?.messages?.[0]?.id ?? null
            : bodyResp?.error ?? null,
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