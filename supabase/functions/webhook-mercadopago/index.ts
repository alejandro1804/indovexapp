import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Supa = ReturnType<typeof createClient>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-signature, x-request-id",
};

// Estados FINALES de un pago de MercadoPago. Solo estos se registran:
// pending / in_process se ignoran y se espera la notificación siguiente
// (la fila es inmutable, un estado intermedio quedaría congelado).
const ESTADOS_FINALES = new Set(["approved", "rejected", "refunded", "cancelled", "charged_back"]);

// Errores de Postgres que no se resuelven reintentando (datos inválidos).
// Ante estos se responde 200 para que MP no reintente en vano.
const ERRORES_PERMANENTES = new Set(["23502", "23503", "23514", "22P02"]);

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
// Consulta a la API de MercadoPago distinguiendo errores
// transitorios (red, 429, 5xx → responder 500 para que MP reintente)
// de permanentes (404, 400 → responder 200, reintentar no sirve).
// ─────────────────────────────────────────────────────────────
type MpResultado =
  | { ok: true; body: any }
  | { ok: false; status: number; transitorio: boolean; detalle: unknown };

async function mpGet(path: string, accessToken: string): Promise<MpResultado> {
  let resp: Response;
  try {
    resp = await fetch(`https://api.mercadopago.com${path}`, {
      headers: { "Authorization": `Bearer ${accessToken}` },
    });
  } catch (e) {
    return { ok: false, status: 0, transitorio: true, detalle: String(e) };
  }

  if (resp.ok) {
    return { ok: true, body: await resp.json() };
  }

  const detalle = await resp.json().catch(() => ({}));
  const transitorio = resp.status === 429 || resp.status >= 500;
  return { ok: false, status: resp.status, transitorio, detalle };
}

function respuestaErrorMp(
  tag: string,
  r: { status: number; transitorio: boolean; detalle: unknown }
): Response {
  console.log(`>>> ${tag} MP respondió ${r.status} (transitorio=${r.transitorio}):`, JSON.stringify(r.detalle));
  return jsonResp(
    { error: "Error consultando MercadoPago", status: r.status },
    r.transitorio ? 500 : 200
  );
}

// ─────────────────────────────────────────────────────────────
// RAMA SUSCRIPCIÓN (preapproval).
// Actualiza el estado de la empresa según el estado de la suscripción.
//
// El tier (starter/pro) se resuelve vía planes.tier a partir del
// preapproval_plan_id de MercadoPago. Antes se seteaba plan='pago',
// que dejó de ser un tier válido: empresas.plan ahora acepta
// trial|starter|pro|interno y de él se derivan los límites de uso
// (usuarios, máquinas, storage) por trigger.
// ─────────────────────────────────────────────────────────────
async function procesarSuscripcion(
  dataId: string,
  supabase: Supa,
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
  const mpPlanId = sub.preapproval_plan_id ?? null;

  console.log(`>>> [SUSCRIPCIÓN] empresaId="${empresaId}" | estadoSub="${estadoSub}" | mpSubId="${mpSubId}" | mpPlanId="${mpPlanId}"`);

  if (!empresaId) {
    console.log(">>> [SUSCRIPCIÓN] suscripción sin external_reference");
    return jsonResp({ error: "Suscripción sin external_reference" }, 200);
  }

  const updateData: Record<string, unknown> = {
    mp_suscripcion_id: mpSubId,
    suscripcion_estado: estadoSub,
    suscripcion_actualizada: new Date().toISOString(),
  };

  // Trazabilidad: qué plan de MercadoPago contrató esta empresa
  if (mpPlanId) {
    updateData.mp_plan_id = mpPlanId;
  }

  if (estadoSub === "authorized") {
    // Resolver el tier desde el catálogo antes de activar.
    // Sin tier no se activa: empresas.plan tiene un check constraint
    // (trial|starter|pro|interno) y un update inválido dejaría a la
    // empresa en un estado inconsistente.
    if (!mpPlanId) {
      console.log(">>> [SUSCRIPCIÓN] suscripción autorizada SIN preapproval_plan_id: no se puede resolver el tier");
      return jsonResp({
        error: "Suscripción autorizada sin preapproval_plan_id",
        empresa_id: empresaId,
        mp_suscripcion_id: mpSubId,
      }, 200);
    }

    const { data: planData, error: planError } = await supabase
      .from("planes")
      .select("tier, nombre")
      .eq("mp_plan_id", mpPlanId)
      .maybeSingle();

    if (planError) {
      console.log(">>> [SUSCRIPCIÓN] error al consultar planes:", planError.message);
      return jsonResp({ error: "Error al resolver el plan", detalle: planError.message }, 200);
    }

    if (!planData?.tier) {
      console.log(`>>> [SUSCRIPCIÓN] no hay plan en el catálogo con mp_plan_id="${mpPlanId}". Empresa NO activada.`);
      return jsonResp({
        error: "Plan de MercadoPago no encontrado en el catálogo",
        mp_plan_id: mpPlanId,
        empresa_id: empresaId,
      }, 200);
    }

    console.log(`>>> [SUSCRIPCIÓN] tier resuelto: "${planData.tier}" (${planData.nombre})`);

    updateData.estado = "activa";
    updateData.plan = planData.tier;   // starter | pro
  } else if (estadoSub === "paused" || estadoSub === "cancelled") {
    updateData.estado = "suspendida";
    // No se toca plan: la empresa conserva su tier y sus límites
    // durante el plazo de conservación (T&C cl. 12.2). La suspensión
    // es reversible.
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

  console.log(`>>> [SUSCRIPCIÓN] empresa ${empresaId} actualizada a estado ${estadoSub}${updateData.plan ? ` con tier ${updateData.plan}` : ""}`);
  return jsonResp({
    ok: true,
    tipo: "suscripcion",
    empresa_id: empresaId,
    estado: estadoSub,
    tier: updateData.plan ?? null,
  }, 200);
}

// ─────────────────────────────────────────────────────────────
// REGISTRO DE PAGO (punto único de escritura en pagos_suscripcion).
//
// Lo usan las dos ramas:
//   • type="payment"                          → registrarPago(id, null)
//   • type="subscription_authorized_payment"  → procesarCuota → registrarPago(payment.id, cuota.id)
//
// Clave única: mp_payment_id = id del PAGO real (/v1/payments/{id}).
// Si llegan ambas notificaciones para el mismo cobro, se registra
// una sola fila (on conflict do nothing).
//
// Datos del pago usados (validados con el pago real 178415774031):
//   external_reference                       → empresa_id
//   operation_type = "recurring_payment"      → es de suscripción
//   metadata.preapproval_id                   → suscripción
//   metadata.template_id                      → plan de MP
//   point_of_interaction.transaction_data.subscription_sequence.number → n.º de cuota
//   fee_details / transaction_details         → comisión y neto
//
// PRIVACIDAD: no se guarda ni se loguea nada de card ni de payer.
// ─────────────────────────────────────────────────────────────
async function registrarPago(
  paymentId: string,
  cuotaId: string | null,
  supabase: Supa,
  accessToken: string
): Promise<Response> {
  console.log(`>>> [PAGO] Consultando MP: /v1/payments/${paymentId}${cuotaId ? ` (cuota ${cuotaId})` : ""}`);
  const r = await mpGet(`/v1/payments/${paymentId}`, accessToken);
  if (!r.ok) return respuestaErrorMp("[PAGO]", r);

  const p = r.body;
  const td = p?.point_of_interaction?.transaction_data ?? {};
  const estado = String(p?.status ?? "");

  // Log acotado: sin datos de tarjeta ni del pagador
  console.log(">>> [PAGO] resumen:", JSON.stringify({
    id: p?.id,
    status: p?.status,
    status_detail: p?.status_detail,
    operation_type: p?.operation_type,
    external_reference: p?.external_reference,
    preapproval_id: p?.metadata?.preapproval_id ?? td?.subscription_id ?? null,
    cuota_numero: td?.subscription_sequence?.number ?? null,
    transaction_amount: p?.transaction_amount,
    currency_id: p?.currency_id,
  }));

  if (p?.operation_type !== "recurring_payment") {
    console.log(`>>> [PAGO] operation_type="${p?.operation_type}": no es un pago de suscripción, se ignora`);
    return jsonResp({ ignored: true, motivo: "no es pago de suscripción" }, 200);
  }

  if (!ESTADOS_FINALES.has(estado)) {
    console.log(`>>> [PAGO] estado "${estado}" no es final, se espera la siguiente notificación`);
    return jsonResp({ ignored: true, motivo: "estado no final", estado }, 200);
  }

  const preapprovalId = p?.metadata?.preapproval_id ?? td?.subscription_id ?? null;
  let empresaId: string | null = p?.external_reference ?? null;
  let mpPlanId: string | null = p?.metadata?.template_id ?? td?.plan_id ?? null;

  // Respaldo: si el pago no trae external_reference, resolver por el preapproval
  if (!empresaId && preapprovalId) {
    console.log(`>>> [PAGO] sin external_reference, resolviendo por /preapproval/${preapprovalId}`);
    const s = await mpGet(`/preapproval/${preapprovalId}`, accessToken);
    if (!s.ok) return respuestaErrorMp("[PAGO]", s);
    empresaId = s.body?.external_reference ?? null;
    mpPlanId = mpPlanId ?? s.body?.preapproval_plan_id ?? null;
  }

  if (!empresaId) {
    console.log(">>> [PAGO] no se pudo resolver empresa_id, no se inserta (fila huérfana evitada)");
    return jsonResp({ error: "No se pudo resolver empresa_id del pago" }, 200);
  }

  const aprobado = estado === "approved";
  const comision = aprobado && Array.isArray(p?.fee_details)
    ? p.fee_details
        .filter((f: any) => f?.fee_payer === "collector")
        .reduce((suma: number, f: any) => suma + Number(f?.amount ?? 0), 0)
    : null;
  const neto = aprobado ? (p?.transaction_details?.net_received_amount ?? null) : null;

  const mpPaymentId = String(p?.id ?? paymentId);

  const registro = {
    empresa_id: empresaId,
    mp_payment_id: mpPaymentId,
    mp_cuota_id: cuotaId,
    mp_suscripcion_id: preapprovalId ? String(preapprovalId) : null,
    mp_plan_id: mpPlanId,
    cuota_numero: td?.subscription_sequence?.number ?? null,
    monto: p?.transaction_amount ?? null,
    moneda: p?.currency_id ?? "UYU",
    estado,
    fecha_pago: p?.date_approved ?? p?.date_created ?? new Date().toISOString(),
    comision_mp: comision,
    monto_neto: neto,
  };

  console.log(">>> [PAGO] Insertando en pagos_suscripcion:", JSON.stringify(registro));

  const { error: insertError } = await supabase
    .from("pagos_suscripcion")
    .upsert(registro, { onConflict: "mp_payment_id", ignoreDuplicates: true });

  if (insertError) {
    const permanente = ERRORES_PERMANENTES.has(insertError.code ?? "");
    console.log(`>>> [PAGO] error al insertar (code=${insertError.code}, permanente=${permanente}):`, insertError.message);
    return jsonResp({ error: "Error al registrar el pago", detalle: insertError.message }, permanente ? 200 : 500);
  }

  // Si la fila ya existía (llegó antes el evento payment), completar la cuota
  if (cuotaId) {
    const { error } = await supabase
      .from("pagos_suscripcion")
      .update({ mp_cuota_id: cuotaId, actualizado: new Date().toISOString() })
      .eq("mp_payment_id", mpPaymentId)
      .is("mp_cuota_id", null);
    if (error) {
      console.log(">>> [PAGO] error al completar mp_cuota_id:", error.message);
      return jsonResp({ error: "Error al completar la cuota", detalle: error.message }, 500);
    }
  }

  // Reembolso o contracargo de un pago ya registrado como aprobado
  if (estado === "refunded" || estado === "charged_back") {
    const { error } = await supabase
      .from("pagos_suscripcion")
      .update({ estado, actualizado: new Date().toISOString() })
      .eq("mp_payment_id", mpPaymentId)
      .eq("estado", "approved");
    if (error) {
      console.log(`>>> [PAGO] error al marcar ${estado}:`, error.message);
      return jsonResp({ error: `Error al marcar ${estado}`, detalle: error.message }, 500);
    }
  }

  console.log(`>>> [PAGO] pago ${mpPaymentId} registrado para empresa ${empresaId} con estado ${estado}`);
  return jsonResp({ ok: true, tipo: "pago", empresa_id: empresaId, mp_payment_id: mpPaymentId, estado }, 200);
}

// ─────────────────────────────────────────────────────────────
// RAMA CUOTA (subscription_authorized_payment).
//
// La cuota tiene DOS niveles de estado:
//   • status (cuota): scheduled | processed | recycling | pending.
//     'processed' NO significa éxito: una cuota rechazada en el último
//     reintento también queda 'processed'.
//   • payment.status (pago real): el que dice si el dinero entró.
//
// La cuota solo sirve para llegar al pago real (payment.id) y delegar
// en registrarPago. Una cuota rechazada sin pago asociado (ej.
// payment_method_not_ready) no tiene payment.id: se loguea y se ignora;
// la detección de morosidad sale de la conciliación periódica.
// ─────────────────────────────────────────────────────────────
async function procesarCuota(
  cuotaId: string,
  supabase: Supa,
  accessToken: string
): Promise<Response> {
  console.log(`>>> [CUOTA] Consultando MP: /authorized_payments/${cuotaId}`);
  const r = await mpGet(`/authorized_payments/${cuotaId}`, accessToken);
  if (!r.ok) return respuestaErrorMp("[CUOTA]", r);

  const c = r.body;
  const paymentId = c?.payment?.id;

  console.log(">>> [CUOTA] resumen:", JSON.stringify({
    id: c?.id,
    status: c?.status,
    payment_id: paymentId ?? null,
    payment_status: c?.payment?.status ?? null,
    payment_status_detail: c?.payment?.status_detail ?? null,
    retry_attempt: c?.retry_attempt ?? null,
    preapproval_id: c?.preapproval_id ?? null,
  }));

  if (!paymentId) {
    console.log(">>> [CUOTA] cuota sin pago asociado, no hay nada que registrar");
    return jsonResp({ ignored: true, motivo: "cuota sin payment.id", cuota_id: c?.id ?? cuotaId }, 200);
  }

  return await registrarPago(String(paymentId), String(c?.id ?? cuotaId), supabase, accessToken);
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
      return await procesarCuota(String(dataId), supabase, accessToken);
    }

    if (tipo === "payment") {
      return await registrarPago(String(dataId), null, supabase, accessToken);
    }

    console.log(`>>> RESULTADO: tipo "${tipo}" ignorado`);
    return jsonResp({ ignored: true, tipo }, 200);

  } catch (error) {
    // Error inesperado: 500 para que MercadoPago reintente la notificación
    const mensaje = error instanceof Error ? error.message : String(error);
    console.log(">>> ERROR CAPTURADO:", mensaje);
    return jsonResp({ error: mensaje }, 500);
  }
});