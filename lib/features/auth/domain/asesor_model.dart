/// Perfiles de acceso (RF-06).
enum PerfilAsesor { operador, superOperador, supervisor, administrador }

extension PerfilAsesorX on PerfilAsesor {
  String get label => switch (this) {
        PerfilAsesor.operador => 'Operador',
        PerfilAsesor.superOperador => 'Super Operador',
        PerfilAsesor.supervisor => 'Supervisor',
        PerfilAsesor.administrador => 'Administrador',
      };

  /// El supervisor y el administrador pueden ver reportes y supervision (M11).
  bool get puedeSupervisar =>
      this == PerfilAsesor.supervisor || this == PerfilAsesor.administrador;

  static PerfilAsesor fromString(String? v) {
    switch (v) {
      case 'super_operador':
        return PerfilAsesor.superOperador;
      case 'supervisor':
        return PerfilAsesor.supervisor;
      case 'administrador':
        return PerfilAsesor.administrador;
      default:
        return PerfilAsesor.operador;
    }
  }
}

/// Modelo de dominio del asesor de negocios (tabla `asesores_negocio`).
/// Clase pura sin dependencias de framework.
class AsesorModel {
  final String id;
  final String codigoEmpleado;
  final String nombres;
  final String apellidos;
  final String agenciaId;
  final PerfilAsesor perfil;
  final bool activo;

  const AsesorModel({
    required this.id,
    required this.codigoEmpleado,
    required this.nombres,
    required this.apellidos,
    required this.agenciaId,
    required this.perfil,
    this.activo = true,
  });

  String get nombreCompleto => '$nombres $apellidos';

  factory AsesorModel.fromJson(Map<String, dynamic> json) {
    return AsesorModel(
      id: json['id'] as String? ?? '',
      codigoEmpleado: json['codigo_empleado'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      agenciaId: json['agencia_id'] as String? ?? '',
      perfil: PerfilAsesorX.fromString(json['perfil'] as String?),
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo_empleado': codigoEmpleado,
        'nombres': nombres,
        'apellidos': apellidos,
        'agencia_id': agenciaId,
        'perfil': switch (perfil) {
          PerfilAsesor.operador => 'operador',
          PerfilAsesor.superOperador => 'super_operador',
          PerfilAsesor.supervisor => 'supervisor',
          PerfilAsesor.administrador => 'administrador',
        },
        'activo': activo,
      };
}
