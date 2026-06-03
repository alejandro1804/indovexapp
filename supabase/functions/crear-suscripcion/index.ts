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
    const { empresa_id, plan } = await req.json();

    if (!empresa_id || !plan) {
      return new Response(
        JSON.stringify({ error: "empresa_id y plan son requeridos" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const precio = plan === "anual" ? 15000 : 1500;
    const frecuencia = plan === "anual" ? 365 : 30;

    const mpResponse = await fetch(
      "https://api.mercadopago.com/preapproval_plan",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          reason: `Indovex Plan ${plan}`,
          auto_recurring: {
            frequency: frecuencia,
            frequency_type: "days",
            transaction_amount: precio,
            currency_id: "UYU",
          },
          back_url: "https://indovex.com/pago-exitoso",
          external_reference: empresa_id,
        }),
      }
    );

    const mpData = await mpResponse.json();

    if (!mpResponse.ok) {
      return new Response(
        JSON.stringify({ error: "Error en MercadoPago", detalle: mpData }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        link: mpData.init_point,
        plan_id: mpData.id,
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