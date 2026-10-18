#!/usr/bin/env bash
# =============================================================================
# Instalador interactivo · Plataforma Correduría Local
# -----------------------------------------------------------------------------
# Prepara un equipo NUEVO (Ubuntu/Debian) de cero:
#   1. Comprobaciones previas (OS, arquitectura, glibc, puerto, permisos).
#   2. Pide TODAS las configuraciones en un único flujo interactivo
#      (nombre del equipo/hostname, zona horaria, modo de acceso, puerto,
#      directorio de datos, canal de actualizaciones, backups...).
#   3. Instala dependencias de terceros (ca-certificates, Tailscale opcional,
#      Caddy opcional).
#   4. Instala el paquete .deb y aplica la configuración generada
#      (/etc/correduria/application.env + override systemd si procede).
#   5. Arranca el servicio, genera el enlace de primera puesta en marcha
#      (setup-link) y muestra el resumen de la instalación.
#
# Uso:
#   sudo bash install.sh                  # modo interactivo (recomendado)
#   sudo bash install.sh --unattended instalacion.conf
#   sudo bash install.sh --solo-config    # reconfigurar sin reinstalar
#   bash install.sh --help
#
# Las credenciales de aplicación (SMTP, IA, contraseña de cuenta) NO se piden
# aquí: se introducen en la interfaz web tras el primer arranque, porque se
# almacenan cifradas en la base de datos de la aplicación.
# =============================================================================
set -euo pipefail

VERSION_INSTALADOR="1.0.0"
LOG_DIR="/var/log/correduria-instalador"
LOG_FILE=""
CONF_ESCRITA=""

# --- Valores por defecto (sobrescribibles por prompt o fichero de respuestas) -
EQUIPO_NOMBRE=""            # hostname del equipo donde se instala
CAMBIAR_HOSTNAME="no"       # sí/no: aplicar EQUIPO_NOMBRE con hostnamectl
ZONA_HORARIA="Europe/Madrid"
DEB_FILE=""                           # ruta o URL del paquete .deb (vacío = detectar)
MODO_ACCESO="tailscale"       # local | tailscale | caddy | lan
PUERTO="8080"
URL_PUBLICA=""              # vacío = derivada del modo elegido
DATA_DIR="/var/lib/correduria"
BACKUP_DIR="/var/lib/correduria/backups"
MANIFEST_URL="https://github.com/pericorl-tech/correduria-release/releases/latest/download/manifest-latest.json"
PUBLIC_KEY_FILE=""          # vacío = clave pública embebida en el paquete
ENTITLEMENT_FILE=""
INSTALAR_TAILSCALE="si"     # sí/no (se fuerza "si" si MODO_ACCESO=tailscale)
TS_AUTH_KEY="${TS_AUTH_KEY:-}"  # opcional: clave de autenticación Tailscale (no se persiste)
DOMINIO_LAN="correduria.local"  # solo MODO_ACCESO=caddy
ACEPTAR_TODO="no"

MANIFEST_GITHUB="https://github.com/pericorl-tech/correduria-release"

# =============================================================================
# Utilidades de salida y registro
# =============================================================================
C_ROJO=$'\e[31m'; C_VERDE=$'\e[32m'; C_AMAR=$'\e[33m'; C_AZUL=$'\e[36m'; C_NEGRITA=$'\e[1m'; C_FIN=$'\e[0m'

info()  { printf '%s\n' "${C_AZUL}==>${C_FIN} $*"; }
ok()    { printf '%s\n' "${C_VERDE}[OK]${C_FIN} $*"; }
aviso() { printf '%s\n' "${C_AMAR}[AVISO]${C_FIN} $*" >&2; }
error() { printf '%s\n' "${C_ROJO}[ERROR]${C_FIN} $*" >&2; }
fatal() { error "$*"; exit 1; }

banner() {
    printf '\n%s\n' "${C_NEGRITA}╔══════════════════════════════════════════════════════════╗${C_FIN}"
    printf '%s\n'  "${C_NEGRITA}   Instalador · Plataforma Correduría Local v${VERSION_INSTALADOR}${C_FIN}"
    printf '%s\n'  "${C_NEGRITA}╚══════════════════════════════════════════════════════════╝${C_FIN}"
}

usar_help() {
    banner
    cat <<'AYUDA'
Uso: sudo bash install.sh [opciones]

Opciones:
  --unattended <fichero>   Modo no interactivo. Lee las respuestas de un
                           fichero KEY=VAL (ver answers.example.conf).
  --solo-config           No instala el paquete: solo reconfigura una
                           instalación existente (application.env, red, TLS).
  --deb <ruta|URL>        Paquete .deb a instalar (por defecto se busca junto
                           al script o se descarga del release más reciente).
  --respuestas <fichero>  Al terminar, exporta las respuestas usadas para
                           reproducir la instalación en otro equipo.
  -y, --yes               Acepta los valores por defecto en los avisos.
  -h, --help              Muestra esta ayuda.

Flujo interactivo (lo que se pregunta):
  1. Nombre del equipo (hostname) y zona horaria.
  2. Paquete a instalar (detectado, ruta local o descarga del release).
  3. Modo de acceso: solo local, Tailscale (recomendado), Caddy LAN o LAN directa.
  4. Puerto de escucha, directorio de datos y directorio de backups.
  5. Canal de actualizaciones (manifiesto firmado, clave pública, entitlement).
  6. Resumen final con el enlace de primera puesta en marcha.

Nota: SMTP, proveedores de IA, avisos y política de backups se configuran
después, en la pestaña Configuración de la interfaz web (se guardan cifrados).
AYUDA
}

inicializar_log() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    LOG_FILE="$LOG_DIR/instalacion-$(date +%Y%m%d-%H%M%S).log"
    if ! : >"$LOG_FILE" 2>/dev/null; then
        LOG_FILE="/dev/null"
    fi
}

registrar() {
    [ -n "$LOG_FILE" ] && printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE" || true
}

ejecutar() {
    # ejecutar <desc> <cmd...> : registra, muestra y ejecuta; aborta si falla.
    local desc="$1"; shift
    info "$desc"
    registrar "CMD: $*"
    if ! "$@" >>"$LOG_FILE" 2>&1; then
        registrar "FALLO CMD: $* (ver $LOG_FILE)"
        return 1
    fi
}

confirmar() {
    # confirmar <pregunta> [valor_por_defecto_s_n]  (devuelve 0 si afirmativo)
    local prompt="$1" def="${2:-s}" rep sufijo
    if [ "$ACEPTAR_TODO" = "si" ]; then
        case "$def" in s|si) return 0 ;; *) return 1 ;; esac
    fi
    case "$def" in
        s) sufijo="[S/n]" ;;
        n) sufijo="[s/N]" ;;
        *) sufijo="[$def]" ;;
    esac
    printf '%s %s %s ' "${C_AZUL}==>${C_FIN}" "$prompt" "$sufijo"
    read -r rep || rep=""
    rep="${rep:-$def}"
    case "$(printf '%s' "$rep" | tr '[:upper:]' '[:lower:]')" in
        s|si|sí|yes|y) return 0 ;;
        *) return 1 ;;
    esac
}

preguntar() {
    # preguntar <var> <enunciado> [valor_por_defecto]
    local var="$1" texto="$2" def="${3:-}" actual="" entrada
    eval "actual=\${$var:-}"
    [ -n "$actual" ] && def="$actual"
    if [ "$MODO_NOINTERACTIVO" = "si" ]; then
        eval "$var=\$def"
        registrar "$var=$def"
        return 0
    fi
    if [ -n "$def" ]; then
        printf '%s %s %s[%s]%s ' "${C_AZUL}==>${C_FIN}" "$texto" "${C_AMAR}" "$def" "${C_FIN}"
    else
        printf '%s %s ' "${C_AZUL}==>${C_FIN}" "$texto"
    fi
    IFS= read -r entrada || entrada=""
    eval "$var=\${entrada:-\$def}"
    registrar "$var=${!var}"
}

# =============================================================================
# Modo no interactivo
# =============================================================================
MODO_NOINTERACTIVO="no"
SOLO_CONFIG="no"

sino_normalizado() {
    # Acepta sí/si/yes/y/1/true/no/n/… y devuelve "si" o "no"
    local v
    v="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[áà]/a/g; s/[éè]/e/g; s/[íí]/i/g; s/[óò]/o/g; s/[úù]/u/g')"
    case "$v" in
        si|yes|y|1|true|verdadero) printf 'si' ;;
        *) printf 'no' ;;
    esac
}

normalizar_respuestas() {
    CAMBIAR_HOSTNAME="$(sino_normalizado "$CAMBIAR_HOSTNAME")"
    INSTALAR_TAILSCALE="$(sino_normalizado "$INSTALAR_TAILSCALE")"
    ACEPTAR_TODO="$(sino_normalizado "$ACEPTAR_TODO")"
}

parsear_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --unattended)
                MODO_NOINTERACTIVO="si"
                [ $# -ge 2 ] || fatal "--unattended necesita un fichero de respuestas"
                cargar_respuestas "$2"; shift 2 ;;
            --solo-config) SOLO_CONFIG="si"; shift ;;
            --deb) [ $# -ge 2 ] || fatal "--deb necesita un valor"; DEB_FILE="$2"; shift 2 ;;
            --respuestas) [ $# -ge 2 ] || fatal "--respuestas necesita un valor"; CONF_ESCRITA="$2"; shift 2 ;;
            -y|--yes) ACEPTAR_TODO="si"; shift ;;
            -h|--help) usar_help; exit 0 ;;
            *) fatal "Opción desconocida: $1 (use --help)" ;;
        esac
    done
}

cargar_respuestas() {
    local f="$1"
    [ -f "$f" ] || fatal "No existe el fichero de respuestas: $f"
    # shellcheck disable=SC1090
    # Cargar solo claves conocidas para no ejecutar código arbitrario
    local linea clave valor
    while IFS= read -r linea || [ -n "$linea" ]; do
        case "$linea" in ''|\#*) continue ;; esac
        clave="${linea%%=*}"; valor="${linea#*=}"
        case "$clave" in
            EQUIPO_NOMBRE|CAMBIAR_HOSTNAME|ZONA_HORARIA|DEB_FILE|MODO_ACCESO|PUERTO|\
            URL_PUBLICA|DATA_DIR|BACKUP_DIR|MANIFEST_URL|PUBLIC_KEY_FILE|ENTITLEMENT_FILE|\
            INSTALAR_TAILSCALE|DOMINIO_LAN|ACEPTAR_TODO)
                eval "$clave=\$valor" ;;
            *) aviso "Clave desconocida ignorada en $f: $clave" ;;
        esac
    done <"$f"
}

export_respuestas() {
    local f="$1"
    umask 077
    cat >"$f" <<RESP
# Respuestas de la instalación de Correduría Local
# Generado por install.sh $(date '+%F %T') — reutilizable con:
#   sudo bash install.sh --unattended $f
EQUIPO_NOMBRE=$EQUIPO_NOMBRE
CAMBIAR_HOSTNAME=$CAMBIAR_HOSTNAME
ZONA_HORARIA=$ZONA_HORARIA
# DEB_FILE es específico del momento de la instalación (no se exporta)
MODO_ACCESO=$MODO_ACCESO
PUERTO=$PUERTO
URL_PUBLICA=$URL_PUBLICA
DATA_DIR=$DATA_DIR
BACKUP_DIR=$BACKUP_DIR
MANIFEST_URL=$MANIFEST_URL
PUBLIC_KEY_FILE=$PUBLIC_KEY_FILE
ENTITLEMENT_FILE=$ENTITLEMENT_FILE
INSTALAR_TAILSCALE=$INSTALAR_TAILSCALE
DOMINIO_LAN=$DOMINIO_LAN
RESP
    ok "Respuestas exportadas a $f"
}

# =============================================================================
# 1. Comprobaciones previas
# =============================================================================
comprobaciones_previas() {
    info "Comprobaciones previas del equipo"

    [ "$(id -u)" -eq 0 ] || fatal "Ejecute el instalador con sudo (root)."

    # Sistema operativo
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|raspbian) ok "Sistema: ${PRETTY_NAME:-$ID}" ;;
            *) fatal "SO no soportado (${PRETTY_NAME:-desconocido}). Se requiere Ubuntu/Debian." ;;
        esac
    else
        fatal "No se lee /etc/os-release: no se puede determinar la distribución."
    fi

    command -v systemctl >/dev/null || fatal "systemd no disponible: instale en una distribución con systemd."

    # Arquitectura
    ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    case "$ARCH" in
        arm64|aarch64) ARCH_OK="arm64" ;;
        amd64|x86_64)
            aviso "Arquitectura amd64: el paquete oficial amd64 está PLANIFICADO y aún no publicado."
            aviso "Continúe solo si dispone de un paquete .deb amd64 propio (opción --deb)."
            [ "$MODO_NOINTERACTIVO" = "si" ] || [ "$ACEPTAR_TODO" = "si" ] || {
                confirmar "¿Continuar de todos modos con amd64?" n || fatal "Instalación cancelada."
            } ;;
        *) fatal "Arquitectura no soportada: $ARCH (disponible: arm64)." ;;
    esac

    # glibc
    GLIBC="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    if [ -n "$GLIBC" ]; then
        caso_major="${GLIBC%%.*}"; caso_minor="${GLIBC#*.}"
        if [ "$caso_major" -gt 2 ] || { [ "$caso_major" -eq 2 ] && [ "$caso_minor" -ge 41 ]; }; then
            ok "glibc $GLIBC (>= 2.41)"
        else
            fatal "glibc $GLIBC demasiado antigua: la aplicación requiere glibc >= 2.41 (Ubuntu 24.10+ / Debian trixie+)."
        fi
    else
        aviso "No se pudo determinar la versión de glibc; la app exige >= 2.41."
    fi

    # Instalación previa
    if dpkg -s correduria-local >/dev/null 2>&1; then
        INSTALADA="si"
        AV="Instalación existente detectada ($(dpkg-query -W -f='${Version}' correduria-local 2>/dev/null))."
        aviso "$AV"
        if [ "$SOLO_CONFIG" != "si" ] && [ "$MODO_NOINTERACTIVO" != "si" ]; then
            confirmar "¿Reconfigurar sin reinstalar el paquete?" s && SOLO_CONFIG="si"
        fi
    else
        INSTALADA="no"
    fi

    ok "Comprobaciones previas superadas."
}

# =============================================================================
# 2. Datos del equipo
# =============================================================================
preguntar_equipo() {
    banner
    info "Paso 1/6 · Datos del equipo de instalación"
    printf '%s\n' "    El 'nombre del equipo' es el hostname del ordenador donde se instala"
    printf '%s\n' "    (mini PC, torre o servidor): identificará el servidor en la red Tailscale,"
    printf '%s\n' "    en los certificados TLS y en los resúmenes de avisos."

    local actual; actual="$(hostname)"
    preguntar EQUIPO_NOMBRE "Nombre del equipo (hostname):" "${EQUIPO_NOMBRE:-$actual}"
    # Validar hostname válido (solo letras, números, guiones y puntos)
    case "$EQUIPO_NOMBRE" in
        *[!a-zA-Z0-9.-]*|'') fatal "Nombre de equipo no válido: use solo letras, números, guiones y puntos (ej. correduria-oficina)." ;;
    esac
    if [ "$MODO_NOINTERACTIVO" != "si" ] && [ "$EQUIPO_NOMBRE" != "$(hostname)" ]; then
        if confirmar "¿Aplicar '$EQUIPO_NOMBRE' como hostname del sistema (hostnamectl)?" s; then
            CAMBIAR_HOSTNAME="si"
        fi
    fi
    preguntar ZONA_HORARIA "Zona horaria (zona IANA):" "$ZONA_HORARIA"

    # Normalizar para Tailscale/DNS (minúsculas)
    EQUIPO_NOMBRE_NORMALIZADO="$(printf '%s' "$EQUIPO_NOMBRE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9.-]//g' | cut -c1-63)"
    ok "Equipo: $EQUIPO_NOMBRE · Zona horaria: $ZONA_HORARIA"
}

# =============================================================================
# 3. Paquete a instalar
# =============================================================================
localizar_paquete() {
    info "Paso 2/6 · Paquete de la aplicación"

    if [ -n "$DEB_FILE" ]; then
        case "$DEB_FILE" in
            http://*|https://*)
                info "Descargando paquete de $DEB_FILE"
                DEB_FILE_LOCAL="/var/tmp/$(basename "$DEB_FILE")"
                ejecutar "Descarga del paquete" curl -fL --retry 3 -o "$DEB_FILE_LOCAL" "$DEB_FILE" \
                    || fatal "Descarga fallida" ;;
            *)
                [ -f "$DEB_FILE" ] || fatal "No existe el paquete: $DEB_FILE"
                DEB_FILE_LOCAL="$DEB_FILE" ;;
        esac
        verificar_sha256 "$DEB_FILE_LOCAL"
        return 0
    fi

    # Detectar .deb junto al script (el de versión más alta)
    local dir_script candidato
    dir_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    candidato="$(ls -V "$dir_script"/correduria-local_*_${ARCH}.deb 2>/dev/null | tail -1 || true)"
    [ -n "$candidato" ] || candidato="$(ls -V "$dir_script"/../correduria-local_*_${ARCH}.deb 2>/dev/null | tail -1 || true)"

    if [ -n "$candidato" ]; then
        preguntar DEB_FILE "Paquete detectado. Ruta del .deb a instalar:" "$candidato"
        [ -f "$DEB_FILE" ] || fatal "No existe el paquete: $DEB_FILE"
        DEB_FILE_LOCAL="$DEB_FILE"
    else
        info "No hay paquete .deb junto al instalador."
        preguntar DEB_FILE "Ruta local o URL del paquete .deb (o URL de descarga):" ""
        [ -n "$DEB_FILE" ] || fatal "Debe indicar un paquete .deb para instalar."
        case "$DEB_FILE" in
            http://*|https://*)
                DEB_FILE_LOCAL="/var/tmp/$(basename "$DEB_FILE")"
                ejecutar "Descargando paquete" curl -fL --retry 3 -o "$DEB_FILE_LOCAL" "$DEB_FILE" ;;
            *) [ -f "$DEB_FILE" ] || fatal "No existe: $DEB_FILE"; DEB_FILE_LOCAL="$DEB_FILE" ;;
        esac
    fi
    verificar_sha256 "$DEB_FILE_LOCAL"
}

verificar_sha256() {
    # Si en el mismo directorio hay manifest-<version>.json o el release publica
    # manifest-latest.json, se comprueba el SHA-256 cuando está disponible.
    local pkg="$1" ver sha esperado
    ver="$(basename "$pkg" | sed -E 's/correduria-local_(.+)_.*\.deb/\1/')"
    local manifest="$(dirname "$pkg")/manifest-${ver}.json"
    if [ -f "$manifest" ] && command -v sha256sum >/dev/null; then
        esperado="$(grep -oE '"sha256"[^,]*' "$manifest" | head -1 | grep -oE '[0-9a-f]{64}' || true)"
        if [ -n "$esperado" ]; then
            sha="$(sha256sum "$pkg" | awk '{print $1}')"
            if [ "$sha" = "$esperado" ]; then
                ok "SHA-256 verificado contra manifest-${ver}.json"
            else
                fatal "SHA-256 NO coincide con el manifiesto (${ver}). No continúe: el paquete puede estar corrupto o manipulado."
            fi
        fi
    fi
}

# =============================================================================
# 4. Modo de acceso y red
# =============================================================================
preguntar_acceso() {
    info "Paso 3/6 · Modo de acceso a la aplicación"
    cat <<'MODOS'
    La aplicación siempre escucha en local. Elija cómo se conectará usted:
      1) Solo local      — solo navegador en este equipo (http://127.0.0.1)
      2) Tailscale       — RED PRIVADA VPN: acceso desde cualquier equipo
                           propio con HTTPS automático (recomendado)
      3) Caddy en LAN    — proxy HTTPS con certificado interno para la oficina
      4) LAN directa     — HTTP sin cifrar en la red local (NO recomendado)
MODOS
    local eleccion=""
    if [ "$MODO_NOINTERACTIVO" != "si" ]; then
        preguntar eleccion "Modo de acceso [1/2/3/4]:" \
            "$(case $MODO_ACCESO in local) echo 1;; tailscale) echo 2;; caddy) echo 3;; lan) echo 4;; *) echo 2;; esac)"
    fi
    case "${eleccion:-$MODO_ACCESO}" in
        1|local)      MODO_ACCESO="local" ;;
        2|tailscale)  MODO_ACCESO="tailscale"; INSTALAR_TAILSCALE="si" ;;
        3|caddy)      MODO_ACCESO="caddy" ;;
        4|lan)
            MODO_ACCESO="lan"
            aviso "Acceso por HTTP plano en la LAN: las contraseñas viajan sin cifrar."
            [ "$ACEPTAR_TODO" = "si" ] || confirmar "¿Confirma el modo LAN directa sin HTTPS?" n || MODO_ACCESO="tailscale"
            ;;
        *) fatal "Opción de modo de acceso no válida: $eleccion" ;;
    esac

    preguntar PUERTO "Puerto de escucha local de la app:" "$PUERTO"
    case "$PUERTO" in *[!0-9]*|'') fatal "Puerto no válido: $PUERTO" ;; esac
    # El puerto debe estar libre, salvo que lo ocupe nuestra propia instalación activa
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$PUERTO$" && \
       ! systemctl is-active --quiet correduria-local.service; then
        fatal "El puerto $PUERTO ya está en uso por otra aplicación. Elija otro o libérelo."
    fi

    # URL pública
    if [ "$MODO_ACCESO" = "caddy" ] && [ "$MODO_NOINTERACTIVO" != "si" ]; then
        preguntar DOMINIO_LAN "Nombre/CN del certificado interno para la LAN:" "$DOMINIO_LAN"
    fi
    case "$MODO_ACCESO" in
        local)      [ -n "$URL_PUBLICA" ] || URL_PUBLICA="http://127.0.0.1:$PUERTO" ;;
        tailscale)  [ -n "$URL_PUBLICA" ] || URL_PUBLICA="https://${EQUIPO_NOMBRE_NORMALIZADO}.ts.net" ;;
        caddy)      [ -n "$URL_PUBLICA" ] || URL_PUBLICA="https://${DOMINIO_LAN}" ;;
        lan)        [ -n "$URL_PUBLICA" ] || URL_PUBLICA="http://$(hostname -I 2>/dev/null | awk '{print $1}'):$PUERTO" ;;
    esac
    preguntar URL_PUBLICA "URL pública (CORREDURIA_PUBLIC_URL) — usada en correos y enlaces:" "$URL_PUBLICA"

    if [ "$MODO_ACCESO" != "tailscale" ] && [ "$MODO_NOINTERACTIVO" != "si" ]; then
        if confirmar "¿Instalar también Tailscale para acceso remoto privado?" "$INSTALAR_TAILSCALE"; then
            INSTALAR_TAILSCALE="si"
        else
            INSTALAR_TAILSCALE="no"
        fi
    fi
    BIND_ADDR="127.0.0.1"
    [ "$MODO_ACCESO" = "lan" ] && BIND_ADDR="0.0.0.0" || BIND_ADDR="127.0.0.1"
    ok "Modo: $MODO_ACCESO · escucha $BIND_ADDR:$PUERTO · URL pública: $URL_PUBLICA"
}

# =============================================================================
# 5. Almacenamiento y canal de actualizaciones
# =============================================================================
preguntar_almacenamiento() {
    info "Paso 4/6 · Datos y backups"
    preguntar DATA_DIR "Directorio de datos de la instalación:" "$DATA_DIR"
    if [ "$DATA_DIR" != "/var/lib/correduria" ] && [ -d "/var/lib/correduria" ] && \
       [ -n "$(ls -A /var/lib/correduria 2>/dev/null)" ]; then
        fatal "/var/lib/correduria ya contiene datos: no se puede cambiar DATA_DIR sobre una instalación con datos."
    fi
    preguntar BACKUP_DIR "Directorio donde se escribirán los .crbk (zona de preparación; aplique luego la regla 3-2-1):" "$BACKUP_DIR"

    info "Paso 5/6 · Canal de actualizaciones firmadas (Ed25519)"
    preguntar MANIFEST_URL "URL del manifiesto de actualizaciones (vacío = no configurar):" "$MANIFEST_URL"
    preguntar PUBLIC_KEY_FILE "Fichero de clave pública Ed25519 del distribuidor (vacío = clave embebida en el paquete):" "$PUBLIC_KEY_FILE"
    preguntar ENTITLEMENT_FILE "Fichero de derecho de actualización entitlement.json (vacío = sin entitlement):" "$ENTITLEMENT_FILE"

    if [ -n "$PUBLIC_KEY_FILE" ] && [ ! -f "$PUBLIC_KEY_FILE" ]; then
        fatal "No existe la clave pública indicada: $PUBLIC_KEY_FILE"
    fi
    if [ -n "$ENTITLEMENT_FILE" ] && [ ! -f "$ENTITLEMENT_FILE" ]; then
        fatal "No existe el entitlement indicado: $ENTITLEMENT_FILE"
    fi
}

# =============================================================================
# 6. Instalación de dependencias de terceros
# =============================================================================
instalar_dependencias() {
    info "Instalando dependencias base (ca-certificates, curl, adduser)"
    export DEBIAN_FRONTEND=noninteractive
    ejecutar "apt-get update" apt-get update -qq || fatal "apt-get update falló (¿red/repositorios?)"
    ejecutar "Instalando dependencias base" apt-get install -y -qq ca-certificates curl adduser || fatal "No se pudieron instalar las dependencias base"

    if [ "$INSTALAR_TAILSCALE" = "si" ]; then
        if command -v tailscale >/dev/null; then
            ok "Tailscale ya instalado: $(tailscale version 2>/dev/null | head -1)"
        else
            info "Instalando Tailscale (repositorio oficial tailscale.com)"
            if curl -fsSL https://tailscale.com/install.sh | sh >>"$LOG_FILE" 2>&1; then
                ok "Tailscale instalado"
            else
                fatal "Falló la instalación de Tailscale. Revise $LOG_FILE o instálelo manualmente: https://tailscale.com/kb/1031/installing"
            fi
        fi
    fi

    if [ "$MODO_ACCESO" = "caddy" ]; then
        if command -v caddy >/dev/null; then
            ok "Caddy ya instalado"
        else
            info "Instalando Caddy (proxy HTTPS)"
            if ! apt-get install -y -qq caddy >>"$LOG_FILE" 2>&1; then
                # Repositorio oficial de Caddy como alternativa
                apt-get install -y -qq gnupg >>"$LOG_FILE" 2>&1 || true
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
                apt-get update -qq >>"$LOG_FILE" 2>&1
                apt-get install -y -qq caddy >>"$LOG_FILE" 2>&1 || fatal "No se pudo instalar Caddy"
            fi
        fi
    fi
}

# =============================================================================
# 6b. Instalación del paquete
# =============================================================================
instalar_paquete() {
    info "Instalando paquete $(basename "$DEB_FILE_LOCAL")"
    ejecutar "dpkg -i" dpkg -i "$DEB_FILE_LOCAL" || {
        aviso "dpkg pidió dependencias; resolviendo con apt -f install"
        ejecutar "apt-get -f install" apt-get install -yf || fatal "Instalación del paquete falló (ver $LOG_FILE)"
    }
    ok "Paquete instalado: $(dpkg-query -W -f='${Version}' correduria-local 2>/dev/null)"
}

# =============================================================================
# 7. Aplicación de configuración
# =============================================================================
aplicar_configuracion() {
    info "Aplicando configuración del sistema"
    umask 077

    # 7.1 hostname del equipo
    if [ "$CAMBIAR_HOSTNAME" = "si" ] && [ -n "$EQUIPO_NOMBRE" ] && [ "$(hostname)" != "$EQUIPO_NOMBRE" ]; then
        ejecutar "Configurando hostname como '$EQUIPO_NOMBRE'" hostnamectl set-hostname "$EQUIPO_NOMBRE"
        # Mantener resolución local en /etc/hosts
        if ! grep -qE "^[0-9.[:space:]]+.*\b${EQUIPO_NOMBRE}\b" /etc/hosts; then
            printf '127.0.1.1\t%s\n' "$EQUIPO_NOMBRE" >>/etc/hosts
        fi
        ok "Hostname aplicado: $EQUIPO_NOMBRE"
    fi

    # 7.2 zona horaria
    if command -v timedatectl >/dev/null; then
        ejecutar "Zona horaria $ZONA_HORARIA" timedatectl set-timezone "$ZONA_HORARIA" || aviso "No se pudo fijar la zona horaria"
    fi

    # 7.3 application.env (copia de seguridad previa + escritura atómica)
    local env_dir="/etc/correduria" env_file="/etc/correduria/application.env"
    install -d -m 0700 "$env_dir"
    if [ -f "$env_file" ]; then
        cp -a "$env_file" "${env_file}.bak-$(date +%Y%m%d%H%M%S)"
        info "Configuración anterior respaldada en ${env_file}.bak-*"
    fi
    cat >"${env_file}.tmp" <<ENV
# Configuración generada por install.sh el $(date '+%F %T')
# Equipo: $EQUIPO_NOMBRE · Instalador v$VERSION_INSTALADOR
CORREDURIA_DATA_DIR=$DATA_DIR
CORREDURIA_PUBLIC_URL=$URL_PUBLICA
# Canal de actualizaciones (manifiesto firmado Ed25519):
CORREDURIA_UPDATE_MANIFEST_URL=$MANIFEST_URL
CORREDURIA_UPDATE_PUBLIC_KEY_FILE=$PUBLIC_KEY_FILE
CORREDURIA_UPDATE_ENTITLEMENT_FILE=$ENTITLEMENT_FILE
ENV
    install -m 0600 "${env_file}.tmp" "$env_file" && rm -f "${env_file}.tmp"
    ok "Escrito $env_file (0600)"

    # 7.3b directorio de datos y backups
    install -d -m 0700 -o correduria-local -g correduria-local "$DATA_DIR"
    if [ "$BACKUP_DIR" != "$DATA_DIR/backups" ]; then
        install -d -m 0700 -o correduria-local -g correduria-local "$BACKUP_DIR"
        info "Recuerde indicarlo en la pestaña Backups de la app: destino $BACKUP_DIR"
    fi

    # 7.4 override systemd si bind/puerto/ReadWritePaths distintos del paquete
    local drop_dir="/etc/systemd/system/correduria-local.service.d"
    local override="$drop_dir/90-instalador.conf"
    rm -f "$override"
    if [ "$BIND_ADDR" != "127.0.0.1" ] || [ "$PUERTO" != "8080" ] || [ "$BACKUP_DIR" != "/var/lib/correduria/backups" ]; then
        install -d -m 0755 "$drop_dir"
        {
            printf '[Service]\n'
            printf 'ExecStart=\n'
            printf 'ExecStart=/opt/correduria/bin/correduria-server serve --host %s --port %s\n' "$BIND_ADDR" "$PUERTO"
            if [ "$BACKUP_DIR" != "$DATA_DIR/backups" ]; then
                printf 'ReadWritePaths=%s\n' "$BACKUP_DIR"
            fi
        } >"$override"
        ok "Override systemd escrito: $override"
    fi
    systemctl daemon-reload

    # 7.5 Tailscale (red privada + TLS automático si procede)
    URL_FINAL="$URL_PUBLICA"
    if [ "$INSTALAR_TAILSCALE" = "si" ]; then
        systemctl enable --now tailscaled >/dev/null 2>&1 || true
        if tailscale ip -4 >/dev/null 2>&1; then
            ok "Tailscale ya conectado ($(tailscale ip -4 | head -1))"
        else
            info "Iniciando sesión en Tailscale (hostname: $EQUIPO_NOMBRE_NORMALIZADO)"
            if [ -n "$TS_AUTH_KEY" ]; then
                tailscale up --hostname="$EQUIPO_NOMBRE_NORMALIZADO" --auth-key="$TS_AUTH_KEY" >>"$LOG_FILE" 2>&1 \
                    || aviso "tailscale up con auth-key falló (ver $LOG_FILE)"
            elif [ "$MODO_NOINTERACTIVO" = "si" ]; then
                aviso "Sin TS_AUTH_KEY: conecte Tailscale después con 'sudo tailscale up'"
            else
                info "Se mostrará una URL de autorización: ábrala en su navegador (espera máx. 120 s)"
                timeout 120 tailscale up --hostname="$EQUIPO_NOMBRE_NORMALIZADO" || true
            fi
            if tailscale ip -4 >/dev/null 2>&1; then
                ok "Tailscale conectado ($(tailscale ip -4 | head -1))"
                if [ "$MODO_ACCESO" = "tailscale" ]; then
                    if tailscale serve --bg "$PUERTO" >>"$LOG_FILE" 2>&1 || \
                       tailscale serve --bg --https=443 "http://127.0.0.1:$PUERTO" >>"$LOG_FILE" 2>&1; then
                        DNSNAME="$(tailscale status --self --json 2>/dev/null | grep -oE '"DNSName"\s*:\s*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/' | sed 's/\.$//' || true)"
                        if [ -n "$DNSNAME" ]; then URL_FINAL="https://${DNSNAME}"; else URL_FINAL="https://$(tailscale ip -4 | head -1)"; fi
                        ok "Tailscale Serve activo: $URL_FINAL -> 127.0.0.1:$PUERTO"
                    else
                        aviso "No se pudo activar tailscale serve; HTTPS automático no disponible"
                    fi
                fi
            else
                aviso "Tailscale aún sin conectar. Cuando quiera: sudo tailscale up"
                [ "$MODO_ACCESO" = "tailscale" ] && aviso "Y después: sudo tailscale serve --bg $PUERTO"
            fi
        fi
    fi

    # 7.6 Caddy (proxy HTTPS interno para la oficina)
    if [ "$MODO_ACCESO" = "caddy" ]; then
        local caddyfile="/etc/caddy/Caddyfile"
        if [ -f "$caddyfile" ] && ! grep -q "reverse_proxy 127.0.0.1:$PUERTO" "$caddyfile"; then
            cp -a "$caddyfile" "${caddyfile}.bak-$(date +%Y%m%d%H%M%S)"
            aviso "Caddyfile existente respaldado; se añade el sitio de Correduría al final"
        fi
        cat >"$caddyfile" <<CADDY
# Gestionado por install.sh · Correduría Local ($EQUIPO_NOMBRE)
$DOMINIO_LAN {
    tls internal
    reverse_proxy 127.0.0.1:$PUERTO
}
CADDY
        systemctl enable --now caddy >/dev/null 2>&1 || true
        systemctl restart caddy >/dev/null 2>&1 || aviso "Reinicie caddy manualmente si falla"
        ok "Caddy proxy HTTPS interno configurado: https://$DOMINIO_LAN"
        aviso "Abra el puerto 443 en el firewall de la oficina si el DNS interno no resuelve $DOMINIO_LAN"
    fi
}

# =============================================================================
# 8. Arranque y enlace de primera configuración
# =============================================================================
arranque_y_verificacion() {
    info "Arrancando servicio correduria-local"
    systemctl enable --now correduria-local.service >/dev/null 2>&1 || true
    systemctl restart correduria-local.service

    info "Esperando a que la aplicación responda en 127.0.0.1:$PUERTO"
    local espera=0 listo="no"
    while [ $espera -lt 30 ]; do
        if curl -fsS -o /dev/null "http://127.0.0.1:$PUERTO/" 2>>"$LOG_FILE"; then listo="si"; break; fi
        espera=$((espera+1)); sleep 2
    done
    [ "$listo" = "si" ] || {
        systemctl status correduria-local.service --no-pager >&2 || true
        fatal "La aplicación no responde. Revise: journalctl -u correduria-local -n 50 y $LOG_FILE"
    }
    ok "Servicio activo y respondiendo"

    # Enlace de primera puesta en marcha (código de un solo uso)
    info "Generando enlace de primera puesta en marcha"
    if SETUP_LINK="$(correduria-setup-link 2>/dev/null)"; then
        SETUP_LINK_URL="$(printf '%s' "$SETUP_LINK" | grep -oE 'https?://[^ ]+' | head -1 || true)"
    else
        SETUP_LINK_URL=""
    fi
}

# =============================================================================
# 9. Resumen final
# =============================================================================
resumen_final() {
    local url_acceso="$URL_FINAL"
    [ "$MODO_ACCESO" = "local" ] && url_acceso="http://127.0.0.1:$PUERTO"
    local paq_info
    if [ -n "${DEB_FILE_LOCAL:-}" ]; then paq_info="$(basename "$DEB_FILE_LOCAL")"; else paq_info="(instalación existente)"; fi
    banner
    printf '%s\n' "${C_VERDE}${C_NEGRITA}Instalación completada en el equipo «$EQUIPO_NOMBRE»${C_FIN}"
    echo
    printf '  %-28s %s\n' "Modo de acceso:"      "$MODO_ACCESO"
    printf '  %-28s %s\n' "Escucha:"              "127.0.0.1:$PUERTO  (nunca exponga HTTP plano)"
    printf '  %-28s %s\n' "URL de acceso:"       "$url_acceso"
    printf '  %-28s %s\n' "Zona horaria:"         "$ZONA_HORARIA"
    printf '  %-28s %s\n' "Directorio de datos:"  "$DATA_DIR (0700, usuario correduria-local)"
    printf '  %-28s %s\n' "Backups (staging):"    "$BACKUP_DIR"
    printf '  %-28s %s\n' "Canal actualizaciones:" "${MANIFEST_URL:-desactivado}"
    printf '  %-28s %s\n' "Configuración sistema:" "/etc/correduria/application.env"
    printf '  %-28s %s\n' "Log del instalador:"   "${LOG_FILE:-no disponible}"
    echo
    if [ -n "${SETUP_LINK_URL:-}" ]; then
        printf '%s\n' "${C_NEGRITA}ENLACE DE PRIMERA PUESTA EN MARCHA (un solo uso):${C_FIN}"
        printf '  %s\n' "$SETUP_LINK_URL"
        echo
    else
        printf '%s\n' "${C_AMAR}No se obtuvo el enlace automáticamente. Ejecute:${C_FIN} sudo correduria-setup-link"
        echo
    fi
    cat <<PASOS
${C_NEGRITA}Pasos siguientes en la interfaz web:${C_FIN}
  1. Abra el enlace y cree su cuenta (correo, contraseña de 12–128 caracteres
     y nombre del negocio). El código queda invalidado al usarse.
  2. Configuración → Correo de recuperación: SMTP (STARTTLS 587 o TLS 465) y
     prueba de envío. Las credenciales se guardan cifradas en la app.
  3. Backups: active la copia diaria y, MUY IMPORTANTE, pulse
     «Guardar clave de recuperación» y guárdela FUERA de este equipo.
     Aplique la regla 3-2-1 (manual de configuración, sección 12).
  4. Configuración → Modelos de IA: suscripción ChatGPT Plus/Pro (OAuth) o
     clave API (OpenAI, Ollama, etc.). Opcional.
  5. Mantenimiento → Comprobar actualizaciones: el canal firmado ya está
     configurado (${paq_info}).

PASOS
    [ "$INSTALAR_TAILSCALE" = "si" ] && printf '%s\n' "  Tailscale: sudo tailscale status · sudo tailscale serve --bg $PUERTO"
    echo
}

# =============================================================================
# main
# =============================================================================
main() {
    parsear_args "$@"
    normalizar_respuestas
    inicializar_log
    banner
    comprobaciones_previas

    if [ "$SOLO_CONFIG" = "si" ]; then
        banner
        info "Modo solo-configuración: se omite la instalación del paquete"
        DEB_FILE_LOCAL=""
        preguntar_equipo
        preguntar_acceso
        preguntar_almacenamiento
        instalar_dependencias
        aplicar_configuracion
        arranque_y_verificacion
        resumen_final
    else
        preguntar_equipo
        localizar_paquete
        preguntar_acceso
        preguntar_almacenamiento
        instalar_dependencias
        instalar_paquete
        aplicar_configuracion
        arranque_y_verificacion
        resumen_final
    fi

    [ -n "$CONF_ESCRITA" ] && export_respuestas "$CONF_ESCRITA"
    registrar "INSTALACION FINALIZADA"
}

main "$@"
