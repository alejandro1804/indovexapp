-- Registra la Política de Privacidad v1.7 (publicada 2026-09-05)
-- y la marca como vigente. Solo puede haber una vigente por documento
-- (índice uq_documento_vigente), por eso primero se apaga la anterior.
-- La vigencia se cuenta desde este registro (+15 días, cl. 10 Privacidad),
-- no desde la publicación, porque recién ahora se notifica a los usuarios.
-- Durante el preaviso legal_estado_pendiente() muestra aviso sin bloquear.

update public.documentos_legales
   set vigente = false
 where documento = 'privacidad'
   and vigente = true;

insert into public.documentos_legales
  (documento, version, fecha_publicacion, fecha_vigencia, url,
   resumen_cambios, requiere_aceptacion, vigente)
values
  ('privacidad', '1.7',
   '2026-09-05',
   '2026-10-16',
   'https://www.indovexapp.com/privacidad.html',
   'Se declara el token de notificaciones push (FCM). Se incorporan GitHub y Google (Firebase Cloud Messaging) como encargados del tratamiento. Se precisa la descripción de Cloudflare y del resto de los encargados.',
   true, true);