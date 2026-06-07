import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-signature, x-request-id",
};

// Valida la firma x-signature que envía MercadoPago.
// Devuelve true si la firma es válida, false si no.
async function validarFirma(
  req: Request,
  dataId: string,
  secret: string
): Promise<boolean> {
  const xSignature = req.headers.get("x-signature");
  const xRequestId = req.headers.get("x-request-id");

  if (!xSignature || !xRequestId) return false;

  // x-signature viene como: "ts=1704908010,v1=hashhexadecimal"
  const partes = xSignature.split(",");
  let ts = "";
  let v1 = "";
  for (const parte of partes) {
    const [clave, valor] = parte.split("=").map((s) => s.trim());
    if (clave === "ts") ts = valor;
    if (clave === "v1") v1 = valor;
  }

  if (!ts || !v1) return false;

  // Plantilla que MercadoPago especifica para reconstruir la firma
  const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

  // HMAC-SHA256 con la clave secreta
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const firma = await crypto.subtle.sign("HMAC", key, encoder.encode(manifest));

  // Convertir a hexadecimal
  const firmaHex = Array.from(new Uint8Array(firma))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return firmaHex === v1;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));

    const url = new URL(req.url);
    const tipo = body?.type ?? url.searchParams.get("type");
    const dataId =
      body?.data?.id ?? url.searchParams.get("id") ?? body?.id ?? "";

    // ── Validar la firma antes de procesar ──────────────────
    const secret = Deno.env.get("MP_WEBHOOK_SECRET");
    if (secret) {
      const firmaValida = await validarFirma(req, String(dataId), secret);
      if (!firmaValida) {
        // Firma inválida → rechazar. Devolvemos 401.
        return new Response(
          JSON.stringify({ error: "Firma inválida" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Solo nos interesan eventos de suscripción
    if (tipo && tipo !== "subscription_preapproval" && tipo !== "preapproval") {
      return new Response(JSON.stringify({ ignored: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!dataId) {
      return new Response(JSON.stringify({ error: "Sin ID de suscripción" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Consultar a MercadoPago los detalles de la suscripción
    const mpResp = await fetch(
      `https://api.mercadopago.com/preapproval/${dataId}`,
      {
        headers: {
          "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
        },
      }
    );

    if (!mpResp.ok) {
      const detalle = await mpResp.json().catch(() => ({}));
      return new Response(
        JSON.stringify({ error: "No se pudo consultar la suscripción", detalle }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const sub = await mpResp.json();
    const empresaId = sub.external_reference;
    const estadoSub = sub.status;
    const mpSubId = sub.id;

    if (!empresaId) {
      return new Response(
        JSON.stringify({ error: "Suscripción sin external_reference" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Actualizar la empresa según el estado
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const updateData: Record<string, unknown> = {
      mp_suscripcion_id: mpSubId,
      suscripcion_estado: estadoSub,
      suscripcion_actualizada: new Date().toISOString(),
    };

    if (estadoSub === "authorized") {
      updateData.estado = "activa";
      updateData.plan = "pago";
    } else if (estadoSub === "paused" || estadoSub === "cancelled") {
      updateData.estado = "suspendida";
    }

    const { error: updateError } = await supabase
      .from("empresas")
      .update(updateData)
      .eq("id", empresaId);

    if (updateError) {
      return new Response(
        JSON.stringify({ error: "Error al actualizar empresa", detalle: updateError.message }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ ok: true, empresa_id: empresaId, estado: estadoSub }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});