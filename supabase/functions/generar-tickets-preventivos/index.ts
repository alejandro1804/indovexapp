import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const hoy = new Date()

    const { data: planes, error: errorPlanes } = await supabase
      .from('planes_mantenimiento')
      .select('*, maquinas(empresa_id, sector_id)')
      .eq('activo', true)
      .eq('tipo_intervalo', 'dias')

    if (errorPlanes) throw errorPlanes
    if (!planes || planes.length === 0) {
      return new Response(JSON.stringify({ message: 'Sin planes para procesar' }), { status: 200 })
    }

    let generados = 0
    let omitidos = 0

    for (const plan of planes) {
      const maquinaData = Array.isArray(plan.maquinas) ? plan.maquinas[0] : plan.maquinas
      const empresaId = maquinaData?.empresa_id
      if (!empresaId) {
        omitidos++
        continue
      }

      let vence = false

      if (!plan.ultimo_valor_ejecutado) {
        const fechaCreacion = new Date(plan.created_at)
        const diasTranscurridos = Math.floor((hoy.getTime() - fechaCreacion.getTime()) / (1000 * 60 * 60 * 24))
        vence = diasTranscurridos >= plan.intervalo_valor
      } else {
        const ultimaEjecucion = new Date(plan.ultimo_valor_ejecutado)
        const diasTranscurridos = Math.floor((hoy.getTime() - ultimaEjecucion.getTime()) / (1000 * 60 * 60 * 24))
        vence = diasTranscurridos >= plan.intervalo_valor
      }

      if (!vence) {
        omitidos++
        continue
      }

      const { data: ticketExistente } = await supabase
        .from('tickets')
        .select('id')
        .eq('plan_id', plan.id)
        .in('estado', ['abierto', 'asignado', 'en_proceso'])
        .maybeSingle()

      if (ticketExistente) {
        omitidos++
        continue
      }

      const { data: usuarioEmpresa } = await supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', empresaId)
        .order('es_super_admin', { ascending: true })
        .limit(1)
        .maybeSingle()

      if (!usuarioEmpresa) {
        console.error(`Empresa ${empresaId} sin usuarios, omitiendo plan ${plan.id}`)
        omitidos++
        continue
      }

      const { data: ultimoTicket } = await supabase
        .from('tickets')
        .select('numero')
        .eq('empresa_id', empresaId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      const ultimoNumero = ultimoTicket
        ? parseInt(ultimoTicket.numero.split('-').pop() || '0')
        : 0
      const nuevoNumero = `TK-${(ultimoNumero + 1).toString().padStart(4, '0')}`

      const { data: ticket, error: errorTicket } = await supabase
        .from('tickets')
        .insert({
          empresa_id: empresaId,
          maquina_id: plan.maquina_id,
          creado_por: usuarioEmpresa.id,
          numero: nuevoNumero,
          estado: 'abierto',
          tipo: 'preventivo',
          prioridad: 'media',
          descripcion_desperfecto: plan.descripcion_tarea,
          plan_id: plan.id,
          fecha_programada: hoy.toISOString().split('T')[0],
        })
        .select()
        .single()

      if (errorTicket) {
        console.error(`Error creando ticket para plan ${plan.id}:`, errorTicket)
        omitidos++
        continue
      }

      await supabase.from('ticket_historial').insert({
        ticket_id: ticket.id,
        usuario_id: usuarioEmpresa.id,
        estado_anterior: null,
        estado_nuevo: 'abierto',
        comentario: `Ticket generado automáticamente por plan de mantenimiento`,
      })

      await supabase
        .from('planes_mantenimiento')
        .update({
          ultimo_valor_ejecutado: hoy.getTime(),
          proximo_valor: hoy.getTime() + (plan.intervalo_valor * 24 * 60 * 60 * 1000),
        })
        .eq('id', plan.id)

      generados++
    }

    return new Response(
      JSON.stringify({ message: 'OK', generados, omitidos }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error en generar-tickets-preventivos:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})