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
    // Cliente con JWT del super admin para ejecutar el RPC (que valida permisos)
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

    // Nota: el email de bienvenida se enviará manualmente por ahora.
    // El envío automático queda pendiente de migrar a ZeptoMail API REST
    // (el SMTP de Zoho vía denomailer agota los recursos del worker).
    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})