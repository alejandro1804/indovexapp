-- gen_storage_policies.sql
-- Lee buckets y políticas de Storage REALES de producción y los escribe
-- como SQL listo para usar como migración.
--
-- Uso (desde la raíz del repo, con $env:PGPASSWORD cargado):
--   psql "URI" -f scripts\gen_storage_policies.sql -o supabase\migrations\<TIMESTAMP>_storage_policies.sql

\encoding UTF8
\set QUIET on
\pset tuples_only on
\pset format unaligned

\qecho '-- storage_policies.sql'
\qecho '-- Buckets y políticas de Storage, generados desde producción.'
\qecho '-- Complementa 20260929000000_remote_schema.sql (que solo cubre el esquema public).'
\qecho ''
\qecho '-- ===================== BUCKETS ====================='

select format(
  'insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values (%L, %L, %s, %s, %L) on conflict (id) do nothing;',
  id, name, case when public then 'true' else 'false' end,
  coalesce(file_size_limit::text, 'null'),
  allowed_mime_types
)
from storage.buckets
order by id;

\qecho ''
\qecho '-- ===================== POLÍTICAS ====================='

select format(
  E'drop policy if exists %I on %I.%I;\ncreate policy %I on %I.%I as %s for %s to %s%s%s;\n',
  policyname, schemaname, tablename,
  policyname, schemaname, tablename,
  permissive, cmd,
  array_to_string(roles, ', '),
  case when qual is not null then E'\n  using (' || qual || ')' else '' end,
  case when with_check is not null then E'\n  with check (' || with_check || ')' else '' end
)
from pg_policies
where schemaname = 'storage'
order by tablename, policyname;