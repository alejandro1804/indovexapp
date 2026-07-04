| linea                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------ |
| # IndovexApp — Documentación de Esquema (auto-generada)                                                                              |
|                                                                                                                                      |
| Generado: 2026-07-04 20:43 UTC                                                                                                       |
| Project: qxrhrvzvzljeavczzytz — Literal E                                                                                            |
|                                                                                                                                      |
| > Fuente de verdad: DB live. No editar a mano — regenerar con `SELECT sa_generar_doc_esquema();`                                     |
|                                                                                                                                      |
| ## Resumen                                                                                                                           |
|                                                                                                                                      |
| | Métrica | Valor |                                                                                                                  |
| |---|---|                                                                                                                            |
| | Tablas (public) | 27 |                                                                                                             |
| | Políticas RLS | 41 |                                                                                                               |
| | Triggers | 78 |                                                                                                                    |
| | Funciones | 57 |                                                                                                                   |
|                                                                                                                                      |
| ## Tablas y columnas                                                                                                                 |
|                                                                                                                                      |
| ### adjuntos  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | entidad_tipo | text | NOT NULL |  |  |                                                                                             |
| | entidad_id | uuid | NOT NULL |  |  |                                                                                               |
| | nombre_archivo | text | NOT NULL |  |  |                                                                                           |
| | tipo_mime | text | NULL |  |  |                                                                                                    |
| | tamanio_bytes | bigint | NULL |  |  |                                                                                              |
| | storage_path | text | NOT NULL |  |  |                                                                                             |
| | url_publica | text | NULL |  |  |                                                                                                  |
| | subido_por | uuid | NULL |  |  |                                                                                                   |
| | created_at | timestamp with time zone | NULL | now() |  |                                                                          |
|                                                                                                                                      |
| ### audit_log  ·  RLS ✓                                                                                                              |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | bigint | NOT NULL | nextval('audit_log_id_seq'::regclass) |  |                                                                |
| | tabla | text | NOT NULL |  |  |                                                                                                    |
| | operacion | text | NOT NULL |  |  |                                                                                                |
| | registro_id | text | NOT NULL |  |  |                                                                                              |
| | empresa_id | uuid | NULL |  |  |                                                                                                   |
| | usuario_id | uuid | NULL |  |  |                                                                                                   |
| | datos_antes | jsonb | NULL |  |  |                                                                                                 |
| | datos_despues | jsonb | NULL |  |  |                                                                                               |
| | ip | text | NULL |  |  |                                                                                                           |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### categorias_repuestos  ·  RLS ✓                                                                                                   |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### config_plazos  ·  RLS ✓                                                                                                          |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | clave | text | NOT NULL |  |  |                                                                                                    |
| | dias | integer | NOT NULL |  |  |                                                                                                  |
| | descripcion | text | NULL |  |  |                                                                                                  |
|                                                                                                                                      |
| ### empresas  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | plan | text | NOT NULL | 'basic'::text |  |                                                                                        |
| | activa | boolean | NOT NULL | true |  |                                                                                            |
| | max_usuarios | integer | NOT NULL | 5 |  |                                                                                         |
| | max_maquinas | integer | NOT NULL | 20 |  |                                                                                        |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | estado | text | NULL | 'pendiente'::text |  |                                                                                      |
| | rut | text | NULL |  |  |                                                                                                          |
| | direccion | text | NULL |  |  |                                                                                                    |
| | telefono | text | NULL |  |  |                                                                                                     |
| | email_contacto | text | NULL |  |  |                                                                                               |
| | trial_vence | timestamp with time zone | NULL |  |  |                                                                              |
| | mp_plan_id | text | NULL |  |  |                                                                                                   |
| | mp_suscripcion_id | text | NULL |  |  |                                                                                            |
| | storage_mb_limit | integer | NOT NULL | 500 |  |                                                                                   |
| | suscripcion_estado | text | NULL |  |  |                                                                                           |
| | suscripcion_actualizada | timestamp with time zone | NULL |  |  |                                                                  |
| | fecha_suspension | timestamp with time zone | NULL |  | Cuándo pasó a suspendida (Situación 2 - falta de pago). |                  |
| | fecha_baja_solicitada | timestamp with time zone | NULL |  | Cuándo el cliente pidió baja voluntaria (Situación 1). |              |
| | fecha_purga_programada | date | NULL |  | Fecha desde la cual la purga queda habilitada. La calcula la RPC de transición. |        |
|                                                                                                                                      |
| ### ingreso_repuestos  ·  RLS ✓                                                                                                      |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | repuesto_id | uuid | NOT NULL |  |  |                                                                                              |
| | proveedor_id | uuid | NULL |  |  |                                                                                                 |
| | registrado_por | uuid | NOT NULL |  |  |                                                                                           |
| | cantidad | integer | NOT NULL |  |  |                                                                                              |
| | quien_entrega | text | NULL |  |  |                                                                                                |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | fecha | date | NOT NULL | CURRENT_DATE |  |                                                                                        |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### lecturas_maquina  ·  RLS ✓                                                                                                       |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | maquina_id | uuid | NOT NULL |  |  |                                                                                               |
| | tipo | text | NOT NULL |  |  |                                                                                                     |
| | valor | numeric | NOT NULL |  |  |                                                                                                 |
| | fecha_lectura | date | NOT NULL | CURRENT_DATE |  |                                                                                |
| | registrado_por | uuid | NOT NULL |  |  |                                                                                           |
| | observacion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### maquina_documentos  ·  RLS ✓                                                                                                     |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | maquina_id | uuid | NOT NULL |  |  |                                                                                               |
| | subido_por | uuid | NOT NULL |  |  |                                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | url | text | NOT NULL |  |  |                                                                                                      |
| | tipo | text | NOT NULL | 'manual'::text |  |                                                                                       |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### maquinas  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | sector_id | uuid | NOT NULL |  |  |                                                                                                |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | codigo | text | NOT NULL |  |  |                                                                                                   |
| | estado | text | NOT NULL | 'operativa'::text |  |                                                                                  |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | imagen_url | text | NULL |  |  |                                                                                                   |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### notificaciones  ·  RLS ✓                                                                                                         |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | tipo | text | NOT NULL |  |  |                                                                                                     |
| | mensaje | text | NOT NULL |  |  |                                                                                                  |
| | ticket_id | uuid | NULL |  |  |                                                                                                    |
| | para_usuario_id | uuid | NOT NULL |  |  |                                                                                          |
| | de_usuario_id | uuid | NULL |  |  |                                                                                                |
| | leida | boolean | NOT NULL | false |  |                                                                                            |
| | leida_en | timestamp with time zone | NULL |  |  |                                                                                 |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### permisos  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | codigo | text | NOT NULL |  |  |                                                                                                   |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | modulo | text | NOT NULL |  |  |                                                                                                   |
|                                                                                                                                      |
| ### planes  ·  RLS ✓                                                                                                                 |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | precio | numeric | NOT NULL |  |  |                                                                                                |
| | ciclo | text | NOT NULL | 'mensual'::text |  |                                                                                     |
| | storage_mb_limit | integer | NOT NULL | 500 |  |                                                                                   |
| | mp_plan_id | text | NULL |  |  |                                                                                                   |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | orden | integer | NOT NULL | 0 |  |                                                                                                |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### planes_mantenimiento  ·  RLS ✓                                                                                                   |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | maquina_id | uuid | NOT NULL |  |  |                                                                                               |
| | descripcion_tarea | text | NOT NULL |  |  |                                                                                        |
| | tipo_intervalo | text | NOT NULL |  |  |                                                                                           |
| | intervalo_valor | numeric | NOT NULL |  |  |                                                                                       |
| | ultimo_valor_ejecutado | numeric | NULL |  |  |                                                                                    |
| | proximo_valor | numeric | NULL |  |  |                                                                                             |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | procedimiento | text | NULL |  |  |                                                                                                |
|                                                                                                                                      |
| ### proveedores  ·  RLS ✓                                                                                                            |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | rut | text | NULL |  |  |                                                                                                          |
| | contacto | text | NULL |  |  |                                                                                                     |
| | telefono | text | NULL |  |  |                                                                                                     |
| | email | text | NULL |  |  |                                                                                                        |
| | direccion | text | NULL |  |  |                                                                                                    |
| | notas | text | NULL |  |  |                                                                                                        |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### repuestos  ·  RLS ✓                                                                                                              |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | categoria_id | uuid | NULL |  |  |                                                                                                 |
| | codigo | text | NOT NULL |  |  |                                                                                                   |
| | descripcion | text | NOT NULL |  |  |                                                                                              |
| | stock_actual | integer | NOT NULL | 0 |  |                                                                                         |
| | stock_minimo | integer | NOT NULL | 0 |  |                                                                                         |
| | ubicacion | text | NULL |  |  |                                                                                                    |
| | unidad_medida | text | NOT NULL | 'unidad'::text |  |                                                                              |
| | notas | text | NULL |  |  |                                                                                                        |
| | imagen_url | text | NULL |  |  |                                                                                                   |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | ref | integer | NULL |  |  |                                                                                                       |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | ultima_alerta_stock_at | timestamp with time zone | NULL |  |  |                                                                   |
|                                                                                                                                      |
| ### repuestos_maquinas  ·  RLS ✓                                                                                                     |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | repuesto_id | uuid | NOT NULL |  |  |                                                                                              |
| | maquina_id | uuid | NOT NULL |  |  |                                                                                               |
| | cantidad | integer | NOT NULL | 1 |  |                                                                                             |
| | ubicacion_en_maquina | text | NULL |  |  |                                                                                         |
| | observacion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### rol_permisos  ·  RLS ✓                                                                                                           |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | rol_id | uuid | NOT NULL |  |  |                                                                                                   |
| | permiso_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### roles  ·  RLS ✓                                                                                                                  |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NULL |  |  |                                                                                                   |
| | restringe_por_sector | boolean | NOT NULL | false |  |                                                                             |
|                                                                                                                                      |
| ### salida_repuestos  ·  RLS ✓                                                                                                       |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | repuesto_id | uuid | NOT NULL |  |  |                                                                                              |
| | ticket_id | uuid | NULL |  |  |                                                                                                    |
| | registrado_por | uuid | NOT NULL |  |  |                                                                                           |
| | cantidad | integer | NOT NULL |  |  |                                                                                              |
| | quien_retira | text | NULL |  |  |                                                                                                 |
| | observacion | text | NULL |  |  |                                                                                                  |
| | fecha | date | NOT NULL | CURRENT_DATE |  |                                                                                        |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### sectores  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### ticket_fotos  ·  RLS ✓                                                                                                           |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | ticket_id | uuid | NOT NULL |  |  |                                                                                                |
| | subido_por | uuid | NOT NULL |  |  |                                                                                               |
| | foto_url | text | NOT NULL |  |  |                                                                                                 |
| | descripcion | text | NULL |  |  |                                                                                                  |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### ticket_historial  ·  RLS ✓                                                                                                       |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | ticket_id | uuid | NOT NULL |  |  |                                                                                                |
| | usuario_id | uuid | NOT NULL |  |  |                                                                                               |
| | estado_anterior | text | NULL |  |  |                                                                                              |
| | estado_nuevo | text | NOT NULL |  |  |                                                                                             |
| | comentario | text | NULL |  |  |                                                                                                   |
| | fecha | timestamp with time zone | NOT NULL | now() |  |                                                                           |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### tickets  ·  RLS ✓                                                                                                                |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | maquina_id | uuid | NOT NULL |  |  |                                                                                               |
| | creado_por | uuid | NOT NULL |  |  |                                                                                               |
| | tecnico_id | uuid | NULL |  |  |                                                                                                   |
| | numero | character varying(20) | NOT NULL |  |  |                                                                                  |
| | estado | text | NOT NULL | 'abierto'::text |  |                                                                                    |
| | descripcion_desperfecto | text | NOT NULL |  |  |                                                                                  |
| | observacion_encargado | text | NULL |  |  |                                                                                        |
| | observacion_tecnico | text | NULL |  |  |                                                                                          |
| | foto_url | text | NULL |  |  |                                                                                                     |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | tipo | text | NOT NULL | 'correctivo'::text |  |                                                                                   |
| | prioridad | text | NOT NULL | 'media'::text |  |                                                                                   |
| | fecha_programada | date | NULL |  |  |                                                                                             |
| | fecha_cierre | timestamp with time zone | NULL |  |  |                                                                             |
| | plan_id | uuid | NULL |  |  |                                                                                                      |
|                                                                                                                                      |
| ### tipos_intervalo  ·  RLS ✓                                                                                                        |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | codigo | text | NOT NULL |  |  |                                                                                                   |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | es_default | boolean | NOT NULL | false |  |                                                                                       |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ### usuario_sector  ·  RLS ✓                                                                                                         |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | usuario_id | uuid | NOT NULL |  |  |                                                                                               |
| | sector_id | uuid | NOT NULL |  |  |                                                                                                |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
|                                                                                                                                      |
| ### usuarios  ·  RLS ✓                                                                                                               |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL |  |  |                                                                                                       |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | rol_id | uuid | NULL |  |  |                                                                                                       |
| | nombre | text | NOT NULL |  |  |                                                                                                   |
| | email | text | NOT NULL |  |  |                                                                                                    |
| | estado | text | NOT NULL | 'activo'::text |  |                                                                                     |
| | primer_login | boolean | NOT NULL | true |  |                                                                                      |
| | ultimo_acceso | timestamp with time zone | NULL |  |  |                                                                            |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | es_super_admin | boolean | NULL | false |  |                                                                                       |
| | telefono | text | NULL |  |  |                                                                                                     |
|                                                                                                                                      |
| ### whatsapp_destinatarios  ·  RLS ✓                                                                                                 |
|                                                                                                                                      |
| *Números de WhatsApp configurados por cada empresa para recibir alertas (ej. stock bajo)*                                            |
|                                                                                                                                      |
| | Columna | Tipo | Null | Default | Nota |                                                                                           |
| |---|---|---|---|---|                                                                                                                |
| | id | uuid | NOT NULL | gen_random_uuid() |  |                                                                                      |
| | empresa_id | uuid | NOT NULL |  |  |                                                                                               |
| | usuario_id | uuid | NOT NULL |  |  |                                                                                               |
| | activo | boolean | NOT NULL | true |  |                                                                                            |
| | created_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
| | updated_at | timestamp with time zone | NOT NULL | now() |  |                                                                      |
|                                                                                                                                      |
| ## Políticas RLS                                                                                                                     |
|                                                                                                                                      |
| | Tabla | Política | Cmd | USING | WITH CHECK |                                                                                      |
| |---|---|---|---|---|                                                                                                                |
| | adjuntos | adjuntos_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                                       |
| | audit_log | audit_log_select | SELECT | `((empresa_id = get_empresa_id()) OR es_super_admin())` | `` |                             |
| | categorias_repuestos | categorias_repuestos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                            |
| | config_plazos | config_plazos_super_admin_select | SELECT | `es_super_admin()` | `` |                                              |
| | config_plazos | config_plazos_super_admin_update | UPDATE | `es_super_admin()` | `` |                                              |
| | empresas | super_admin_ver_empresas | SELECT | `es_super_admin()` | `` |                                                           |
| | empresas | usuarios pueden ver su propia empresa | SELECT | `(id = get_empresa_id())` | `` |                                       |
| | empresas | super_admin_actualizar_empresas | UPDATE | `es_super_admin()` | `es_super_admin()` |                                    |
| | empresas | super_admin_editar_storage_limit | UPDATE | `es_super_admin()` | `es_super_admin()` |                                   |
| | ingreso_repuestos | ingreso_repuestos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                  |
| | lecturas_maquina | lecturas_maquina_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                    |
| | maquina_documentos | maquina_documentos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `(empresa_id = get_empresa_id())` | |
| | maquinas | maquinas_mi_empresa | ALL | `((empresa_id = get_empresa_id()) AND ((NOT fn_usuario_restringido_sector()) OR (` | `` |   |
| | notificaciones | notificaciones_insertar | INSERT | `` | `(empresa_id = get_empresa_id())` |                                       |
| | notificaciones | notificaciones_leer_propias | SELECT | `(para_usuario_id = auth.uid())` | `` |                                    |
| | notificaciones | notificaciones_actualizar_propias | UPDATE | `(para_usuario_id = auth.uid())` | `` |                              |
| | permisos | permisos_lectura_publica | SELECT | `true` | `` |                                                                       |
| | planes | planes_super_admin_gestionar | ALL | `es_super_admin()` | `es_super_admin()` |                                            |
| | planes | planes_leer_activos | SELECT | `((activo = true) OR es_super_admin())` | `` |                                             |
| | planes_mantenimiento | planes_mantenimiento_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                            |
| | proveedores | proveedores_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                              |
| | repuestos | repuestos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                                  |
| | repuestos_maquinas | repuestos_maquinas_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `(empresa_id = get_empresa_id())` | |
| | rol_permisos | rol_permisos_mi_empresa | ALL | `(rol_id IN ( SELECT roles.id                                                       |
|    FROM roles                                                                                                                        |
|   WHERE (roles.empresa_id = get_empre` | `` |                                                                                        |
| | roles | roles_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                                          |
| | salida_repuestos | salida_repuestos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                    |
| | sectores | sectores_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                                    |
| | ticket_fotos | ticket_fotos_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `(empresa_id = get_empresa_id())` |             |
| | ticket_historial | ticket_historial_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `(empresa_id = get_empresa_id())` |     |
| | tickets | tickets_mi_empresa | ALL | `((empresa_id = get_empresa_id()) AND ((NOT fn_usuario_restringido_sector()) OR (` | `` |     |
| | tipos_intervalo | tipos_intervalo_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `` |                                      |
| | usuario_sector | usuario_sector_mi_empresa | ALL | `(empresa_id = get_empresa_id())` | `(empresa_id = get_empresa_id())` |         |
| | usuarios | usuarios_admin_insertar | INSERT | `` | `((empresa_id = get_empresa_id()) OR es_super_admin())` |                       |
| | usuarios | usuarios_leer_propio | SELECT | `(id = auth.uid())` | `` |                                                              |
| | usuarios | usuarios_ver_mi_empresa | SELECT | `(empresa_id = get_empresa_id())` | `` |                                             |
| | usuarios | usuarios_actualizar_propio | UPDATE | `(id = auth.uid())` | `` |                                                        |
| | usuarios | usuarios_admin_actualizar | UPDATE | `((empresa_id = get_empresa_id()) OR es_super_admin())` | `` |                     |
| | whatsapp_destinatarios | whatsapp_destinatarios_delete | DELETE | `(empresa_id = get_empresa_id())` | `` |                         |
| | whatsapp_destinatarios | whatsapp_destinatarios_insert | INSERT | `` | `(empresa_id = get_empresa_id())` |                         |
| | whatsapp_destinatarios | whatsapp_destinatarios_select | SELECT | `(empresa_id = get_empresa_id())` | `` |                         |
| | whatsapp_destinatarios | whatsapp_destinatarios_update | UPDATE | `(empresa_id = get_empresa_id())` | `` |                         |
|                                                                                                                                      |
| ## Funciones                                                                                                                         |
|                                                                                                                                      |
| | Función | Security | Args | Retorna |                                                                                              |
| |---|---|---|---|                                                                                                                    |
| | _dias_plazo | DEFINER | p_clave text | integer |                                                                                   |
| | admin_categorias_empresa | DEFINER | p_empresa_id uuid | SETOF categorias_repuestos |                                              |
| | admin_maquinas_empresa | DEFINER | p_empresa_id uuid | SETOF maquinas |                                                            |
| | admin_repuestos_empresa | DEFINER | p_empresa_id uuid | SETOF repuestos |                                                          |
| | admin_sectores_empresa | DEFINER | p_empresa_id uuid | SETOF sectores |                                                            |
| | admin_tickets_empresa | DEFINER | p_empresa_id uuid | TABLE(id uuid, numero text, estado text, |                                   |
| | admin_usuarios_empresa | DEFINER | p_empresa_id uuid | TABLE(id uuid, nombre text, email text,  |                                  |
| | aprobar_empresa | DEFINER | p_empresa_id uuid | void |                                                                             |
| | crear_rol | DEFINER | p_nombre text | uuid |                                                                                       |
| | crear_ticket | DEFINER | p_maquina_id uuid, p_descripcion text, p_foto_url text DEFAULT NULL::text | uuid |                        |
| | dashboard_kpis | DEFINER | (sin args) | jsonb |                                                                                    |
| | eliminar_rol | DEFINER | p_rol_id uuid | void |                                                                                    |
| | es_super_admin | DEFINER | (sin args) | boolean |                                                                                  |
| | establecer_permisos_rol | DEFINER | p_rol_id uuid, p_permiso_ids uuid[] | void |                                                   |
| | estado_mi_empresa | DEFINER | (sin args) | text |                                                                                  |
| | fn_audit_log | DEFINER | (sin args) | trigger |                                                                                    |
| | fn_check_stock_bajo | DEFINER | (sin args) | trigger |                                                                             |
| | fn_marcar_empresas_a_purgar | DEFINER | (sin args) | void |                                                                        |
| | fn_proteger_audit_log | INVOKER | (sin args) | trigger |                                                                           |
| | fn_sectores_usuario | DEFINER | (sin args) | uuid[] |                                                                              |
| | fn_set_empresa_maquina_documentos | DEFINER | (sin args) | trigger |                                                               |
| | fn_set_empresa_notificaciones | DEFINER | (sin args) | trigger |                                                                   |
| | fn_set_empresa_repuestos_maquinas | DEFINER | (sin args) | trigger |                                                               |
| | fn_set_empresa_ticket_fotos | DEFINER | (sin args) | trigger |                                                                     |
| | fn_set_empresa_ticket_historial | DEFINER | (sin args) | trigger |                                                                 |
| | fn_set_empresa_usuario_sector | DEFINER | (sin args) | trigger |                                                                   |
| | fn_usuario_restringido_sector | DEFINER | (sin args) | boolean |                                                                   |
| | fn_validar_empresa_maquina_sector | INVOKER | (sin args) | trigger |                                                               |
| | fn_validar_empresa_repuesto_categoria | INVOKER | (sin args) | trigger |                                                           |
| | fn_validar_empresa_usuario_rol | INVOKER | (sin args) | trigger |                                                                  |
| | generar_numero_ticket | DEFINER | p_empresa_id uuid | text |                                                                       |
| | get_config_plazos | DEFINER | (sin args) | SETOF config_plazos |                                                                   |
| | get_empresa_id | DEFINER | (sin args) | uuid |                                                                                     |
| | get_mtbf_empresa | DEFINER | (sin args) | TABLE(maquina_id uuid, maquina_nombre te |                                               |
| | listar_empresas_pendientes | DEFINER | (sin args) | TABLE(empresa_id uuid, empresa_nombre te |                                     |
| | listar_todas_empresas | DEFINER | (sin args) | TABLE(empresa_id uuid, empresa_nombre te |                                          |
| | mis_permisos | DEFINER | (sin args) | SETOF text |                                                                                 |
| | proteger_campos_usuario | DEFINER | (sin args) | trigger |                                                                         |
| | registrar_ingreso_stock | DEFINER | p_repuesto_id uuid, p_cantidad integer, p_proveedor_id uuid DEFAULT NULL::uuid,  | void |      |
| | registrar_salida_stock | DEFINER | p_repuesto_id uuid, p_cantidad integer, p_ticket_id uuid DEFAULT NULL::uuid, p_o | void |       |
| | renombrar_rol | DEFINER | p_rol_id uuid, p_nombre text | void |                                                                    |
| | rls_auto_enable | DEFINER | (sin args) | event_trigger |                                                                           |
| | rut_uy_valido | INVOKER | rut text | boolean |                                                                                     |
| | sa_export_empresa | DEFINER | p_empresa_id uuid | jsonb |                                                                          |
| | sa_generar_doc_esquema | DEFINER | (sin args) | text |                                                                             |
| | sa_purgar_datos_empresa | DEFINER | p_empresa_id uuid | jsonb |                                                                    |
| | sa_reactivar_empresa | DEFINER | p_empresa_id uuid | void |                                                                        |
| | sa_solicitar_baja | DEFINER | p_empresa_id uuid | void |                                                                           |
| | sa_suspender_empresa | DEFINER | p_empresa_id uuid | void |                                                                        |
| | set_config_plazo | DEFINER | p_clave text, p_dias integer | void |                                                                 |
| | unaccent | INVOKER | regdictionary, text | text |                                                                                  |
| | unaccent | INVOKER | text | text |                                                                                                 |
| | unaccent_immutable | INVOKER | text | text |                                                                                       |
| | unaccent_init | INVOKER | internal | internal |                                                                                    |
| | unaccent_lexize | INVOKER | internal, internal, internal, internal | internal |                                                    |
| | update_updated_at | INVOKER | (sin args) | trigger |                                                                               |
| | uso_storage_empresa | DEFINER | p_empresa_id uuid | jsonb |                                                                        |
|                                                                                                                                      |
| ## Triggers                                                                                                                          |
|                                                                                                                                      |
| | Tabla | Trigger | Timing | Evento | Función |                                                                                      |
| |---|---|---|---|---|                                                                                                                |
| | audit_log | trg_proteger_audit_log | BEFORE | DELETE, UPDATE | fn_proteger_audit_log() |                                           |
| | categorias_repuestos | trg_audit_categorias_repuestos | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                          |
| | empresas | trg_audit_empresas | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                  |
| | ingreso_repuestos | trg_audit_ingreso_repuestos | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                |
| | lecturas_maquina | trg_audit_lecturas_maquina | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                  |
| | maquina_documentos | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_maquina_documentos() |                                     |
| | maquinas | trg_audit_maquinas | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                  |
| | maquinas | trg_validar_empresa_maquina_sector | BEFORE | INSERT, UPDATE | fn_validar_empresa_maquina_sector() |                    |
| | notificaciones | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_notificaciones() |                                             |
| | planes_mantenimiento | trg_audit_planes_mantenimiento | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                          |
| | proveedores | proveedores_updated_at | BEFORE | UPDATE | update_updated_at() |                                                     |
| | proveedores | trg_audit_proveedores | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                            |
| | repuestos | repuestos_updated_at | BEFORE | UPDATE | update_updated_at() |                                                         |
| | repuestos | trg_audit_repuestos | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                |
| | repuestos | trg_stock_bajo | AFTER | UPDATE | fn_check_stock_bajo() |                                                              |
| | repuestos | trg_validar_empresa_repuesto_categoria | BEFORE | INSERT, UPDATE | fn_validar_empresa_repuesto_categoria() |           |
| | repuestos_maquinas | trg_audit_repuestos_maquinas | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                              |
| | repuestos_maquinas | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_repuestos_maquinas() |                                     |
| | rol_permisos | trg_audit_rol_permisos | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                          |
| | roles | trg_audit_roles | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                        |
| | salida_repuestos | trg_audit_salida_repuestos | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                  |
| | sectores | trg_audit_sectores | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                  |
| | ticket_fotos | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_ticket_fotos() |                                                 |
| | ticket_historial | trg_audit_ticket_historial | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                  |
| | ticket_historial | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_ticket_historial() |                                         |
| | tickets | tickets_updated_at | BEFORE | UPDATE | update_updated_at() |                                                             |
| | tickets | trg_audit_tickets | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                    |
| | tipos_intervalo | trg_audit_tipos_intervalo | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                    |
| | usuario_sector | trg_audit_usuario_sector | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                      |
| | usuario_sector | trg_set_empresa | BEFORE | INSERT | fn_set_empresa_usuario_sector() |                                             |
| | usuarios | trg_audit_usuarios | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                                                  |
| | usuarios | trg_proteger_campos_usuario | BEFORE | UPDATE | proteger_campos_usuario() |                                             |
| | usuarios | trg_validar_empresa_usuario_rol | BEFORE | INSERT, UPDATE | fn_validar_empresa_usuario_rol() |                          |
| | usuarios | usuarios_updated_at | BEFORE | UPDATE | update_updated_at() |                                                           |
| | whatsapp_destinatarios | trg_audit_whatsapp_destinatarios | AFTER | DELETE, INSERT, UPDATE | fn_audit_log() |                      |
| | whatsapp_destinatarios | whatsapp_destinatarios_updated_at | BEFORE | UPDATE | update_updated_at() |                               |
|                                                                                                                                      |