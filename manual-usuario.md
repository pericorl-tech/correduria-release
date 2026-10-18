# Manual de Usuario · Plataforma Correduría

Este manual describe el funcionamiento, la navegación y el uso diario de la plataforma web local de gestión de correduría (versión 0.8.3).

La aplicación está diseñada para operar de forma local y monousuario, protegiendo los datos confidenciales de los asegurados mediante accesos temporales reforzados y garantizando la trazabilidad documental del negocio.

Para consultar los parámetros técnicos, requisitos de red, proveedores o políticas del sistema, consulte el [Manual de Configuración para el Usuario](manual-configuracion.md).

---

## Índice

1. [Acceso y Seguridad de la Sesión](#1-acceso-y-seguridad-de-la-sesión)
2. [Estructura General de la Interfaz](#2-estructura-general-de-la-interfaz)
3. [Resumen (Panel de Control de Vencimientos)](#3-resumen-panel-de-control-de-vencimientos)
4. [Calendario de Vencimientos](#4-calendario-de-vencimientos)
5. [Avisos y Notificaciones](#5-avisos-y-notificaciones)
6. [Gestión de Clientes](#6-gestión-de-clientes)
7. [Gestión de Pólizas y Periodos](#7-gestión-de-pólizas-y-periodos)
8. [Gestor Documental (PDFs y Autorizaciones)](#8-gestor-documental-pdfs-y-autorizaciones)
9. [Privacidad y Derechos RGPD (Operativa y Exportación)](#9-privacidad-y-derechos-rgpd-operativa-y-exportación)
10. [Asistente de Consulta (IA y Consultas Directas)](#10-asistente-de-consulta-ia-y-consultas-directas)
11. [Copias de Seguridad (Uso del Operador)](#11-copias-de-seguridad-uso-del-operador)
12. [Mantenimiento y Diagnóstico Operativo](#12-mantenimiento-y-diagnóstico-operativo)
13. [Tabla Resumen de Módulos y Referencias de Configuración](#13-tabla-resumen-de-módulos-y-referencias-de-configuración)

---

## 1. Acceso y Seguridad de la Sesión

### 1.1 Primera puesta en marcha (Setup)
* **Para qué sirve**: Inicializar la instalación única creando la cuenta de administración del negocio.
* **Disponibilidad**: Solo disponible la primera vez que se accede a la plataforma antes de crear la cuenta.
* **Cómo se usa**:
  1. El instalador/técnico obtiene el enlace con el código temporal (`setup-token`) mediante el comando de terminal `correduria setup-link`.
  2. Introduzca el **Código de instalación**, el **Nombre del negocio**, el **Correo de la cuenta** y defina una **Contraseña** segura (mínimo 12 caracteres, máximo 128).
  3. Tras pulsar *Crear mi cuenta*, el código de instalación queda invalidado permanentemente.
* **Configuración asociada**: [Manual de Configuración · Sección 1 (Cuenta Local)](manual-configuracion.md#1-cuenta-local-y-seguridad-de-acceso).

### 1.2 Inicio de sesión (Login)
* **Para qué sirve**: Autenticar al usuario titular de la correduría.
* **Disponibilidad**: Disponible siempre que la cuenta esté creada.
* **Cómo se usa**: Introduzca su correo electrónico y su contraseña. La sesión tiene una duración máxima por defecto de 8 horas de inactividad.

### 1.3 Recuperación de contraseña (Forgot / Reset)
* **Para qué sirve**: Restablecer el acceso si ha olvidado su contraseña.
* **Disponibilidad**: Solo funciona si el servicio de correo saliente (SMTP) ha sido configurado y probado con anterioridad.
* **Cómo se usa**:
  1. Pulse en *He olvidado mi contraseña* en la pantalla de acceso.
  2. Introduzca su correo registrado.
  3. Si el correo SMTP está operativo, recibirá un enlace temporal válido durante 20 minutos y de un solo uso.
  4. Al abrir el enlace (desde un navegador con acceso a la red de la instalación), defina la nueva contraseña. Las sesiones activas previas quedarán automáticamente cerradas.
* **Configuración asociada**: [Manual de Configuración · Sección 2 (Correo Saliente SMTP)](manual-configuracion.md#2-correo-saliente-smtp).

### 1.4 Acceso protegido temporal a datos reservados («Proof») e Indicador de Bóveda en Vivo
* **Para qué sirve**: Protección de datos sensibles (NIF, nombre, teléfono, domicilio, números contractuales y documentos originales). Las pantallas habituales muestran únicamente códigos de cliente (seudonimizados) y ramos.
* **Cómo se usa**: Cuando pulse en *Ver datos*, *Desbloquear identidad ahora* (en la Vista 360°), *Documentos*, *Histórico contractual*, *Privacidad* o tareas documentales del Asistente, la aplicación solicitará su contraseña actual. Al verificarla, se concede un **acceso temporal de 5 minutos** exclusivo para esa ficha.
* **Indicador de Bóveda en la barra superior (`🔒 / 🔓`)**:
  * Mientras ninguna ficha esté desbloqueada, la barra superior muestra el estado `🔒 Datos protegidos`.
  * Cuando desbloquea una ficha, el indicador pasa a estado activo en ámbar (`🔓 CLI-000001 (295s)`), mostrando una cuenta atrás en vivo y un botón **Bloquear** para cerrar manualmente el acceso temporal en cualquier instante sin esperar a que agote los 5 minutos.

---

## 2. Estructura General de la Interfaz y Diseño Adaptable (Escritorio, Tablet y Móvil)

La plataforma cuenta con una arquitectura **App Shell responsiva** diseñada para ofrecer una experiencia ergonómica tanto en monitores de oficina como en tablets y teléfonos móviles:

### 2.1 Menú lateral categorizado (`Sidebar`)
Organiza los módulos del negocio en tres áreas operativas claras, mostrando en su cabecera el logotipo, el nombre de la correduría y la versión activa (p. ej., `v0.8.2`), y en el pie el usuario activo junto al botón *Cerrar sesión*:
1. **Control y Vencimientos**:
   * **Resumen (`📊`)**: Panel ejecutivo con tarjetas KPI de vencimientos inmediatos y avisos.
   * **Calendario (`📅`)**: Vista mensual y diaria interactiva en doble columna (calendario + detalle lateral).
   * **Avisos (`🔔`)**: Bandeja de alertas internas y envíos por correo electrónico al corredor.
2. **Cartera y Documentación**:
   * **Clientes (`👥`)**: Fichero de asegurados con contador en vivo de clientes activos, vista en tarjetas o tabla y panel lateral *Vista 360°*.
   * **Pólizas (`🛡️`)**: Control de contratos, periodos de vigencia y plantillas de comisión con vista en tarjetas o tabla.
   * **Documentos (`📄`)**: Repositorio de ficheros PDF cifrados (autorizaciones, pólizas y anexos).
3. **Inteligencia y Sistema**:
   * **Configuración (`⚙️`)**: Parámetros de numeración, catálogos, condiciones económicas, suscripciones de IA y seguridad de cuenta.
   * **Backups (`💾`)**: Ejecución manual, política y descarga de copias de seguridad cifradas.
   * **Privacidad (`⚖️`)**: Tramitación de derechos RGPD y exportación de fichas en ZIP.
   * **Mantenimiento (`🛠️`)**: Diagnóstico de salud, sondas técnicas y canal de actualizaciones.
   * **Consultar asistente (`🤖`)**: Acceso al asistente de consulta documental e histórica.

### 2.2 Barra superior de herramientas (`Topbar`)
Situada de forma fija en la parte superior del área de trabajo, incorpora:
* **Miga de pan contextual**: Indica el bloque operativo y el título de la vista actual.
* **Buscador rápido global (`Ctrl+K`)**: Permite buscar instantáneamente desde cualquier pantalla por código de cliente, compañía aseguradora o ramo de seguro, abriendo directamente la *Vista 360°* del cliente o filtrando sus pólizas.
* **Indicador de Bóveda de Seguridad (`🔒 / 🔓`)**: Muestra el estado de bloqueo de identidades y permite revocar accesos temporales con un clic (*Bloquear*).
* **Conmutador de vista por dispositivo (`🖥️ / 📱 / 📲`)**: Permite alternar entre la vista automática/escritorio (`🖥️`), la vista optimizada de Tablet (`📱`) y la vista de Teléfono Móvil (`📲`).
* **Selector de tema Claro / Oscuro (`🌙 / ☀️`)**: Conmuta entre el tema claro corporativo y el modo oscuro de alto contraste, recordando su preferencia en el navegador.

### 2.3 Comportamiento en Escritorio, Tablet y Teléfono Móvil
* **Versión Escritorio (`> 1024px`)**: Menú lateral fijo a la izquierda, vista dividida a dos columnas en el Calendario y formularios de alta/configuración en cuadrícula de dos columnas.
* **Versión Tablet (`721px – 1024px` o modo `📱`)**: El menú lateral se convierte en un cajón deslizable (*Slide-over Drawer*) que se abre con el botón `☰` y se cierra tocando el fondo oscurecido (*backdrop*) o al elegir cualquier sección, liberando el 100 % del ancho para tablas y tarjetas.
* **Versión Móvil (`≤ 720px` o modo `📲`)**:
  * **Barra de navegación inferior fija (`Bottom Nav`)**: 5 botones táctiles permanentes para manejo con el pulgar (*Resumen*, *Calendario*, *Clientes*, *Pólizas* y *Más* para abrir el menú completo).
  * **Transformación automática de tablas en tarjetas**: Cuando se activa la vista `📋 Tabla` en un móvil, cada fila se transforma automáticamente en una tarjeta vertical apilada con etiquetas a la izquierda y valores a la derecha, evitando el desplazamiento horizontal.
  * **Diálogos y paneles estilo hoja inferior (*Bottom Sheet*)**: Las ventanas modales y la *Vista 360°* emergen desde el borde inferior de la pantalla para facilitar la lectura e interacción táctil.

---

## 3. Resumen (Panel de Control de Vencimientos)

### 3.1 Utilidad
Ofrece una vista ejecutiva e inmediata del estado de vencimiento del **último periodo registrado** de las pólizas pertenecientes a clientes activos (no archivados).

> [!NOTE]
> Las fechas mostradas corresponden al último periodo registrado en el sistema; no constituyen una garantía legal de cobertura en vigor ante la entidad aseguradora.

### 3.2 Disponibilidad
Disponible de inmediato en todas las instalaciones. Se sincroniza automáticamente al entrar a la pestaña.

### 3.3 Elementos del panel
* **Filtros rápidos (Barra superior)**:
  * *Compañía*: Permite filtrar por una aseguradora concreta o ver todas.
  * *Ramo*: Filtra por tipo de seguro (Auto, Hogar, Vida, etc.).
  * *Cliente*: Filtra por el código de un cliente específico.
* **Tarjetas métricas**:
  * **Mes actual**: Número total de pólizas que vencen en el mes natural en curso.
  * **Vencen hoy**: Pólizas cuya fecha de expiración coincide con la fecha del sistema.
  * **Próximos N días**: Pólizas que vencerán en la ventana configurada de anticipación (por defecto, 30 días).
  * **Vencimientos pasados**: Pólizas cuya fecha ya ha expirado y no se ha registrado renovación posterior.
  * **Avisos sin leer**: Contador global de alertas internas pendientes de revisión en la bandeja general.
* **Lista de próximos vencimientos**: Lista ordenada de hasta 20 pólizas inmediatas con indicación de días restantes. Cada tarjeta incluye un botón *Ver histórico de póliza* para consultar los periodos anteriores.

### 3.4 Configuración requerida
* [Manual de Configuración · Sección 6 (Política de Vencimientos y Avisos)](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones) para modificar los días de anticipación o la zona horaria.

---

## 4. Calendario de Vencimientos

### 4.1 Utilidad
Permite explorar visualmente el calendario mes a mes, comprobar la carga de vencimientos de cada día y listar las pólizas correspondientes con paginación completa.

### 4.2 Disponibilidad
Disponible de inmediato.

### 4.3 Cómo se usa
1. **Navegación temporal**: Utilice los botones *Mes anterior*, *Mes siguiente* o el selector de mes/año (`AAAA-MM`).
2. **Disposición dividida en Escritorio y apilada en Tablet/Móvil**: En monitores de escritorio, la cuadrícula mensual se muestra a la izquierda y el listado detallado de pólizas del día o mes seleccionado a la derecha; en tablets y móviles se apilan verticalmente con celdas táctiles compactas.
3. **Rejilla mensual**: Cada celda muestra el día del mes y una etiqueta con el número de vencimientos previstos para esa jornada. El día de hoy aparece resaltado en el calendario.
4. **Selección de día**: Al pulsar sobre un día concreto, la cuadrícula resalta la celda seleccionada y el listado lateral/inferior se actualiza para mostrar exclusivamente las pólizas de ese día exacto.
5. **Ver todo el mes**: Pulse *Ver todo el mes* para regresar a la lista de todas las pólizas del mes completo.
6. **Filtros combinados**: Puede combinar la navegación del calendario con los desplegables de *Compañía*, *Ramo* y *Cliente*.
7. **Paginación**: Si el resultado supera 50 registros, se habilitan los botones *Página anterior* y *Página siguiente*.

### 4.4 Configuración requerida
* [Manual de Configuración · Sección 6 (Política de Vencimientos y Avisos)](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones) para la zona horaria de cálculo.

---

## 5. Avisos y Notificaciones

### 5.1 Utilidad
Centraliza la gestión de recordatorios de vencimiento para el corredor. El sistema genera **un único aviso por periodo de póliza** para evitar saturación o duplicidades.

Los avisos se gestionan a través de dos canales independientes:
1. **Aviso interno (In-app)**: Alerta visible en la plataforma web.
2. **Correo electrónico al corredor**: Envío automático de un resumen diario al email registrado del titular (no a los asegurados).

### 5.2 Disponibilidad
* La bandeja interna está **disponible** de inmediato.
* El canal de correo electrónico está **desactivado por defecto** y requiere que el servidor SMTP esté configurado y que el usuario active expresamente la casilla correspondiente.

### 5.3 Cómo se usa
* **Actualizar avisos**: El botón *Actualizar avisos* sincroniza inmediatamente la bandeja comprobando si existen nuevos periodos dentro de la ventana de anticipación.
* **Marcar como leído**: En cada aviso pendiente, pulse *Marcar leído* para retirarlo del contador de pendientes.
* **Ver intentos de envío**: Pulse *Intentos de envío* para abrir un historial con la fecha, número de intento, resultado y mensaje devuelto por el servidor de correo.
* **Reintentar tras revisión**: Si un envío queda en estado *Fallido* o *Incierto*, aparece este botón. Requiere su contraseña.
  > [!WARNING]
  > En caso de estado *Incierto* (el servidor SMTP cortó la conexión sin confirmar si admitió el mensaje), revise su buzón antes de forzar un reintento para evitar duplicar correos al titular.
* **Procesar correo ahora**: Permite disparar de forma manual e inmediata la cola de envíos pendientes sin esperar a la hora programada (solicita su contraseña).
* **Incluir histórico/sustituidos**: Casilla para visualizar alertas de periodos ya cancelados, renovados o archivados.

### 5.4 Estados de los avisos
* `Correo desactivado`: El canal de correo no está activo en la política.
* `Pendiente`: Listo para ser procesado a la hora indicada.
* `Esperando SMTP`: El canal está activo pero faltan datos del servidor SMTP.
* `En proceso`: Mensaje reservado por el gestor de envío para evitar duplicidades concurrentes.
* `Aceptado por SMTP`: El servidor de correo aceptó el mensaje (no acredita lectura).
* `Fallido`: Error conocido de envío. Dispone de hasta 5 intentos automáticos espaciados. Agotados los reintentos, requiere intervención manual.
* `Incierto`: Se desconoce si el servidor lo procesó; no se reintenta automáticamente por seguridad.
* `Cancelado`: La póliza se renovó o el cliente se archivó antes del envío.

### 5.5 Configuración requerida
* [Manual de Configuración · Sección 2 (Correo Saliente SMTP)](manual-configuracion.md#2-correo-saliente-smtp).
* [Manual de Configuración · Sección 6 (Política de Vencimientos y Avisos)](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones).

---

## 6. Gestión de Clientes

### 6.1 Utilidad
Permite administrar las fichas de los asegurados del negocio, clasificadas en **Particular**, **Autónomo** y **Empresa**. Cumple con el principio de seudonimización: en los listados generales solo se exponen códigos inmutables y el tipo de cliente.

### 6.2 Disponibilidad
Disponible de inmediato.

### 6.3 Cómo se usa
1. **Conmutador de vista (`🗂️ Tarjetas` / `📋 Tabla`)**:
   * En la barra de herramientas superior puede alternar entre la vista en cuadrícula de **Tarjetas** y la vista compacta en **Tabla**. En dispositivos móviles, la tabla se convierte automáticamente en tarjetas apiladas verticales.
2. **Panel Lateral «Vista 360°» de Cliente**:
   * Pulse **Vista 360°** en cualquier cliente (o selecciónelo desde el buscador global `Ctrl+K`) para abrir un panel lateral consolidado sin abandonar la pantalla actual.
   * Muestra en un único lugar el estado de la ficha, los datos identificativos protegidos (con botón *Desbloquear identidad ahora* si están bloqueados), todos los periodos de póliza registrados y los originales PDF con descarga directa.
3. **Crear nuevo cliente**:
   * Pulse *Nuevo cliente*.
   * Seleccione el tipo (*Particular*, *Autónomo* o *Empresa*).
   * **Código de cliente**: Si el sistema está en modo automático, puede dejarlo vacío para generar la secuencia configurada (p. ej., `CLI-000001`), o introducir un código manual si está permitido.
   * Rellene los datos de contacto: Nombre/Razón social, NIF/CIF, Dirección, Teléfono, Correo, Representante.
   * Para particulares y autónomos se habilitan campos específicos: *Fecha de nacimiento* y *Fecha del carnet de conducir*. En empresas se ocultan automáticamente.
   * **Datos adicionales**: Campo de texto libre para introducir un objeto JSON válido (p. ej., `{"actividad_cnae": "6201", "preferencia_contacto": "tardes"}`).
   * Pulse *Crear ficha*. El código de cliente asignado **nunca podrá modificarse**.
4. **Consultar y editar datos protegidos**:
   * En la ficha correspondiente, pulse *Ver datos*.
   * Introduzca su contraseña actual. Tendrá acceso de visualización y edición durante 5 minutos (visible en el indicador `🔓` de la barra superior).
   * Guarde los cambios mediante el botón *Guardar datos protegidos*.
5. **Archivar / Reactivar**:
   * Si un cliente causa baja o finaliza su relación comercial, pulse *Archivar*.
   * La ficha dejará de aparecer en los listados habituales y no generará nuevos avisos de vencimiento.
   * Al marcar la casilla *Mostrar archivados* de la barra superior, podrá localizarlo y pulsar *Reactivar*.
   > [!NOTE]
   > Archivar es una acción organizativa reversible; no equivale a la supresión o bloqueo legal de datos del RGPD. Para ello, consulte la pestaña [Privacidad](#9-privacidad-y-derechos-rgpd-operativa-y-exportación).

### 6.4 Configuración requerida
* [Manual de Configuración · Sección 3 (Códigos de Cliente)](manual-configuracion.md#3-formato-y-generación-de-códigos-de-cliente).

---

## 7. Gestión de Pólizas y Periodos

### 7.1 Utilidad
Registro y control de las pólizas de seguros intermediadas. Cada póliza cuenta con un identificador interno inmutable vinculado a un cliente, y se estructura en **periodos anuales o temporales** sucesivos.

### 7.2 Disponibilidad
Disponible de inmediato.

### 7.3 Cómo se usa
1. **Conmutador de vista (`🗂️ Tarjetas` / `📋 Tabla`)**:
   * Al igual que en Clientes, la barra superior permite alternar entre vista en **Tarjetas** o **Tabla** (adaptable automáticamente en móvil).
2. **Alta de nueva póliza**:
   * En la pestaña *Pólizas*, pulse *Nueva póliza*.
   * Seleccione el **Cliente** (por su código).
   * Seleccione la **Compañía** aseguradora y el **Tipo de seguro (Ramo)**.
   * Indique la fecha de **Inicio del periodo** y **Vencimiento del periodo** (`AAAA-MM-DD`).
   * **Condiciones guardadas**: Desplegable opcional para vincular una plantilla económica de remuneración existente en ese momento.
   * **Número contractual (protegido)**: Número de póliza oficial de la compañía. Se almacena cifrado en la base de datos.
   * **Datos adicionales protegidos**: Objeto JSON opcional para coberturas, matrícula, capital asegurado, etc.
   * Pulse *Guardar póliza*.
3. **Renovar periodo**:
   * Cuando venza un periodo o se negocie la prórroga, localice la póliza y pulse *Renovar*.
   * El sistema precarga la compañía, el ramo y los datos contractuales.
   * Ajuste las nuevas fechas de vigencia y, si procede, seleccione una nueva versión de plantilla económica.
   * Pulse *Crear nuevo periodo*. El histórico anterior se conserva intacto.
4. **Consultar histórico contractual**:
   * Pulse *Histórico* en cualquier póliza para ver todos sus periodos registrados.
   * Para ver el número de contrato o los datos JSON protegidos de un periodo antiguo, pulse *Ver datos contractuales* e introduzca su contraseña.

### 7.4 Configuración requerida
* [Manual de Configuración · Sección 4 (Catálogos Propios: Compañías y Ramos)](manual-configuracion.md#4-catálogos-propios-compañías-y-tipos-de-seguro).
* [Manual de Configuración · Sección 5 (Condiciones de Remuneración)](manual-configuracion.md#5-condiciones-de-remuneración-comisiones).

---

## 8. Gestor Documental (PDFs y Autorizaciones)

### 8.1 Utilidad
Custodia centralizada y cifrada de ficheros originales en formato PDF de hasta 10 MiB por archivo. Protege autorizaciones de corretaje firmadas, condiciones particulares/generales de pólizas y documentación complementaria.

### 8.2 Disponibilidad
Disponible de inmediato.

### 8.3 Cómo se usa
1. **Selección de cliente**: Elija el código del cliente en el desplegable superior.
2. **Subir documento original**:
   * Seleccione la **Categoría**:
     * *Autorización firmada*: Documento propio del cliente (documento de representación o consentimiento). Deshabilita la selección de periodo.
     * *Póliza / condiciones*: Exige seleccionar a qué periodo concreto de póliza pertenece el PDF.
     * *Otro documento*: Anexos, partes o recibos generales.
   * Seleccione el archivo PDF de su equipo.
   * Pulse *Subir original* e introduzca su contraseña si no tiene un acceso activo.
   * El archivo se cifra en el servidor con AES/Fernet y se calcula su huella criptográfica SHA-256.
3. **Descarga de originales**:
   * En el listado de documentos, pulse *Descargar original*.
   * Previa verificación de contraseña, el navegador descargará el PDF descifrado.
4. **Marcar como Revocado / Almacenado**:
   * Si un documento queda obsoleto o es revocado por el cliente, pulse *Marcar revocado*.
   * El archivo no se elimina del servidor (se mantiene la custodia histórica y la inclusión en backups), pero se excluye de las consultas documentales del asistente IA.

### 8.4 Configuración requerida
* No requiere configuración externa. Las copias de seguridad de los documentos se rigen por la política de backups: [Manual de Configuración · Sección 7](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups).

---

## 9. Privacidad y Derechos RGPD (Operativa y Exportación)

### 9.1 Utilidad
Proporciona al mediador herramientas para gestionar las solicitudes de ejercicio de derechos en materia de protección de datos (RGPD / LOPDGDD) y generar paquetes completos de portabilidad/acceso.

> [!IMPORTANT]
> Esta herramienta es un registro operativo para la correduría. El cambio de estado de una solicitud **no ejecuta un borrado o bloqueo físico automático** de la base de datos ni emite dictamen legal. Es el operador quien debe valorar y responder jurídicamente a la solicitud.

### 9.2 Disponibilidad
Disponible de inmediato.

### 9.3 Cómo se usa
1. **Registrar solicitud de derecho**:
   * Seleccione el cliente y pulse *Registrar solicitud* (solicita contraseña).
   * Elija el **Tipo de solicitud**: *Acceso*, *Rectificación*, *Supresión*, *Limitación*, *Oposición* o *Portabilidad*.
   * Rellene los campos protegidos:
     * *Fecha de seguimiento*: Fecha límite o estimada fijada por el operador para responder.
     * *Contacto/solicitante*: Identificación del interesado o representante.
     * *Petición / comprobación de identidad*: Detalle de lo solicitado y método de acreditación.
     * *Actuación / motivo de respuesta*: Notas sobre el trámite realizado.
   * Pulse *Guardar registro*.
2. **Evolución y versiones de la solicitud**:
   * Al pulsar *Ver / actualizar*, puede modificar el estado (*Abierta*, *En tratamiento*, *Actuación registrada*, *Respuesta negativa registrada*) y añadir nuevas notas. Cada cambio genera una nueva versión auditable sin borrar los estados anteriores.
3. **Exportación completa de ficha y originales (Portabilidad)**:
   * Pulse el botón *Exportar ficha y originales*.
   * Requiere verificar su contraseña.
   * El sistema genera y descarga un archivo `client-data-export.zip`.
   * **Contenido del ZIP**:
     * `client.json`: Ficha completa descifrada (datos de perfil, periodos, pólizas y metadatos).
     * Carpeta `documents/`: Todos los PDFs originales vinculados a ese cliente (autorizaciones, pólizas).
     * `manifest.json`: Huellas digitales SHA-256 de todos los archivos incluidos.
   > [!CAUTION]
   > El archivo ZIP descargado contiene información personal y documental en texto claro y legible. No se envía automáticamente por correo. Custódielo en un entorno seguro y revíselo antes de cualquier entrega a terceros.

### 9.4 Configuración requerida
* Las solicitudes y sus eventos forman parte de la base de datos cifrada y se respaldan en los backups: [Manual de Configuración · Sección 7](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups).

---

## 10. Asistente de Consulta (Chatbot IA y Consultas Directas)

### 10.1 Utilidad y experiencia de Chatbot continuo
El sistema incorpora un **Chatbot conversacional real** disponible desde cualquier lugar de la aplicación:
1. **Botón flotante en toda la web**: En la esquina inferior derecha de la pantalla se muestra un botón circular con icono de chat y punto de estado en vivo (verde activo, gris desconectado). Pulsándolo desde cualquier pestaña (Clientes, Pólizas, Calendario, etc.) se despliega el panel de chat sin perder la vista de trabajo actual.
2. **Acceso desde el menú principal**: El botón *Consultar asistente* de la cabecera abre también de forma inmediata el panel del chatbot.
3. **Conversación fluida y natural**: Permite escribir consultas directamente en lenguaje natural (p. ej. *«¿Qué pólizas vencen este mes?»*, *«Dame un resumen de cartera»*, *«Explícame qué seguros tiene el cliente X»*). Dispone de chips de sugerencia rápida para preguntas frecuentes.
4. **Consulta directa local (sin IA)**: Muestra información matemática y agregada de vencimientos de forma instantánea y local sin necesidad de conexión externa.

> [!NOTE]
> El agente opera en **modo estricto de lectura**: no modifica datos de clientes, no emite pólizas ni envía correos. Muestra siempre las citas documentales y los datos contrastados (*facts*) para permitir la supervisión del mediador.

### 10.2 Descarga y selección dinámica de modelos («🔄 Modelos»)
* **Selector en la cabecera del chat**: En la barra superior del chatbot se muestra el modelo activo y un desplegable para conmutar entre los modelos disponibles.
* **Descarga de modelos en tiempo real**: Al pulsar el botón **🔄 Modelos**, el sistema conecta directamente con su cuenta de ChatGPT Plus/Pro o proveedor configurado, descarga la lista oficial de modelos habilitados para su plan (p. ej. `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-6-luna`, etc.) y actualiza el desplegable automáticamente.
* **Conmutación rápida sin contraseña**: Puede cambiar de un modelo a otro directamente desde el desplegable del chat sin necesidad de reintroducir contraseñas de seguridad.

### 10.3 Conexión rápida («Añadir suscripción / ⚙️»)
* Puede vincular o gestionar su suscripción pulsando el icono **⚙️** de la barra del chat o desde **Configuración** → **Modelos de IA y Suscripciones** → **Añadir suscripción**.
* La ventana emergente permite elegir:
  * **Suscripción ChatGPT Plus / Pro (Auth automático)**: Vincula su cuenta Plus o Pro desde el navegador mediante código web único o redirección local (método OpenCode OAuth), sin claves API y sin usar la consola.
  * **Clave API (API Key)**: Permite introducir una clave `sk-...` de OpenAI Platform, un proveedor compatible o un servidor local (Ollama/vLLM).

### 10.4 Consulta de historial cómoda y sin contraseñas repetitivas
* Al pulsar el icono **📜 Historial** en el chatbot, se despliega la lista de conversaciones anteriores con fecha, hora y temática.
* **Sin fricción de contraseña**: Al hacer clic sobre cualquier conversación guardada, se cargan y muestran todos sus mensajes directamente en el chat, sin exigir la contraseña de la aplicación en cada visualización.
* Se reserva la confirmación de contraseña exclusivamente para la eliminación definitiva de conversaciones del historial (*icono de papelera*) o la apertura de fichas documentales con datos personales reservados del cliente.

### 10.5 Comprobación de hechos y fuentes
Cuando el agente genera una respuesta utilizando datos del negocio o pólizas, la interfaz muestra:
* El texto en lenguaje natural de la respuesta.
* **Resultados verificados de herramientas (Facts)**: Desplegable con los datos reales estructurados que el agente consultó (vencimientos, dashboard, etc.) para que el usuario pueda contrastar la veracidad de la información.

### 10.6 Configuración requerida
* [Manual de Configuración · Sección 8 (Proveedor de Inteligencia Artificial y Memoria)](manual-configuracion.md#8-proveedor-de-inteligencia-artificial-y-memoria-del-asistente).
* [Manual de Configuración · Sección 11.3 (Suscripción de ChatGPT Plus / Pro de forma automática)](manual-configuracion.md#113-suscripción-de-chatgpt-plus--pro-vinculación-automática-desde-la-web).

---

## 11. Copias de Seguridad (Uso del Operador)

### 11.1 Utilidad
Permite al usuario titular forzar una copia de seguridad inmediata, descargar copias existentes o guardar la clave de recuperación criptográfica.

### 11.2 Disponibilidad
Disponible de inmediato.

### 11.3 Cómo se usa
* **Crear copia ahora**:
  * Pulse el botón *Crear copia ahora*.
  * Introduzca su contraseña actual.
  * La plataforma generará una copia completa en formato cifrado `.crbk` que incluye la base de datos íntegra, todas las claves de datos y la totalidad de los PDFs almacenados.
* **Guardar clave de recuperación**:
  * Pulse *Guardar clave de recuperación*.
  * Introduzca su contraseña actual.
  * Se descargará el archivo `correduria-backup-recovery.key`.
  > [!CAUTION]
  > Este archivo es indispensable para descifrar las copias de seguridad en caso de desastre. Debe custodiarlo fuera del equipo de instalación (el servidor donde corre la aplicación, identificado por el *hostname* que se definió al instalar; p. ej., en un gestor de contraseñas o unidad externa cifrada). Si pierde este archivo y el equipo original se avería, las copias de seguridad no podrán recuperarse.
* **Descargar copia**:
  * En la lista de archivos de copia, pulse *Descargar* e introduzca su contraseña para guardar el fichero `.crbk` en su ordenador local.

### 11.4 Configuración requerida
* [Manual de Configuración · Sección 7 (Política y Almacenamiento de Copias de Seguridad)](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups).
* [Manual de Configuración · Sección 11 (Buenas Prácticas de Backup)](manual-configuracion.md#11-buenas-prácticas-de-seguridad-y-almacenamiento-de-backups).

---

## 12. Mantenimiento y Diagnóstico Operativo

### 12.1 Utilidad
Proporciona al titular y al servicio técnico visibilidad en tiempo real sobre el estado del servidor, permisos de almacenamiento, ejecución de pruebas de componentes y gestión de actualizaciones del software.

### 12.2 Disponibilidad
Disponible de inmediato en la pestaña *Mantenimiento*.

### 12.3 Comprobaciones disponibles (Sondas bajo demanda)
Todas las comprobaciones solicitan la contraseña del usuario y registran la fecha y resultado en un historial auditable:
1. **Probar correo saliente (SMTP)**: Envía un mensaje sintético de prueba a la cuenta de correo de la correduría para comprobar conectividad y autenticación.
2. **Probar proveedor IA**: Realiza una petición mínima de verificación (`{"status": "ok"}`) contra el endpoint configurado (API o ChatGPT) sin enviar datos de clientes ni PDFs.
3. **Probar destino de copias**: Verifica permisos de escritura y espacio libre en el directorio configurado para los backups.
4. **Verificar restauración en entorno aislado**: Ejecuta una prueba automática de restauración de la última copia de seguridad completa sobre un directorio temporal aislado, comprobando la integridad de SQLite y los PDFs sin interferir con el servicio activo.

### 12.4 Canal de actualizaciones firmadas
* **Comprobar actualizaciones**: Comprueba si existe una versión superior firmada criptográficamente (Ed25519) en el canal de distribución oficial.
* **Descargar actualización firmada**: Descarga el paquete verificado a la zona de preparación (*staging*).
* La instalación definitiva se ejecuta mediante terminal por el operador del sistema (`correduria update-install`). La aplicación nunca se actualiza ni se reinicia automáticamente sin autorización humana.

### 12.5 Configuración requerida
* [Manual de Configuración · Sección 9 (Canal de Actualizaciones)](manual-configuracion.md#9-canal-de-actualizaciones-firmadas).
* [Manual de Configuración · Sección 10 (Sondas y Diagnóstico)](manual-configuracion.md#10-mantenimiento-y-diagnóstico-del-sistema).

---

## 13. Tabla Resumen de Módulos y Referencias de Configuración

| Apartado de Usuario | Estado / Disponibilidad | ¿Requiere Configuración? | Apartado en el Manual de Configuración |
|---|---|---|---|
| **Acceso / Setup** | Disponible | Sí (cuenta inicial) | [Manual Configuración · Sección 1](manual-configuracion.md#1-cuenta-local-y-seguridad-de-acceso) |
| **Recuperación de Contraseña** | Requiere SMTP | Sí (servidor de correo) | [Manual Configuración · Sección 2](manual-configuracion.md#2-correo-saliente-smtp) |
| **Resumen** | Disponible | Opcional (anticipación / zona) | [Manual Configuración · Sección 6](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones) |
| **Calendario** | Disponible | Opcional (zona horaria) | [Manual Configuración · Sección 6](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones) |
| **Avisos (Bandeja interna)** | Disponible | No | [Manual Configuración · Sección 6](manual-configuracion.md#6-política-de-vencimientos-y-avisos-notificaciones) |
| **Avisos (Correo saliente)** | Desactivado por defecto | Sí (SMTP + política activa) | [Manual Configuración · Secciones 2 y 6](manual-configuracion.md#2-correo-saliente-smtp) |
| **Clientes (Fichas y datos)** | Disponible | Opcional (patrón de código) | [Manual Configuración · Sección 3](manual-configuracion.md#3-formato-y-generación-de-códigos-de-cliente) |
| **Pólizas y Periodos** | Disponible | Recomendado (catálogos y comisiones) | [Manual Configuración · Secciones 4 y 5](manual-configuracion.md#4-catálogos-propios-compañías-y-tipos-de-seguro) |
| **Documentos (PDFs)** | Disponible | No (directorio de datos) | [Manual Configuración · Sección 7](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups) |
| **Privacidad (RGPD y ZIP)** | Disponible | No | [Manual Configuración · Sección 7](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups) |
| **Asistente (Consulta directa)** | Disponible | No | — |
| **Asistente (Modo IA)** | Requiere credenciales | Sí (API o suscripción ChatGPT) | [Manual Configuración · Sección 8](manual-configuracion.md#8-proveedor-de-inteligencia-artificial-y-memoria-del-asistente) |
| **Backups (Crear / Descargar)** | Disponible | Sí (horario, retención y destino) | [Manual Configuración · Secciones 7 y 11](manual-configuracion.md#7-política-y-almacenamiento-de-copias-de-seguridad-backups) |
| **Mantenimiento (Sondas / Updates)** | Disponible | Opcional (URL canal / claves) | [Manual Configuración · Secciones 9 y 10](manual-configuracion.md#9-canal-de-actualizaciones-firmadas) |
