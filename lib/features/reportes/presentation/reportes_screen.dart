import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/gradient_app_bar.dart';

class ProductividadRow {
  final String asesor;
  final int enviadas, aprobadas, desembolsadas;
  final double montoTotal, tasaAprobacion;
  const ProductividadRow(this.asesor, this.enviadas, this.aprobadas,
      this.desembolsadas, this.montoTotal, this.tasaAprobacion);

  factory ProductividadRow.fromJson(Map<String, dynamic> j) => ProductividadRow(
        j['asesor_nombre'] as String? ?? '',
        (j['enviadas'] as num?)?.toInt() ?? 0,
        (j['aprobadas'] as num?)?.toInt() ?? 0,
        (j['desembolsadas'] as num?)?.toInt() ?? 0,
        (j['monto_total'] as num?)?.toDouble() ?? 0,
        (j['tasa_aprobacion'] as num?)?.toDouble() ?? 0,
      );
}

final productividadProvider =
    FutureProvider<List<ProductividadRow>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/reportes/productividad');
  return (data as List)
      .map((e) => ProductividadRow.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Genera y comparte/imprime el reporte de productividad como PDF (HU-33).
Future<void> _exportarPdf(List<ProductividadRow> filas) async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Banco Santander Consumer Perú - Productividad mensual',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Reporte de la fuerza de ventas',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Asesor',
              'Enviadas',
              'Aprobadas',
              'Desembolsadas',
              'Monto',
              '% Aprob.'
            ],
            data: filas
                .map((f) => [
                      f.asesor,
                      '${f.enviadas}',
                      '${f.aprobadas}',
                      '${f.desembolsadas}',
                      'S/ ${f.montoTotal.toStringAsFixed(2)}',
                      '${f.tasaAprobacion}%',
                    ])
                .toList(),
          ),
        ],
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (format) => doc.save());
}

/// M11 - Reporte de productividad mensual (HU-33). Solo Supervisor/Admin.
class ReportesScreen extends ConsumerWidget {
  const ReportesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productividadProvider);
    final filas = async.valueOrNull;
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Reportes y supervision',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: (filas == null || filas.isEmpty)
                ? null
                : () => _exportarPdf(filas),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('No se pudo cargar el reporte.')),
        data: (filas) => filas.isEmpty
            ? const Center(child: Text('Sin datos del periodo.'))
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _Grafico(filas: filas),
                  const SizedBox(height: 16),
                  _Tabla(filas: filas),
                ],
              ),
      ),
    );
  }
}

class _Grafico extends StatelessWidget {
  final List<ProductividadRow> filas;
  const _Grafico({required this.filas});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solicitudes por asesor',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= filas.length) {
                            return const SizedBox();
                          }
                          final n = filas[i].asesor.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(n,
                                style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(filas.length, (i) {
                    final f = filas[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: f.enviadas.toDouble(),
                          color: AppColors.info,
                          width: 7),
                      BarChartRodData(
                          toY: f.aprobadas.toDouble(),
                          color: AppColors.success,
                          width: 7),
                      BarChartRodData(
                          toY: f.desembolsadas.toDouble(),
                          color: AppColors.secondary,
                          width: 7),
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(spacing: 12, children: [
              _Leyenda(color: AppColors.info, texto: 'Enviadas'),
              _Leyenda(color: AppColors.success, texto: 'Aprobadas'),
              _Leyenda(color: AppColors.secondary, texto: 'Desembolsadas'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _Leyenda({required this.color, required this.texto});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 12)),
      ]);
}

class _Tabla extends StatelessWidget {
  final List<ProductividadRow> filas;
  const _Tabla({required this.filas});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Asesor')),
            DataColumn(label: Text('Env.')),
            DataColumn(label: Text('Aprob.')),
            DataColumn(label: Text('Desemb.')),
            DataColumn(label: Text('Monto')),
            DataColumn(label: Text('% Aprob.')),
          ],
          rows: filas
              .map((f) => DataRow(cells: [
                    DataCell(Text(f.asesor)),
                    DataCell(Text('${f.enviadas}')),
                    DataCell(Text('${f.aprobadas}')),
                    DataCell(Text('${f.desembolsadas}')),
                    DataCell(Text(Formatters.soles(f.montoTotal))),
                    DataCell(Text('${f.tasaAprobacion}%')),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}
