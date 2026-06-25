import '../../../core/storage/local_db.dart';

/// Persistencia local del registro de clientes desertores (RF-42).
/// Offline-first: se guarda con pendiente_sync = 1 para enviarlo al
/// reconectar (igual patron que visitas_pendientes).
class DesertorLocalDataSource {
  final LocalDb _db;
  DesertorLocalDataSource([LocalDb? db]) : _db = db ?? LocalDb.instance;

  Future<void> guardar({
    required String id,
    required String asesorId,
    required String clienteNombre,
    required String documento,
    required String motivo,
    required String institucionMigro,
    required String probabilidadRetorno,
    required String observaciones,
  }) async {
    final db = await _db.database;
    await db.insert('clientes_desertores', {
      'id': id,
      'asesor_id': asesorId,
      'cliente_nombre': clienteNombre,
      'documento': documento,
      'motivo': motivo,
      'institucion_migro': institucionMigro,
      'probabilidad_retorno': probabilidadRetorno,
      'observaciones': observaciones,
      'pendiente_sync': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> contar(String asesorId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM clientes_desertores WHERE asesor_id = ?',
      [asesorId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
