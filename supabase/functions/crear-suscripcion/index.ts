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

    // Cliente Supabase con service role (lee tablas sin RLS)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Buscar el plan en la tabla por ciclo (mensual/anual) y que esté activo
    const { data: planData, error: planError } = await supabase
      .from("planes")
      .select("mp_plan_id, nombre, precio")
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

    // 2. Buscar el email de contacto de la empresa
    const { data: empresaData, error: empresaError } = await supabase
      .from("empresas")
      .select("email_contacto, nombre")
      .eq("id", empresa_id)
      .maybeSingle();

    if (empresaError || !empresaData) {
      return new Response(
        JSON.stringify({ error: "Empresa no encontrada" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!empresaData.email_contacto) {
      return new Response(
        JSON.stringify({ error: "La empresa no tiene email de contacto configurado" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Crear la suscripción (preapproval) vinculada al plan existente
    const mpResponse = await fetch(
      "https://api.mercadopago.com/preapproval",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          preapproval_plan_id: planData.mp_plan_id,
          payer_email: empresaData.email_contacto,
          external_reference: empresa_id,
          back_url: "https://indovex.com/pago-exitoso",
          reason: `Indovex ${planData.nombre}`,
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
        preapproval_id: mpData.id,
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