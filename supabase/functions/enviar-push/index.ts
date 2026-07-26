// supabase/functions/enviar-push/index.ts  (v2 con logs de diagnóstico)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function log(...args: unknown[]) {
  console.log('[enviar-push]', ...args)
}

let serviceAccount: any = null
try {
  serviceAccount = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!)
  log('service account parseada, project:', serviceAccount.project_id)
} catch (e) {
  log('ERROR parseando FCM_SERVICE_ACCOUNT:', String(e))
}

// Normaliza la private key: convierte "\n" literales en saltos reales.
function normalizePrivateKey(pk: string): string {
  return pk.includes('\\n') ? pk.replace(/\\n/g, '\n') : pk
}

async function getAccessToken(): Promise<string> {
  log('getAccessToken: inicio')
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const unsigned = `${enc(header)}.${enc(claim)}`

  const pkRaw = normalizePrivateKey(serviceAccount.private_key)
  const pem = pkRaw
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  log('private key preparada, largo base64:', pem.length)

  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))
  log('importando key...')
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  log('key importada, firmando JWT...')
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const jwt = `${unsigned}.${sigB64}`
  log('JWT firmado, pidiendo access_token a Google...')

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const data = await resp.json()
  if (!data.access_token) {
    log('ERROR: sin access_token, respuesta Google:', JSON.stringify(data))
    throw new Error('No access_token: ' + JSON.stringify(data))
  }
  log('access_token obtenido OK')
  return data.access_token
}

async function enviarAToken(
  accessToken: string, token: string, titulo: string, cuerpo: string, ticketId: string | null,
): Promise<{ ok: boolean; invalido: boolean }> {
  const projectId = serviceAccount.project_id
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const mensaje = {
    message: {
      token,
      notification: { title: titulo, body: cuerpo },
      data: ticketId ? { ticket_id: ticketId } : {},
      android: { priority: 'high', notification: { sound: 'default' } },
    },
  }
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(mensaje),
  })
  if (resp.ok) { log('FCM enviado OK a token ...' + token.slice(-8)); return { ok: true, invalido: false } }
  const err = await resp.text()
  const invalido = resp.status === 404 || err.includes('UNREGISTERED') || err.includes('INVALID_ARGUMENT')
  log(`FCM error (${resp.status}): ${err}`)
  return { ok: false, invalido }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    log('invocación recibida')
    const payload = await req.json()
    const notif = payload.record ?? payload
    const paraUsuarioId = notif.para_usuario_id
    const cuerpo = notif.mensaje ?? ''
    const ticketId = notif.ticket_id ?? null
    log('destinatario:', paraUsuarioId, 'mensaje:', cuerpo)

    if (!paraUsuarioId || !cuerpo) {
      log('skip: sin destinatario o mensaje')
      return new Response(JSON.stringify({ skip: true }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const { data: dispositivos, error } = await supabase
      .from('dispositivos').select('token').eq('usuario_id', paraUsuarioId)
    if (error) log('error consultando dispositivos:', JSON.stringify(error))
    log('dispositivos encontrados:', dispositivos?.length ?? 0)

    if (!dispositivos || dispositivos.length === 0) {
      return new Response(JSON.stringify({ skip: 'sin dispositivos' }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const accessToken = await getAccessToken()
    let enviados = 0
    const invalidos: string[] = []
    for (const d of dispositivos) {
      const r = await enviarAToken(accessToken, d.token, 'IndovexApp', cuerpo, ticketId)
      if (r.ok) enviados++
      if (r.invalido) invalidos.push(d.token)
    }
    if (invalidos.length > 0) {
      await supabase.from('dispositivos').delete().in('token', invalidos)
    }
    log('resultado: enviados', enviados, 'invalidos', invalidos.length)
    return new Response(JSON.stringify({ enviados, invalidos: invalidos.length }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    log('EXCEPCIÓN:', String(e))
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})