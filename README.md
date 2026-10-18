# Correduría · Distribución oficial

Distribución binaria de la **plataforma web local de gestión de correduría de seguros**: aplicación *self-hosted* y monousuario para corredurías que se instala en un equipo propio (el *equipo* que elija la correduría —mini PC, sobremesa o servidor—, identificado por su *hostname*), no en la nube.

Gestión del negocio en un solo lugar: clientes (particulares, autónomos y empresas), pólizas y periodos de vigencia, gestor documental cifrado, calendario de vencimientos y avisos, exportación para derechos RGPD, asistente de consulta con IA opcional, copias de seguridad cifradas y **actualizaciones firmadas criptográficamente (Ed25519)**.

Este repositorio contiene paquetes instalables, manuales y los **instaladores guiados** (carpetas `installer-linux/` e `installer-windows/`). El código fuente permanece en el repositorio privado `correduria` (no incluido en el paquete).

### Estructura del proyecto

| Carpeta / repo | Contenido | Sistema |
|---|---|---|
| (raíz) `correduria-release` | Paquetes `.deb`, manuales, análisis | — |
| [`installer-linux/`](installer-linux/) | Instalador guiado `install.sh` + plantilla de respuestas | Ubuntu/Debian arm64 |
| [`installer-windows/`](installer-windows/) | Instalador guiado `Setup-Correduria.ps1` + servicio WinSW + `Update-Correduria.ps1` | Windows 10/11 x64 (piloto) |

Los instaladores viven como **carpetas de este repositorio** (se descargan junto con todo lo demás). Si en el futuro se publicaran como repositorios propios (`correduria-installer-linux` / `correduria-installer-windows`), pueden extraerse con `git subtree split --prefix=installer-linux -b main` sin perder historial. Ambos comparten el mismo **canal de actualizaciones firmado** (manifiesto Ed25519 multi-arquitectura) publicado en los Releases de este repo.

## Plataformas

| Plataforma | Estado |
|---|---|
| Ubuntu/Debian arm64 (glibc ≥ 2.41) | **Disponible** (paquete `.deb` + instalador guiado `installer-linux`) |
| Ubuntu amd64 | Planificado |
| Windows 10/11 x64 | Piloto — instalador `installer-windows` + análisis en [docs/analisis-instalador-windows.md](docs/analisis-instalador-windows.md) |

Por ahora **solo hay versión para Ubuntu/Debian** (paquete `.deb`). El **nombre del equipo (hostname)** es un elemento a configurar durante la instalación: la plataforma funciona en el equipo que elija la correduría (mini PC, equipo de escritorio o servidor pequeño), sin depender de ningún modelo concreto de hardware.

## Descarga

Use el último [release](https://github.com/pericorl-tech/correduria-release/releases) más reciente.

Cada release incluye:

* `correduria-local_<versión>_arm64.deb` — paquete binario (incluye su *runtime*; no requiere Python ni dependencias del sistema).
* `manifest-<versión>.json` — manifiesto firmado (Ed25519) con la URL del artefacto, su SHA-256 y su tamaño exacto, para el canal de actualizaciones.
* `manifest-latest.json` — el mismo manifiesto firmado de **la versión vigente**, bajo un nombre estable: es la URL recomendada para configurar instalaciones (`releases/latest/download/manifest-latest.json`) y no cambia entre versiones. Publicada una nueva versión, se **reemplaza** este asset con el manifiesto nuevo firmado.

## Instalación (Ubuntu/Debian arm64)

### Opción recomendada: instalador guiado

El instalador [`installer-linux/install.sh`](installer-linux/install.sh) prepara un equipo **nuevo de cero** y pide **todas** las configuraciones durante el proceso (nombre del equipo/hostname, zona horaria, modo de acceso, puerto, datos, backups y canal de actualizaciones), sin tener que editar a mano ficheros `.env` ni `config.json`:

```bash
sudo bash installer-linux/install.sh
```

El instalador:

1. Comprueba SO, arquitectura (arm64) y glibc (≥ 2.41).
2. Pregunta el **nombre del equipo** (*hostname* donde se instalará: mini PC, escritorio o servidor) y la zona horaria.
3. Localiza o descarga el paquete `.deb` y verifica su SHA-256 contra el manifiesto.
4. Pide el **modo de acceso**: solo local, **Tailscale** (red privada con HTTPS automático, recomendado), proxy Caddy con HTTPS interno en la oficina, o LAN directa.
5. Pide directorio de datos, directorio de backups y parámetros del canal de actualizaciones firmado.
6. Instala las **dependencias de terceros**: `ca-certificates` y, si se eligen, **Tailscale** (repositorio oficial `tailscale.com`) y **Caddy** (proxy HTTPS).
7. Instala el paquete, genera `/etc/correduria/application.env` (y un *override* de systemd si procede) y muestra el **enlace de primera puesta en marcha**.

Opciones: `--help`, `--unattended respuestas.conf` (instalación desatendida; ver [`installer-linux/answers.example.conf`](installer-linux/answers.example.conf)), `--solo-config` (reconfigurar sin reinstalar), `--deb <ruta|URL>`, `--respuestas <fichero>` (exportar las respuestas para reproducir la instalación).

> Las credenciales de aplicación (SMTP, proveedores de IA, cuenta) **no** se piden en el instalador: se introducen en la interfaz web tras el primer arranque y se almacenan cifradas en la base de datos.

### Opción manual (paquete `.deb` directo)

1. Compruebe la arquitectura del equipo:

   ```bash
   dpkg --print-architecture        # debe decir arm64
   ldd --version | head -1          # glibc >= 2.41
   ```

2. Verifique la integridad del paquete con el SHA-256 publicado en el release:

   ```bash
   sha256sum correduria-local_<versión>_arm64.deb
   ```

3. Instale:

   ```bash
   sudo dpkg -i correduria-local_<versión>_arm64.deb
   ```

   El postinst crea el usuario `correduria-local`, el directorio de datos `/var/lib/correduria` (permisos `0700`), y habilita el servicio `correduria-local.service`.

4. Compruebe el servicio y obtenga el enlace de primera configuración:

   ```bash
   systemctl status correduria-local.service
   sudo correduria-setup-link
   ```

5. Abra `http://127.0.0.1:8080` en el propio equipo (o el enlace mostrado por el paso anterior) y **durante la primera puesta en marcha cree su cuenta** (correo, contraseña de 12–128 caracteres y nombre del negocio). El código de instalación queda invalidado al usarse.

Para publicar la web en LAN con HTTPS, el instalador configura automáticamente **Tailscale Serve** (red privada con certificado TLS gestionado) o **Caddy** (proxy con certificado interno); si instala el paquete a mano, la app siempre escucha en `127.0.0.1:8080` por defecto y deberá montar usted el proxy.

## Dependencias de terceros

Para un funcionamiento completo en un entorno totalmente nuevo, el instalador se ocupa de:

| Dependencia | Para qué | Cuándo se instala |
|---|---|---|
| `ca-certificates`, `adduser`, `curl` | Confianza TLS, usuario de servicio, descargas | Siempre |
| **Tailscale** | Red privada entre los equipos de la correduría + HTTPS automático (`tailscale serve`); alternativa a exponer la LAN | Si elige el modo de acceso Tailscale (recomendado) |
| **Caddy** | Proxy inverso HTTPS con certificado interno en la LAN de la oficina | Si elige el modo de acceso Caddy |

El resto de servicios externos (SMTP para avisos, proveedores de IA) son opcionales y se configuran desde la propia interfaz web, no requieren instalación en el servidor.

## Actualizaciones

La aplicación nunca se actualiza sola:

1. En **Mantenimiento → Comprobar actualizaciones** la app compara su versión con un manifiesto firmado, descarga a *staging* y verifica firma, hash y derecho de actualización de la instalación.
2. Un operador ejecuta en terminal:

   ```bash
   /opt/correduria/bin/correduria-server update-install
   ```

El canal de manifiesto se configura vía variables en `/etc/correduria/application.env` (`CORREDURIA_UPDATE_MANIFEST_URL`, `CORREDURIA_UPDATE_PUBLIC_KEY_FILE`, `CORREDURIA_UPDATE_ENTITLEMENT_FILE`) o desde el panel **Configuración / Mantenimiento**. Los manifiestos generados a partir de este repositorio apuntan aquí (`releases/download/`), de modo que instalaciones nuevas no necesiten credenciales para comprobar actualizaciones.

> [!IMPORTANT]
> **`update-install` es una función interna de la aplicación `correduria-server`, no del sistema operativo.** Ni Linux ni Windows aportan ese mecanismo para aplicaciones de terceros: es el propio binario quien verifica el manifiesto firmado Ed25519, el hash y el derecho de actualización, y aplica el paquete. En Windows ocurre lo mismo: el subcomando `update-install` deberá existir **dentro de `correduria-server.exe`** (repositorio privado, fase 2); hasta entonces, el instalador [`installer-windows`](installer-windows/) aplica las actualizaciones con su script externo [`tools/Update-Correduria.ps1`](installer-windows/tools/Update-Correduria.ps1) (verifica SHA-256 y tamaño, para el servicio, sustituye ficheros y arranca). El **canal** (manifiesto firmado, multi-arquitectura) es idéntico para ambos sistemas operativos; lo que cambia es solo el aplicador.

## Instalación (Windows 10/11 x64 · piloto)

Existe un instalador guiado en PowerShell en el repositorio anidado [`installer-windows/`](installer-windows/) (equivalente al `install.sh` de Linux: pide nombre del equipo/hostname, zona horaria, modo de acceso, puerto, datos, backups y canal de actualizaciones):

```powershell
# Como Administrador:
powershell -ExecutionPolicy Bypass -File .\installer-windows\Setup-Correduria.ps1
```

Requiere el artefacto `correduria-local_<versión>_win32-x64.zip`. **Su generación ya está automatizada**: un workflow de GitHub Actions (`windows-latest`) lo produce en el repositorio privado. Copie [`installer-windows/ci/build-windows.yml`](installer-windows/ci/build-windows.yml) al repo `correduria` como `.github/workflows/build-windows.yml`, ejecute *Run workflow* y descargue el artefacto. Instrucciones completas en [`installer-windows/README.md`](installer-windows/README.md). Estado y limitaciones: [docs/analisis-instalador-windows.md](docs/analisis-instalador-windows.md).

## Manuales y documentación

* [Manual de Instalación](manual-instalacion.md): instalación paso a paso en un equipo nuevo (Linux guiado/desatendido y Windows piloto), preguntas explicadas, primeras configuraciones, comprobaciones y resolución de incidencias.
* [Manual de Usuario](manual-usuario.md): uso diario de cada módulo (resumen, calendario, avisos, clientes, pólizas, documentos, privacidad, asistente, backups y mantenimiento).
* [Manual de Configuración](manual-configuracion.md): cuenta, SMTP, códigos de cliente, catálogos, comisiones, política de vencimientos, backups (regla 3-2-1), proveedores de IA (API o suscripción ChatGPT Plus/Pro), canal de actualizaciones y diagnóstico.
* [Análisis del instalador para Windows](docs/analisis-instalador-windows.md): viabilidad, componentes necesarios y elementos que habría que adaptar del diseño actual (servicio, permisos y canal de actualizaciones).

## Seguridad

* Los datos se almacenan cifrados localmente (SQLite + Fernet/AES por documento) y los backups son cifrados con clave de recuperación fuera del equipo.
* El paquete binario **no incluye el código fuente** de la aplicación.
* Cada release y su manifiesto están firmados con Ed25519; una firma válida es la única vía para que la app acepte una actualización, con independencia de dónde se alojen los ficheros.
* La llave pública de confianza va incluida dentro del paquete; la clave privada de firma nunca sale del puesto de firma y no forma parte de este repositorio.

## Estado del producto

* Versión actual: véase el último release.
* Las comisiones se registran como "condiciones comerciales" sin cálculo automático por momento; OCR y facturación se incorporarán con reglas/proveedores confirmados.
* La plataforma no certifica cumplimiento normativo integral: ofrece registros, cifrado y trazabilidad que apoyan a la correduría.

## Sobre este repositorio

* Software propietario de la correduría; distribución controlada vía releases firmados.
* Repositorio de código (privado): `pericorl-tech/correduria`.
* Sugerencias y avisos (p. ej. fallo de verificación de firma): abra un *issue* aquí.
