import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Inicializacion y migraciones de la base de datos local SQLite.
///
/// Implementa el soporte offline-first descrito en el documento:
///  - `cartera_cache`        : copia local de `cartera_diaria` (lectura offline)
///  - `visitas_pendientes`   : cola de escrituras pendientes de sync (RF-17/18)
///  - `solicitudes_borrador` : borradores de solicitud (RF-49, para M5)
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const int _version = 2;
  Database? _db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite no disponible en web');
    }
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'santander_consumer_peru_fventas.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cartera_cache (
        id TEXT PRIMARY KEY,
        asesor_id TEXT,
        cliente_id TEXT,
        cliente_nombre TEXT,
        documento TEXT,
        tipo_gestion TEXT,
        prioridad TEXT,
        score_prioridad INTEGER,
        monto_credito REAL,
        estado_visita TEXT,
        orden_manual INTEGER,
        fecha_asignacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE visitas_pendientes (
        id TEXT PRIMARY KEY,
        cartera_id TEXT,
        resultado TEXT,
        observacion TEXT,
        timestamp_visita TEXT,
        lat REAL,
        lng REAL,
        pendiente_sync INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE solicitudes_borrador (
        id TEXT PRIMARY KEY,
        cliente_id TEXT,
        cliente_nombre TEXT,
        paso_actual INTEGER,
        datos_json TEXT,
        monto_solicitado REAL,
        asesor_id TEXT,
        updated_at INTEGER
      )
    ''');

    await _crearTablaDesertores(db);
  }

  Future<void> _crearTablaDesertores(Database db) async {
    // Registro de clientes desertores (RF-42), offline-first.
    await db.execute('''
      CREATE TABLE clientes_desertores (
        id TEXT PRIMARY KEY,
        asesor_id TEXT,
        cliente_nombre TEXT,
        documento TEXT,
        motivo TEXT,
        institucion_migro TEXT,
        probabilidad_retorno TEXT,
        observaciones TEXT,
        pendiente_sync INTEGER DEFAULT 1,
        created_at INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await _crearTablaDesertores(db);
    }
  }

  /// Numero de solicitudes pendientes de sincronizar (para el aviso de
  /// cierre de sesion, RF-08).
  Future<int> contarPendientesSync() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM visitas_pendientes WHERE pendiente_sync = 1',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Borra cache sensible al cerrar sesion (RF-07).
  Future<void> limpiarCacheSesion() async {
    final db = await database;
    await db.delete('cartera_cache');
  }

  /// DEV SEED — inserta cartera de muestra si la cache esta vacia, para poder
  /// ver la UI sin Supabase configurado. Quitar al conectar el backend real.
  Future<void> seedDemoSiVacio(String asesorId) async {
    final db = await database;
    final c = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cartera_cache'),
        ) ??
        0;
    if (c > 0) return;

    final hoy = DateTime(2026, 6, 2).toIso8601String();
    final demo = <Map<String, Object?>>[
      {
        'id': 'c1', 'cliente_nombre': 'Maria Quispe Huaman', 'documento': '***456',
        'tipo_gestion': 'RECUPERACION_MORA', 'prioridad': 'alta',
        'score_prioridad': 88, 'monto_credito': 8500.0, 'estado_visita': 'pendiente',
        'orden_manual': 0,
      },
      {
        'id': 'c2', 'cliente_nombre': 'Jose Mamani Flores', 'documento': '***123',
        'tipo_gestion': 'RENOVACION', 'prioridad': 'alta',
        'score_prioridad': 72, 'monto_credito': 12000.0, 'estado_visita': 'pendiente',
        'orden_manual': 1,
      },
      {
        'id': 'c3', 'cliente_nombre': 'Rosa Condori Apaza', 'documento': '***789',
        'tipo_gestion': 'AMPLIACION', 'prioridad': 'media',
        'score_prioridad': 55, 'monto_credito': 5000.0, 'estado_visita': 'pendiente',
        'orden_manual': 2,
      },
      {
        'id': 'c4', 'cliente_nombre': 'Pedro Ccahua Ramos', 'documento': '***234',
        'tipo_gestion': 'NUEVA_SOLICITUD', 'prioridad': 'normal',
        'score_prioridad': 30, 'monto_credito': 3000.0, 'estado_visita': 'pendiente',
        'orden_manual': 3,
      },
      {
        'id': 'c5', 'cliente_nombre': 'Lucia Vargas Soto', 'documento': '***567',
        'tipo_gestion': 'SEGUIMIENTO', 'prioridad': 'normal',
        'score_prioridad': 15, 'monto_credito': 4500.0, 'estado_visita': 'visitado',
        'orden_manual': 4,
      },
    ];

    final batch = db.batch();
    for (final row in demo) {
      batch.insert('cartera_cache', {
        ...row,
        'asesor_id': asesorId,
        'cliente_id': row['id'],
        'fecha_asignacion': hoy,
      });
    }
    await batch.commit(noResult: true);
  }
}
