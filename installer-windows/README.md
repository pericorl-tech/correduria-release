# correduria-installer-windows · Instalador guiado (Windows) — FASE PILOTO

Instalador guiado para **Windows 10/11 x64** de la Plataforma Correduría Local (carpeta dentro del repositorio `correduria-release`). Réplica en PowerShell del flujo de `../installer-linux/`: un único asistente que configura **todo** (nombre del equipo, zona horaria, acceso/red, datos, backups, canal de actualizaciones).

Guía paso a paso para usuarios: [Manual de Instalación](../manual-instalacion.md) (sección 6 para Windows).

> ⚠️ **Estado: fase piloto (v0.1).** Requiere el artefacto binario de Windows `correduria-local_<versión>_win32-x64.zip`, que se genera en el repositorio privado `correduria` (build PyInstaller win64). El análisis completo de viabilidad está en [docs/analisis-instalador-windows.md](../docs/analisis-instalador-windows.md) del repositorio principal.

---

## ⚠️ Importante: `update-install` es INTERNO de la aplicación

El mecanismo de actualizaciones firmadas (manifiesto Ed25519 + verificación + `update-install`) **es una función interna del programa `correduria-server`**, no algo que proporcione el sistema operativo:

| Sistema | Quién aplica la actualización |
|---|---|
| Linux (hoy) | El propio binario `correduria-server` (subcomando `update-install`, envuelto por dpkg) |
| Windows (objetivo) | Deberá implementarse el subcomando equivalente en `correduria-server.exe` — **pendiente, repositorio privado** (fase 2) |
| Windows (mientras tanto) | Este repositorio incluye `tools/Update-Correduria.ps1`: aplicador externo de fase piloto (para servicio, verifica SHA-256, sustituye ficheros, arranca servicio) |

Windows **no** aporta ningún `update-install` para apps de terceros (Windows Update solo actualiza Windows; `winget` es un gestor de paquetes genérico sin relación con el canal firmado de la aplicación). El **canal** (manifiesto JSON firmado Ed25519, multi-arquitectura) es reutilizable tal cual entre Linux y Windows; lo que falta es el **aplicador** dentro del `.exe`.

---

## Uso

```powershell
# Como Administrador:
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1

# Desatendido con fichero de respuestas + paquete concreto:
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1 -AnswersFile instalacion.conf -Package C:\descargas\correduria-local_0.9.0_win32-x64.zip

# Solo reconfigurar (no reinstalar ficheros):
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1 -SoloConfig
```

El asistente pregunta (iguales conceptos que en Linux):

1. **Nombre del equipo** (*hostname*: se aplica con `Rename-Computer`; identificará al servidor en Tailscale y certificados).
2. Zona horaria (Windows: p. ej. `Romance Standard Time`).
3. Paquete `win32-x64.zip` (detectado, ruta local o URL).
4. **Modo de acceso**: solo local / **Tailscale** (recomendado; HTTPS automático con `tailscale serve` — también disponible en el cliente Windows) / Caddy LAN / LAN directa.
5. Puerto, directorio de datos (`%ProgramData%\Correduria` por defecto) y de backups.
6. Canal de actualizaciones: URL del manifiesto, clave pública y `entitlement.json` (opcionales).

## Qué instala (dependencias de terceros)

| Componente | Rol | Cómo |
|---|---|---|
| **WinSW** | Servicio de Windows (equivalente a systemd) | Descarga `WinSW-x64.exe` + plantilla `service/correduria-service.xml` |
| **Tailscale** | Red privada + HTTPS automático (`tailscale up`, `tailscale serve`) | MSI oficial (o `winget install Tailscale.Tailscale`) |
| **Caddy** (opcional) | Proxy HTTPS interno en la oficina | `winget install` o zip oficial |
| ACLs NTFS | Equivalente a los permisos `0700/0600` POSIX | `icacls` sobre `%ProgramData%\Correduria` |

## Cómo generar el artefacto win64 (requisito previo)

El binario `correduria-local_<versión>_win32-x64.zip` **no puede compilarse desde Linux** (PyInstaller no hace compilación cruzada): se genera en un runner Windows mediante GitHub Actions.

1. El workflow está en [`ci/build-windows.yml`](ci/build-windows.yml) (copia de referencia). Colóquelo en el repo privado `correduria` como `.github/workflows/build-windows.yml` (interfaz web de GitHub → Actions → *New workflow* → pegar y confirmar; el token almacenado en puestos sin scope `workflow` no puede subirlo por git).
2. En el repo privado, ejecute **Actions → Build Windows x64 (win64) → Run workflow** sobre la rama `feature/win64-build` (contiene `build_binary.py` ya adaptado a Windows).
3. Descargue el artefacto `correduria-local_<versión>_win32-x64` de la ejecución y úselo con este instalador:

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup-Correduria.ps1 -Package C:\descargas\correduria-local_0.8.3_win32-x64.zip
```

> La rama `feature/win64-build` del repo privado solo cambia `scripts/build_binary.py` (separador `--add-data` por plataforma y eliminación del bloqueo a Linux); el resto de la aplicación **ya era compatible con Windows** (el límite `resource` del lector PDF y `geteuid` están protegidos con guards; los `chmod` no rompen nada en NTFS).

## Fases de este repositorio

1. **Fase 1 (piloto)** ✅ inicial: `Setup-Correduria.ps1` + WinSW + Tailscale; actualizaciones con `tools/Update-Correduria.ps1` (hash + swap manual).
2. **Fase 2**: cuando `correduria-server.exe` incluya `update-install` (repo privado), `Update-Correduria.ps1` delegará en él la verificación Ed25519 completa.
3. **Fase 3**: empaquetador **Inno Setup** (`correduria-instalador-<versión>.exe`) con firma Authenticode, que envuelva este script.

## Ficheros

| Fichero | Rol |
|---|---|
| `Setup-Correduria.ps1` | Instalador guiado (interactive/desatendido) |
| `service/correduria-service.xml` | Plantilla de servicio WinSW |
| `tools/Update-Correduria.ps1` | Aplicador de actualizaciones (fase piloto) |
| `ci/build-windows.yml` | Workflow que genera el artefacto win64 (copiar al repo privado `correduria` → `.github/workflows/`) |
| `answers.example.conf` | Plantilla de respuestas para modo desatendido |
