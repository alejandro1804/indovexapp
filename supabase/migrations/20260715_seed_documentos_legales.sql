-- =====================================================================
-- Seed: versiones legales vigentes (T&C v1.4 / Privacidad v1.6)
-- =====================================================================

-- fecha_vigencia = publicacion + 15 dias (preaviso T&C cl. 13 / Priv. cl. 10)
insert into public.documentos_legales (
  documento, version, fecha_publicacion, fecha_vigencia, url,
  resumen_cambios, requiere_aceptacion, vigente
) values
(
  'tyc', '1.4', '2026-07-15', '2026-07-30',
  'https://www.indovexapp.com/terminos.html',
  'Se incorpora la cláusula 3 (Ámbito Territorial del Servicio): el Servicio se ofrece exclusivamente en la República Oriental del Uruguay. Renumeración de cláusulas 3 a 15.',
  true, true
),
(
  'privacidad', '1.6', '2026-07-15', '2026-07-30',
  'https://www.indovexapp.com/privacidad.html',
  'El RUT pasa a declararse como dato opcional. Se corrige el listado de encargados del tratamiento: se retira Twilio y se identifica a Meta Platforms Inc. como único proveedor de notificaciones WhatsApp. Se referencia el ámbito territorial uruguayo.',
  true, true
)
on conflict (documento, version) do nothing;