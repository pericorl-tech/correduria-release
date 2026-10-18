#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instalador guiado - Plataforma Correduria Local (Windows 10/11 x64) - FASE PILOTO.

.DESCRIPTION
    Prepara un equipo Windows nuevo de cero y pregunta TODAS las configuraciones
    en un unico flujo (nombre del equipo/hostname, zona horaria, modo de acceso,
    puerto, datos, backups, canal de actualizaciones). Equivalente en PowerShell
    de install.sh (repositorio correduria-installer-linux).

    NO pide credenciales de aplicacion (SMTP, IA, cuenta): se introducen en la
    interfaz web tras el primer arranque y se guardan cifradas en la base de datos.

    IMPORTANTE: el mecanismo update-install es INTERNO de la aplicacion
    correduria-server (no lo aporta Windows). Mientras el .exe no incorpore el
    subcomando (fase 2, repositorio privado), las actualizaciones de fase piloto
    se aplican con tools/Update-Correduria.ps1.

.PARAMETER Package
    Ruta o URL del artefacto correduria-local_<version>_win32-x64.zip.

.PARAMETER AnswersFile
    Fichero KEY=VAL para instalacion desatendida (ver answers.example.conf).

.PARAMETER SoloConfig
    Solo reconfigura una instalacion existente (no copia ficheros del paquete).

.PARAMETER Yes
    Acepta los valores por defecto de los avisos.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1
#>
[CmdletBinding()]
param(
    [string]$Package = '',
    [string]$AnswersFile = '',
    [string]$InstallDir = (Join-Path ${env:ProgramFiles} 'Correduria'),
    [switch]$SoloConfig,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
try {
    # Habilitar TLS 1.2 para las descargas (Windows PowerShell 5.1)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$InstaladorVersion = '0.1.0'

# ---------------------------------------------------------------------------
# Valores por defecto (sobrescribibles por -AnswersFile o por prompt)
# ---------------------------------------------------------------------------
$EquipoNombre        = $env:COMPUTERNAME
$ZonaHoraria         = 'Romance Standard Time'
$ModoAcceso          = 'tailscale'   # local | tailscale | caddy | lan
$Puerto              = 8080
$UrlPublica          = ''
$DataDir             = Join-Path $env:ProgramData 'Correduria'
$BackupDir           = Join-Path $DataDir 'backups'
$ManifestUrl         = 'https://github.com/pericorl-tech/correduria-release/releases/latest/download/manifest-latest.json'
$PublicKeyFile       = ''
$EntitlementFile     = ''
$DominioLan          = 'correduria.local'
$InstalarTailscale   = $true
$TsAuthKey           = $env:TS_AUTH_KEY   # opcional; nunca se persiste en disco

$CuentaServicio = 'NT AUTHORITY\LocalService'   # fase piloto; fase 2: cuenta dedicada CorreduriaSvc
$BinarioApp       = 'correduria-server.exe'
$NombreServicio   = 'CorreduriaLocal'

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
function Info($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "[OK] $m" -ForegroundColor Green }
function Aviso($m) { Write-Warning $m }
function Fatal($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

function Banner() {
    Write-Host ''
    Write-Host '=================================================================' -ForegroundColor White
    Write-Host ('   Instalador - Plataforma Correduria Local v' + $InstaladorVersion + ' (Windows)') -ForegroundColor White
    Write-Host '=================================================================' -ForegroundColor White
}

function Ask($texto, $defecto) {
    if ($Yes) { return $defecto }
    $v = Read-Host "$texto [$defecto]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $defecto }
    return $v.Trim()
}

function AskBool($texto, $defecto) {
    if ($Yes) { return $defecto }
    $sufijo = '[S/n]'
    if (-not $defecto) { $sufijo = '[s/N]' }
    $v = Read-Host "$texto $sufijo"
    if ([string]::IsNullOrWhiteSpace($v)) { return $defecto }
    $v = $v.Trim().ToLowerInvariant()
    return ($v -eq 's' -or $v -eq 'si' -or $v -eq 'yes' -or $v -eq 'y' -or $v -eq '1')
}

# ---------------------------------------------------------------------------
# Fichero de respuestas (KEY=VAL) para modo desatendido
# ---------------------------------------------------------------------------
if ($AnswersFile -ne '') {
    if (-not (Test-Path $AnswersFile)) { Fatal "No existe el fichero de respuestas: $AnswersFile" }
    Get-Content $AnswersFile | ForEach-Object {
        $linea = $_.Trim()
        if ($linea -eq '' -or $linea.StartsWith('#')) { return }
        $idx = $linea.IndexOf('=')
        if ($idx -lt 1) { return }
        $clave = $linea.Substring(0, $idx).Trim()
        $valor = $linea.Substring($idx + 1).Trim()
        switch ($clave) {
            'EQUIPO_NOMBRE'        { $EquipoNombre = $valor }
            'ZONA_HORARIA'       { $ZonaHoraria = $valor }
            'MODO_ACCESO'        { $ModoAcceso = $valor.ToLowerInvariant() }
            'PUERTO'             { $Puerto = [int]$valor }
            'URL_PUBLICA'        { $UrlPublica = $valor }
            'DATA_DIR'           { $DataDir = $valor }
            'BACKUP_DIR'         { $BackupDir = $valor }
            'MANIFEST_URL'       { $ManifestUrl = $valor }
            'PUBLIC_KEY_FILE'    { $PublicKeyFile = $valor }
            'ENTITLEMENT_FILE'   { $EntitlementFile = $valor }
            'DOMINIO_LAN'        { $DominioLan = $valor }
            'INSTALAR_TAILSCALE' { $InstalarTailscale = ($valor -match '^(si|si|yes|y|1|true)$') }
            default { Aviso "Clave desconocida ignorada en el fichero de respuestas: $clave" }
        }
    }
}

# ---------------------------------------------------------------------------
# 1. Comprobaciones previas
# ---------------------------------------------------------------------------
Info 'Comprobaciones previas del equipo'
if (-not [Environment]::Is64BitOperatingSystem) { Fatal 'Se requiere Windows de 64 bits (x64).' }
$so = Get-CimInstance Win32_OperatingSystem
Info ('Sistema: ' + $so.Caption + ' build ' + $so.BuildNumber)
if ([int]$so.BuildNumber -lt 17763) { Fatal 'Se requiere Windows 10 1809 / Windows Server 2019 o superior.' }

if (Get-Service -Name $NombreServicio -ErrorAction SilentlyContinue) {
    Aviso 'Instalacion existente detectada (servicio CorreduriaLocal).'
    if (-not $SoloConfig -and (AskBool '¿Reconfigurar sin reinstalar los ficheros?' $true)) {
        $SoloConfig = [switch]::new($true)
    }
}

# ---------------------------------------------------------------------------
# 2. Datos del equipo
# ---------------------------------------------------------------------------
Banner
Info 'Paso 1/5 - Datos del equipo de instalacion'
Write-Host '   El nombre del equipo (hostname) identifica el servidor en la red Tailscale'
Write-Host '   y en los certificados. Mini PC, sobremesa o servidor: el que usted elija.'
$EquipoNombre = Ask 'Nombre del equipo (hostname)' $EquipoNombre
if ($EquipoNombre -notmatch '^[A-Za-z0-9.-]+$') { Fatal 'Nombre de equipo no valido: solo letras, numeros, guiones y puntos.' }
if ($EquipoNombre -ne $env:COMPUTERNAME -and (AskBool ('¿Aplicar ' + $EquipoNombre + ' como nombre del equipo (se aplica al reiniciar)?') $true)) {
    try {
        Rename-Computer -NewName $EquipoNombre -Force -ErrorAction Stop
        Aviso 'El nombre se aplicara al reiniciar el equipo. Continue ahora y reinicie al terminar.'
    } catch { Aviso ('No se pudo renombrar el equipo: ' + $_.Exception.Message) }
}
$EquipoNombreNormalizado = $EquipoNombre.ToLowerInvariant()

$ZonaHoraria = Ask 'Zona horaria (nombre de zona de Windows)' $ZonaHoraria
try { [void][System.TimeZoneInfo]::FindSystemTimeZoneById($ZonaHoraria) }
catch { Fatal "Zona horaria desconocida: $ZonaHoraria (ej.: Romance Standard Time)" }
Start-Process tzutil.exe -ArgumentList '/s', ('"' + $ZonaHoraria + '"') -Wait -NoNewWindow
Ok ('Equipo: ' + $EquipoNombre + '  -  Zona: ' + $ZonaHoraria)

# ---------------------------------------------------------------------------
# 3. Paquete a instalar (win32-x64)
# ---------------------------------------------------------------------------
Info 'Paso 2/5 - Paquete de la aplicacion (win32-x64)'
$PackageLocal = ''
if ($Package -match '^https?://') {
    $PackageLocal = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($Package))
    Info ('Descargando ' + $Package)
    Invoke-WebRequest -Uri $Package -OutFile $PackageLocal -UseBasicParsing
} elseif ($Package -ne '') {
    if (-not (Test-Path $Package)) { Fatal ('No existe el paquete: ' + $Package) }
    $PackageLocal = (Resolve-Path $Package).Path
} elseif ($SoloConfig) {
    # En modo solo-config no se necesita el paquete
} else {
    $dirScript = Split-Path -Parent $MyInvocation.MyCommand.Path
    $candidato = Get-ChildItem -Path $dirScript -Filter 'correduria-local_*_win32-x64.zip' -ErrorAction SilentlyContinue |
                 Sort-Object Name | Select-Object -Last 1
    if ($null -ne $candidato) { $ruta = Ask 'Paquete detectado. Ruta del ZIP' $candidato.FullName }
    else { $ruta = Ask 'Ruta local o URL del ZIP win32-x64' '' }
    if ($ruta -match '^https?://') {
        $PackageLocal = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($ruta))
        Info 'Descargando paquete...'
        Invoke-WebRequest -Uri $ruta -OutFile $PackageLocal -UseBasicParsing
    } else {
        if (-not (Test-Path $ruta)) { Fatal 'Debe indicar un paquete win32-x64 valido.' }
        $PackageLocal = (Resolve-Path $ruta).Path
    }
}

# Verificacion SHA-256 contra manifest-<version>.json si existe junto al paquete
if ($PackageLocal -and $PackageLocal -match 'correduria-local_(.+)_win32-x64\.zip$') {
    $version = [regex]::Match($PackageLocal, 'correduria-local_(.+)_win32-x64\.zip$').Groups[1].Value
    $manifestLocal = Join-Path (Split-Path $PackageLocal) ('manifest-' + $version + '.json')
    if (Test-Path $manifestLocal) {
        $manifestJson = Get-Content $manifestLocal -Raw | ConvertFrom-Json
        if ($manifestJson.PSObject.Properties['sha256']) {
            $sha = (Get-FileHash $PackageLocal -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($sha -ne ([string]$manifestJson.sha256).ToLowerInvariant()) {
                Fatal 'SHA-256 NO coincide con el manifiesto. No continue: paquete posiblemente corrupto o manipulado.'
            }
            Ok ('SHA-256 verificado contra manifest-' + $version + '.json')
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Modo de acceso y red
# ---------------------------------------------------------------------------
Info 'Paso 3/5 - Modo de acceso'
Write-Host '   1) Solo local    - solo navegador en este equipo (http://127.0.0.1)'
Write-Host '   2) Tailscale     - red privada con HTTPS automatico (recomendado)'
Write-Host '   3) Caddy LAN     - proxy HTTPS con certificado interno para la oficina'
Write-Host '   4) LAN directa   - HTTP sin cifrar (NO recomendado)'
$eleccion = Ask 'Modo de acceso [1/2/3/4]' '2'
switch ($eleccion) {
    '1' { $ModoAcceso = 'local' }
    '2' { $ModoAcceso = 'tailscale'; $InstalarTailscale = $true }
    '3' { $ModoAcceso = 'caddy' }
    '4' {
        $ModoAcceso = 'lan'
        Aviso 'HTTP plano en la LAN: las contrasenas viajan sin cifrar.'
        if (-not (AskBool '¿Confirma el modo LAN directa sin HTTPS?' $false)) { $ModoAcceso = 'tailscale' }
    }
    default { Fatal 'Opcion de modo de acceso no valida.' }
}
$Puerto = [int](Ask 'Puerto local de escucha' $Puerto)
$enUso = Get-NetTCPConnection -State Listen -LocalPort $Puerto -ErrorAction SilentlyContinue
if ($null -ne $enUso -and -not (Get-Service -Name $NombreServicio -ErrorAction SilentlyContinue)) {
    Fatal ('El puerto ' + $Puerto + ' ya esta en uso por otra aplicacion.')
}
if ($ModoAcceso -eq 'caddy') { $DominioLan = Ask 'Nombre/CN del certificado interno LAN' $DominioLan }
if ($UrlPublica -eq '') {
    switch ($ModoAcceso) {
        'local'     { $UrlPublica = 'http://127.0.0.1:' + $Puerto }
        'tailscale' { $UrlPublica = 'https://' + $EquipoNombreNormalizado + '.ts.net' }
        'caddy'     { $UrlPublica = 'https://' + $DominioLan }
        'lan' {
            $ipLan = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
                    Select-Object -First 1
            if ($null -ne $ipLan) { $UrlPublica = 'http://' + $ipLan.IPAddress + ':' + $Puerto }
            else { $UrlPublica = 'http://127.0.0.1:' + $Puerto }
        }
    }
}
$UrlPublica = Ask 'URL publica (aparece en correos y enlaces)' $UrlPublica
if ($ModoAcceso -ne 'tailscale') {
    $InstalarTailscale = AskBool '¿Instalar tambien Tailscale para acceso remoto privado?' $InstalarTailscale
}
Ok ('Modo: ' + $ModoAcceso + '  - escucha 127.0.0.1:' + $Puerto + '  - URL: ' + $UrlPublica)

# ---------------------------------------------------------------------------
# 4b. Datos, backups y canal de actualizaciones
# ---------------------------------------------------------------------------
Info 'Paso 4/5 - Datos, backups y canal de actualizaciones'
$DataDir = Ask 'Directorio de datos' $DataDir
$BackupDir = Ask 'Directorio de backups (.crbk; despues copie fuera del equipo: regla 3-2-1)' $BackupDir
$ManifestUrl = Ask 'URL del manifiesto de actualizaciones (vacio = no configurar)' $ManifestUrl
$PublicKeyFile = Ask 'Clave publica Ed25519 propia (vacio = embebida en el paquete)' $PublicKeyFile
$EntitlementFile = Ask 'Fichero entitlement.json (vacio = sin entitlement)' $EntitlementFile
if ($PublicKeyFile -ne '' -and -not (Test-Path $PublicKeyFile)) { Fatal ('No existe la clave publica: ' + $PublicKeyFile) }
if ($EntitlementFile -ne '' -and -not (Test-Path $EntitlementFile)) { Fatal ('No existe el entitlement: ' + $EntitlementFile) }

# ---------------------------------------------------------------------------
# 5. Dependencias de terceros
# ---------------------------------------------------------------------------
Info 'Paso 5/5 - Dependencias de terceros y despliegue'

# --- Tailscale (red privada + HTTPS automatico con tailscale serve) ----------
$ts = $null
if ($InstalarTailscale) {
    $cmdTs = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($null -ne $cmdTs) { $ts = $cmdTs.Source }
    elseif (Test-Path "$env:ProgramFiles\Tailscale\tailscale.exe") { $ts = "$env:ProgramFiles\Tailscale\tailscale.exe" }
    if ($null -eq $ts) {
        Info 'Instalando Tailscale (MSI oficial de tailscale.com)'
        $msi = Join-Path $env:TEMP 'TailscaleInstaller.msi'
        try {
            Invoke-WebRequest -Uri 'https://tailscale.com/downloads/latest/Tailscale-64-bit.msi' -OutFile $msi -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList @('/i', ('"' + $msi + '"'), '/qn') -Wait
            if (Test-Path "$env:ProgramFiles\Tailscale\tailscale.exe") { $ts = "$env:ProgramFiles\Tailscale\tailscale.exe" }
        } catch { Aviso 'No se pudo descargar/instalar Tailscale. Instalelo desde https://tailscale.com/download/windows' }
    }
    if ($null -ne $ts) { Ok 'Tailscale disponible' }
}

# --- Caddy (proxy HTTPS interno de la oficina) --------------------------------
if ($ModoAcceso -eq 'caddy') {
    $cmdCaddy = Get-Command caddy -ErrorAction SilentlyContinue
    if ($null -eq $cmdCaddy) {
        Info 'Instalando Caddy via winget (si no hay winget, instalelo manualmente)'
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($null -ne $winget) {
            winget install --id CaddyServer.Caddy --silent --accept-package-agreements --accept-source-agreements
            $cmdCaddy = Get-Command caddy -ErrorAction SilentlyContinue
        }
        if ($null -eq $cmdCaddy) { Fatal 'No se pudo instalar Caddy. Instalelo y repita con -SoloConfig.' }
    }
    $dirCaddy = Split-Path -Parent $cmdCaddy.Source
    $caddyFile = Join-Path $dirCaddy 'Caddyfile'
    Set-Content -Path $caddyFile -Encoding UTF8 -Value @(
        '# Gestionado por Setup-Correduria.ps1 - Correduria Local (' + $EquipoNombre + ')'
        ($DominioLan + ' {')
        '    tls internal'
        ('    reverse_proxy 127.0.0.1:' + $Puerto)
        '}'
    )
    Ok ('Caddyfile escrito: ' + $caddyFile + '  (configure caddy como servicio o "caddy run")')
}

# ---------------------------------------------------------------------------
# 6. Despliegue de ficheros
# ---------------------------------------------------------------------------
if (-not $SoloConfig) {
    Info ('Desplegando ' + (Split-Path -Leaf $PackageLocal) + ' en ' + $InstallDir)
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    $tmp = Join-Path $env:TEMP ('correduria-deploy-' + [Guid]::NewGuid().ToString('N'))
    Expand-Archive -Path $PackageLocal -DestinationPath $tmp -Force
    Copy-Item -Path (Join-Path $tmp '*') -Destination $InstallDir -Recurse -Force
    Remove-Item $tmp -Recurse -Force
    if (-not (Test-Path (Join-Path $InstallDir $BinarioApp))) { Fatal ('El paquete no contiene ' + $BinarioApp) }
}

# ---------------------------------------------------------------------------
# Datos + ACLs NTFS (equivalente a los permisos 0700/0600 de Linux)
# ---------------------------------------------------------------------------
Info ('Creando ' + $DataDir + ' con permisos restringidos')
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$acl = Get-Acl $DataDir
$acl.SetAccessRuleProtection($true, $false)
@($acl.Access) | ForEach-Object { [void]$acl.RemoveAccessRule($_) }
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators', 'FullControl', 'ContainerInherit,ObjectInherit', 'Allow')))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($CuentaServicio, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
Set-Acl -Path $DataDir -AclObject $acl
Ok 'ACLs NTFS aplicadas (solo administradores y la cuenta del servicio)'

# ---------------------------------------------------------------------------
# Configuracion estilo application.env (la consume el servicio)
# ---------------------------------------------------------------------------
$configDir = Join-Path $DataDir 'config'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$envFilePath = Join-Path $configDir 'application.env'
@(
    ('# Configurado por Setup-Correduria.ps1 el ' + (Get-Date -Format 's'))
    ('# Equipo: ' + $EquipoNombre + '  (instalador v' + $InstaladorVersion + ')')
    ('CORREDURIA_DATA_DIR=' + $DataDir)
    ('CORREDURIA_PUBLIC_URL=' + $UrlPublica)
    ('CORREDURIA_UPDATE_MANIFEST_URL=' + $ManifestUrl)
    ('CORREDURIA_UPDATE_PUBLIC_KEY_FILE=' + $PublicKeyFile)
    ('CORREDURIA_UPDATE_ENTITLEMENT_FILE=' + $EntitlementFile)
) | Set-Content -Path $envFilePath -Encoding UTF8
Ok ('Configuracion escrita: ' + $envFilePath)

# ---------------------------------------------------------------------------
# Servicio de Windows con WinSW (no existe systemd)
# ---------------------------------------------------------------------------
Info 'Instalando el servicio de Windows (WinSW)'
$winsw = Join-Path $InstallDir 'correduria-service.exe'
if (-not (Test-Path $winsw)) {
    Info 'Descargando WinSW (envoltorio de servicio, equivalente a systemd)'
    try {
        Invoke-WebRequest -Uri 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe' -OutFile $winsw -UseBasicParsing
    } catch { Fatal 'No se pudo descargar WinSW. Descarguelo de https://github.com/winsw/winsw y repita con -SoloConfig.' }
}
$plantilla = Get-Content (Join-Path $PSScriptRoot 'service\correduria-service.xml') -Raw
function XmlEsc($s) { ($s -replace '&', '&amp;') -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' }
$envEntries = @(
    ('  <env name="CORREDURIA_DATA_DIR" value="' + (XmlEsc $DataDir) + '" />')
    ('  <env name="CORREDURIA_PUBLIC_URL" value="' + (XmlEsc $UrlPublica) + '" />')
    ('  <env name="CORREDURIA_UPDATE_MANIFEST_URL" value="' + (XmlEsc $ManifestUrl) + '" />')
    ('  <env name="CORREDURIA_UPDATE_PUBLIC_KEY_FILE" value="' + (XmlEsc $PublicKeyFile) + '" />')
    ('  <env name="CORREDURIA_UPDATE_ENTITLEMENT_FILE" value="' + (XmlEsc $EntitlementFile) + '" />')
) -join [Environment]::NewLine
$plantilla = $plantilla.Replace('{{INSTALL_DIR}}', $InstallDir).Replace('{{PORT}}', [string]$Puerto).Replace('{{ENV_ENTRIES}}', $envEntries)
Set-Content -Path (Join-Path $InstallDir 'correduria-service.xml') -Value $plantilla -Encoding UTF8
if (Get-Service -Name $NombreServicio -ErrorAction SilentlyContinue) {
    Info 'Reinstalando el servicio existente'
    & $winsw stop  2>&1 | Out-Null
    & $winsw uninstall 2>&1 | Out-Null
}
& $winsw install
& $winsw start

# ---------------------------------------------------------------------------
# Firewall (solo en modo LAN directa)
# ---------------------------------------------------------------------------
if ($ModoAcceso -eq 'lan') {
    New-NetFirewallRule -DisplayName 'Correduria LAN (HTTP)' -Direction Inbound -Action Allow -LocalPort $Puerto -Protocol TCP -ErrorAction SilentlyContinue | Out-Null
    Aviso 'Regla de firewall anadida para LAN sin HTTPS: revise que sea realmente lo deseado.'
}

# ---------------------------------------------------------------------------
# Espera de la aplicacion
# ---------------------------------------------------------------------------
Info ('Esperando respuesta en http://127.0.0.1:' + $Puerto + '/')
$appListo = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        Invoke-WebRequest -Uri ('http://127.0.0.1:' + $Puerto + '/') -UseBasicParsing -TimeoutSec 5 | Out-Null
        $appListo = $true
        break
    } catch { Start-Sleep -Seconds 2 }
}
if (-not $appListo) { Fatal ('La aplicacion no responde. Revise los logs de WinSW en ' + $InstallDir) }
Ok 'Servicio activo y respondiendo'

# ---------------------------------------------------------------------------
# Enlace de primera puesta en marcha (se ejecuta como la cuenta del servicio)
# ---------------------------------------------------------------------------
Info 'Generando enlace de primera puesta en marcha'
$setupLinkUrl = ''
try {
    $taskName = 'Correduria-SetupLink-' + (Get-Date -Format 'yyyyMMddHHmmss')
    $outFile = Join-Path $env:TEMP 'correduria-setuplink.txt'
    $exePath = Join-Path $InstallDir $BinarioApp
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c ""' + $exePath + '" setup-link > "' + $outFile + '" 2>&1"')
    $principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\LocalService' -LogonType ServiceAccount
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 8
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    if (Test-Path $outFile) {
        $salida = Get-Content $outFile -Raw
        if ($salida -match 'https?://\S+') { $setupLinkUrl = $Matches[0] }
    }
} catch { Aviso ('No se pudo generar el enlace automaticamente: ' + $_.Exception.Message) }

# ---------------------------------------------------------------------------
# Tailscale: up + serve (HTTPS automatico)
# ---------------------------------------------------------------------------
$UrlFinal = $UrlPublica
if ($InstalarTailscale -and $null -ne $ts) {
    & $ts status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Info 'Iniciando sesion en Tailscale (abra la URL que se muestre; espere hasta 120 s)'
        if ($TsAuthKey) {
            & $ts up ('--authkey=' + $TsAuthKey) ('--hostname=' + $EquipoNombreNormalizado) 2>&1 | Out-Null
        } else {
            & $ts up ('--hostname=' + $EquipoNombreNormalizado)
        }
    }
    $ipTs = & $ts ip -4 2>$null
    if ($LASTEXITCODE -eq 0 -and $ipTs) {
        Ok ('Tailscale conectado: ' + ($ipTs | Select-Object -First 1))
        if ($ModoAcceso -eq 'tailscale') {
            & $ts serve --bg $Puerto 2>&1 | Out-Null
            try {
                $st = & $ts status --self --json 2>$null | ConvertFrom-Json
                if ($st.Self.DNSName) { $UrlFinal = 'https://' + ([string]$st.Self.DNSName).TrimEnd('.') }
            } catch { }
            Ok ('Tailscale Serve activo: ' + $UrlFinal + ' -> 127.0.0.1:' + $Puerto)
        }
    } else {
        Aviso ('Tailscale aun sin conectar. Ejecute: & "' + $ts + '" up  y despues  & $ts serve --bg ' + $Puerto)
    }
}

# ---------------------------------------------------------------------------
# Resumen final
# ---------------------------------------------------------------------------
Banner
Write-Host ('Instalacion completada en el equipo «' + $EquipoNombre + '»') -ForegroundColor Green
Write-Host ''
Write-Host ('  Modo de acceso .......... ' + $ModoAcceso)
Write-Host ('  Escucha ................. 127.0.0.1:' + $Puerto + '  (nunca exponga HTTP plano)')
Write-Host ('  URL de acceso ........... ' + $UrlFinal)
Write-Host ('  Datos ................... ' + $DataDir + '  (ACLs restringidas)')
Write-Host ('  Backups (staging) ....... ' + $BackupDir)
$canalInfo = 'desactivado'
if ($ManifestUrl) { $canalInfo = $ManifestUrl }
Write-Host ('  Canal actualizaciones ... ' + $canalInfo)
Write-Host ('  Configuracion ........... ' + $envFilePath)
Write-Host ''
if ($setupLinkUrl) {
    Write-Host 'ENLACE DE PRIMERA PUESTA EN MARCHA (un solo uso):' -ForegroundColor White
    Write-Host ('  ' + $setupLinkUrl)
    Write-Host ''
} else {
    Aviso 'Enlace no obtenido automaticamente. Ejecute (como Administrador): "' + (Join-Path $InstallDir $BinarioApp) + '" setup-link con CORREDURIA_DATA_DIR=' + $DataDir
}
Write-Host 'Pasos siguientes en la interfaz web:' -ForegroundColor White
Write-Host '  1. Cree su cuenta (correo, contrasena de 12-128 y nombre del negocio).'
Write-Host '  2. Configuracion -> Correo de recuperacion (SMTP) + prueba de envio.'
Write-Host '  3. Backups: active la copia diaria y guarde la CLAVE DE RECUPERACION FUERA del equipo (3-2-1).'
Write-Host '  4. (Opcional) Modelos de IA: suscripcion ChatGPT Plus/Pro (OAuth) o clave API.'
Write-Host '  5. Actualizaciones: tools/Update-Correduria.ps1 (fase piloto; despues, update-install interno de la app).'
Write-Host ''
