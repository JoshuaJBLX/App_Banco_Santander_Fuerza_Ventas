import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_db.dart';
import '../domain/borrador_model.dart';

/// Persistencia de borradores de solicitud en SQLite (HU-18 / RF-49).
class SolicitudLocalDataSource {
  final LocalDb _db;
  SolicitudLocalDataSource([LocalDb? db]) : _db = db ?? LocalDb.instance;

  Future<void> guardarBorrador({
    required String id,
    required String asesorId,
    required String clienteNombre,
    required int pasoActual,
    required Map<String, dynamic> datos,
    required double montoSolicitado,
  }) async {
    final db = await _db.database;
    await db.insert(
      'solicitudes_borrador',
      {
        'id': id,
        'asesor_id': asesorId,
        'cliente_nombre': clienteNombre,
        'paso_actual': pasoActual,
        'datos_json': jsonEncode(datos),
        'monto_solicitado': montoSolicitado,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BorradorSolicitud>> listar(String asesorId) async {
    final db = await _db.database;
    final rows = await db.query(
      'solicitudes_borrador',
      where: 'asesor_id = ?',
      whereArgs: [asesorId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(BorradorSolicitud.fromMap).toList();
  }

  Future<void> eliminar(String id) async {
    final db = await _db.database;
    await db.delete('solicitudes_borrador', where: 'id = ?', whereArgs: [id]);
  }
}
