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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Contrato: plan_id es el UUID de la fila del catálogo `planes`, que
    // identifica una combinación tier + ciclo (ej: Starter mensual).
    // Antes se recibía `plan` con el ciclo ('mensual'/'anual'), lo que
    // dejó de alcanzar cuando el catálogo pasó a tener dos tiers.
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Buscar el plan por id (identifica tier + ciclo sin ambigüedad)
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
      `>>> [CREAR-SUSC] empresa="${empresa_id}" | plan="${planData.nombre}" | tier="${planData.tier}" | ciclo="${planData.ciclo}" | mp_plan_id="${planData.mp_plan_id}"`
    );

    // 2. Crear la suscripción (preapproval) vía API con la tarjeta tokenizada.
    //    Con card_token_id + status "authorized", MercadoPago acepta la
    //    creación por API y guarda el external_reference (empresa_id) de
    //    forma garantizada. El webhook luego lo lee para activar la empresa
    //    y resolver el tier vía planes.tier a partir del preapproval_plan_id.
    const preapprovalBody = {
      preapproval_plan_id: planData.mp_plan_id,
      card_token_id: card_token_id,
      payer_email: payer_email,
      external_reference: empresa_id,
      back_url: "https://indovexapp.com",
      status: "authorized",
    };

    const mpResp = await fetch("https://api.mercadopago.com/preapproval", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(preapprovalBody),
    });

    const mpData = await mpResp.json();

    if (!mpResp.ok) {
      console.log(">>> [CREAR-SUSC] MP rechazó la creación:", JSON.stringify(mpData));
      return jsonResp(
        { error: "MercadoPago rechazó la creación de la suscripción", detalle: mpData },
        400
      );
    }

    console.log(
      `>>> [CREAR-SUSC] suscripción creada: id="${mpData.id}" | status="${mpData.status}"`
    );

    // 3. Suscripción creada y autorizada. Devolvemos el id y el estado.
    //    La activación de la empresa (estado + tier) la hace el webhook:
    //    es la fuente de verdad y evita que un fallo de red acá deje a la
    //    empresa activa sin suscripción confirmada.
    return jsonResp(
      {
        ok: true,
        preapproval_id: mpData.id,
        status: mpData.status,
        tier: planData.tier,
        ciclo: planData.ciclo,
      },
      200
    );

  } catch (error) {
    console.log(">>> [CREAR-SUSC] error capturado:", error.message);
    return jsonResp({ error: error.message }, 500);
  }
});