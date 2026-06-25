// Modelo de dominio de mora (M10).
class MoraItem {
  final String id;
  final String codCuentaCredito;
  final String clienteId;
  final String clienteNombre;
  final String documento;
  final String? telefono;
  final int diasMora;
  final double montoVencido;

  const MoraItem({
    required this.id,
    required this.codCuentaCredito,
    required this.clienteId,
    required this.clienteNombre,
    required this.documento,
    this.telefono,
    required this.diasMora,
    required this.montoVencido,
  });

  factory MoraItem.fromJson(Map<String, dynamic> j) => MoraItem(
        id: j['id'] as String? ?? '',
        codCuentaCredito: j['cod_cuenta_credito'] as String? ?? '',
        clienteId: j['cliente_id'] as String? ?? '',
        clienteNombre: j['cliente_nombre'] as String? ?? '',
        documento: j['documento'] as String? ?? '',
        telefono: j['telefono'] as String?,
        diasMora: (j['dias_mora'] as num?)?.toInt() ?? 0,
        montoVencido: (j['monto_vencido'] as num?)?.toDouble() ?? 0,
      );
}
