# correduria-installer-linux · Instalador guiado (Unix)

Carpeta con el **instalador guiado para Ubuntu/Debian (arm64)** de la Plataforma Correduría Local (dentro del repositorio `correduria-release`). Prepara un equipo nuevo de cero y configura **todo** en un único flujo interactivo, sin editar `.env` ni `config.json` a mano.

Guía paso a paso para usuarios: [Manual de Instalación](../manual-instalacion.md). Paquetes `.deb` y manuales: en este mismo repositorio (`correduria-release`). Versión Windows: carpeta `../installer-windows/`.

## Uso rápido

```bash
# Equipo nuevo (interactivo): pregunta hostname, zona horaria, modo de acceso,
# puerto, datos, backups y canal de actualizaciones — todo en un flujo.
sudo bash install.sh

# Instalación desatendida (mismo resultado, sin preguntas):
sudo bash install.sh --unattended answers.example.conf --deb correduria-local_0.8.3_arm64.deb

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

1. **Prechecks**: root, Ubuntu/Debian, arch arm64, glibc ≥ 2.41, puerto libre, instalación previa.
2. **Equipo**: nombre del equipo (*hostname* configurable del ordenador donde se instala — mini PC, escritorio o servidor), zona horaria.
3. **Paquete**: detectado junto al instalador, ruta local o URL; verifica SHA-256 contra `manifest-<versión>.json` si existe.
4. **Acceso**: solo local / **Tailscale** (recomendado: red privada + HTTPS automático con `tailscale serve`) / **Caddy** HTTPS interno en LAN / LAN directa (desaconsejado).
5. **Datos**: directorio de datos, directorio de backups (regla 3-2-1), canal de actualizaciones Ed25519 (manifiesto, clave pública, `entitlement.json`).
6. **Dependencias de terceros**: `ca-certificates`, `curl`, `adduser` y, según el modo elegido, **Tailscale** (script oficial) y **Caddy**.
7. **Salida**: servicio activo + **enlace de primera puesta en marcha** + checklist (cuenta, SMTP, clave de recuperación de backups, IA).

SMTP, proveedores de IA y la cuenta de usuario se configuran **después**, en la interfaz web (se guardan cifrados en la base de datos de la aplicación).

## Ficheros

| Fichero | Propósito |
|---|---|
| `install.sh` | Instalador interactivo/desatendido |
| `answers.example.conf` | Plantilla KEY=VAL para `--unattended` |

## Registros y configuración resultante

- Log por ejecución: `/var/log/correduria-instalador/instalacion-<fecha>.log`
- Configuración generada: `/etc/correduria/application.env` (0600) + *override* systemd (`/etc/systemd/system/correduria-local.service.d/90-instalador.conf`) si se cambió puerto/bind/destino de backups.
