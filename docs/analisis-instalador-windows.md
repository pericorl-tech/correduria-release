# Análisis técnico · Instalador para Windows · Plataforma Correduría Local

**Fecha:** octubre 2026 · **Basado en:** paquete `correduria-local_0.8.3_arm64.deb` (build PyInstaller onedir, aarch64/glibc 2.41).

Objetivo: determinar **qué sería necesario** para publicar una versión Windows y **qué rompería** del funcionamiento actual del programa.

> [!IMPORTANT]
> **Sobre `update-install`: es una función interna de la aplicación, no de Windows.** El mecanismo de actualizaciones firmadas (manifiesto Ed25519 + verificación + subcomando `update-install`) lo implementa el propio `correduria-server`; Windows no ofrece ningún equivalente para apps de terceros. Para la versión Windows el canal firmado se reutiliza igual, pero el **aplicador** (`update-install`) debe implementarse dentro de `correduria-server.exe` en el repositorio privado (fase 2). En fase piloto se usa un aplicador externo PowerShell incluido en el repo `correduria-installer-windows`.

Los instaladores se distribuyen en dos repositorios hermanos: `correduria-installer-linux` (este proyecto, ya operativo) y `correduria-installer-windows` (piloto, PowerShell + WinSW).

---

## 1. Situación actual (lo que existe hoy)

| Componente | Implementación actual (Linux) |
|---|---|
| Binario | `correduria-server` — binario PyInstaller *onedir* para **Linux arm64** (glibc ≥ 2.41). Sin dependencias de Python del sistema. |
| Servicio | `systemd` (`correduria-local.service`) con *hardening* (`ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, `NoNewPrivileges`, `UMask=0077`). |
| Usuario de servicio | Usuario de sistema POSIX `correduria-local`, datos en `/var/lib/correduria` (`0700`), secretos `0600`. |
| Configuración del sistema | `/etc/correduria/application.env` (conffile del `.deb`). |
| Paquetización | `.deb` con `postinst`/`prerm`/`postrm` (dpkg). |
| Actualizaciones | Canal firmado **Ed25519**: manifiesto JSON firmado + artefacto `.deb` + `correduria-server update-install` (aplica vía dpkg como root). |
| Acceso | Escucha `127.0.0.1:8080`; HTTPS recomendado vía Tailscale Serve o Caddy. |
| Utilidades CLI | `correduria-setup-link` (script `/bin/sh`), `correduria-server restore/restore/restore`, `chatgpt-login/import`. |
| Diagnóstico | Verifica permisos POSIX `0600/0700` de `secret.key`, `application.db` y el directorio de datos. |

**Buenas noticias estructurales:** la lógica de negocio es Python puro empaquetado, con librerías que tienen ruedas/precompilados para Windows (cryptography/Fernet, argon2-cffi, SQLite estándar, pycryptodome/`_rust` con *wheels* Windows). El protocolo HTTP en loopback, el cifrado AES-256-GCM de backups (`.crbk`), Ed25519 y el flujo OAuth de ChatGPT **son portables y no dependen de Linux**. Tailscale y Caddy tienen cliente/servidor nativos para Windows.

---

## 2. Qué sería necesario construir para Windows

### 2.1 Compilación (build)
1. **Rebuild del binario en Windows x64**: PyInstaller `--onedir` sobre Python 3.13 en Windows. Verificar en CI que `argon2_cffi_bindings`, `cryptography` (Rust) y `sqlite3` empaquetan correctamente sus `.pyd`.
2. **Rutas internas**: revisar el código (repo privado) por usos de rutas POSIX duras (`/var/lib/correduria`, `/etc/correduria`, `/usr/bin`). El diseño ya lee `CORREDURIA_DATA_DIR` y `CORREDURIA_PUBLIC_URL` desde entorno — esto **facilita mucho** el puerto: en Windows se alimentarían desde el gestor de servicio.
3. **Firmado Authenticode**: certificado OV/EV de firma de código. Sin firmar, SmartScreen y los antivirus de las oficinas bloquearán o alarmarán sobre el ejecutable (los binarios PyInstaller son un falso positivo clásico).

### 2.2 Empaquetado e instalación
4. **Instalador**: **Inno Setup** (recomendado) o MSIX. Debe:
   - Instalar a `%ProgramFiles%\Correduria\` (binarios) y datos a `%ProgramData%\Correduria\` (equivalente a `/var/lib/correduria`).
   - Crear **cuenta local dedicada** `CorreduriaSvc` (o usar *Virtual Service Account* + ACLs) y aplicar **NTFS ACLs** restrictivas (`icacls`) sobre `%ProgramData%\Correduria` — el equivalente funcional de `0700/0600`.
   - Escribir la configuración del sistema (equivalente a `application.env`) en `%PROGRAMDATA%\Correduria\application.env` o en el Registro.
5. **Servicio de Windows** (no existe systemd): la opción sin tocar código es **WinSW** (XML → `sc create`) o **NSSM**:
   ```xml
   <!-- WinSW: Exec=correduria-server.exe, Arguments=serve --host 127.0.0.1 --port 8080 -->
   ```
   Alternativa a medio plazo: servicio nativo con `pywin32` dentro de la app (cambio en el repositorio privado).
6. **Firewall de Windows**: regla `netsh advfirewall` solo si se habilita acceso LAN; por defecto loopback no requiere reglas.
7. **Utilidades CLI**: `correduria-setup-link` es un `/bin/sh` → debe existir equivalente `correduria-setup-link.exe` o subcomando `correduria-server.exe setup-link` (ejecutado como la cuenta de servicio). Los comandos de recuperación (`restore --backup ... --key ...`) pasan a PowerShell.

### 2.3 Red y TLS (Tailscale / Caddy)
8. **Tailscale Windows**: MSI oficial; soporta `tailscale up --hostname` y **`tailscale serve` también en Windows**. El modo recomendado de la instalación guiada (red privada + TLS automático) **es replicable 1:1**.
9. **Caddy para LAN**: binario `caddy.exe` oficial; puede correr como servicio con WinSW; `tls internal` funciona igual.

### 2.4 Canal de actualizaciones
10. El formato de manifiesto ya es multi-arquitectura (`correduria-local_<versión>_<arch>`); falta:
    - Publicar artefactos `win32-x64` (`.exe`/`.zip` firmados Authenticode, además de la firma Ed25519 del manifiesto).
    - Un **aplicador de actualización para Windows**: el actual `update-install` está pensado sobre dpkg/`.deb`. Haría falta una variante que: detenga el servicio, sustituya el árbol de ficheros (staging → carpeta de instalación) y reinicie. Es un desarrollo contenido **en el repositorio privado** (la app es cerrada desde este repo).

### 2.5 Instalador interactivo Windows
11. El flujo del `install.sh` actual (hostname del equipo, zona horaria, modo de acceso, puerto, datos, canal de actualizaciones) es **portable como guion**: en Windows se implementaría como **PowerShell** (`Setup-Correduria.ps1`) embebido en Inno Setup, con las mismas preguntas. PowerShell 5.1 ya viene en cualquier Windows 10/11.

---

## 3. Qué ROMPERÍA del funcionamiento actual

| Elemento | ¿Se rompe? | Detalle y mitigación |
|---|---|---|
| Servicio systemd + hardening (`ProtectSystem`, `PrivateTmp`, `ProtectHome`) | **Sí** | No hay equivalente 1:1 en Windows. Se mitiga con cuenta de servicio dedicada + ACLs NTFS + firewall, pero el *sandbox* de systemd es más estricto. **Es la pérdida de seguridad más relevante.** |
| Actualizaciones firmadas vía `.deb`/dpkg (`update-install`) | **Sí** | El canal manifiesto+Ed25519 sobrevive, pero el aplicador es Linux-específico. Requiere nuevo aplicador Windows en el repo privado. Hasta tenerlo, las actualizaciones Windows serían manuales (descarga + reinstalador). |
| Usuario `correduria-local` y permisos `0600/0700` | **Sí (parcial)** | NTFS no tiene chmod; la **sonda de Mantenimiento** que comprueba `0600/0700` fallaría o sería engañosa. Adaptar la sonda a verificar ACLs (`Get-Acl`). |
| Scripts `correduria-setup-link`, `sudo -u correduria-local ... restore`, `postrm/prerm` | **Sí** | Son scripts POSIX. Reescribirlos como `.exe`/PowerShell. La sintaxis documentada de `restore` (`--backup --key --destination`) se mantiene como interfaz; cambia el envoltorio. |
| Rutas `/var/lib/correduria`, `/etc/correduria` | **Sí** | Pasan a `%ProgramData%\Correduria` y `%ProgramFiles%\Correduria`. La app ya está preparada (`CORREDURIA_DATA_DIR`), pero **toda la documentación y procedimientos de recuperación** (manual de configuración §12.4) deben duplicarse para Windows. |
| Actualizador de paquetes (`dpkg -i`, `apt`) y el instalador Tailscale `install.sh` | **Sí** | En Windows: MSI de Tailscale e instalador propio; el instalador PowerShell sustituye a `install.sh`. |
| Cifrado (Fernet/AES-GCM, argon2id, SQLite) | **No** | Librerías multiplataforma con *wheels* Windows; el formato `.crbk` es independiente del SO → **un backup hecho en Linux podrá restaurarse en Windows y viceversa** (salvaguarda del 3-2-1 intacta). |
| Modelo monousuario, UI, OAuth ChatGPT, SMTP, avisos | **No** | Lógica de aplicación pura; no depende del SO. |
| Escucha `127.0.0.1` y restricción HTTP-solo-loopback | **No** | Idéntico en Windows. |
| Tailscale / Caddy | **No** | Clientes Windows oficiales; `serve` disponible. |
| Antivirus/SmartScreen | **Fricción operativa** | No rompe el programa pero sí la experiencia: exige firmado Authenticode y, probablemente, excepciones en el antivirus corporativo durante la prueba. |

### Riesgos no funcionales a valorar
- **Falsos positivos de antivirus** sobre PyInstaller en entornos corporativos (mitigación: firma de código + envíos a VirusTotal/whitelisting).
- **Reinicios de Windows** (Windows Update): el servicio debe ser `Automatic` y la app tolerar cortes; en Linux systemd ya lo gestiona igual, riesgo equivalente.
- **Custodia del `.crbk` y la clave de recuperación**: invariante de diseño, no se ve afectado, pero los manuales deben reescribir las rutas.

---

## 4. Esfuerzo estimado

| Fase | Trabajo | Dónde | Esfuerzo |
|---|---|---|---|
| F1. Piloto | Build Windows + Inno Setup + WinSW + ACLs + firewall + Tailscale MSI + instalador PowerShell | CI + este repo | Bajo–medio (no toca la lógica) |
| F2. Adaptaciones de la app | Sondas de permisos/ACLs y CLI (`setup-link`, `restore`) | Repositorio privado `correduria` | Bajo |
| F2. Canal Windows | Aplicador `update-install` para Windows + publicación de artefactos `win32-x64` | Repositorio privado + pipeline de releases | Medio |
| F3. Distribución | Firma de código (certificado OV/EV, proceso Authenticode) | Organización | Medio |

**Conclusión: viable.** Ningún componente crítico de la aplicación (cifrado, base de datos, UI, OAuth, SMTP) depende de Linux. Lo que se rompe es **la capa de sistema** (servicio, permisos, dpkg, scripts de shell, actualizador) y todo tiene camino conocido: WinSW/NSSM + Inno Setup + PowerShell + MSI de Tailscale + un nuevo aplicador de actualización. La única pérdida funcional real es el nivel de *hardening* de systemd, compensable parcialmente con cuenta de servicio dedicada y ACLs.

### Recomendación de fases
1. **Fase 1 (piloto):** build PyInstaller win64 + Inno Setup + WinSW + Tailscale MSI; actualizaciones manuales con el instalador; sin `update-install` automático.
2. **Fase 2:** aplicador de actualizaciones Windows (mismo manifiesto Ed25519, artefactos `.zip` firmados) + adaptaciones de sondas/CLI.
3. **Fase 3:** firma Authenticode y distribución oficial en GitHub Releases (`correduria-local_<versión>_win32-x64.exe`).
