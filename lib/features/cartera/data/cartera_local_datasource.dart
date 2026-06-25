import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_db.dart';
import '../domain/cartera_model.dart';

/// Fuente local (SQLite) de la cartera: lectura de cache offline y
/// persistencia del resultado descargado de Supabase (RF-09).
class CarteraLocalDataSource {
  final LocalDb _db;
  CarteraLocalDataSource([LocalDb? db]) : _db = db ?? LocalDb.instance;

  Future<List<CarteraItem>> leerCache(String asesorId) async {
    final db = await _db.database;
    final rows = await db.query(
      'cartera_cache',
      where: 'asesor_id = ?',
      whereArgs: [asesorId],
      orderBy: 'score_prioridad DESC',
    );
    return rows.map(CarteraItem.fromMap).toList();
  }

  /// Reemplaza la cache del asesor con el resultado remoto.
  /// Estampa el asesor_id (el backend no lo devuelve por item) y usa upsert
  /// para que recargas sucesivas no choquen por PK.
  Future<void> guardarCache(String asesorId, List<CarteraItem> items) async {
    final db = await _db.database;
    final batch = db.batch();
    batch.delete('cartera_cache', where: 'asesor_id = ?', whereArgs: [asesorId]);
    for (final item in items) {
      final map = item.toMap();
      map['asesor_id'] = asesorId; // dueño correcto para lectura offline
      batch.insert('cartera_cache', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Persiste el orden manual de la cartera (RF-16): orden_manual = posicion.
  Future<void> actualizarOrden(List<CarteraItem> items) async {
    final db = await _db.database;
    final batch = db.batch();
    for (var i = 0; i < items.length; i++) {
      batch.update(
        'cartera_cache',
        {'orden_manual': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Actualiza el estado de visita en cache (para reflejarlo offline).
  Future<void> actualizarEstadoVisita(String id, String estado) async {
    final db = await _db.database;
    await db.update(
      'cartera_cache',
      {'estado_visita': estado},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Encola un resultado de visita pendiente de sincronizar (RF-17).
  Future<void> encolarVisita({
    required String carteraId,
    required String resultado,
    required String observacion,
    double? lat,
    double? lng,
  }) async {
    final db = await _db.database;
    await db.insert('visitas_pendientes', {
      'id': '$carteraId-${DateTime.now().millisecondsSinceEpoch}',
      'cartera_id': carteraId,
      'resultado': resultado,
      'observacion': observacion,
      'timestamp_visita': DateTime.now().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'pendiente_sync': 1,
    });
  }

  Future<void> seedDemo(String asesorId) => _db.seedDemoSiVacio(asesorId);

  /// Visitas en cola pendientes de sincronizar (RF-18).
  Future<List<Map<String, Object?>>> visitasPendientes() async {
    final db = await _db.database;
    return db.query('visitas_pendientes',
        where: 'pendiente_sync = 1', orderBy: 'timestamp_visita ASC');
  }

  Future<void> eliminarPendiente(String id) async {
    final db = await _db.database;
    await db.delete('visitas_pendientes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarPendientes() async {
    final db = await _db.database;
    final r = await db
        .rawQuery('SELECT COUNT(*) c FROM visitas_pendientes WHERE pendiente_sync = 1');
    return (r.first['c'] as int?) ?? 0;
  }
}
