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

    // 2. Construir el link del checkout del plan, pasando el empresa_id
    //    como external_reference vía query param. MercadoPago lo conserva
    //    en la suscripción resultante, lo que permite identificar la empresa
    //    en el webhook de confirmación.
    const link =
      `https://www.mercadopago.com.uy/subscriptions/checkout` +
      `?preapproval_plan_id=${planData.mp_plan_id}` +
      `&external_reference=${encodeURIComponent(empresa_id)}`;

    return new Response(
      JSON.stringify({ link }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});