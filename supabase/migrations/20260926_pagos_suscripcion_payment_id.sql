-- ─────────────────────────────────────────────────────────────
-- 20260926_pagos_suscripcion_payment_id.sql
--
-- Contexto: el pago de septiembre de RIOS (MP payment 178415774031)
-- llegó como notificación type="payment" y el webhook la ignoró.
-- Se unifica el registro: una fila por PAGO real de MercadoPago.
--
--   mp_payment_id  = id del pago real (/v1/payments/{id})  ← clave única
--   mp_cuota_id    = id del authorized_payment (cuota), si se conoce
--
-- Orden: limpieza → columnas → corrección julio → integridad → trigger.
-- La limpieza y la corrección van ANTES del trigger porque después
-- quedarían bloqueadas por la inmutabilidad (ALCOA+).
-- ─────────────────────────────────────────────────────────────

begin;

-- 1. Limpieza de filas de prueba
delete from public.pagos_suscripcion
where mp_payment_id like 'TEST-HIST-%'
   or mp_payment_id = '7029899381';

-- 2. Columnas nuevas (nullable: los rechazados no tienen comisión ni neto)
alter table public.pagos_suscripcion
  add column if not exists mp_cuota_id  text,
  add column if not exists cuota_numero integer,
  add column if not exists comision_mp  numeric,
  add column if not exists monto_neto   numeric;

comment on column public.pagos_suscripcion.mp_payment_id is 'Id del pago real de MercadoPago (/v1/payments). Clave de idempotencia.';
comment on column public.pagos_suscripcion.mp_cuota_id   is 'Id del authorized_payment (cuota de la suscripción), si se conoce.';
comment on column public.pagos_suscripcion.cuota_numero  is 'Número de cuota de la suscripción (subscription_sequence.number).';
comment on column public.pagos_suscripcion.comision_mp   is 'Comisión cobrada por MercadoPago al vendedor.';
comment on column public.pagos_suscripcion.monto_neto    is 'Monto neto acreditado (monto - comisión).';

-- 3. Corrección de la fila de julio de RIOS:
--    guardaba el id de la cuota (7030087775) en mp_payment_id.
--    El pago real es 168295894439 (payment_reference del pago de septiembre).
update public.pagos_suscripcion
set mp_cuota_id   = '7030087775',
    mp_payment_id = '168295894439',
    cuota_numero  = 1,
    actualizado   = now()
where mp_payment_id = '7030087775';

-- 4. Integridad
alter table public.pagos_suscripcion
  alter column mp_payment_id set not null;

alter table public.pagos_suscripcion
  drop constraint if exists pagos_suscripcion_estado_check;

alter table public.pagos_suscripcion
  add constraint pagos_suscripcion_estado_check
  check (estado in ('approved', 'rejected', 'refunded', 'cancelled', 'charged_back'));

-- 5. Inmutabilidad (append-only)
--    • DELETE: prohibido.
--    • UPDATE permitido solo en:
--        - facturado, factura_numero, factura_fecha, actualizado (marcar_pago_facturado)
--        - mp_cuota_id: solo de NULL a un valor (completar trazabilidad)
--        - estado: solo approved → refunded | charged_back
--    Para una corrección excepcional: deshabilitar el trigger dentro de
--    una migración documentada, corregir y volver a habilitarlo.
create or replace function public.fn_pagos_suscripcion_inmutable()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'pagos_suscripcion es append-only: DELETE no permitido (id=%)', old.id;
  end if;

  if new.id                is distinct from old.id
     or new.empresa_id        is distinct from old.empresa_id
     or new.mp_payment_id     is distinct from old.mp_payment_id
     or new.mp_suscripcion_id is distinct from old.mp_suscripcion_id
     or new.mp_plan_id        is distinct from old.mp_plan_id
     or new.monto             is distinct from old.monto
     or new.moneda            is distinct from old.moneda
     or new.fecha_pago        is distinct from old.fecha_pago
     or new.cuota_numero      is distinct from old.cuota_numero
     or new.comision_mp       is distinct from old.comision_mp
     or new.monto_neto        is distinct from old.monto_neto
     or new.creado            is distinct from old.creado
  then
    raise exception 'pagos_suscripcion: solo se pueden modificar los campos de facturación (id=%)', old.id;
  end if;

  if new.mp_cuota_id is distinct from old.mp_cuota_id
     and old.mp_cuota_id is not null then
    raise exception 'pagos_suscripcion: mp_cuota_id ya asignado, no se puede cambiar (id=%)', old.id;
  end if;

  if new.estado is distinct from old.estado
     and not (old.estado = 'approved' and new.estado in ('refunded', 'charged_back')) then
    raise exception 'pagos_suscripcion: transición de estado no permitida % → % (id=%)',
      old.estado, new.estado, old.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pagos_suscripcion_inmutable on public.pagos_suscripcion;

create trigger trg_pagos_suscripcion_inmutable
before update or delete on public.pagos_suscripcion
for each row execute function public.fn_pagos_suscripcion_inmutable();

commit;