import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body = await req.json()
    const { type, data } = body

    // Solo procesamos eventos de suscripcion
    if (type !== 'subscription_preapproval') {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const suscripcionId = data?.id
    if (!suscripcionId) {
      return new Response(JSON.stringify({ error: 'ID de suscripcion no encontrado' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Consultar MercadoPago para obtener los detalles de la suscripcion
    const mpResponse = await fetch(
      `https://api.mercadopago.com/preapproval/${suscripcionId}`,
      {
        headers: {
          'Authorization': `Bearer ${Deno.env.get('MP_ACCESS_TOKEN')}`,
        }
      }
    )

    const suscripcion = await mpResponse.json()

    if (!mpResponse.ok) {
      return new Response(JSON.stringify({ error: 'Error consultando MercadoPago' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const empresaId = suscripcion.external_reference
    const estado = suscripcion.status // authorized, paused, cancelled

    if (!empresaId) {
      return new Response(JSON.stringify({ error: 'empresa_id no encontrado en suscripcion' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Actualizar la empresa segun el estado de la suscripcion
    if (estado === 'authorized') {
      await supabaseAdmin
        .from('empresas')
        .update({
          plan: suscripcion.reason.includes('anual') ? 'anual' : 'mensual',
          mp_suscripcion_id: suscripcionId,
          estado: 'activa',
        })
        .eq('id', empresaId)
    } else if (estado === 'cancelled') {
      await supabaseAdmin
        .from('empresas')
        .update({
          plan: 'trial',
          mp_suscripcion_id: null,
        })
        .eq('id', empresaId)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})