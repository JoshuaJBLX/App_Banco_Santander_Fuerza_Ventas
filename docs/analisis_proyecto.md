# Analisis del proyecto: App Fuerza de Ventas Banco Santander Consumer Perú

Fecha de analisis: 2026-06-14

## 1. Resumen ejecutivo

Este repositorio contiene una solucion movil para oficiales de credito en campo del Banco Santander Consumer Perú. La aplicacion principal esta desarrollada en Flutter y sigue una organizacion por modulos funcionales dentro de `lib/features`. El proyecto tambien incluye un backend REST en FastAPI dentro de `backend_mobile` y scripts SQL para crear y poblar una base PostgreSQL operacional llamada `bd_core_mobile`.

La app esta orientada a fuerza de ventas y cobranza: autenticacion de asesores, cartera diaria, ficha de cliente, rutas, alertas, campanas, preevaluacion, solicitudes de credito, consulta de buro, documentos, seguimiento de solicitudes, cobranza, reportes y transmision/sincronizacion.

El enfoque tecnico principal es:

- Flutter multiplataforma.
- Estado con Riverpod usando ViewModels basados en `StateNotifier`.
- Navegacion declarativa con GoRouter.
- Backend remoto por API REST FastAPI.
- Persistencia local SQLite para funcionamiento offline-first.
- Almacenamiento seguro para token JWT y datos de sesion.
- Sincronizacion nocturna con Workmanager.
- Notificaciones locales para cartera y compromisos de pago.

## 2. Estructura general del repositorio

```text
.
|-- lib/                                      App Flutter
|   |-- app/                                  Configuracion global y rutas
|   |-- core/                                 Infraestructura compartida
|   |-- features/                             Modulos funcionales
|   |-- shared/                               Widgets y utilidades reutilizables
|-- backend_mobile/                           Backend FastAPI
|   |-- routers/                              Endpoints REST por dominio
|   |-- auth.py                               JWT, hash y validacion
|   |-- config.py                             Variables de conexion/config
|   |-- database.py                           Pool PostgreSQL
|   |-- main.py                               App FastAPI
|-- database/                                 Script SQL consolidado
|-- mobile_bd_core_financiero_andino_postgresql/ Scripts SQL secuenciales
|-- android/, ios/, web/, windows/, macos/, linux/ Plataformas Flutter
|-- pubspec.yaml                              Dependencias Flutter
```

Archivos fuente identificados:

- `lib`: 67 archivos.
- `backend_mobile`: 28 archivos, incluyendo `__pycache__`.
- Modulos Flutter en `lib/features`: 15 modulos.

## 3. Stack tecnologico

### Flutter

El proyecto usa Flutter con SDK `^3.9.2`.

Dependencias principales:

- `flutter_riverpod`: gestion de estado e inyeccion de dependencias.
- `go_router`: navegacion declarativa y rutas protegidas.
- `http`: consumo de API REST.
- `sqflite` y `path`: base de datos local SQLite.
- `flutter_secure_storage`: persistencia segura de token, asesor y preferencias.
- `connectivity_plus`: deteccion de conectividad.
- `intl`: formatos de fecha, moneda y numeros.
- `url_launcher`: acciones externas como llamadas o mapas.
- `fl_chart`: graficos de reportes.
- `image_picker` e `image`: captura/procesamiento de documentos.
- `pdf` y `printing`: generacion/impresion o comparticion de PDF.
- `geolocator` y `geocoding`: ubicacion y geocodificacion.
- `flutter_local_notifications`, `timezone`: notificaciones locales.
- `google_maps_flutter`: mapa de ruta.
- `workmanager`: tareas en segundo plano para sincronizacion nocturna.

### Backend

El backend usa:

- `FastAPI`.
- `uvicorn`.
- `psycopg2-binary` con pool de conexiones.
- `bcrypt` para contrasenas.
- `python-jose` para JWT.
- `pydantic` y `pydantic-settings`.

### Base de datos

La base remota es PostgreSQL (`bd_core_mobile`) y la app usa SQLite local (`santander_consumer_peru_fventas.db`) para cache y colas offline.

## 4. Arranque de la app Flutter

El punto de entrada es `lib/main.dart`.

Flujo de inicializacion:

1. Inicializa Flutter con `WidgetsFlutterBinding.ensureInitialized()`.
2. Intenta inicializar `NotificacionService`.
3. Intenta inicializar `SyncNocturna`.
4. Crea un `ProviderContainer`.
5. Restaura sesion persistente con `loginViewModelProvider.notifier.restaurarSesion()`.
6. Ejecuta la app con `UncontrolledProviderScope`.

Este diseno permite que la sesion se restaure antes de pintar la UI y que GoRouter pueda decidir si debe enviar al usuario a login o a cartera.

## 5. Configuracion global y navegacion

### Tema visual

`lib/app/app.dart` define `MaterialApp.router`, tema Material 3 y colores de marca desde:

- `lib/core/constants/app_colors.dart`
- `lib/core/constants/app_strings.dart`

### Rutas

`lib/app/router.dart` centraliza la navegacion con GoRouter. La ruta inicial es `/splash`.

Rutas principales:

- `/splash`: pantalla inicial.
- `/login`: autenticacion.
- `/cartera`: cartera diaria.
- `/ruta`: mapa/ruta.
- `/alertas`: alertas.
- `/campanas`: campanas comerciales.
- `/ficha/:clienteId`: ficha del cliente.
- `/solicitud`: captura de solicitud.
- `/borradores`: borradores locales.
- `/simulador`: simulador de credito.
- `/historial`: historial de solicitudes.
- `/transmision`: transmision de datos.
- `/documentos`: documentos.
- `/buro`: consulta de buro.
- `/preevaluacion`: preevaluacion.
- `/desertor`: registro de desertores.
- `/estado`: estado de solicitudes.
- `/cobranza`: cobranza.
- `/reportes`: reportes.

El `redirect` protege rutas segun el estado de `loginViewModelProvider`:

- Usuario no autenticado fuera de `/login` y `/splash`: redirige a `/login`.
- Usuario autenticado en `/login`: redirige a `/cartera`.
- `/splash` no se intercepta porque decide su propia navegacion.

## 6. Arquitectura Flutter

La app sigue una arquitectura por feature con capas:

- `domain`: modelos de dominio.
- `data`: repositorios y datasources.
- `presentation`: pantallas y ViewModels.

Patron dominante:

- La UI es `ConsumerWidget` o `ConsumerStatefulWidget`.
- El estado se concentra en ViewModels con `StateNotifier`.
- Los repositorios encapsulan API REST, SQLite o logica offline.
- Riverpod expone providers para repositorios, datasources y ViewModels.

Ejemplo representativo:

```text
cartera/
|-- domain/cartera_model.dart
|-- data/cartera_remote_datasource.dart
|-- data/cartera_local_datasource.dart
|-- data/cartera_repository.dart
|-- presentation/cartera_viewmodel.dart
|-- presentation/cartera_screen.dart
```

## 7. Core de infraestructura

### API REST

`lib/core/network/api_client.dart`

Responsabilidades:

- Define `baseUrl = http://localhost:8003`.
- Mantiene el JWT en memoria.
- Agrega `Authorization: Bearer <token>` cuando existe token.
- Expone `get` y `post`.
- Procesa errores HTTP con `ApiException`.

Nota importante: para emulador Android o telefono fisico, el comentario indica alternativas como `10.0.2.2:8003`, IP LAN o `adb reverse tcp:8003 tcp:8003`.

### Red

`lib/core/network/network_monitor.dart`

Responsabilidades:

- Consultar conectividad actual.
- Exponer stream de estado online/offline con Riverpod.

### SQLite local

`lib/core/storage/local_db.dart`

Base local: `santander_consumer_peru_fventas.db`

Version actual: `2`.

Tablas locales:

- `cartera_cache`: cache de la cartera diaria.
- `visitas_pendientes`: cola offline de visitas pendientes de sincronizar.
- `solicitudes_borrador`: borradores de solicitud.
- `clientes_desertores`: registro local offline-first de desertores.

Tambien incluye:

- Conteo de pendientes de sync.
- Limpieza de cache sensible al cerrar sesion.
- Seed demo para cartera si la cache esta vacia.

### Sincronizacion nocturna

`lib/core/sync/sync_nocturna.dart`

Responsabilidades:

- Inicializar Workmanager.
- Registrar tarea periodica diaria alrededor de las 22:00.
- Descargar cartera del dia siguiente.
- Guardar cache local.
- Guardar marca de ultima sincronizacion.
- Emitir notificacion local al finalizar.

La tarea usa `FlutterSecureStorage` para recuperar token y asesor antes de invocar la API.

### Notificaciones

`lib/core/notificaciones/notificacion_service.dart`

Responsabilidades:

- Inicializar plugin de notificaciones.
- Solicitar permiso en Android 13+.
- Mostrar aviso cuando la cartera nocturna queda lista.
- Programar o mostrar compromisos de pago.

La zona horaria se configura como `America/Lima`.

## 8. Modulos funcionales Flutter

### 8.1 Auth

Ubicacion: `lib/features/auth`

Archivos clave:

- `domain/asesor_model.dart`
- `data/auth_remote_datasource.dart`
- `data/auth_repository.dart`
- `presentation/login_viewmodel.dart`
- `presentation/login_screen.dart`

Responsabilidades:

- Login por `codigoEmpleado` y password.
- Persistencia de token y asesor en `FlutterSecureStorage`.
- Restauracion de sesion al iniciar la app.
- Logout.
- "Recordarme" para codigo de empleado.
- Bloqueo local por intentos fallidos.

Estado:

- `AuthStatus.idle`
- `AuthStatus.loading`
- `AuthStatus.authenticated`
- `AuthStatus.error`

Observacion: el bloqueo local esta configurado con maximo de 5 intentos y duracion de 10 segundos, probablemente pensado para pruebas.

### 8.2 Cartera

Ubicacion: `lib/features/cartera`

Archivos clave:

- `domain/cartera_model.dart`
- `data/cartera_remote_datasource.dart`
- `data/cartera_local_datasource.dart`
- `data/cartera_repository.dart`
- `presentation/cartera_viewmodel.dart`
- `presentation/cartera_screen.dart`

Responsabilidades:

- Obtener cartera diaria del asesor.
- Cachear cartera en SQLite.
- Mostrar banner offline cuando se carga desde cache.
- Filtrar por todos, renovaciones, nuevas, en mora y visitados.
- Buscar por nombre o documento.
- Priorizar no visitados y mayor `scorePrioridad`.
- Reordenamiento manual con persistencia local.
- Registrar visitas.
- Encolar visitas cuando no hay red o falla el backend.
- Sincronizar visitas pendientes al reconectar.

El repositorio es offline-first:

1. Intenta sincronizar pendientes.
2. Si hay red, intenta traer cartera remota.
3. Guarda cache local.
4. Si falla o no hay red, devuelve cache local.

### 8.3 Ficha de cliente

Ubicacion: `lib/features/ficha_cliente`

Responsabilidades:

- Consultar ficha completa con `GET /clientes/{cliente_id}/ficha`.
- Mostrar datos personales, contacto, posicion financiera, comportamiento, historial y oferta.
- Actualizar ubicacion del negocio con `POST /clientes/{cliente_id}/ubicacion`.
- Integrar ubicacion GPS y geocodificacion.

### 8.4 Solicitud

Ubicacion: `lib/features/solicitud`

Responsabilidades:

- Crear solicitudes de credito con `POST /solicitudes`.
- Listar historial con `GET /solicitudes`.
- Gestionar notas internas.
- Guardar borradores locales en SQLite.
- Simulador de credito.
- Pantallas de historial y borradores.

Componentes:

- `SolicitudRepository`: API REST.
- `SolicitudLocalDataSource`: borradores locales.
- `SolicitudViewModel`: estado de creacion.
- Modelos: `SolicitudCreada`, `SolicitudResumen`, `BorradorSolicitud`.

### 8.5 Preevaluacion

Ubicacion: `lib/features/preevaluacion`

Responsabilidades:

- Pre-evaluar prospectos con `POST /pre-evaluar`.
- Registrar clientes desertores localmente.

Resultado esperado:

- `APTO`
- `REVISAR`
- `NO_PROCEDE`

El modulo calcula o recibe puntaje, motivo y calificacion.

### 8.6 Buro

Ubicacion: `lib/features/buro`

Responsabilidades:

- Consultar riesgo crediticio con `POST /buro/consulta`.
- Mostrar calificacion SBS, entidades con deuda, deuda total, mayor deuda, dias de mora, lista negra e interpretacion.

### 8.7 Cobranza

Ubicacion: `lib/features/cobranza`

Responsabilidades:

- Consultar clientes en mora con `GET /cobranza/mora`.
- Registrar acciones de cobranza con `POST /cobranza/accion`.
- Manejar compromisos de pago, pagos parciales, llamadas, visitas y mensajes.
- Programar notificaciones locales para compromisos.

### 8.8 Alertas

Ubicacion: `lib/features/alertas`

Responsabilidades:

- Listar alertas con `GET /alertas`.
- Contar no leidas con `GET /alertas/no-leidas`.
- Marcar alerta leida con `POST /alertas/{id}/leer`.

### 8.9 Campanas

Ubicacion: `lib/features/campanas`

Responsabilidades:

- Mostrar campanas activas/ofertas comerciales.
- El provider actual parece orientado a datos simples o demo desde la UI.

### 8.10 Ruta

Ubicacion: `lib/features/ruta`

Responsabilidades:

- Visualizar ruta de visitas.
- Integracion prevista con Google Maps.
- Uso de ubicacion para campo.

### 8.11 Documentos

Ubicacion: `lib/features/documentos`

Responsabilidades:

- Captura de documentos.
- Checklist documental.
- Posible uso de `image_picker`, `image`, `pdf` y `printing`.

### 8.12 Estado de solicitudes

Ubicacion: `lib/features/estado_solicitudes`

Responsabilidades:

- Visualizar estado/detalle de solicitudes.
- Mostrar notas internas.

### 8.13 Reportes

Ubicacion: `lib/features/reportes`

Responsabilidades:

- Mostrar productividad o indicadores.
- Usa `fl_chart`.

### 8.14 Splash

Ubicacion: `lib/features/splash`

Responsabilidades:

- Pantalla inicial.
- Decide navegacion despues del arranque segun estado de sesion.

### 8.15 Transmision

Ubicacion: `lib/features/transmision`

Responsabilidades:

- Mostrar o simular transmision de datos de solicitud.
- Recibe datos por `state.extra` desde GoRouter.

## 9. Widgets y utilidades compartidas

Ubicacion: `lib/shared`

Widgets reutilizables:

- `BadgeTipoGestion`: etiqueta visual para tipo de gestion.
- `ClienteCard`: tarjeta de cliente.
- `DocumentoChecklist`: estado de documentos.
- `GradientAppBar`: barra superior con gradiente.
- `LogoSantanderConsumerPeru`: logo custom.
- `ModuloPlaceholder`: pantalla placeholder para modulos.
- `SemaforoRiesgo`: indicador visual de riesgo.
- `SignaturePad`: captura de firma con `CustomPainter`.
- `StepperSolicitud`: pasos de una solicitud.

Utilidades:

- `Formatters`: formateo de moneda, fechas y textos.
- `Simulador`: calculos de credito.
- `Validators`: validaciones de formularios.

## 10. Backend FastAPI

Ubicacion: `backend_mobile`

### Configuracion

`config.py` define:

- Host: `localhost`
- Puerto DB: `5432`
- DB: `bd_core_mobile`
- Usuario: `postgres`
- Password: `postgres`
- JWT secret y algoritmo.
- Expiracion JWT: 480 minutos.

### Conexion a base de datos

`database.py` crea un `ThreadedConnectionPool` de PostgreSQL:

- Minimo: 2 conexiones.
- Maximo: 10 conexiones.

### Seguridad

`auth.py` maneja:

- Hash de password con bcrypt.
- Verificacion de password.
- Creacion de JWT.
- Decodificacion de JWT.
- Dependencia `get_asesor_id` para proteger endpoints.

### Endpoints principales

Routers incluidos en `main.py`:

- Auth
- Cartera
- Clientes
- Solicitudes
- Pre-evaluacion
- Buro
- Cobranza
- Alertas

Endpoints detectados:

```text
GET  /
POST /auth/login
GET  /cartera?fecha=YYYY-MM-DD
POST /cartera/{cartera_id}/visita
GET  /clientes/{cliente_id}/ficha
POST /clientes/{cliente_id}/ubicacion
POST /solicitudes
GET  /solicitudes
GET  /solicitudes/{solicitud_id}/notas
POST /solicitudes/{solicitud_id}/notas
POST /pre-evaluar
POST /buro/consulta
GET  /cobranza/mora
POST /cobranza/accion
GET  /alertas
GET  /alertas/no-leidas
POST /alertas/{alerta_id}/leer
GET  /campanas
GET  /reportes/productividad
```

## 11. Base de datos PostgreSQL

El esquema remoto esta documentado en:

- `database/bd_core_mobile.sql`
- `mobile_bd_core_financiero_andino_postgresql/01_DDL_create_tables_core_mobile.sql`

El directorio `mobile_bd_core_financiero_andino_postgresql` incluye scripts secuenciales:

- `00_DDL_drop_tables_core_mobile.sql`
- `01_DDL_create_tables_core_mobile.sql`
- `02_DML_catalogos_core_mobile.sql`
- `03_DML_clientes_core_mobile.sql`
- `04_DML_cartera_core_mobile.sql`
- `99_run_all.sql`

Tablas principales agrupadas:

### Identidad/catalogos

- `agencias`
- `asesores`
- `clientes`

### Replica del core

- `cr_creditos`
- `cr_cronograma_pagos`
- `cr_cuentas_ahorro`
- `cr_movimientos`

### Operacion fuerza de ventas

- `creditos_preaprobados`
- `cartera_diaria`
- `campanas_activas`
- `solicitudes_credito`
- `solicitudes_documentos`
- `consultas_buro`
- `acciones_cobranza`
- `alertas_cartera`
- `solicitudes_notas_internas`

### App clientes

- `usuarios_cliente`
- `tarjetas`
- `operaciones_cliente`
- `notificaciones`

### Sincronizacion

- `sync_outbox`
- `sync_log`

Datos demo documentados:

- 3 agencias.
- 30 asesores.
- 600 clientes.
- 600 creditos.
- 13 500 cuotas.
- 240 alertas de cartera.
- 240 acciones de cobranza.

Credenciales demo indicadas en el README SQL:

- `codigo_empleado`: `0001` a `0030`.
- Password: `1234`.

## 12. Flujos funcionales importantes

### Login y sesion

1. Usuario ingresa codigo de empleado y password.
2. App llama `POST /auth/login`.
3. Backend valida contra `asesores`.
4. Backend devuelve token y datos del asesor.
5. App guarda token y asesor en secure storage.
6. `ApiClient` adjunta token a llamadas futuras.
7. En siguientes arranques, `main.dart` restaura sesion antes de pintar la UI.

### Carga de cartera diaria

1. CarteraScreen solicita carga al ViewModel.
2. ViewModel llama a `CarteraRepository.obtenerCartera`.
3. Repositorio intenta sincronizar visitas pendientes.
4. Si hay red, consulta `GET /cartera`.
5. Guarda resultados en `cartera_cache`.
6. Si no hay red o falla el backend, lee `cartera_cache`.
7. UI muestra lista, filtros, progreso y banner offline si corresponde.

### Registro de visita offline-first

1. Usuario marca una visita.
2. La app actualiza `cartera_cache` como visitado.
3. Si hay red, intenta `POST /cartera/{id}/visita`.
4. Si falla o no hay red, inserta en `visitas_pendientes`.
5. En la siguiente carga con red, `sincronizarPendientes` reintenta enviar.

### Solicitud de credito

1. Usuario completa formulario de solicitud.
2. Puede guardar borrador en SQLite.
3. Al enviar, app llama `POST /solicitudes`.
4. Backend crea registro en `solicitudes_credito`.
5. Se puede consultar historial con `GET /solicitudes`.
6. Las notas internas se gestionan con endpoints `/notas`.

### Sincronizacion nocturna

1. Workmanager programa tarea diaria.
2. Recupera token y asesor desde secure storage.
3. Consulta cartera del dia siguiente.
4. Guarda cache en SQLite.
5. Registra ultima sincronizacion.
6. Muestra notificacion local.

## 13. Ejecucion local

### Backend

Instalar dependencias:

```powershell
cd backend_mobile
python -m pip install -r requirements.txt
```

Ejecutar:

```powershell
uvicorn main:app --reload --port 8003
```

### Base de datos

Crear base:

```powershell
psql -U postgres -h localhost -c "CREATE DATABASE bd_core_mobile;"
```

Cargar scripts:

```powershell
cd mobile_bd_core_financiero_andino_postgresql
psql -U postgres -h localhost -d bd_core_mobile -f 99_run_all.sql
```

### Flutter

Instalar dependencias:

```powershell
flutter pub get
```

Ejecutar:

```powershell
flutter run
```

Para Android fisico con backend local:

```powershell
adb reverse tcp:8003 tcp:8003
```

## 14. Observaciones tecnicas

### Fortalezas

- Estructura modular clara por feature.
- Uso consistente de Riverpod para inyeccion y estado.
- Repositorio de cartera bien orientado a offline-first.
- Separacion entre backend, app y scripts de base de datos.
- Documentacion interna en comentarios de codigo con referencias funcionales RF/HU.
- Persistencia segura para token y sesion.
- Scripts SQL suficientemente completos para levantar datos de prueba.

### Riesgos o puntos a revisar

- `ApiClient.baseUrl` esta fijo en `http://localhost:8003`; convendria externalizar por ambiente.
- Hay textos con caracteres mal codificados en algunos archivos (`â€”`, `dueÃ±o`, etc.), probablemente por encoding.
- El bloqueo de login dura 10 segundos, lo cual parece configuracion de prueba.
- El backend usa credenciales por defecto y JWT secret hardcodeado; debe moverse a variables de entorno para produccion.
- CORS permite todo (`allow_origins=["*"]`), util en desarrollo pero riesgoso en produccion.
- No se observaron pruebas automatizadas especificas de dominio; solo scaffolding base de Flutter.
- Hay archivos generados y cacheados (`build`, `.dart_tool`, `__pycache__`) presentes en el arbol local; no deberian versionarse si estuvieran en git.
- Algunas pantallas parecen usar datos demo o comportamiento parcial; conviene validar cada flujo contra backend real.

## 15. Recomendaciones

1. Crear configuracion por ambiente para `baseUrl`, secrets y credenciales de DB.
2. Agregar pruebas unitarias para ViewModels y repositorios clave: auth, cartera, solicitud y cobranza.
3. Agregar pruebas de integracion para flujos criticos: login, carga de cartera, visita offline, solicitud.
4. Corregir encoding de archivos para que los textos en espanol se vean correctamente.
5. Documentar contratos JSON por endpoint.
6. Revisar permisos Android/iOS para ubicacion, notificaciones, camara y almacenamiento.
7. Separar datos demo de logica productiva mediante flags de ambiente.
8. Implementar estrategia formal de refresh/expiracion de token si el backend lo requiere.
9. Agregar manejo uniforme de errores API en UI.
10. Incluir README principal mas completo con pasos de backend, DB, app y credenciales demo.

## 16. Mapa rapido de responsabilidades

```text
main.dart
  Inicializa servicios, restaura sesion y monta ProviderScope.

app/router.dart
  Define rutas y proteccion por autenticacion.

core/network/api_client.dart
  Cliente REST con token Bearer.

core/storage/local_db.dart
  SQLite local, cache y colas offline.

core/sync/sync_nocturna.dart
  Descarga periodica de cartera.

features/auth
  Login, sesion, secure storage.

features/cartera
  Cartera diaria, filtros, cache, visitas offline.

features/ficha_cliente
  Ficha, comportamiento, historial, ubicacion.

features/solicitud
  Solicitudes, borradores, simulador, notas.

features/preevaluacion
  Evaluacion inicial y desertores.

features/buro
  Consulta de riesgo crediticio.

features/cobranza
  Mora y acciones de cobranza.

features/alertas
  Alertas de cartera y conteo no leidas.

backend_mobile
  API REST FastAPI sobre PostgreSQL.

mobile_bd_core_financiero_andino_postgresql
  DDL/DML para levantar la base operacional.
```

## 17. Conclusion

El proyecto ya tiene una base solida para una app de fuerza de ventas bancaria: modulos funcionales bien separados, backend propio, esquema PostgreSQL amplio y soporte offline en los flujos mas importantes de campo. La mayor oportunidad esta en endurecer configuracion por ambiente, pruebas automatizadas, limpieza de encoding y documentacion de contratos API. Con esos ajustes, el sistema quedaria mucho mas preparado para evolucionar desde prototipo funcional hacia una version mantenible y desplegable.
