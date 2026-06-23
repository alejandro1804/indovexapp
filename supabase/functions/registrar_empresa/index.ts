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

async function enviarEmailNotificacion(datos: {
  empresa_nombre: string
  rut: string | null
  admin_nombre: string
  admin_email: string
  fecha: string
}) {
  const smtpHost = Deno.env.get('ZOHO_SMTP_HOST')!
  const smtpPort = parseInt(Deno.env.get('ZOHO_SMTP_PORT') ?? '465')
  const smtpUser = Deno.env.get('ZOHO_SMTP_USER')!
  const smtpPass = Deno.env.get('ZOHO_SMTP_PASS')!

  const asunto = `Nueva solicitud de registro — ${datos.empresa_nombre}`
  const cuerpo = `
Nueva empresa pendiente de aprobación en IndovexApp.

Empresa:     ${datos.empresa_nombre}
RUT:         ${datos.rut ?? 'No ingresado'}
Administrador: ${datos.admin_nombre}
Email:       ${datos.admin_email}
Fecha:       ${datos.fecha}

Ingresá a la app para aprobar o rechazar la solicitud.
  `.trim()

  // Encode credentials for Basic Auth
  const credentials = btoa(`${smtpUser}:${smtpPass}`)

  // Usar Zoho Mail API REST como alternativa a SMTP directo en Deno
  // Zoho SMTP via fetch con nodemailer no está disponible en Deno edge
  // Usamos el endpoint SMTP de Zoho via TCP con la librería smtp de deno
  const { SMTPClient } = await import('https://deno.land/x/denomailer@1.6.0/mod.ts')

  const client = new SMTPClient({
    connection: {
      hostname: smtpHost,
      port: smtpPort,
      tls: true,
      auth: {
        username: smtpUser,
        password: smtpPass,
      },
    },
  })

  await client.send({
    from: `IndovexApp <${smtpUser}>`,
    to: smtpUser, // se envía a soporte@indovexapp.com (o sea, a vos)
    subject: asunto,
    content: cuerpo,
  })

  await client.close()
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

    // ── Enviar email de notificación a soporte (no bloquea el registro si falla) ──
    try {
      const fecha = new Date().toLocaleString('es-UY', { timeZone: 'America/Montevideo' })
      await enviarEmailNotificacion({
        empresa_nombre: empresaNombre,
        rut: rutNormalizado,
        admin_nombre: adminNombre,
        admin_email: adminEmail,
        fecha,
      })
    } catch (emailErr) {
      console.error('Error al enviar email de notificación:', emailErr)
      // No se interrumpe el registro por fallo de email
    }

    return new Response(JSON.stringify({ success: true, empresa_id: nuevaEmpresa.id }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})