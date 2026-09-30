-- Migration: vincular destinatarios de WhatsApp a usuarios registrados
-- En vez de un número libre por destinatario, ahora se selecciona un
-- usuario existente y el número se resuelve desde su perfil (usuarios.telefono)

-- 1. Teléfono opcional en usuarios --------------------------------------
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS telefono text;

-- 2. Rediseñar whatsapp_destinatarios ------------------------------------
--    Ya no guarda número ni nombre libre: usuario_id pasa a ser obligatorio
--    y el dato se resuelve por join contra usuarios al momento de enviar

ALTER TABLE public.whatsapp_destinatarios
  DROP COLUMN numero_whatsapp,
  DROP COLUMN nombre_referencia,
  ALTER COLUMN usuario_id SET NOT NULL;

-- Evitar que el mismo usuario quede duplicado como destinatario de una empresa
ALTER TABLE public.whatsapp_destinatarios
  ADD CONSTRAINT uq_whatsapp_destinatarios_empresa_usuario UNIQUE (empresa_id, usuario_id);

-- 3. Migrar el destinatario de prueba cargado anteriormente -------------
--    (tenía el número como texto libre; ahora se vincula al usuario y el
--    número se guarda en su perfil)

UPDATE usuarios
SET telefono = '+59899668216'
WHERE id = '0304ca9f-1a4f-429b-b0d5-1ab4d68151bd';

DELETE FROM whatsapp_destinatarios
WHERE empresa_id = '3470bac5-45a4-4b9e-837b-d747c7446da3';

INSERT INTO whatsapp_destinatarios (empresa_id, usuario_id, activo)
VALUES (
  '3470bac5-45a4-4b9e-837b-d747c7446da3',
  '0304ca9f-1a4f-429b-b0d5-1ab4d68151bd',
  true
);