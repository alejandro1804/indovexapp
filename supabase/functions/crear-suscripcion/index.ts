import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResp(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const MP_API = "https://api.mercadopago.com";

function mpHeaders(): Record<string, string> {
  return {
    "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
    "Content-Type": "application/json",
  };
}

// ─────────────────────────────────────────────────────────────
// crear-suscripcion
//
// Crea la suscripción (preapproval) de una empresa a un plan del catálogo.
//
// 1. PERMISOS: solo un administrador de ESA empresa puede contratar.
//    - El usuario se identifica por su sesión (JWT de la página de pagos).
//    - usuarios.empresa_id debe coincidir con el empresa_id pedido.
//    - es_admin_empresa() debe ser true (excluye al super admin: el
//      super admin no obliga contractualmente a ninguna empresa).
//
// 2. SUSCRIPCIONES EXISTENTES: se consultan en MercadoPago (no en la
//    base, que se entera recién con el webhook y dejaría pasar un
//    doble clic):
//    - Ya tiene una activa DEL MISMO PLAN → se rechaza (409).
//    - Tiene una activa de OTRO plan (plan viejo o cambio de tier)
//      → CAMBIO DE PLAN: se crea la nueva, se marca como vigente en
//        empresas.mp_suscripcion_id y recién después se cancelan las
//        anteriores. Así el webhook ignora esas cancelaciones (no son
//        la vigente) y la empresa no se suspende.
//    - Si no se puede consultar MP, no se crea nada (falla cerrada).
//
// 3. La activación de la empresa (estado + tier) la sigue haciendo el
//    webhook al recibir la suscripción autorizada.
// ─────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Contrato: plan_id es el UUID de la fila del catálogo `planes`, que
    // identifica una combinación tier + ciclo (ej: Starter mensual).
    const { empresa_id, plan_id, payer_email, card_token_id } = await req.json();

    if (!empresa_id || !plan_id) {
      return jsonResp({ error: "empresa_id y plan_id son requeridos" }, 400);
    }
    if (!payer_email) {
      return jsonResp({ error: "payer_email es requerido" }, 400);
    }
    if (!card_token_id) {
      return jsonResp({ error: "card_token_id es requerido" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabase = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // ── 1. Permisos ──
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResp({ error: "Sesión requerida" }, 401);
    }

    // Cliente con la sesión del usuario: auth.uid() y es_admin_empresa()
    // se resuelven como ese usuario.
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      console.log(">>> [CREAR-SUSC] sesión inválida:", userError?.message);
      return jsonResp({ error: "Sesión inválida" }, 401);
    }
    const userId = userData.user.id;

    const { data: usuario, error: usuarioError } = await supabase
      .from("usuarios")
      .select("empresa_id")
      .eq("id", userId)
      .maybeSingle();

    if (usuarioError) {
      console.log(">>> [CREAR-SUSC] error al leer el usuario:", usuarioError.message);
      return jsonResp({ error: "Error al verificar el usuario" }, 500);
    }

    if (!usuario || usuario.empresa_id !== empresa_id) {
      console.log(`>>> [CREAR-SUSC] RECHAZADO: usuario ${userId} no pertenece a la empresa ${empresa_id}`);
      return jsonResp({ error: "No tenés permiso para contratar un plan para esta empresa" }, 403);
    }

    const { data: esAdmin, error: adminError } = await userClient.rpc("es_admin_empresa");
    if (adminError) {
      console.log(">>> [CREAR-SUSC] error en es_admin_empresa:", adminError.message);
      return jsonResp({ error: "Error al verificar permisos" }, 500);
    }
    if (esAdmin !== true) {
      console.log(`>>> [CREAR-SUSC] RECHAZADO: usuario ${userId} no es administrador de la empresa ${empresa_id}`);
      return jsonResp({ error: "Solo un administrador de la empresa puede contratar el plan" }, 403);
    }

    // ── 2. Plan del catálogo ──
    const { data: planData, error: planError } = await supabase
      .from("planes")
      .select("mp_plan_id, nombre, tier, ciclo, precio, activo")
      .eq("id", plan_id)
      .maybeSingle();

    if (planError) {
      console.log(">>> [CREAR-SUSC] error al consultar planes:", planError.message);
      return jsonResp({ error: "Error al consultar el plan", detalle: planError.message }, 500);
    }
    if (!planData) {
      return jsonResp({ error: "Plan no encontrado" }, 404);
    }
    if (!planData.activo) {
      return jsonResp({ error: "El plan no está disponible" }, 400);
    }
    if (!planData.mp_plan_id) {
      return jsonResp(
        { error: "El plan no está habilitado para pago (sin MercadoPago Plan ID)" },
        400
      );
    }

    console.log(
      `>>> [CREAR-SUSC] empresa="${empresa_id}" | usuario="${userId}" | plan="${planData.nombre}" | tier="${planData.tier}" | mp_plan_id="${planData.mp_plan_id}"`
    );

    // ── 3. Suscripciones activas de la empresa en MercadoPago ──
    const busqueda = await fetch(
      `${MP_API}/preapproval/search?external_reference=${encodeURIComponent(empresa_id)}&status=authorized`,
      { headers: mpHeaders() }
    );

    if (!busqueda.ok) {
      const detalle = await busqueda.json().catch(() => ({}));
      console.log(">>> [CREAR-SUSC] no se pudieron consultar las suscripciones activas:", JSON.stringify(detalle));
      return jsonResp({ error: "No se pudo verificar el estado de la suscripción. Probá de nuevo en unos minutos." }, 502);
    }

    // MP ignora el filtro external_reference de /preapproval/search y
    // devuelve TODAS las suscripciones activas de la cuenta vendedora
    // (detectado en producción, sept 2026). Se filtra acá por empresa:
    // sin este filtro, el alta de una empresa se trataría como cambio
    // de plan sobre las suscripciones de OTRA empresa y las cancelaría.
    const resultados: Array<{ id: string; preapproval_plan_id?: string; external_reference?: string; status?: string }> =
      (await busqueda.json())?.results ?? [];

    const activas = resultados.filter(
      (s) => s.external_reference === empresa_id && s.status === "authorized"
    );

    console.log(`>>> [CREAR-SUSC] suscripciones activas: ${JSON.stringify(activas.map((s) => ({ id: s.id, plan: s.preapproval_plan_id })))}`);

    if (activas.some((s) => s.preapproval_plan_id === planData.mp_plan_id)) {
      console.log(">>> [CREAR-SUSC] RECHAZADO: la empresa ya tiene una suscripción activa a este plan");
      return jsonResp({ error: "Tu empresa ya tiene este plan activo" }, 409);
    }

    const cambioDePlan = activas.length > 0;

    // ── 4. Crear la suscripción ──
    //    Con card_token_id + status "authorized", MercadoPago acepta la
    //    creación por API y guarda el external_reference (empresa_id).
    const mpResp = await fetch(`${MP_API}/preapproval`, {
      method: "POST",
      headers: mpHeaders(),
      body: JSON.stringify({
        preapproval_plan_id: planData.mp_plan_id,
        card_token_id: card_token_id,
        payer_email: payer_email,
        external_reference: empresa_id,
        back_url: "https://indovexapp.com",
        status: "authorized",
      }),
    });

    const mpData = await mpResp.json();

    if (!mpResp.ok) {
      console.log(">>> [CREAR-SUSC] MP rechazó la creación:", JSON.stringify(mpData));
      return jsonResp(
        { error: "MercadoPago rechazó la creación de la suscripción", detalle: mpData },
        400
      );
    }

    const nuevaId = String(mpData.id);
    console.log(`>>> [CREAR-SUSC] suscripción creada: id="${nuevaId}" | status="${mpData.status}"`);

    if (!cambioDePlan) {
      return jsonResp({
        ok: true,
        preapproval_id: nuevaId,
        status: mpData.status,
        tier: planData.tier,
        ciclo: planData.ciclo,
        cambio_plan: false,
      }, 200);
    }

    // ── 5. Cambio de plan: marcar la nueva como vigente y cancelar las anteriores ──
    //    El orden importa: primero vigente, después cancelar. Si el orden
    //    se invierte, el webhook recibiría la cancelación de la vigente
    //    y suspendería a la empresa.
    const { error: vigenteError } = await supabase
      .from("empresas")
      .update({ mp_suscripcion_id: nuevaId })
      .eq("id", empresa_id);

    if (vigenteError) {
      // No se cancelan las anteriores: cancelarlas sin haber marcado la
      // nueva como vigente suspendería a la empresa.
      console.log(`>>> [CREAR-SUSC] ATENCIÓN: no se pudo marcar ${nuevaId} como vigente (${vigenteError.message}). Suscripciones anteriores SIN cancelar: ${activas.map((s) => s.id).join(", ")}. Cancelarlas a mano para no cobrar dos veces.`);
      return jsonResp({
        ok: true,
        preapproval_id: nuevaId,
        status: mpData.status,
        tier: planData.tier,
        ciclo: planData.ciclo,
        cambio_plan: true,
        pendientes_de_cancelar: activas.map((s) => s.id),
      }, 200);
    }

    const canceladas: string[] = [];
    const sinCancelar: string[] = [];

    for (const anterior of activas) {
      const resp = await fetch(`${MP_API}/preapproval/${anterior.id}`, {
        method: "PUT",
        headers: mpHeaders(),
        body: JSON.stringify({ status: "cancelled" }),
      });
      if (resp.ok) {
        canceladas.push(anterior.id);
      } else {
        const detalle = await resp.json().catch(() => ({}));
        console.log(`>>> [CREAR-SUSC] no se pudo cancelar ${anterior.id}:`, JSON.stringify(detalle));
        sinCancelar.push(anterior.id);
      }
    }

    console.log(`>>> [CREAR-SUSC] cambio de plan: vigente=${nuevaId} | canceladas=${canceladas.join(", ") || "-"}`);
    if (sinCancelar.length > 0) {
      console.log(`>>> [CREAR-SUSC] ATENCIÓN: quedaron SIN cancelar ${sinCancelar.join(", ")}. Cancelarlas a mano para no cobrar dos veces.`);
    }

    return jsonResp({
      ok: true,
      preapproval_id: nuevaId,
      status: mpData.status,
      tier: planData.tier,
      ciclo: planData.ciclo,
      cambio_plan: true,
      canceladas,
      pendientes_de_cancelar: sinCancelar,
    }, 200);

  } catch (error) {
    const mensaje = error instanceof Error ? error.message : String(error);
    console.log(">>> [CREAR-SUSC] error capturado:", mensaje);
    return jsonResp({ error: mensaje }, 500);
  }
});