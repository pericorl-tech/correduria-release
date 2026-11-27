# Manual de Instalación · Plataforma Correduría Local

Manual paso a paso para dejar la plataforma funcionando en un **equipo nuevo desde cero**. Dirigido a la persona técnica o al propio corredor que realiza la instalación (no requiere conocer el producto por adelantado).

Versión del manual: 1.2 (Correduría v1.0.0) · Instalador Linux v1.0.1 · Instalador Windows: fase piloto.

Documentación relacionada:
- [Manual de Usuario](manual-usuario.md) (uso diario) · [Manual de Configuración](manual-configuracion.md) (credenciales y parámetros de la app) · [Análisis de la versión Windows](docs/analisis-instalador-windows.md).
- Repositorios de instaladores: `installer-linux/` y `installer-windows/` (incluidos en el proyecto; véase el README).

---

## Índice

1. [Qué necesita tener preparado](#1-qué-necesita-antes-de-empezar)
2. [Instalación en Ubuntu/Debian (guiada, recomendada)](#2-instalación-en-ubuntudebian-guiada-recomendada)
3. [Las preguntas del instalador, explicadas](#3-las-preguntas-del-instalador-una-a-una)
4. [Después de instalar: primera puesta en marcha](#4-después-de-instalar-primera-puesta-en-marcha-en-la-web)
5. [Instalación desatendida (varios equipos)](#5-instalación-desatendida-varios-equipos)
6. [Instalación en Windows (fase piloto)](#6-instalación-en-windows-fase-piloto)
7. [Comprobaciones finales](#7-comprobaciones-finales)
8. [Resolución de incidencias](#8-resolución-de-incidencias)
9. [Desinstalación](#9-desinstalación)

---

## 1. Qué necesita antes de empezar

### Para cualquier instalación

| Elemento | Detalle |
|---|---|
| El **equipo de instalación** | El ordenador elegido (mini PC, sobremesa o servidor). No hay hardware mínimo exigente: 2 GB de RAM o más y unos GB libres de disco son suficientes. |
| Nombre para el equipo | Un nombre (*hostname*) sencillo y único para el equipo: p. ej. `correduria-oficina`. Solo letras, números y guiones. Es el nombre con el que reconocerá el servidor en la red privada. |
| Cuenta de correo de la correduría | Será la cuenta única de la aplicación (monousuario) y destino de los avisos. |
| Acceso a Internet en el equipo | El instalador descarga dependencias y, si se usa, la cuenta de Tailscale. |

### Servicios opcionales de terceros (decida antes si los quiere)

| Servicio | Para qué | Imprescindible |
|---|---|---|
| **Tailscale** (cuenta gratuita basta) | Acceder desde sus dispositivos (portátil, móvil) con HTTPS, sin abrir puertos en el router. | No, pero es **muy recomendable** |
| SMTP (Gmail, Outlook, correo de dominio propio) | Avisos de vencimientos y recuperación de contraseña. Se configura **después**, en la web. Puede configurarse después. |
| Proveedor de IA (ChatGPT Plus/Pro, API OpenAI u Ollama local) | Asistente de consulta. | No |

### Específico por sistema

| Sistema | Requisitos |
|---|---|
| **Ubuntu/Debian arm64** | Ubuntu 24.10+ / Debian 13 (glibc ≥ 2.41), arquitectura arm64, `sudo` disponible. |
| **Ubuntu/Debian amd64** | Ubuntu/Debian amd64 con **glibc ≥ 2.43** (build oficial desde v0.8.3), `sudo` disponible. |
| **Windows 10/11 x64 (piloto)** | Windows 10 1809+ o Windows 11, cuenta de Administrador, y el artefacto `correduria-local_<versión>_win32-x64.zip` (se genera con el workflow `installer-windows/ci/build-windows.yml` en un runner Windows; véase sección 6). |

### Materiales de la aplicación

1. El paquete del último *release* para su arquitectura (`correduria-local_<versión>_amd64.deb` o `correduria-local_<versión>_arm64.deb`) y su manifiesto (`manifest-latest-amd64.json` para amd64; `manifest-latest.json` para arm64), desde los Releases del proyecto. Desde `v0.8.4` hasta `v1.0.0` se publica paquete oficial `amd64`; la arquitectura `arm64` dispone de paquete publicado hasta `v0.8.3`.
2. Los instaladores: carpeta `installer-linux/` o `installer-windows/` (incluidas en este repositorio `correduria-release`).

---

## 2. Instalación en Ubuntu/Debian (guiada, recomendada)

### 2.1 Copie los materiales al equipo nuevo

```bash
# Opción A: clone el repositorio de distribución (incluye los instaladores)
git clone https://github.com/pericorl-tech/correduria-release.git
cd correduria-release/installer-linux
# Descargue además del release más reciente de su arquitectura el paquete
#   correduria-local_<versión>_<arch>.deb   (arch = amd64 en v1.0.0, o arm64 hasta v0.8.3)
#   (+ su manifiesto: manifest-latest-amd64.json en amd64 / manifest-latest.json en arm64)
#   y colóquelos en esta misma carpeta (o en su carpeta padre).

# Opción B: copie manualmente la carpeta installer-linux y el .deb por USB/SCP.
```

### 2.2 Ejecute el instalador

```bash
cd installer-linux
sudo bash install.sh
```

El instalador comprueba primero el equipo (root, Ubuntu/Debian, arquitectura `arm64` con glibc ≥ 2.41 o `amd64` con glibc ≥ 2.43, puerto libre) y le va haciendo las preguntas del flujo. Responda una a una; cada pregunta muestra entre corchetes `[...]` el valor por defecto (pulse Enter para aceptarlo).

### 2.3 Al terminar

El instalador muestra un resumen con la **URL de acceso** y el **ENLACE DE PRIMERA PUESTA EN MARCHA** (código de un solo uso). **Cópielo**: solo funciona la primera vez. Si no apareció, obténgalo con:

```bash
sudo correduria-setup-link
```

---

## 3. Las preguntas del instalador, una a una

| # | Pregunta | Qué significa | Ejemplo |
|---|---|---|---|
| 1 | **Nombre del equipo (hostname)** | El nombre del ordenador donde instala: mini PC, sobremesa o servidor. El instalador ofrece aplicarlo al sistema (`hostnamectl`). | `correduria-oficina` |
| 2 | **Zona horaria** | Zona IANA; afecta a avisos, backups y horarios. | `Europe/Madrid` |
| 3 | **Paquete .deb** | Qué paquete instalar (detecta el de mayor versión junto al script; admite ruta o URL). Verifica SHA-256 contra el manifiesto si está disponible. | `correduria-local_1.0.0_amd64.deb` |
| 4 | **Modo de acceso** | 1 local / 2 **Tailscale** (recomendado: red privada + HTTPS automático) / 3 Caddy HTTPS interno / 4 Proxy HTTPS propio (la app escucha en `127.0.0.1`). | `2` |
| 5 | Puerto local | Dónde escucha la app (por defecto 8080). No lo exponga nunca en HTTP plano. | `8080` |
| 6 | **URL pública** | La URL que verá usted y saldrá en los correos. Se deriva del modo elegido; puede editarla. | `https://correduria-oficina.ts.net` |
| 7 | Directorio de datos | Donde vive la base de datos cifrada y los PDFs (0700). Cambiables solo antes del primer arranque con datos. | `/var/lib/correduria` |
| 8 | **Directorio de backups** | Zona de preparación de los `.crbk`. Recuerde la regla 3-2-1: copie los backups **fuera** del equipo. | `/var/lib/correduria/backups` |
| 9 | Canal de actualizaciones | URL del manifiesto firmado (por defecto el canal público de su arquitectura). Vacío = sin canal. | `https://github.com/pericorl-tech/correduria-release/releases/latest/download/manifest-latest-amd64.json` |
| 10 | Clave pública / entitlement | Solo si el distribuidor le ha dado clave pública o fichero `entitlement.json` propios. Si deja vacía la clave pública, se usa `/etc/correduria/release-public.key`. | (vacío) |
| 11 | ¿Instalar Tailscale? | Se instala del repositorio oficial si lo eligió. Si no dispone de auth-key, el instalador muestra una URL para unir el equipo a su red Tailscale desde el navegador. | `S` |

**Ajustes automáticos incluidos (`v0.8.5`+ / `v1.0.0`):** el paquete `.deb` y `install.sh` dejan `/etc/correduria` con permisos `0755`, configuran por defecto `CORREDURIA_UPDATE_PUBLIC_KEY_FILE=/etc/correduria/release-public.key` y `CORREDURIA_LOCAL_CA_CERT_FILE=/etc/correduria/local-ca-root.crt` (exportando automáticamente el certificado raíz público de Caddy en modo Caddy) y habilitan `correduria-updater.path` para permitir actualizaciones verificadas en 1 clic.

**Lo que el instalador NO pregunta** (se hace después, en la web, porque se guarda cifrado en la base de datos): contraseña de la cuenta, SMTP, proveedores de IA, política de avisos y política de backups.

---

## 4. Después de instalar: primera puesta en marcha en la web

1. Abra el **enlace de primera puesta en marcha** (o `http://127.0.0.1:8080` en el propio equipo) y cree su cuenta: correo, contraseña de **12–128 caracteres** y nombre del negocio. El código queda invalidado tras el uso.
2. **Configuración → Cuenta y correo → Correo de recuperación**: servidor SMTP, puerto 587 (STARTTLS) o 465 (TLS), remitente, usuario y contraseña de aplicación; pulse **Enviar correo de prueba**.
3. **Backups**: active la copia diaria y pulse **Guardar clave de recuperación** → guarde el archivo `correduria-backup-recovery.key` **fuera del equipo** (gestor de contraseñas o USB cifrado). Sin esa clave, los backups no se pueden descifrar jamás.
4. (Opcional) **Configuración → Asistente IA → Modelos de IA y Suscripciones**: suscripción ChatGPT Plus/Pro (OAuth automático) o clave API.
5. **Mantenimiento → Actualizaciones del sistema**: verifique el canal firmado configurado, copie el **ID de instalación** si necesita solicitar o renovar su fichero de derecho (`entitlement.json`) y use **Comprobar actualizaciones** / **Actualizar ahora** (en 1 clic mediante `correduria-updater.path`).
6. (Si utiliza Caddy HTTPS interno en la oficina) **Mantenimiento → Certificado HTTPS para sus dispositivos**: descargue el perfil o script para su equipo (`.mobileconfig`, `.command`, `.cmd`, `.sh` o `.crt`) y compruebe la **huella SHA-256** para evitar avisos del navegador.

Detalle de cada punto: [Manual de Configuración](manual-configuracion.md).

---

## 5. Instalación desatendida (varios equipos)

Para repetir la misma instalación en varios equipos sin repetir preguntas:

```bash
# 1. En el primer equipo, tras instalar, exporte las respuestas:
sudo bash install.sh --solo-config --respuestas instalacion.conf   # o añada --respuestas a la instalación

# 2. Copie install.sh + answers + el .deb a los equipos nuevos y ejecute:
sudo bash install.sh --unattended instalacion.conf --deb correduria-local_1.0.0_amd64.deb
```

- Plantilla de fichero de respuestas: [`installer-linux/answers.example.conf`](installer-linux/answers.example.conf).
- La clave de autenticación de Tailscale (si la usa) va **solo por variable de entorno**, nunca en el fichero: `TS_AUTH_KEY=tskey-... sudo bash install.sh --unattended instalacion.conf --deb ...`.

## 5b. Reconfigurar sin reinstalar y perfil multi-origen

```bash
sudo bash install.sh --solo-config    # mismo flujo de preguntas; no toca los ficheros del paquete
```

Sirve para cambiar hostname del equipo, modo de acceso (p. ej. pasar de local a Tailscale), puerto, URL pública o canal de actualizaciones.

En servidores Ubuntu dedicados con `caddy` y `avahi-daemon` que necesiten acceso simultáneo por red local Bonjour (`https://<hostname>.local/`) y acceso remoto por Tailscale (`CORREDURIA_ADDITIONAL_PUBLIC_URLS`), también puede aplicar el perfil multi-origen:

```bash
sudo correduria-configure-access                        # solo LAN (https://<hostname>.local/)
sudo correduria-configure-access equipo.tailnet.ts.net  # LAN + Tailscale simultáneos
```

El comando guarda copia previa de `Caddyfile` y `application.env` en `/var/backups/correduria-access.*`, exporta automáticamente el certificado público CA de Caddy a `/etc/correduria/local-ca-root.crt` y reinicia los servicios. (Si incluye Tailscale con Caddy, conceda previamente `TS_PERMIT_CERT_UID=caddy` a `tailscaled`).

---

## 6. Instalación en Windows (fase piloto)

> [!IMPORTANT]
> El instalador PowerShell **ya está disponible** en `installer-windows/Setup-Correduria.ps1` y funciona de principio a fin **si dispone del artefacto binario** `correduria-local_<versión>_win32-x64.zip`. Ese artefacto se compila en un runner Windows de GitHub Actions (PyInstaller no compila desde Linux): copie `installer-windows/ci/build-windows.yml` al repositorio privado `correduria` como `.github/workflows/build-windows.yml`, ejecute *Run workflow* sobre la rama `feature/win64-build` y descargue el artefacto. Mientras no exista el zip, la instalación en Windows no puede completarse (el instalador lo indica claramente al no encontrar el paquete). Análisis completo: [docs/analisis-instalador-windows.md](docs/analisis-instalador-windows.md).

Cuando el artefacto exista:

```powershell
# En PowerShell, como Administrador:
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1
# Desatendido:
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1 -AnswersFile instalacion.conf -Package C:\descargas\correduria-local_0.9.0_win32-x64.zip
```

Preguntas y comportamiento son los mismos conceptos que en Linux (nombre de equipo, zona horaria en formato Windows —p. ej. `Romance Standard Time`—, modo de acceso, puerto, datos en `%ProgramData%\Correduria`, canal de actualizaciones). Como servicios de terceros instala **WinSW** (servicio de Windows) y **Tailscale** (MSI oficial), con la misma red privada y HTTPS automático.

**Actualizar en Windows (fase piloto)**: `tools/Update-Correduria.ps1` (descarga manifiesto → verifica SHA-256 y tamaño → para el servicio → guarda backup → sustituye → arranca). El mecanismo `update-install` es **interno de la aplicación**; la versión Windows lo tendrá dentro de `correduria-server.exe` en la fase 2, usando el mismo manifiesto firmado que Linux.

---

## 7. Comprobaciones finales

| Comprobación | Linux | Windows |
|---|---|---|
| Servicio activo | `systemctl status correduria-local.service` | `Get-Service CorreduriaLocal` |
| Responde la web | `curl -I http://127.0.0.1:8080/` | `Invoke-WebRequest http://127.0.0.1:8080/` |
| Red privada (si usó Tailscale) | `tailscale status` · `tailscale serve status` | `tailscale status` / `tailscale serve status` |
| Permisos estrictos | `ls -ld /var/lib/correduria` (drwx------) | `icacls C:\ProgramData\Correduria` (solo admins y cuenta de servicio) |
| Canal de actualizaciones | pestaña **Mantenimiento** de la web | igual |
| Actualizador en 1 clic | `systemctl status correduria-updater.path` | — (fase 2 en `correduria-server.exe`) |
| Certificado CA local (modo Caddy) | `ls -l /etc/correduria/local-ca-root.crt` | — |

## 8. Resolución de incidencias

| Síntoma | Causa probable | Solución |
|---|---|---|
| El instalador aborta: "glibc demasiado antigua" | Ubuntu/Debian con glibc anterior a 2.41 (`arm64`) o 2.43 (`amd64`) | Actualice a Ubuntu 24.10+ / Debian 13 (arm64) o sistema compatible con glibc ≥ 2.43 (amd64). |
| "Puerto en uso" | Otra aplicación ocupa el 8080 | Elija otro puerto en la pregunta o libere el puerto. |
| La web no responde tras instalar | Servicio caído | `journalctl -u correduria-local -n 50` (Linux) o logs de WinSW en la carpeta de instalación (Windows). |
| No llega el enlace de setup | Ya se usó antes | `sudo correduria-setup-link` genera uno nuevo (el anterior queda invalidado). |
| Tailscale conectado pero la URL `.ts.net` da error | Falta `serve` | `sudo tailscale serve --bg 8080` (o `--bg <puerto>`). |
| El navegador avisa de certificado (modo Caddy) | Certificado interno sin confiar aún en el dispositivo cliente | Descargue e instale el perfil o script desde **Mantenimiento → Certificado HTTPS para sus dispositivos** verificando su huella SHA-256 (en iPhone/iPad active además la confianza total en *Ajustes → General → Información → Ajustes de certificados*). |
| Correo de prueba SMTP falla | Contraseña de aplicación no generada | Vea Manual de Configuración §11.1 (Gmail/Microsoft 365). |

## 9. Desinstalación

- **Linux**: `sudo apt remove correduria-local` detiene el servicio y retira el programa. Los **datos y claves NO se borran** (`/var/lib/correduria`). Para borrarlos usted mismo (sin retorno): `sudo rm -rf /var/lib/correduria` y borre el usuario con `sudo deluser --remove-home correduria-local`.
- **Windows**: `cd "C:\Program Files\Correduria" && correduria-service.exe stop && correduria-service.exe uninstall`. Los datos de `%ProgramData%\Correduria` se conservan; bórrelos solo si está seguro.

> [!CAUTION]
> Antes de desinstalar o formatear el equipo, haga una **copia manual** del último `.crbk` y, sobre todo, conserve la **clave de recuperación** fuera del equipo (manual de configuración §12.3).
