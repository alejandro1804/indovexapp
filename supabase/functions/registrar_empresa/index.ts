import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function rutUyValido(rut: string): boolean {
  if (!/^[0-9]{12}$/.test(rut)) return false
  const pesos = [4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  let suma = 0
  for (let i = 0; i < 11; i++) {
    suma += parseInt(rut[i]) * pesos[i]
  }
  const resto = suma % 11
  const verificador = (11 - resto) % 11
  return parseInt(rut[11]) === verificador
}

function emailValido(email: string): boolean {
  return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email)
}

// Notifica a soporte que se registró una empresa nueva (pendiente de aprobar).
// Llama a la función central enviar-email; si algo falla, no rompe el registro.
async function notificarSoporte(
  supabaseUrl: string,
  empresaNombre: string,
  adminNombre: string,
  adminEmail: string,
  rut: string | null,
) {
  const internalSecret = Deno.env.get('INTERNAL_FUNCTION_SECRET')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  const html = `
    <div style="max-width:600px;margin:0 auto;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
      <div style="background:#1e3a5f;padding:20px;text-align:center;border-radius:8px 8px 0 0;">
        <h2 style="color:#ffffff;margin:0;">Nueva empresa registrada</h2>
      </div>
      <div style="padding:24px;background:#ffffff;">
        <p style="font-size:16px;">Se registró una empresa nueva que está <strong>pendiente de aprobación</strong>.</p>
        <table style="font-size:15px;border-collapse:collapse;margin-top:12px;">
          <tr><td style="padding:4px 12px 4px 0;color:#555;">Empresa:</td><td><strong>${empresaNombre}</strong></td></tr>
          <tr><td style="padding:4px 12px 4px 0;color:#555;">Administrador:</td><td>${adminNombre}</td></tr>
          <tr><td style="padding:4px 12px 4px 0;color:#555;">Email:</td><td>${adminEmail}</td></tr>
          <tr><td style="padding:4px 12px 4px 0;color:#555;">RUT:</td><td>${rut ?? '(no informado)'}</td></tr>
        </table>
        <p style="font-size:15px;margin-top:20px;">Revisala en el panel de super admin, filtro <strong>"Pendientes"</strong>.</p>
      </div>
    </div>
  `

  const resp = await fetch(`${supabaseUrl}/functions/v1/enviar-email`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${anonKey}`,
      'x-internal-secret': internalSecret,
    },
    body: JSON.stringify({
      to: 'soporte@indovexapp.com',
      toName: 'Soporte IndovexApp',
      subject: `Nueva empresa pendiente: ${empresaNombre}`,
      html,
    }),
  })

  if (!resp.ok) {
    const txt = await resp.text()
    throw new Error(`enviar-email respondió ${resp.status}: ${txt}`)
  }
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
    const {
      empresa_nombre, rut, direccion, telefono, email_contacto,
      admin_nombre, admin_email, admin_password,
    } = body

    if (!empresa_nombre || !admin_nombre || !admin_email || !admin_password) {
      return new Response(JSON.stringify({ error: 'Faltan datos obligatorios' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (admin_password.length < 6) {
      return new Response(JSON.stringify({ error: 'La contrasena debe tener al menos 6 caracteres' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const empresaNombre = empresa_nombre.trim().replace(/\s+/g, ' ')
    const adminNombre = admin_nombre.trim().replace(/\s+/g, ' ')
    const adminEmail = admin_email.trim().toLowerCase()
    const rutNormalizado = rut ? rut.trim().replace(/\s+/g, '') : null
    const direccionNorm = direccion ? direccion.trim().replace(/\s+/g, ' ') : null
    const telefonoNorm = telefono ? telefono.trim().replace(/\s+/g, ' ') : null
    const emailContactoNorm = email_contacto ? email_contacto.trim().toLowerCase() : null

    if (!emailValido(adminEmail)) {
      return new Response(JSON.stringify({ error: 'El email del administrador no tiene un formato válido.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (emailContactoNorm && !emailValido(emailContactoNorm)) {
      return new Response(JSON.stringify({ error: 'El email de contacto no tiene un formato válido.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (rutNormalizado && !rutUyValido(rutNormalizado)) {
      return new Response(JSON.stringify({ error: 'El RUT ingresado no es válido. Verificá los 12 dígitos.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (empresaNombre.length > 100 || adminNombre.length > 100) {
      return new Response(JSON.stringify({ error: 'El nombre no puede superar los 100 caracteres.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (rutNormalizado) {
      const { data: empresaExistente } = await supabaseAdmin
        .from('empresas')
        .select('id')
        .eq('rut', rutNormalizado)
        .maybeSingle()

      if (empresaExistente) {
        return new Response(JSON.stringify({ error: 'Ya existe una empresa registrada con ese RUT.' }), {
          status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    const { data: nuevoAuth, error: errAuth } = await supabaseAdmin.auth.admin.createUser({
      email: adminEmail,
      password: admin_password,
      email_confirm: true,
    })

    if (errAuth || !nuevoAuth.user) {
      const msg = errAuth?.message ?? ''
      if (msg.toLowerCase().includes('already registered') || msg.toLowerCase().includes('already exists')) {
        return new Response(JSON.stringify({
          error: 'Este email ya está registrado. Si ya tenés una cuenta, iniciá sesión en lugar de registrarte.'
        }), {
          status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({ error: msg || 'Error al crear el usuario' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const nuevoUserId = nuevoAuth.user.id

    const { data: nuevaEmpresa, error: errEmpresa } = await supabaseAdmin
      .from('empresas')
      .insert({
        nombre: empresaNombre,
        rut: rutNormalizado,
        direccion: direccionNorm,
        telefono: telefonoNorm,
        email_contacto: emailContactoNorm,
        estado: 'pendiente',
        plan: 'trial',
        trial_vence: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
      })
      .select('id')
      .single()

    if (errEmpresa || !nuevaEmpresa) {
      await supabaseAdmin.auth.admin.deleteUser(nuevoUserId)
      if (errEmpresa?.code === '23505') {
        return new Response(JSON.stringify({ error: 'Ya existe una empresa registrada con ese RUT.' }), {
          status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({ error: 'Error al crear la empresa: ' + (errEmpresa?.message ?? '') }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { error: errUsuario } = await supabaseAdmin
      .from('usuarios')
      .insert({
        id: nuevoUserId,
        empresa_id: nuevaEmpresa.id,
        rol_id: null,
        nombre: adminNombre,
        email: adminEmail,
        estado: 'activo',
        primer_login: false,
      })

    if (errUsuario) {
      await supabaseAdmin.from('empresas').delete().eq('id', nuevaEmpresa.id)
      await supabaseAdmin.auth.admin.deleteUser(nuevoUserId)
      return new Response(JSON.stringify({ error: 'Error al crear el usuario admin: ' + errUsuario.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ── Notificación a soporte vía ZeptoMail (no bloquea el registro si falla) ──
    let notificado = false
    let notifError: string | null = null
    try {
      await notificarSoporte(
        Deno.env.get('SUPABASE_URL')!,
        empresaNombre,
        adminNombre,
        adminEmail,
        rutNormalizado,
      )
      notificado = true
    } catch (e) {
      notifError = String(e)
      console.error('>>> [REGISTRAR-EMPRESA] Error notificando a soporte:', notifError)
    }

    return new Response(JSON.stringify({
      success: true,
      empresa_id: nuevaEmpresa.id,
      soporte_notificado: notificado,
      notif_error: notifError,
    }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})