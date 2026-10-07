import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Mismo formato que exige la base (chk_usuarios_email_formato).
const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/

function responder(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Evita que un nombre con caracteres especiales rompa el HTML del email.
function escaparHtml(texto: string): string {
  return texto
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

// Envia un email via la funcion central enviar-email.
// Solo arma el CONTENIDO; el marco responsive lo pone enviar-email.
async function enviarEmail(
  emailDestino: string,
  nombreDestino: string,
  asunto: string,
  contenido: string,
) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  const resp = await fetch(`${supabaseUrl}/functions/v1/enviar-email`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${anonKey}`,
      'x-internal-secret': internalSecret,
    },
    body: JSON.stringify({
      to: emailDestino,
      toName: nombreDestino,
      subject: asunto,
      contenido,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`enviar-email respondio ${resp.status}: ${txt}`)
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Cliente con el token del que llama (para saber quien es)
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return responder({ error: 'No autenticado' }, 401)
    }

    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: { user: caller } } = await supabaseUser.auth.getUser()
    if (!caller) {
      return responder({ error: 'No autenticado' }, 401)
    }

    // 2. Cliente con service role (se saltea RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 3. Autorizacion: la decide la base, con las mismas funciones que usan
    //    las politicas RLS. Las dos exigen que el usuario este activo.
    const { data: esSuperAdmin, error: errSa } = await supabaseUser.rpc('es_super_admin')
    const { data: puedeGestionar, error: errPermiso } = await supabaseUser.rpc(
      'tiene_permiso',
      { p_codigo: 'gestionar_usuarios' },
    )

    if (errSa || errPermiso) {
      console.error('>>> [CAMBIAR-EMAIL] Error verificando permisos:', errSa ?? errPermiso)
      return responder({ error: 'No se pudieron verificar tus permisos' }, 500)
    }

    const callerEsSuperAdmin = esSuperAdmin === true
    if (!callerEsSuperAdmin && puedeGestionar !== true) {
      return responder({ error: 'No tenés permisos para cambiar el email de un usuario' }, 403)
    }

    // 4. Perfil del que llama (empresa y nombre para auditoria y avisos)
    const { data: perfilCaller, error: errPerfil } = await supabaseAdmin
      .from('usuarios')
      .select('id, empresa_id, nombre')
      .eq('id', caller.id)
      .single()

    if (errPerfil || !perfilCaller) {
      return responder({ error: 'No se encontró tu perfil' }, 403)
    }

    // 5. Datos del pedido
    let body: { usuario_id?: string; email?: string }
    try {
      body = await req.json()
    } catch (_) {
      return responder({ error: 'Pedido inválido' }, 400)
    }

    const usuarioId = (body.usuario_id ?? '').trim()
    const emailNuevo = (body.email ?? '').trim().toLowerCase()

    if (!usuarioId || !emailNuevo) {
      return responder({ error: 'Faltan datos obligatorios' }, 400)
    }
    if (emailNuevo.length > 255 || !EMAIL_REGEX.test(emailNuevo)) {
      return responder({ error: 'El email ingresado no tiene un formato válido' }, 400)
    }

    // 6. Usuario objetivo
    const { data: objetivo, error: errObjetivo } = await supabaseAdmin
      .from('usuarios')
      .select('id, empresa_id, es_super_admin, nombre, email')
      .eq('id', usuarioId)
      .single()

    if (errObjetivo || !objetivo) {
      return responder({ error: 'Usuario no encontrado' }, 404)
    }

    // Un admin solo puede cambiar usuarios de SU empresa
    if (!callerEsSuperAdmin && objetivo.empresa_id !== perfilCaller.empresa_id) {
      return responder({ error: 'No podés cambiar el email de usuarios de otra empresa' }, 403)
    }

    // Nadie (salvo super admin) puede cambiar el email de un super admin
    if (objetivo.es_super_admin === true && !callerEsSuperAdmin) {
      return responder({ error: 'No autorizado' }, 403)
    }

    const emailAnterior = (objetivo.email ?? '').toLowerCase()
    if (emailAnterior === emailNuevo) {
      return responder({ error: 'El email nuevo es igual al actual' }, 400)
    }

    // 7. Cambiar el email en Auth. El trigger trg_sync_email_usuario lo
    //    replica a usuarios.email. La contrasena no se toca.
    const { error: errAuth } = await supabaseAdmin.auth.admin.updateUserById(
      usuarioId,
      { email: emailNuevo, email_confirm: true },
    )

    if (errAuth) {
      const msg = (errAuth.message ?? '').toLowerCase()
      const codigo = ((errAuth as any).code ?? '').toString()
      if (codigo === 'email_exists' || msg.includes('already')) {
        return responder({
          error: 'Ese email ya está registrado en el sistema (posiblemente en otra empresa). Usá otro email.',
        }, 409)
      }
      return responder({ error: 'Error al cambiar el email: ' + errAuth.message }, 400)
    }

    // 8. Confirmar que la copia en usuarios quedo sincronizada
    const { data: verificado } = await supabaseAdmin
      .from('usuarios')
      .select('email')
      .eq('id', usuarioId)
      .single()

    if ((verificado?.email ?? '').toLowerCase() !== emailNuevo) {
      console.error('>>> [CAMBIAR-EMAIL] Auth cambio pero usuarios.email no:', usuarioId)
      return responder({
        error: 'El email de acceso cambió pero el perfil no se actualizó. Avisá a soporte.',
      }, 500)
    }

    // 9. Auditoria con el actor real. El trigger de usuarios registra el
    //    UPDATE sin usuario (lo ejecuta Auth), asi que el "quien" va aca.
    const { error: errAudit } = await supabaseAdmin.from('audit_log').insert({
      tabla: 'usuarios',
      operacion: 'CAMBIO_EMAIL',
      registro_id: usuarioId,
      empresa_id: objetivo.empresa_id,
      usuario_id: caller.id,
      datos_antes: { email: emailAnterior },
      datos_despues: {
        email: emailNuevo,
        evento: 'Cambio de email de usuario',
        cambiado_por: perfilCaller.nombre,
      },
    })
    if (errAudit) {
      console.error('>>> [CAMBIAR-EMAIL] Error registrando auditoria:', errAudit.message)
    }

    // 10. Avisos por email. Si fallan, el cambio YA quedo hecho: no se revierte.
    const { data: empresa } = await supabaseAdmin
      .from('empresas')
      .select('nombre')
      .eq('id', objetivo.empresa_id)
      .single()

    const nombreEmpresa = escaparHtml(empresa?.nombre ?? 'tu empresa')
    const nombreUsuario = escaparHtml(objetivo.nombre ?? '')
    const nombreActor = escaparHtml(perfilCaller.nombre ?? 'un administrador')

    let avisoNuevoEnviado = false
    let avisoAnteriorEnviado = false

    // 10.1 Al email nuevo: con que usuario ingresa desde ahora
    try {
      await enviarEmail(
        emailNuevo,
        objetivo.nombre ?? '',
        `Tu email de acceso a IndovexApp fue actualizado — ${empresa?.nombre ?? ''}`,
        `
          <p>Hola <strong>${nombreUsuario}</strong>,</p>
          <p>El email de tu cuenta de IndovexApp en <strong>${nombreEmpresa}</strong> fue actualizado por <strong>${nombreActor}</strong>.</p>
          <p>Desde ahora ingresás en <a href="https://app.indovexapp.com">app.indovexapp.com</a> con:</p>
          <table class="ix-datos">
            <tr><td class="ix-label">Usuario:</td><td><strong>${emailNuevo}</strong></td></tr>
          </table>
          <div class="ix-aviso">
            Tu contraseña no cambió: seguís usando la misma.
          </div>
          <p>Si no esperabas este cambio, escribinos a <a href="mailto:soporte@indovexapp.com">soporte@indovexapp.com</a>.</p>
        `,
      )
      avisoNuevoEnviado = true
    } catch (e) {
      console.error('>>> [CAMBIAR-EMAIL] Error avisando al email nuevo:', String(e))
    }

    // 10.2 Al email anterior: aviso de seguridad. No incluye el email nuevo
    //      a proposito (si la direccion vieja era de un tercero, no se filtra).
    try {
      await enviarEmail(
        emailAnterior,
        objetivo.nombre ?? '',
        `El email de tu cuenta de IndovexApp fue cambiado — ${empresa?.nombre ?? ''}`,
        `
          <p>Hola <strong>${nombreUsuario}</strong>,</p>
          <p>El email de acceso de tu cuenta de IndovexApp en <strong>${nombreEmpresa}</strong> fue cambiado por <strong>${nombreActor}</strong>.</p>
          <div class="ix-aviso">
            Esta dirección ya no sirve para ingresar a la aplicación.
          </div>
          <p>Si no esperabas este cambio, contactá al administrador de tu empresa o escribinos a <a href="mailto:soporte@indovexapp.com">soporte@indovexapp.com</a>.</p>
        `,
      )
      avisoAnteriorEnviado = true
    } catch (e) {
      console.error('>>> [CAMBIAR-EMAIL] Error avisando al email anterior:', String(e))
    }

    return responder({
      success: true,
      email: emailNuevo,
      aviso_nuevo_enviado: avisoNuevoEnviado,
      aviso_anterior_enviado: avisoAnteriorEnviado,
    })

  } catch (e) {
    return responder({ error: String(e) }, 500)
  }
})