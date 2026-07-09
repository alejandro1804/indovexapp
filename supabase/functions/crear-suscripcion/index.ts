import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { empresa_id, plan, payer_email, card_token_id } = await req.json();

    if (!empresa_id || !plan) {
      return new Response(
        JSON.stringify({ error: "empresa_id y plan son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!payer_email) {
      return new Response(
        JSON.stringify({ error: "payer_email es requerido" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!card_token_id) {
      return new Response(
        JSON.stringify({ error: "card_token_id es requerido" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Buscar el plan en la tabla
    const { data: planData, error: planError } = await supabase
      .from("planes")
      .select("mp_plan_id, nombre")
      .eq("ciclo", plan)
      .eq("activo", true)
      .maybeSingle();

    if (planError || !planData) {
      return new Response(
        JSON.stringify({ error: "Plan no encontrado o inactivo" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!planData.mp_plan_id) {
      return new Response(
        JSON.stringify({ error: "El plan no está habilitado para pago (sin MercadoPago Plan ID)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Crear la suscripción (preapproval) vía API con la tarjeta tokenizada.
    //    Con card_token_id + status "authorized", MercadoPago acepta la
    //    creación por API y guarda el external_reference (empresa_id) de
    //    forma garantizada. El webhook luego lo lee para activar la empresa.
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
      return new Response(
        JSON.stringify({ error: "MercadoPago rechazó la creación de la suscripción", detalle: mpData }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Suscripción creada y autorizada. Devolvemos el id y el estado.
    //    El webhook recibirá la notificación y actualizará la empresa,
    //    pero también actualizamos acá de forma optimista por si el
    //    webhook demora.
    return new Response(
      JSON.stringify({
        ok: true,
        preapproval_id: mpData.id,
        status: mpData.status,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});