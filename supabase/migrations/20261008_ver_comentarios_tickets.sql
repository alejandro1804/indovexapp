-- ============================================================
-- IndovexApp — Permiso "Ver comentarios de tickets"
--
-- Separa dos niveles en los comentarios de ticket:
--   ver_comentarios_ticket -> VE el hilo (solo lectura)      [NUEVO]
--   comentar_ticket        -> VE y COMENTA                   [ya existía]
--
-- comentar_ticket incluye la lectura: quien comenta siempre ve.
-- La escritura NO se toca (sigue mandando puede_comentar_ticket:
-- permiso + pertenencia + ticket no cerrado/rechazado).
--
-- Ajustada al estado real de la base (consulta previa 08/10/2026):
--   - rol_permisos NO tiene empresa_id; tiene UNIQUE (rol_id, permiso_id)
--   - existe tiene_permiso(p_codigo text) SECURITY DEFINER
--   - única policy de lectura: ticket_comentarios_select
--
-- Idempotente: se puede correr más de una vez.
-- Ejecutar en Supabase SQL Editor.
-- ============================================================

-- ------------------------------------------------------------
-- 1) CATÁLOGO GLOBAL
-- ------------------------------------------------------------
insert into public.permisos (codigo, nombre, modulo)
select 'ver_comentarios_ticket', 'Ver comentarios de tickets', 'tickets'
where not exists (
  select 1 from public.permisos where codigo = 'ver_comentarios_ticket'
);

-- Solo el nombre visible. El codigo NO cambia.
update public.permisos
   set nombre = 'Ver y comentar en tickets'
 where codigo = 'comentar_ticket';

-- ------------------------------------------------------------
-- 2) SIEMBRA EN EMPRESAS EXISTENTES
--    Hoy lee el hilo todo el que entra al ticket. Para que nadie
--    pierda acceso de golpe, el permiso nuevo se asigna a todo
--    rol que tenga ver_tickets (20 roles al 08/10/2026: los 5
--    con tickets de Barizo, Demo, RIOS y prueba; shopper no).
--    Después cada admin destilda desde "Permisos: <rol>".
--    Demo queda sembrada para las empresas que se aprueben luego.
-- ------------------------------------------------------------
insert into public.rol_permisos (rol_id, permiso_id)
select rp.rol_id, nuevo.id
  from public.rol_permisos rp
  join public.permisos p on p.id = rp.permiso_id and p.codigo = 'ver_tickets'
 cross join (select id from public.permisos
              where codigo = 'ver_comentarios_ticket') nuevo
on conflict (rol_id, permiso_id) do nothing;

-- ------------------------------------------------------------
-- 3) RLS — SELECT de ticket_comentarios
--    Antes: cualquiera de la empresa.
--    Ahora: empresa + (ver_comentarios_ticket O comentar_ticket).
--    Super admin sigue viendo todo, como hasta hoy.
-- ------------------------------------------------------------
drop policy if exists ticket_comentarios_select on public.ticket_comentarios;

create policy ticket_comentarios_select
  on public.ticket_comentarios
  for select
  using (
    es_super_admin()
    or (
      empresa_id = get_empresa_id()
      and (
        (select public.tiene_permiso('ver_comentarios_ticket'))
        or (select public.tiene_permiso('comentar_ticket'))
      )
    )
  );

-- ------------------------------------------------------------
-- 4) VERIFICACIÓN (solo lectura, una sola grilla)
--    Esperado: 2 policies (1 INSERT + 1 SELECT) y, por rol,
--    "ve: SI" en todos los que tienen ver_tickets.
-- ------------------------------------------------------------
select '1 policies' as seccion,
       policyname || ' | ' || cmd || ' | USING: ' || coalesce(qual, '-') as detalle
  from pg_policies
 where schemaname = 'public' and tablename = 'ticket_comentarios'
union all
select '2 roles',
       coalesce(e.nombre, '(sin empresa)') || ' / ' || r.nombre
       || ' | ve: '           || case when bool_or(p.codigo = 'ver_comentarios_ticket') then 'SI' else 'no' end
       || ' | ve y comenta: ' || case when bool_or(p.codigo = 'comentar_ticket')        then 'SI' else 'no' end
  from public.roles r
  left join public.empresas e      on e.id = r.empresa_id
  left join public.rol_permisos rp on rp.rol_id = r.id
  left join public.permisos p      on p.id = rp.permiso_id
                                  and p.codigo in ('ver_comentarios_ticket', 'comentar_ticket')
 group by e.nombre, r.nombre
 order by 1, 2;