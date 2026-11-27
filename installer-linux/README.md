# correduria-installer-linux · Instalador guiado (Unix)

Carpeta con el **instalador guiado para Ubuntu/Debian (arm64 y amd64)** de la Plataforma Correduría Local (dentro del repositorio `correduria-release`). Prepara un equipo nuevo de cero y configura **todo** en un único flujo interactivo, sin editar `.env` ni `config.json` a mano.

Guía paso a paso para usuarios: [Manual de Instalación](../manual-instalacion.md). Paquetes `.deb` y manuales: en este mismo repositorio (`correduria-release`). Versión Windows: carpeta `../installer-windows/`.

## Uso rápido

```bash
# Equipo nuevo (interactivo): pregunta hostname, zona horaria, modo de acceso,
# puerto, datos, backups y canal de actualizaciones — todo en un flujo.
sudo bash install.sh

# Instalación desatendida (mismo resultado, sin preguntas):
sudo bash install.sh --unattended answers.example.conf --deb correduria-local_1.0.0_amd64.deb

# Reconfigurar una instalación existente (mismo flujo de preguntas, sin tocar el paquete):
sudo bash install.sh --solo-config
```

| Opción | Efecto |
|---|---|
| `--unattended <fichero>` | Modo desatendido con fichero KEY=VAL ([ejemplo](answers.example.conf)) |
| `--solo-config` | Reconfigura sin reinstalar el paquete |
| `--deb <ruta\|URL>` | Paquete `.deb` concreto a instalar |
| `--respuestas <fichero>` | Exporta las respuestas usadas (instalación reproducible) |
| `-y` / `--yes` | Acepta los valores por defecto |

## Qué pregunta / instala

1. **Prechecks**: root, Ubuntu/Debian, arch `arm64` (glibc ≥ 2.41) o `amd64` (glibc ≥ 2.43), puerto libre, instalación previa.
2. **Equipo**: nombre del equipo (*hostname* configurable del ordenador donde se instala — mini PC, escritorio o servidor), zona horaria.
3. **Paquete**: detectado junto al instalador, ruta local o URL; verifica SHA-256 contra `manifest-<versión>-<arch>.json` o `manifest-<versión>.json` (y `manifest-latest-...`) si está presente.
4. **Acceso**: solo local / **Tailscale** (recomendado: red privada + HTTPS automático con `tailscale serve`) / **Caddy** HTTPS interno en LAN (con exportación automática de la CA local a `/etc/correduria/local-ca-root.crt` vía `correduria-server export-ca`) / **Proxy HTTPS propio** (la app escucha siempre en `127.0.0.1`). Para acceso multi-origen LAN Bonjour + Tailscale tras instalar, el paquete incluye además `sudo correduria-configure-access`.
5. **Datos**: directorio de datos, directorio de backups (regla 3-2-1), canal de actualizaciones Ed25519 (manifiesto `manifest-latest.json` o `manifest-latest-amd64.json`, clave pública `/etc/correduria/release-public.key` por defecto y `entitlement.json`).
6. **Dependencias de terceros**: `ca-certificates`, `curl`, `adduser` y, según el modo elegido, **Tailscale** (script oficial) y **Caddy**.
7. **Salida**: servicio activo (`correduria-local.service` y `correduria-updater.path` para actualizaciones en 1 clic) + **enlace de primera puesta en marcha** + checklist (cuenta, SMTP, clave de recuperación de backups, IA).

SMTP, proveedores de IA y la cuenta de usuario se configuran **después**, en la interfaz web (se guardan cifrados en la base de datos de la aplicación).

## Ficheros

| Fichero | Propósito |
|---|---|
| `install.sh` | Instalador interactivo/desatendido |
| `answers.example.conf` | Plantilla KEY=VAL para `--unattended` |

## Registros y configuración resultante

- Log por ejecución: `/var/log/correduria-instalador/instalacion-<fecha>.log`
- Configuración generada: `/etc/correduria/` (`0755`), `/etc/correduria/application.env` (`0600`, incluyendo `CORREDURIA_LOCAL_CA_CERT_FILE=/etc/correduria/local-ca-root.crt`), certificado público `/etc/correduria/local-ca-root.crt` (`0644` en modo Caddy) + *override* systemd (`/etc/systemd/system/correduria-local.service.d/90-instalador.conf`) si se cambió puerto/bind/destino de backups.
