| linea                                                                                                                         |
| ----------------------------------------------------------------------------------------------------------------------------- |
| # IndovexApp — Documentación de Esquema (auto-generada)                                                                       |
|                                                                                                                               |
| Generado: 2026-07-04 20:14 UTC                                                                                                |
| Project: qxrhrvzvzljeavczzytz — Literal E                                                                                     |
|                                                                                                                               |
| > Fuente de verdad: DB live. No editar a mano — regenerar con `SELECT sa_generar_doc_esquema();`                              |
|                                                                                                                               |
| ## Resumen                                                                                                                    |
|                                                                                                                               |
| | Métrica | Valor |                                                                                                           |
| |---|---|                                                                                                                     |
| | Tablas (public) | 27 |                                                                                                      |
| | Políticas RLS | 41 |                                                                                                        |
| | Triggers | 78 |                                                                                                             |
| | Funciones | 57 |                                                                                                            |
|                                                                                                                               |
| ## Tablas y columnas                                                                                                          |
|                                                                                                                               |
| ### adjuntos  ·  RLS ✓                                                                                                        |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                               |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                        |
| | entidad_tipo | text | NOT NULL |  |  |                                                                                      |
| | entidad_id | uuid | NOT NULL |  |  |                                                                                        |
| | nombre_archivo | text | NOT NULL |  |  |                                                                                    |
| | tipo_mime | text | NULL |  |  |                                                                                             |
| | tamanio_bytes | bigint | NULL |  |  |                                                                                       |
| | storage_path | text | NOT NULL |  |  |                                                                                      |
| | url_publica | text | NULL |  |  |                                                                                           |
| | subido_por | uuid | NULL |  |  |                                                                                            |
| | created_at | timestamp with time zone | NULL | now() |  |                                                                   |
|                                                                                                                               |
| ### audit_log  ·  RLS ✓                                                                                                       |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | id | bigint | NOT NULL | nextval('audit_log_id_seq'::regclass) |  |                                                         |
| | tabla | text | NOT NULL |  |  |                                                                                             |
| | operacion | text | NOT NULL |  |  |                                                                                         |
| | registro_id | text | NOT NULL |  |  |                                                                                       |
| | empresa_id | uuid | NULL |  |  |                                                                                            |
| | usuario_id | uuid | NULL |  |  |                                                                                            |
| | datos_antes | jsonb | NULL |  |  |                                                                                          |
| | datos_despues | jsonb | NULL |  |  |                                                                                        |
| | ip | text | NULL |  |  |                                                                                                    |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                               |
|                                                                                                                               |
| ### categorias_repuestos  ·  RLS ✓                                                                                            |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                               |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                        |
| | nombre | text | NOT NULL |  |  |                                                                                            |
| | descripcion | text | NULL |  |  |                                                                                           |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                               |
|                                                                                                                               |
| ### config_plazos  ·  RLS ✓                                                                                                   |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | clave | text | NOT NULL |  |  |                                                                                             |
| | dias | integer | NOT NULL |  |  |                                                                                           |
| | descripcion | text | NULL |  |  |                                                                                           |
|                                                                                                                               |
| ### empresas  ·  RLS ✓                                                                                                        |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                            |
| | plan | text | NOT NULL | 'basic'::text |  |                                                                                 |
| | activa | boolean | NOT NULL | true |  |                                                                                     |
| | max_usuarios | integer | NOT NULL | 5 |  |                                                                                  |
| | max_maquinas | integer | NOT NULL | 20 |  |                                                                                 |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                               |
| | estado | text | NULL | 'pendiente'::text |  |                                                                               |
| | rut | text | NULL |  |  |                                                                                                   |
| | direccion | text | NULL |  |  |                                                                                             |
| | telefono | text | NULL |  |  |                                                                                              |
| | email_contacto | text | NULL |  |  |                                                                                        |
| | trial_vence | timestamp with time zone | NULL |  |  |                                                                       |
| | mp_plan_id | text | NULL |  |  |                                                                                            |
| | mp_suscripcion_id | text | NULL |  |  |                                                                                     |
| | storage_mb_limit | integer | NOT NULL | 500 |  |                                                                            |
| | suscripcion_estado | text | NULL |  |  |                                                                                    |
| | suscripcion_actualizada | timestamp with time zone | NULL |  |  |                                                           |
| | fecha_suspension | timestamp with time zone | NULL |  | Cuándo pasó a suspendida (Situación 2 - falta de pago). |           |
| | fecha_baja_solicitada | timestamp with time zone | NULL |  | Cuándo el cliente pidió baja voluntaria (Situación 1). |       |
| | fecha_purga_programada | date | NULL |  | Fecha desde la cual la purga queda habilitada. La calcula la RPC de transición. | |
|                                                                                                                               |
| ### ingreso_repuestos  ·  RLS ✓                                                                                               |
|                                                                                                                               |
| | Columna | Tipo | Null | Default | Nota |                                                                                    |
| |---|---|---|---|---|                                                                                                         |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                               |
| | repuesto_id | uuid | NOT NULL |  |  |                                                                                       |
| | proveedor_id | uuid | NULL |  |  |                                                                                          |