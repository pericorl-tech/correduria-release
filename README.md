# Correduría · Distribución oficial

Distribución binaria de la **plataforma web local de gestión de correduría de seguros**: aplicación *self-hosted* y monousuario para corredurías que se instala en un equipo propio (desde Raspberry Pi hasta un PC de escritorio), no en la nube.

Gestión del negocio en un solo lugar: clientes (particulares, autónomos y empresas), pólizas y periodos de vigencia, gestor documental cifrado, calendario de vencimientos y avisos, exportación para derechos RGPD, asistente de consulta con IA opcional, copias de seguridad cifradas y **actualizaciones firmadas criptográficamente (Ed25519)**.

Este repositorio solo tiene paquetes instalables y manuales. El código fuente permanece en el repositorio privado `correduria` (no incluido en el paquete).

## Plataformas

| Plataforma | Estado |
|---|---|
| Ubuntu arm64 (Debian/Raspberry Pi OS con glibc 2.41) | **Disponible** |
| Ubuntu amd64 | Planificado |
| Windows | Planificado (futuro) |

Por ahora **solo hay versión para Ubuntu** (paquete `.deb`). En un futuro habrá versión para Windows.

## Descarga

Use el último [release](https://github.com/pericorl-tech/correduria-release/releases) más reciente.

Cada release incluye:

* `correduria-local_<versión>_arm64.deb` — paquete binario (incluye su *runtime*; no requiere Python ni dependencias del sistema).
* `manifest-<versión>.json` — manifiesto firmado (Ed25519) con la URL del artefacto, su SHA-256 y su tamaño exacto, para el canal de actualizaciones.

## Instalación (Ubuntu arm64)

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

Para publicar la web en LAN con HTTPS existe un ejemplo de proxy inverso (Caddy) incluido en los materiales del proyecto; la app siempre escucha en `127.0.0.1:8080` por defecto.

## Actualizaciones

La aplicación nunca se actualiza sola:

1. En **Mantenimiento → Comprobar actualizaciones** la app compara su versión con un manifiesto firmado, descarga a *staging* y verifica firma, hash y derecho de actualización de la instalación.
2. Un operador ejecuta en terminal:

   ```bash
   /opt/correduria/bin/correduria-server update-install
   ```

El canal de manifiesto se configura vía variables en `/etc/correduria/application.env` (`CORREDURIA_UPDATE_MANIFEST_URL`, `CORREDURIA_UPDATE_PUBLIC_KEY_FILE`, `CORREDURIA_UPDATE_ENTITLEMENT_FILE`) o desde el panel **Configuración / Mantenimiento**. Los manifiestos generados a partir de este repositorio apuntan aquí (`releases/download/`), de modo que instalaciones nuevas no necesiten credenciales para comprobar actualizaciones.

## Manuales

* [Manual de Usuario](manual-usuario.md): uso diario de cada módulo (resumen, calendario, avisos, clientes, pólizas, documentos, privacidad, asistente, backups y mantenimiento).
* [Manual de Configuración](manual-configuracion.md): cuenta, SMTP, códigos de cliente, catálogos, comisiones, política de vencimientos, backups (regla 3-2-1), proveedores de IA (API o suscripción ChatGPT Plus/Pro), canal de actualizaciones y diagnóstico.

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
