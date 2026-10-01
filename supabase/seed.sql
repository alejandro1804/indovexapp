--
-- seed.sql — Datos iniciales de documentos_legales
--
-- Generado con pg_dump (--data-only) desde producción, ajustado a mano.
-- Solo se usa al recrear una base desde cero (supabase db reset);
-- nunca se ejecuta sobre producción.
--
-- Orden en un reset: primero corren las migraciones y después este seed.
-- La versión vigente de Privacidad (v1.7) la inserta la migración
-- 20261001022531_registrar_privacidad_v1_7.sql, por eso acá la v1.6
-- va con vigente = false (índice uq_documento_vigente: una vigente por documento).
--
-- Columnas: id, documento, version, fecha_publicacion, fecha_vigencia, url,
--           resumen_cambios, requiere_aceptacion, vigente, creado_en
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Términos y Condiciones v1.4 (vigente)
INSERT INTO public.documentos_legales VALUES ('e0c8c5cb-b3da-4039-8fcd-86503df92d39', 'tyc', '1.4', '2026-07-15', '2026-07-30', 'https://www.indovexapp.com/terminos.html', 'Se incorpora la cláusula 3 (Ámbito Territorial del Servicio): el Servicio se ofrece exclusivamente en la República Oriental del Uruguay. Renumeración de cláusulas 3 a 15.', true, true, '2026-07-15 19:31:45.520628+00');

-- Política de Privacidad v1.6 (histórica, reemplazada por v1.7)
INSERT INTO public.documentos_legales VALUES ('16cd02a0-80dd-4754-8f15-b91913956f7c', 'privacidad', '1.6', '2026-07-15', '2026-07-30', 'https://www.indovexapp.com/privacidad.html', 'El RUT pasa a declararse como dato opcional. Se corrige el listado de encargados del tratamiento: se retira Twilio y se identifica a Meta Platforms Inc. como único proveedor de notificaciones WhatsApp. Se referencia el ámbito territorial uruguayo.', true, false, '2026-07-15 19:31:45.520628+00');