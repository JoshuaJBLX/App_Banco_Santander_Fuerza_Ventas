import 'dart:math' as math;

/// Resultado de la simulacion de un credito.
class SimulacionCredito {
  final double cuotaMensual;
  final double totalPagar;
  final double costoFinanciero;
  final double teaReferencial;

  const SimulacionCredito({
    required this.cuotaMensual,
    required this.totalPagar,
    required this.costoFinanciero,
    required this.teaReferencial,
  });
}

/// Simulador de cuota con amortizacion francesa (RF-47). Sincrono, sin red.
class Simulador {
  Simulador._();

  /// [teaPorcentaje] en porcentaje (p. ej. 40 = 40%).
  static SimulacionCredito calcular({
    required double monto,
    required int plazoMeses,
    double teaPorcentaje = 40,
  }) {
    if (monto <= 0 || plazoMeses <= 0) {
      return SimulacionCredito(
        cuotaMensual: 0,
        totalPagar: 0,
        costoFinanciero: 0,
        teaReferencial: teaPorcentaje,
      );
    }
    final tea = teaPorcentaje / 100.0;
    // Tasa mensual equivalente = (1 + TEA)^(1/12) - 1
    final tm = math.pow(1 + tea, 1 / 12) - 1;
    // Cuota = Monto * tm / (1 - (1 + tm)^(-plazo))
    final cuota = tm == 0
        ? monto / plazoMeses
        : monto * tm / (1 - math.pow(1 + tm, -plazoMeses));
    final total = cuota * plazoMeses;
    return SimulacionCredito(
      cuotaMensual: cuota,
      totalPagar: total,
      costoFinanciero: total - monto,
      teaReferencial: teaPorcentaje,
    );
  }
}
