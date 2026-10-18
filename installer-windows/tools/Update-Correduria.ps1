#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Aplicador de actualizaciones - Correduria Local (Windows) - FASE PILOTO.

.DESCRIPTION
    EL MECANISMO update-install ES INTERNO DE LA APLICACION correduria-server.
    Windows no aporta ninguno propio para aplicaciones de terceros (Windows Update
    solo actualiza Windows; winget es un gestor de paquetes generico).

    Mientras correduria-server.exe no incorpore el subcomando 'update-install'
    (fase 2, repositorio privado), este script es el aplicador externo de fase
    piloto:

      1. Descarga el manifiesto firmado del canal
         (schema: payload{version, platform, architecture, artifact_url,
          artifact_name, size_bytes, sha256} + signature Ed25519).
      2. Comprueba que el manifiesto declara platform=windows / architecture=amd64.
      3. Descarga el artefacto y verifica SHA-256 y tamano (integridad de transporte).
      4. Detiene el servicio (WinSW), guarda la version anterior en
         %ProgramFiles%\Correduria\backup-anterior-<fecha>, sustituye los ficheros
         y arranca el servicio.

    LIMITACION FASE PILOTO: la verificacion COMPLETA de la firma Ed25519 del
    manifiesto y del derecho de actualizacion (entitlement) es potestad de la
    aplicacion (Mantenimiento -> Comprobar actualizaciones). Este script verifica
    hash y tamano (integridad del transporte).
    TODO (fase 2): cuando correduria-server.exe exponga 'update-install', este
    script descargara y delegara en el la verificacion de firma + entitlement.

.PARAMETER ManifestUrl
    URL del manifiesto firmado del canal.

.PARAMETER InstallDir
    Carpeta de instalacion (por defecto %ProgramFiles%\Correduria).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\Update-Correduria.ps1
#>
[CmdletBinding()]
param(
    [string]$ManifestUrl = 'https://github.com/pericorl-tech/correduria-release/releases/latest/download/manifest-latest.json',
    [string]$InstallDir = (Join-Path ${env:ProgramFiles} 'Correduria')
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

function Info($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "[OK] $m" -ForegroundColor Green }
function Fatal($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

$winsw   = Join-Path $InstallDir 'correduria-service.exe'
$binario = Join-Path $InstallDir 'correduria-server.exe'
if (-not (Test-Path $winsw)) { Fatal ('No hay instalacion de Correduria en ' + $InstallDir) }

# ---------------------------------------------------------------------------
# 1. Manifiesto firmado
# ---------------------------------------------------------------------------
Info ('Descargando manifiesto: ' + $ManifestUrl)
$manifestFile = Join-Path $env:TEMP 'correduria-manifest.json'
Invoke-WebRequest -Uri $ManifestUrl -OutFile $manifestFile -UseBasicParsing
$json = Get-Content $manifestFile -Raw | ConvertFrom-Json
if ($null -eq $json.payload) { Fatal 'El manifiesto no tiene el bloque "payload" esperado.' }
$payload = $json.payload

# 2. Comprobacion de plataforma del manifiesto
$platform = [string]$payload.platform
$arch     = [string]$payload.architecture
if ($platform -ne 'windows') {
    Fatal ('El manifiesto del canal declara platform=' + $platform + ' (' + $arch + '). El canal de actualizaciones para Windows (artefactos win32-x64) AUN NO esta publicado (fase 2). Este instalador solo puede actualizarse con este canal cuando existan artefactos windows.')
}

$version     = [string]$payload.version
$artifactUrl = [string]$payload.artifact_url
$sha256Esperado = [string]$payload.sha256
$tamanoEsperado = 0
if ($payload.PSObject.Properties['size_bytes']) { $tamanoEsperado = [int64]$payload.size_bytes }
Info ('Version publicada para Windows: ' + $version)

# ---------------------------------------------------------------------------
# 3. Descarga del artefacto + verificacion de integridad (hash + tamano)
# ---------------------------------------------------------------------------
if ($artifactUrl -eq '') { Fatal 'El manifiesto no declara artifact_url.' }
$tmpDir = Join-Path $env:TEMP ('correduria-update-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$artifactFile = Join-Path $tmpDir ([string]$payload.artifact_name)
Info ('Descargando ' + $payload.artifact_name)
Invoke-WebRequest -Uri $artifactUrl -OutFile $artifactFile -UseBasicParsing

$sha = (Get-FileHash $artifactFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sha256Esperado -ne '' -and $sha -ne $sha256Esperado.ToLowerInvariant()) {
    Fatal 'SHA-256 NO coincide con el manifiesto. No se aplicara la actualizacion.'
}
if ($tamanoEsperado -gt 0 -and (Get-Item $artifactFile).Length -ne $tamanoEsperado) {
    Fatal 'El tamano del artefacto no coincide con el manifiesto.'
}
Ok ('Integridad verificada (SHA-256 + tamano). Firma Ed25519: comprobar en Mantenimiento (la app) o fase 2 (delegate en update-install).')

# ---------------------------------------------------------------------------
# 4. Parar servicio, sustituir ficheros, arrancar
# ---------------------------------------------------------------------------
Info 'Deteniendo servicio CorreduriaLocal'
& (Join-Path $InstallDir 'correduria-service.exe') stop 2>&1 | Out-Null
Start-Sleep -Seconds 3

$backup = Join-Path $InstallDir ('backup-anterior-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Info ('Version anterior guardada en ' + $backup)
Copy-Item -Path (Join-Path $InstallDir 'correduria-server.exe') -Destination $backup -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $InstallDir 'correduria-service.xml') -Destination $backup -Force -ErrorAction SilentlyContinue

$staging = Join-Path $tmpDir 'nuevo'
Expand-Archive -Path $artifactFile -DestinationPath $staging -Force
Copy-Item -Path (Join-Path $staging '*') -Destination $InstallDir -Recurse -Force
Ok 'Ficheros sustituidos'

Info 'Arrancando servicio'
& (Join-Path $InstallDir 'correduria-service.exe') start
Start-Sleep -Seconds 5

try {
    Invoke-WebRequest -Uri 'http://127.0.0.1:8080/' -UseBasicParsing -TimeoutSec 15 | Out-Null
    Ok ('Aplicacion actualizada a ' + $version + ' y respondiendo.')
} catch {
    Fatal ('La aplicacion no responde tras la actualizacion. Rollback manual: para el servicio, restaura los ficheros de ' + $backup + ' y arranca de nuevo.')
}

Write-Host ''
Write-Host 'Recordatorio: la verificacion de firma Ed25519 y del entitlement corresponde'
Write-Host 'a la aplicacion (pestanas de Mantenimiento). Cuando correduria-server.exe'
Write-Host 'incorpore "update-install", este script delegara en el la comprobacion completa.'
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
