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

// ─────────────────────────────────────────────────────────────
// RAMA SUSCRIPCIÓN (preapproval): tu lógica original, sin cambios.
// Actualiza el estado de la empresa según el estado de la suscripción.
// ─────────────────────────────────────────────────────────────
async function procesarSuscripcion(
  dataId: string,
  supabase: ReturnType<typeof createClient>,
  accessToken: string
): Promise<Response> {
  console.log(`>>> [SUSCRIPCIÓN] Consultando MP: /preapproval/${dataId}`);
  const mpResp = await fetch(
    `https://api.mercadopago.com/preapproval/${dataId}`,
    { headers: { "Authorization": `Bearer ${accessToken}` } }
  );

  console.log(`>>> [SUSCRIPCIÓN] MP respondió status: ${mpResp.status}`);

  if (!mpResp.ok) {
    const detalle = await mpResp.json().catch(() => ({}));
    console.log(">>> [SUSCRIPCIÓN] MP no pudo consultar suscripción:", JSON.stringify(detalle));
    return jsonResp({ error: "No se pudo consultar la suscripción", detalle }, 200);
  }

  const sub = await mpResp.json();
  console.log(">>> [SUSCRIPCIÓN] SUSCRIPCIÓN MP:", JSON.stringify(sub));

  const empresaId = sub.external_reference;
  const estadoSub = sub.status;
  const mpSubId = sub.id;

  console.log(`>>> [SUSCRIPCIÓN] empresaId="${empresaId}" | estadoSub="${estadoSub}" | mpSubId="${mpSubId}"`);

  if (!empresaId) {
    console.log(">>> [SUSCRIPCIÓN] suscripción sin external_reference");
    return jsonResp({ error: "Suscripción sin external_reference" }, 200);
  }

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

  console.log(">>> [SUSCRIPCIÓN] Actualizando empresa con:", JSON.stringify(updateData));

  const { error: updateError } = await supabase
    .from("empresas")
    .update(updateData)
    .eq("id", empresaId);

  if (updateError) {
    console.log(">>> [SUSCRIPCIÓN] error al actualizar empresa:", updateError.message);
    return jsonResp({ error: "Error al actualizar empresa", detalle: updateError.message }, 200);
  }

  console.log(`>>> [SUSCRIPCIÓN] empresa ${empresaId} actualizada a estado ${estadoSub}`);
  return jsonResp({ ok: true, tipo: "suscripcion", empresa_id: empresaId, estado: estadoSub }, 200);
}

// ─────────────────────────────────────────────────────────────
// RAMA PAGO (subscription_authorized_payment).
// Consulta el pago, resuelve la empresa vía el preapproval
// (external_reference = empresa_id) e inserta en pagos_suscripcion.
//
// IMPORTANTE sobre el estado (según doc oficial de MercadoPago):
// El authorized_payment tiene DOS niveles de estado:
//   • status (nivel cuota): scheduled | processed | recycling | pending.
//     'processed' NO significa éxito: una cuota rechazada en el último
//     reintento también queda 'processed'. No sirve para facturar.
//   • payment.status (nivel pago real): approved | rejected | pending |
//     in_process | refunded | cancelled. ESTE es el que dice si el dinero
//     entró. Es el que guardamos como 'estado' para poder facturar.
// Por eso priorizamos payment.status sobre el status de la cuota.
// ─────────────────────────────────────────────────────────────
async function procesarPago(
  dataId: string,
  supabase: ReturnType<typeof createClient>,
  accessToken: string
): Promise<Response> {
  // 1. Consultar el pago autorizado de la suscripción
  console.log(`>>> [PAGO] Consultando MP: /authorized_payments/${dataId}`);
  const payResp = await fetch(
    `https://api.mercadopago.com/authorized_payments/${dataId}`,
    { headers: { "Authorization": `Bearer ${accessToken}` } }
  );

  console.log(`>>> [PAGO] MP respondió status: ${payResp.status}`);

  if (!payResp.ok) {
    const detalle = await payResp.json().catch(() => ({}));
    console.log(">>> [PAGO] MP no pudo consultar el pago:", JSON.stringify(detalle));
    return jsonResp({ error: "No se pudo consultar el pago", detalle }, 200);
  }

  const pago = await payResp.json();
  console.log(">>> [PAGO] PAGO MP:", JSON.stringify(pago));

  // Campos del authorized_payment de MercadoPago
  const mpPaymentId = String(pago.id ?? dataId);
  const preapprovalId = pago.preapproval_id;

  const monto =
    pago?.transaction_amount ??
    pago?.payment?.transaction_amount ??
    pago?.debit_amount ??
    null;

  // ── ESTADO: priorizar payment.status (nivel pago real = "approved") ──
  // sobre el status de la cuota (nivel authorized_payment = "processed").
  const estadoPago =
    pago?.payment?.status ??   // approved | rejected | pending | ... (el que importa para facturar)
    pago?.status ??            // fallback: status de la cuota (scheduled/processed/recycling/pending)
    "unknown";

  // ── FECHA: priorizar la fecha de acreditación del pago real ──
  const fechaPago =
    pago?.payment?.date_approved ??
    pago?.date_created ??
    new Date().toISOString();

  const moneda =
    pago?.currency_id ??
    pago?.payment?.currency_id ??
    "UYU";

  console.log(`>>> [PAGO] mpPaymentId="${mpPaymentId}" | preapprovalId="${preapprovalId}" | monto="${monto}" | estado(payment.status)="${estadoPago}"`);

  if (!preapprovalId) {
    console.log(">>> [PAGO] pago sin preapproval_id, no se puede resolver la empresa");
    return jsonResp({ error: "Pago sin preapproval_id" }, 200);
  }

  // 2. Resolver empresa_id vía el preapproval (fuente de verdad = external_reference)
  console.log(`>>> [PAGO] Consultando MP: /preapproval/${preapprovalId} para resolver empresa`);
  const subResp = await fetch(
    `https://api.mercadopago.com/preapproval/${preapprovalId}`,
    { headers: { "Authorization": `Bearer ${accessToken}` } }
  );

  if (!subResp.ok) {
    const detalle = await subResp.json().catch(() => ({}));
    console.log(">>> [PAGO] no se pudo consultar el preapproval:", JSON.stringify(detalle));
    return jsonResp({ error: "No se pudo resolver la empresa del pago", detalle }, 200);
  }

  const sub = await subResp.json();
  const empresaId = sub.external_reference;
  const mpPlanId = sub.preapproval_plan_id ?? null;

  console.log(`>>> [PAGO] empresaId="${empresaId}" | mpPlanId="${mpPlanId}"`);

  if (!empresaId) {
    console.log(">>> [PAGO] preapproval sin external_reference, no se inserta (fila huérfana evitada)");
    return jsonResp({ error: "No se pudo resolver empresa_id del pago" }, 200);
  }

  // 3. Insertar el pago (upsert por mp_payment_id para evitar duplicados por reintentos)
  const registroPago = {
    empresa_id: empresaId,
    mp_payment_id: mpPaymentId,
    mp_suscripcion_id: String(preapprovalId),
    mp_plan_id: mpPlanId,
    monto: monto,
    moneda: moneda,
    estado: estadoPago,
    fecha_pago: fechaPago,
  };

  console.log(">>> [PAGO] Insertando en pagos_suscripcion:", JSON.stringify(registroPago));

  const { error: insertError } = await supabase
    .from("pagos_suscripcion")
    .upsert(registroPago, { onConflict: "mp_payment_id", ignoreDuplicates: true });

  if (insertError) {
    console.log(">>> [PAGO] error al insertar pago:", insertError.message);
    return jsonResp({ error: "Error al registrar el pago", detalle: insertError.message }, 200);
  }

  console.log(`>>> [PAGO] pago ${mpPaymentId} registrado para empresa ${empresaId} con estado ${estadoPago}`);
  return jsonResp({ ok: true, tipo: "pago", empresa_id: empresaId, mp_payment_id: mpPaymentId, estado: estadoPago }, 200);
}

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
        return jsonResp({ error: "Firma inválida" }, 401);
      }
    } else {
      console.log(">>> ADVERTENCIA: MP_WEBHOOK_SECRET no está configurado");
    }

    if (!dataId) {
      console.log(">>> RESULTADO: sin dataId, devolviendo 200");
      return jsonResp({ error: "Sin ID en la notificación" }, 200);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const accessToken = Deno.env.get("MP_ACCESS_TOKEN")!;

    // ── Ramificar según el tipo de evento ──
    if (tipo === "subscription_preapproval" || tipo === "preapproval") {
      return await procesarSuscripcion(String(dataId), supabase, accessToken);
    }

    if (tipo === "subscription_authorized_payment") {
      return await procesarPago(String(dataId), supabase, accessToken);
    }

    console.log(`>>> RESULTADO: tipo "${tipo}" ignorado (no es suscripción ni pago)`);
    return jsonResp({ ignored: true, tipo }, 200);

  } catch (error) {
    console.log(">>> ERROR CAPTURADO:", error.message);
    return jsonResp({ error: error.message }, 200);
  }
});