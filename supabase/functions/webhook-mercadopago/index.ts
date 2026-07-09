import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-signature, x-request-id",
};

// Valida la firma x-signature que envía MercadoPago.
async function validarFirma(
  req: Request,
  dataId: string,
  secret: string
): Promise<boolean> {
  const xSignature = req.headers.get("x-signature");
  const xRequestId = req.headers.get("x-request-id");

  if (!xSignature || !xRequestId) {
    console.log(">>> FIRMA: faltan headers x-signature o x-request-id");
    return false;
  }

  const partes = xSignature.split(",");
  let ts = "";
  let v1 = "";
  for (const parte of partes) {
    const [clave, valor] = parte.split("=").map((s) => s.trim());
    if (clave === "ts") ts = valor;
    if (clave === "v1") v1 = valor;
  }

  if (!ts || !v1) {
    console.log(">>> FIRMA: no se pudo parsear ts o v1");
    return false;
  }

  const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const firma = await crypto.subtle.sign("HMAC", key, encoder.encode(manifest));

  const firmaHex = Array.from(new Uint8Array(firma))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const coincide = firmaHex === v1;
  console.log(`>>> FIRMA: manifest="${manifest}" | coincide=${coincide}`);
  return coincide;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    console.log(">>> BODY RECIBIDO:", JSON.stringify(body));

    const url = new URL(req.url);
    console.log(">>> URL:", req.url);

    const tipo = body?.type ?? url.searchParams.get("type");
    const dataId =
      body?.data?.id ?? url.searchParams.get("id") ?? body?.id ?? "";

    console.log(`>>> tipo="${tipo}" | dataId="${dataId}"`);

    // ── Validar la firma antes de procesar ──
    const secret = Deno.env.get("MP_WEBHOOK_SECRET");
    if (secret) {
      const firmaValida = await validarFirma(req, String(dataId), secret);
      if (!firmaValida) {
        console.log(">>> RESULTADO: firma inválida, devolviendo 401");
        return new Response(
          JSON.stringify({ error: "Firma inválida" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      console.log(">>> ADVERTENCIA: MP_WEBHOOK_SECRET no está configurado");
    }

    // Solo nos interesan eventos de suscripción
    if (tipo && tipo !== "subscription_preapproval" && tipo !== "preapproval") {
      console.log(`>>> RESULTADO: tipo "${tipo}" ignorado (no es suscripción)`);
      return new Response(JSON.stringify({ ignored: true, tipo }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!dataId) {
      console.log(">>> RESULTADO: sin dataId, devolviendo 200");
      return new Response(JSON.stringify({ error: "Sin ID de suscripción" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Consultar a MercadoPago los detalles de la suscripción
    console.log(`>>> Consultando MP: /preapproval/${dataId}`);
    const mpResp = await fetch(
      `https://api.mercadopago.com/preapproval/${dataId}`,
      {
        headers: {
          "Authorization": `Bearer ${Deno.env.get("MP_ACCESS_TOKEN")}`,
        },
      }
    );

    console.log(`>>> MP respondió status: ${mpResp.status}`);

    if (!mpResp.ok) {
      const detalle = await mpResp.json().catch(() => ({}));
      console.log(">>> RESULTADO: MP no pudo consultar suscripción:", JSON.stringify(detalle));
      return new Response(
        JSON.stringify({ error: "No se pudo consultar la suscripción", detalle }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const sub = await mpResp.json();
    console.log(">>> SUSCRIPCIÓN MP:", JSON.stringify(sub));

    const empresaId = sub.external_reference;
    const estadoSub = sub.status;
    const mpSubId = sub.id;

    console.log(`>>> empresaId="${empresaId}" | estadoSub="${estadoSub}" | mpSubId="${mpSubId}"`);

    if (!empresaId) {
      console.log(">>> RESULTADO: suscripción sin external_reference");
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

    console.log(">>> Actualizando empresa con:", JSON.stringify(updateData));

    const { error: updateError } = await supabase
      .from("empresas")
      .update(updateData)
      .eq("id", empresaId);

    if (updateError) {
      console.log(">>> RESULTADO: error al actualizar empresa:", updateError.message);
      return new Response(
        JSON.stringify({ error: "Error al actualizar empresa", detalle: updateError.message }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`>>> RESULTADO: empresa ${empresaId} actualizada correctamente a estado ${estadoSub}`);
    return new Response(
      JSON.stringify({ ok: true, empresa_id: empresaId, estado: estadoSub }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.log(">>> ERROR CAPTURADO:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});