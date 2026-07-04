# Cómo actualizar la documentación

Guía de referencia para regenerar la documentación auto-generada de IndovexApp.
Toda la doc se genera desde la fuente de verdad (la DB y el filesystem), así que
nunca queda desactualizada mientras se regenere.

---

## 1. Documentación del esquema de la DB

Incluye: tablas, columnas, políticas RLS, funciones y triggers.

**Cuándo:** cada vez que cambiás algo en la base (nueva columna, política, función, etc.).

**Paso a paso:**

1. Abrir el **SQL Editor** de Supabase.
2. Verificar que abajo a la derecha el límite esté en **"No limit"** (no "100 rows").
   Si no, hacer click ahí y elegir "No limit".
3. Correr esta línea:

   ```sql
   SELECT unnest(string_to_array(sa_generar_doc_esquema(), E'\n')) AS linea;
   ```

4. Seleccionar toda la columna `linea`, copiar.
5. Pegar en `supabase\DB_Esquema.md`, **reemplazando todo el contenido anterior**.
6. Guardar.

> La función `sa_generar_doc_esquema()` ya vive en la DB — no hay que recrearla.
> Solo se corre el SELECT.

---

## 2. Documentación del árbol de carpetas

Incluye: listado de archivos + alertas del criterio de orden
(migraciones con guiones, backups/zips sueltos, .env filtrado).

**Cuándo:** cada vez que agregás, movés o borrás archivos del repo.

**Paso a paso:**

1. Abrir PowerShell en la raíz del repo:

   ```powershell
   cd C:\Users\aleja\Documents\GitHub\indovexapp
   ```

2. Correr el script:

   ```powershell
   .\generar_estructura.ps1
   ```

3. Eso regenera `ESTRUCTURA.md`. Revisar la sección "Alertas del criterio de orden"
   al final del archivo por si aparece algo para ordenar.

---

## 3. Guardar en Git (siempre al final)

Después de regenerar una o ambas docs:

```powershell
git add supabase\DB_Esquema.md ESTRUCTURA.md
git commit -m "docs: actualizar esquema y estructura"
git push origin main
```

El `git diff` (o el commit en GitHub) muestra exactamente qué cambió desde la
última vez. Ese es el hábito que mantiene la doc siempre al día.

---

## Resumen rápido

| Cambió... | Corrés... | Pegás/generás en... |
|---|---|---|
| Algo en la DB | `SELECT sa_generar_doc_esquema()` (en Supabase) | `supabase\DB_Esquema.md` |
| Archivos del repo | `.\generar_estructura.ps1` (en PowerShell) | `ESTRUCTURA.md` (automático) |
| Cualquiera de los dos | Los 3 comandos de git | — |

---

## Cabos sueltos anotados (sin urgencia)

- Revisar si `ticket_preventivo_correctivo.sql` y `tickets_preventivo_correctivo.sql`
  son migraciones duplicadas (una podría ser basura).
- Opcional: renombrar las migraciones con guiones (`2026-06-...`) al formato sin
  guiones (`20260604_...`). Es cosmético; la DB no se afecta. Recordá: los guiones
  hacen que el CLI saltee la migración.
