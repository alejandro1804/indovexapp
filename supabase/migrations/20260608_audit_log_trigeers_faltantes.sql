-- Audit log triggers faltantes
CREATE TRIGGER trg_audit_sectores
  AFTER INSERT OR UPDATE OR DELETE ON sectores
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_categorias_repuestos
  AFTER INSERT OR UPDATE OR DELETE ON categorias_repuestos
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_roles
  AFTER INSERT OR UPDATE OR DELETE ON roles
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_rol_permisos
  AFTER INSERT OR UPDATE OR DELETE ON rol_permisos
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_repuestos_maquinas
  AFTER INSERT OR UPDATE OR DELETE ON repuestos_maquinas
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_encargado_sector
  AFTER INSERT OR UPDATE OR DELETE ON encargado_sector
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

CREATE TRIGGER trg_audit_proveedores
  AFTER INSERT OR UPDATE OR DELETE ON proveedores
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();