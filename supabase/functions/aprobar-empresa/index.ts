import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function enviarEmailBienvenida(datos: {
  admin_nombre: string
  admin_email: string
  empresa_nombre: string
}) {
  const smtpHost = Deno.env.get('ZOHO_SMTP_HOST')!
  const smtpPort = parseInt(Deno.env.get('ZOHO_SMTP_PORT') ?? '465')
  const smtpUser = Deno.env.get('ZOHO_SMTP_USER')!
  const smtpPass = Deno.env.get('ZOHO_SMTP_PASS')!

  const cuerpoHtml = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:20px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;max-width:600px;width:100%;">

        <tr><td style="background:#1B3A5C;padding:28px 24px;text-align:center;">
          <h1 style="margin:0;color:#ffffff;font-size:26px;font-weight:bold;">IndovexApp</h1>
        </td></tr>
        <tr><td style="background:#2E6DA4;padding:12px 24px;text-align:center;">
          <p style="margin:0;color:#ffffff;font-size:14px;">¡Tu cuenta fue aprobada y ya podés comenzar!</p>
        </td></tr>

        <tr><td style="padding:28px 24px 16px;">
          <p style="margin:0 0 12px;color:#222;font-size:15px;">Hola <strong>${datos.admin_nombre}</strong>,</p>
          <p style="margin:0;color:#444;font-size:14px;line-height:1.6;">
            ¡Bienvenido a IndovexApp! Tu empresa <strong>${datos.empresa_nombre}</strong> ha sido aprobada.
            A continuación encontrás tus datos de acceso y los primeros pasos para comenzar.
          </p>
        </td></tr>

        <tr><td style="padding:0 24px 20px;">
          <p style="margin:0 0 10px;color:#1B3A5C;font-size:15px;font-weight:bold;">🔑 Tus datos de acceso</p>
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;border-radius:6px;">
            <tr>
              <td style="padding:10px 14px;color:#666;font-size:13px;width:120px;">Email:</td>
              <td style="padding:10px 14px;color:#1B3A5C;font-size:13px;font-weight:bold;">${datos.admin_email}</td>
            </tr>
            <tr style="border-top:1px solid #e0e0e0;">
              <td style="padding:10px 14px;color:#666;font-size:13px;">Contraseña:</td>
              <td style="padding:10px 14px;color:#1B3A5C;font-size:13px;font-weight:bold;">La que ingresaste al registrarte</td>
            </tr>
            <tr style="border-top:1px solid #e0e0e0;">
              <td style="padding:10px 14px;color:#666;font-size:13px;">Acceso:</td>
              <td style="padding:10px 14px;font-size:13px;"><a href="https://app.indovexapp.com" style="color:#2E6DA4;font-weight:bold;">app.indovexapp.com</a></td>
            </tr>
          </table>
          <p style="margin:8px 0 0;color:#888;font-size:11px;">Tu email puede ser Gmail, Outlook u otro — el que ingresaste al registrarte.</p>
        </td></tr>

        <tr><td style="padding:0 24px 8px;"><hr style="border:none;border-top:1px solid #e0e0e0;margin:0;"></td></tr>

        <tr><td style="padding:8px 24px 16px;">
          <p style="margin:0 0 8px;color:#1B3A5C;font-size:15px;font-weight:bold;">🚀 Primeros pasos para comenzar</p>
          <p style="margin:0 0 14px;color:#666;font-size:13px;">Seguí este orden para configurar tu empresa correctamente:</p>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 1 — Configurá tu empresa</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Completá los datos de perfil de tu empresa: dirección, teléfono y logo.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 2 — Configuración inicial</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0 0 6px;color:#333;font-size:13px;">Dentro del menú <strong>Configuración</strong>, completá en este orden:</p>
              <p style="margin:3px 0 3px 12px;color:#333;font-size:12px;">• <strong>Sectores</strong> — Áreas o zonas donde están tus máquinas</p>
              <p style="margin:3px 0 3px 12px;color:#333;font-size:12px;">• <strong>Roles y permisos</strong> — Ajustalos según tu operación</p>
              <p style="margin:3px 0 3px 12px;color:#333;font-size:12px;">• <strong>Unidades de intervalo</strong> — Para tus mantenimientos</p>
              <p style="margin:3px 0 3px 12px;color:#333;font-size:12px;">• <strong>Categorías de repuestos</strong> — Para organizar tu inventario</p>
              <p style="margin:3px 0 3px 12px;color:#333;font-size:12px;">• <strong>Usuarios</strong> — Sumá a tu equipo con sus roles</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 3 — Agregá tus máquinas</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Registrá los equipos o activos que querés gestionar y asignalos a su sector.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 4 — Cargá tus repuestos</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Ingresá tu inventario inicial con stock mínimo para recibir alertas automáticas.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 5 — Creá tu primer ticket</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Registrá una orden de mantenimiento de prueba para familiarizarte con el flujo.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#1B3A5C;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">Paso 6 — Configurá planes de mantenimiento</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Definí los mantenimientos preventivos para tus máquinas con su frecuencia e intervalo.</p>
            </td></tr>
          </table>
        </td></tr>

        <tr><td style="padding:0 24px 8px;"><hr style="border:none;border-top:1px solid #e0e0e0;margin:0;"></td></tr>

        <tr><td style="padding:8px 24px 16px;">
          <p style="margin:0 0 12px;color:#1B3A5C;font-size:15px;font-weight:bold;">💡 Funcionalidades que te van a simplificar el trabajo</p>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#2E6DA4;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">📎 Adjuntos en máquinas y repuestos</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Podés adjuntar fotos, PDFs y otros archivos directamente a cada máquina o repuesto. Ideal para guardar manuales, fichas técnicas o certificados de garantía.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#2E6DA4;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">📱 Códigos QR para máquinas</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">IndovexApp genera un código QR único por cada máquina. Imprimilo y pegalo en el equipo — cualquier técnico puede escanearlo para ver toda la información al instante.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#2E6DA4;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">📄 Exportación a PDF</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Tickets, máquinas, repuestos y planes de mantenimiento se pueden exportar en PDF directamente desde la app, listos para imprimir o compartir.</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:6px;">
            <tr><td style="background:#2E6DA4;padding:8px 12px;border-radius:4px 4px 0 0;">
              <p style="margin:0;color:#ffffff;font-size:13px;font-weight:bold;">✅ Trazabilidad y auditoría ALCOA+</p>
            </td></tr>
            <tr><td style="background:#f9f9f9;padding:8px 12px;border-radius:0 0 4px 4px;">
              <p style="margin:0;color:#333;font-size:13px;">Cada acción queda documentada con usuario, fecha y hora exacta, garantizando trazabilidad completa para empresas que necesitan respaldo formal ante auditorías.</p>
            </td></tr>
          </table>
        </td></tr>

        <tr><td style="padding:0 24px 8px;"><hr style="border:none;border-top:1px solid #e0e0e0;margin:0;"></td></tr>

        <tr><td style="padding:8px 24px 20px;">
          <p style="margin:0 0 6px;color:#2E6DA4;font-size:14px;font-weight:bold;">¿Tenés alguna duda o necesitás ayuda?</p>
          <p style="margin:0;color:#444;font-size:13px;">Estamos disponibles en <a href="mailto:soporte@indovexapp.com" style="color:#2E6DA4;font-weight:bold;">soporte@indovexapp.com</a>. Con gusto te acompañamos en los primeros pasos.</p>
        </td></tr>

        <tr><td style="background:#1B3A5C;padding:16px 24px;text-align:center;">
          <p style="margin:0;color:#ffffff;font-size:12px;">IndovexApp — Victor Alejandro Rios | Uruguay</p>
          <p style="margin:4px 0 0;font-size:12px;"><a href="https://indovexapp.com" style="color:#aac8e8;">indovexapp.com</a> | <a href="mailto:soporte@indovexapp.com" style="color:#aac8e8;">soporte@indovexapp.com</a></p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>
  `.trim()

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
    to: datos.admin_email,
    subject: `¡Bienvenido a IndovexApp, ${datos.empresa_nombre}!`,
    html: cuerpoHtml,
  })

  await client.close()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Cliente admin para leer datos de empresa y usuario
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

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

    // 1. Obtener datos de la empresa
    const { data: empresa, error: errEmpresa } = await supabaseAdmin
      .from('empresas')
      .select('id, nombre')
      .eq('id', empresa_id)
      .single()

    if (errEmpresa || !empresa) {
      return new Response(JSON.stringify({ error: 'Empresa no encontrada' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 2. Obtener datos del usuario admin de la empresa
    const { data: usuario, error: errUsuario } = await supabaseAdmin
      .from('usuarios')
      .select('nombre, email')
      .eq('empresa_id', empresa_id)
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    if (errUsuario || !usuario) {
      return new Response(JSON.stringify({ error: 'Usuario admin no encontrado' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 3. Ejecutar el RPC con el JWT del super admin (valida permisos correctamente)
    const { error: errRpc } = await supabaseUser.rpc('aprobar_empresa', {
      p_empresa_id: empresa_id
    })

    if (errRpc) {
      return new Response(JSON.stringify({ error: 'Error al aprobar empresa: ' + errRpc.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 4. Enviar email de bienvenida al cliente
    try {
      await enviarEmailBienvenida({
        admin_nombre: usuario.nombre,
        admin_email: usuario.email,
        empresa_nombre: empresa.nombre,
      })
    } catch (emailErr) {
      console.error('Error al enviar email de bienvenida:', emailErr)
      // La aprobación ya se hizo — no se revierte por fallo de email
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})