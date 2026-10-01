-- 20260929000001_storage_policies.sql
-- Buckets y políticas de Storage, generados desde producción.
-- Complementa 20260929000000_remote_schema.sql (que solo cubre el esquema public).

-- ===================== BUCKETS =====================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('documentos', 'documentos', false, null, NULL) on conflict (id) do nothing;

-- ===================== POLÍTICAS =====================
drop policy if exists documentos_delete on storage.objects;
create policy documentos_delete on storage.objects as PERMISSIVE for DELETE to authenticated
  using (((bucket_id = 'documentos'::text) AND (((storage.foldername(name))[1] = (get_empresa_id())::text) OR ((storage.foldername(name))[3] = (get_empresa_id())::text) OR es_super_admin())));

drop policy if exists documentos_insert on storage.objects;
create policy documentos_insert on storage.objects as PERMISSIVE for INSERT to authenticated
  with check (((bucket_id = 'documentos'::text) AND (((storage.foldername(name))[1] = (get_empresa_id())::text) OR ((storage.foldername(name))[3] = (get_empresa_id())::text) OR es_super_admin()) AND fn_empresa_tiene_espacio()));

drop policy if exists documentos_select on storage.objects;
create policy documentos_select on storage.objects as PERMISSIVE for SELECT to authenticated
  using (((bucket_id = 'documentos'::text) AND (((storage.foldername(name))[1] = (get_empresa_id())::text) OR ((storage.foldername(name))[3] = (get_empresa_id())::text) OR es_super_admin())));

drop policy if exists documentos_update on storage.objects;
create policy documentos_update on storage.objects as PERMISSIVE for UPDATE to authenticated
  using (((bucket_id = 'documentos'::text) AND (((storage.foldername(name))[1] = (get_empresa_id())::text) OR ((storage.foldername(name))[3] = (get_empresa_id())::text) OR es_super_admin())))
  with check (((bucket_id = 'documentos'::text) AND (((storage.foldername(name))[1] = (get_empresa_id())::text) OR ((storage.foldername(name))[3] = (get_empresa_id())::text) OR es_super_admin())));

