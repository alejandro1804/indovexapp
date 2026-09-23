# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Regla obligatoria de estructura

**No crear, mover ni renombrar carpetas o archivos sin consultar primero al usuario.** `ESTRUCTURA.md` (regenerado con `.\generar_estructura.ps1`) es la referencia obligatoria del orden de carpetas del proyecto — respetá esa organización y no la alteres unilateralmente. Cualquier cambio de ubicación, nombre o creación de carpetas/archivos nuevos requiere confirmación explícita del usuario antes de ejecutarse.

## Qué es este proyecto

IndovexApp: app Flutter (Android/iOS/Web/Windows/Linux/macOS) de gestión industrial y mantenimiento — máquinas, planes de mantenimiento preventivo/correctivo, tickets, repuestos/stock, proveedores, y administración multiempresa con roles y permisos. Backend en Supabase (Postgres + Auth + Storage + Edge Functions) y notificaciones push vía Firebase Cloud Messaging.

## Comandos comunes

```powershell
flutter pub get                 # instalar dependencias
flutter run                     # correr en el dispositivo/emulador conectado
flutter run -d chrome           # correr en web
flutter run -d windows          # correr en Windows desktop
flutter analyze                 # linter estático (flutter_lints)
flutter test                    # correr todos los tests
flutter test test/widget_test.dart   # correr un test puntual
flutter build apk / flutter build web / flutter build windows   # builds de release
```

Regenerar documentación auto-generada (ver `COMO_ACTUALIZAR_DOCS.md` para el detalle paso a paso):
- Esquema de la DB → correr `SELECT sa_generar_doc_esquema();` en el SQL Editor de Supabase y pegar el resultado en `supabase\DB_Esquema.md`.
- Árbol de carpetas → `.\generar_estructura.ps1` regenera `ESTRUCTURA.md` (revisar la sección "Alertas del criterio de orden" al final).

Edge Functions de Supabase (Deno) viven en `supabase/functions/*`; cada una tiene su propio `deno.json`. Se despliegan con la Supabase CLI (`supabase functions deploy <nombre>`), no hay script propio en este repo para eso.

## Arquitectura

**Capas dentro de `lib/`:**
- `core/` — infraestructura transversal: cliente de Supabase (`supabase_client.dart`), constantes (colores, URLs), helpers de errores de DB (`db_error_helper.dart`, incluye traducción de códigos Postgres como `23505`/`23503`/`23502` a mensajes en español), subida de documentos/imágenes con implementaciones separadas para mobile vs web (`document_helper_mobile.dart` / `document_helper_web.dart` detrás de `document_helper.dart`), y utilidades responsive.
- `models/` — clases de datos planas con `fromMap`/`toMap` que mapean 1:1 filas de tablas Postgres.
- `services/` — una clase por entidad (`MaquinaService`, `TicketService`, `RepuestoService`, etc.) que envuelve llamadas directas a `Supabase.instance.client.from(...)`. Los servicios NO filtran manualmente por empresa: el multi-tenant se resuelve enteramente vía RLS (Row Level Security) en Postgres según el usuario autenticado. También hay servicios de generación de PDF (`*_pdf_service.dart`, usan `pdf`/`printing`).
- `providers/` — estado de la app con `ChangeNotifier` + `package:provider` (no `go_router` a pesar de estar en `pubspec.yaml`: la navegación real es con `Navigator`/`MaterialPageRoute` manuales, ver `main.dart`). `AuthProvider` es el central: carga el usuario, sus permisos (vía RPC `mis_permisos`), datos de la empresa (plan/trial) y expone `tienePermiso(codigo)`.
- `screens/` — organizadas por módulo funcional (`admin/`, `auth/`, `maquinas/`, `planes_mantenimiento/`, `repuestos/`, `tickets/`, `dashboard/`, `reportes/`, `pagos/`, `configuracion/`, `notificaciones/`, `home/`).
- `widgets/` — componentes reutilizables entre pantallas (secciones de adjuntos, repuestos de ticket/máquina, campana de notificaciones, gate de aceptación legal).

**Autenticación y sesión:** `main.dart` define `AuthGate`, que al iniciar chequea sesión de Supabase, carga el usuario (bloqueando si `estado != 'activo'` o si la empresa no está `activa`, vía RPC `estado_mi_empresa`), y redirige a login/cambio de contraseña obligatorio (`primerLogin`)/home. También maneja deep links (`https://app.indovexapp.com/maquina/{id}`) guardándolos si aún no hay sesión o el home no está montado, y recovery de contraseña vía el evento `passwordRecovery` de Supabase Auth.

**Multi-tenant y permisos:** cada tabla de negocio tiene `empresa_id` y políticas RLS (ver `supabase/DB_Esquema.md`, fuente de verdad del esquema — no editar a mano). Los permisos de usuario son códigos string (ej. `gestionar_usuarios`, `gestionar_roles`) resueltos por rol vía la RPC `mis_permisos`; el super admin implícitamente tiene todos los permisos (`Usuario.tienePermiso` lo chequea aparte). Roles pueden además `restringe_por_sector`.

**Backend (Supabase):**
- `supabase/migrations/` — SQL versionado. Ojo: las migraciones nombradas con guion en la fecha (`2026-06-04_...` en vez de `20260604_...`) son salteadas por la Supabase CLI; están señaladas como alerta en `ESTRUCTURA.md`. Nuevas migraciones deben usar el formato `YYYYMMDD_descripcion.sql` sin guiones en la fecha.
- `supabase/functions/*` — Edge Functions en Deno/TypeScript para operaciones que no pueden vivir en RLS/triggers: aprobación de empresas, suscripciones/pagos (Mercado Pago), envío de emails (función central `enviar-email` que otras funciones invocan pasándole solo el contenido, no el layout), envío de push, generación de tickets preventivos, notificación de stock bajo, alta/reseteo de usuarios, purga de empresa.

**Notificaciones push:** Firebase Cloud Messaging vía `firebase_messaging` + `flutter_local_notifications`, inicializado en `main.dart` (`PushService.initRecepcion()`) antes de Supabase. El registro/desregistro de dispositivo ocurre en `login`/`logout` de `AuthProvider`.

**Validaciones de negocio replicadas en Dart:** `db_error_helper.dart` reimplementa en Dart validaciones que también existen como CHECK constraints en la DB (formato de email, RUT uruguayo con dígito verificador módulo 11) para dar feedback inmediato en el form antes del round-trip al servidor — si se cambia una de estas reglas, hay que actualizar ambos lados.

## Reglas del proyecto (obligatorias)

### Forma de trabajo
- Trabajar por tandas chicas; esperar mi validación entre tandas.
- Después de cada cambio: `flutter analyze`. Solo se aceptan 2 issues preexistentes e intencionales: dart:html en document_helper_web.dart y _navegarCuandoListo sin uso.
- Terminal: PowerShell (ej. `gci -r -filter`, no `dir /S /B`).
- No hacer commits, push ni deploys (web ni Edge Functions): los hago yo.

### Prohibido
- Nunca ejecutar `flutter clean`: destruye build\web/.git, CNAME y .nojekyll (build\web es un repo de deploy aparte).
- Nunca `git add -A -f` fuera de build\web.
- No leer ni modificar `.env`.

### Nombres
- En la UI, Máquina se muestra como "Activo" y Sector como "Ubicación". Es solo visual: tablas, columnas, clases, servicios, rutas, keys de storage, RPCs y códigos de permisos mantienen los nombres originales. Nunca renombrarlos.

### Base de datos
- Tablas append-only (aceptaciones_legales, audit_log, pagos_suscripcion): nunca UPDATE ni DELETE.
- Soft delete siempre: usuarios y empresas nunca se borran físicamente.
- Los límites por plan salen de fn_limites_plan() (fuente única); no se editan a mano.
- SQL nuevo: entregarlo como archivo de migración para que yo lo corra en el SQL Editor de Supabase, no ejecutarlo contra la base.