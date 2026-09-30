-- Tabla tipos_intervalo
CREATE TABLE tipos_intervalo (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id uuid NOT NULL REFERENCES empresas(id),
  nombre text NOT NULL,
  codigo text NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  es_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (empresa_id, codigo)
);

ALTER TABLE tipos_intervalo ENABLE ROW LEVEL SECURITY;

CREATE POLICY tipos_intervalo_mi_empresa
  ON tipos_intervalo FOR ALL
  USING (empresa_id = get_empresa_id());

CREATE TRIGGER trg_audit_tipos_intervalo
  AFTER INSERT OR UPDATE OR DELETE ON tipos_intervalo
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Insertar los 4 defaults para la empresa Demo
INSERT INTO tipos_intervalo (empresa_id, nombre, codigo, es_default)
VALUES
  ('3470bac5-45a4-4b9e-837b-d747c7446da3', 'Días', 'dias', true),
  ('3470bac5-45a4-4b9e-837b-d747c7446da3', 'Horas', 'horas', true),
  ('3470bac5-45a4-4b9e-837b-d747c7446da3', 'Ciclos', 'ciclos', true),
  ('3470bac5-45a4-4b9e-837b-d747c7446da3', 'M³', 'm3', true);

-- Actualizar aprobar_empresa para clonar tipos_intervalo
CREATE OR REPLACE FUNCTION aprobar_empresa(p_empresa_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_empresa_plantilla uuid := '3470bac5-45a4-4b9e-837b-d747c7446da3';
  v_rol record;
  v_nuevo_rol_id uuid;
  v_rol_admin_id uuid;
begin
  if not es_super_admin() then
    raise exception 'No autorizado: solo el super admin puede aprobar empresas';
  end if;

  if not exists (
    select 1 from public.empresas
    where id = p_empresa_id and estado = 'pendiente'
  ) then
    raise exception 'La empresa no existe o no está pendiente';
  end if;

  update public.empresas
  set estado = 'activa'
  where id = p_empresa_id;

  for v_rol in
    select id, nombre from public.roles
    where empresa_id = v_empresa_plantilla
  loop
    insert into public.roles (empresa_id, nombre)
    values (p_empresa_id, v_rol.nombre)
    returning id into v_nuevo_rol_id;

    if v_rol.nombre = 'admin' then
      v_rol_admin_id := v_nuevo_rol_id;
    end if;

    insert into public.rol_permisos (rol_id, permiso_id)
    select v_nuevo_rol_id, rp.permiso_id
    from public.rol_permisos rp
    where rp.rol_id = v_rol.id;
  end loop;

  insert into public.tipos_intervalo (empresa_id, nombre, codigo, es_default)
  select p_empresa_id, nombre, codigo, es_default
  from public.tipos_intervalo
  where empresa_id = v_empresa_plantilla;

  update public.usuarios
  set rol_id = v_rol_admin_id
  where empresa_id = p_empresa_id
    and rol_id is null;

end;
$$;