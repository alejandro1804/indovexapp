# ============================================================
# generar_estructura.ps1 (v2 - iterativa, sin recursion)
# Arbol de carpetas + alertas del criterio de orden IndovexApp
# Uso: .\generar_estructura.ps1
# ============================================================

$raiz = Get-Location
$out = "ESTRUCTURA.md"
$ignorar = @('.git','.dart_tool','build','.idea','.vscode','node_modules','.gradle','.temp')

$lineas = @()
$alertas = @()

$lineas += "# IndovexApp - Estructura de Carpetas (auto-generada)"
$lineas += ""
$lineas += "Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$lineas += ""

# --- Listado de archivos (plano, con indentacion por profundidad) ---
$archivos = Get-ChildItem -Recurse -File | Where-Object {
    $ruta = $_.FullName
    $saltar = $false
    foreach ($ig in $ignorar) {
        if ($ruta -like "*\$ig\*") { $saltar = $true; break }
    }
    -not $saltar
} | Sort-Object FullName

foreach ($a in $archivos) {
    $rel = $a.FullName.Substring($raiz.Path.Length + 1)
    $prof = ($rel.ToCharArray() | Where-Object { $_ -eq '\' }).Count
    $indent = "  " * $prof
    $nombre = Split-Path $rel -Leaf
    $lineas += "$indent$nombre"

    # --- Reglas del criterio de orden ---

    # Migracion con guiones (el CLI las saltea)
    if ($rel -like "supabase\migrations\*" -and $nombre -match '^\d{4}-\d{2}-\d{2}') {
        $alertas += "Migracion con guiones (CLI la saltea): $nombre"
    }

    # Backups / zips sueltos
    if ($nombre -like "*.zip" -or $nombre -like "*.bak" -or $nombre -like "*.old" -or $nombre -like "* - copia*") {
        $alertas += "Backup/zip suelto en repo: $rel"
    }

    # .env versionado (riesgo de secrets)
    if ($nombre -eq ".env") {
        $alertas += "ATENCION .env en el repo - verificar que este en .gitignore: $rel"
    }
}

$lineas += ""
$lineas += "## Alertas del criterio de orden"
$lineas += ""
if ($alertas.Count -eq 0) {
    $lineas += "Sin alertas - todo encaja en el criterio."
} else {
    $lineas += "Se detectaron $($alertas.Count) item(s) para revisar:"
    $lineas += ""
    foreach ($al in $alertas) {
        $lineas += "- [!] $al"
    }
}

$lineas | Out-File -FilePath $out -Encoding utf8
Write-Host "Generado: $out - Alertas: $($alertas.Count)" -ForegroundColor Green