import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';

/// Umbral de nitidez (varianza de Laplaciano). Por debajo => borrosa (RF-54).
const double _umbralNitidez = 80;

/// Calcula la varianza del Laplaciano como medida de nitidez (RF-54).
Future<double> _varianzaLaplaciano(String path) async {
  final decoded = img.decodeImage(await File(path).readAsBytes());
  if (decoded == null) return 0;
  final gray = img.grayscale(img.copyResize(decoded, width: 400));
  final lap = img.convolution(gray, filter: const [0, 1, 0, 1, -4, 1, 0, 1, 0]);
  double sum = 0, sumSq = 0;
  final n = lap.width * lap.height;
  for (var y = 0; y < lap.height; y++) {
    for (var x = 0; x < lap.width; x++) {
      final l = img.getLuminance(lap.getPixel(x, y)).toDouble();
      sum += l;
      sumSq += l * l;
    }
  }
  if (n == 0) return 0;
  final mean = sum / n;
  return (sumSq / n) - mean * mean;
}

/// M6 — Captura de documentos del cliente (HU-21/22).
/// Camara del sistema (image_picker) + validacion de nitidez (Laplaciano, RF-54).
/// La subida real a Storage queda pendiente (requiere backend de archivos).
class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});
  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final _picker = ImagePicker();

  // tipo -> (etiqueta, obligatorio)
  static const _docs = <String, (String, bool)>{
    'dni_anverso': ('DNI (anverso)', true),
    'dni_reverso': ('DNI (reverso)', true),
    'foto_negocio': ('Foto del negocio', true),
    'foto_visita': ('Foto asesor con cliente', true),
    'ruc': ('RUC', false),
    'recibo_servicios': ('Recibo de servicios', false),
  };

  final Map<String, String> _capturas = {}; // tipo -> path
  final Map<String, double> _nitidez = {}; // tipo -> varianza Laplaciano
  final Map<String, int> _tamanios = {}; // tipo -> tamano en KB tras comprimir

  Future<void> _capturar(String tipo) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (foto == null) return;
      final v = await _varianzaLaplaciano(foto.path); // validacion de nitidez
      if (v < _umbralNitidez) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Foto borrosa'),
              content: Text(
                  'La imagen no es lo bastante nitida (puntaje ${v.toStringAsFixed(0)}). '
                  'Por favor, retomala con mejor enfoque.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido')),
              ],
            ),
          );
        }
        return; // no se acepta
      }
      // Compresion iterativa a < 800 KB (RF-54).
      final (path, kb) = await _comprimirAUmbral(foto.path);
      setState(() {
        _capturas[tipo] = path;
        _nitidez[tipo] = v;
        _tamanios[tipo] = kb;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir la camara.')));
      }
    }
  }

  /// Comprime la imagen reduciendo la calidad en pasos de 10 hasta que el
  /// archivo sea menor a 800 KB (RF-54). Devuelve (ruta, tamano en KB).
  Future<(String, int)> _comprimirAUmbral(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (path, (bytes.length / 1024).round());
    var q = 90;
    var out = img.encodeJpg(decoded, quality: q);
    while (out.length > 800 * 1024 && q > 30) {
      q -= 10;
      out = img.encodeJpg(decoded, quality: q);
    }
    final nuevoPath = '$path.c.jpg';
    await File(nuevoPath).writeAsBytes(out);
    return (nuevoPath, (out.length / 1024).round());
  }

  /// Visor a pantalla completa con zoom de pincel (RF-55) y acciones de
  /// retomar/eliminar (RF-56).
  void _verImagen(String tipo) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(child: Image.file(File(_capturas[tipo]!))),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retomar'),
                    onPressed: () {
                      Navigator.pop(context);
                      _capturar(tipo);
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    onPressed: () => _eliminar(tipo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Eliminar documento con confirmacion (RF-56).
  Future<void> _eliminar(String tipo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: const Text('¿Seguro que deseas eliminar esta foto?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _capturas.remove(tipo);
      _nitidez.remove(tipo);
      _tamanios.remove(tipo);
    });
    if (mounted) Navigator.of(context).pop(); // cierra el visor
  }

  bool get _obligatoriosListos => _docs.entries
      .where((e) => e.value.$2)
      .every((e) => _capturas.containsKey(e.key));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Documentos'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ..._docs.entries.map((e) {
            final tipo = e.key;
            final (label, obligatorio) = e.value;
            final listo = _capturas.containsKey(tipo);
            final (icon, color, estado) = listo
                ? (Icons.check_circle, AppColors.success, 'LISTO')
                : obligatorio
                    ? (Icons.error, AppColors.danger, 'OBLIGATORIO')
                    : (Icons.schedule, AppColors.warning, 'OPCIONAL');
            return Card(
              child: ListTile(
                leading: listo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(_capturas[tipo]!),
                            width: 44, height: 44, fit: BoxFit.cover),
                      )
                    : Icon(icon, color: color),
                title: Text(label),
                subtitle: Text(
                    listo
                        ? 'LISTO · nitidez ${_nitidez[tipo]?.toStringAsFixed(0) ?? '-'} · ${_tamanios[tipo] ?? '-'} KB'
                        : estado,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                trailing: IconButton(
                  icon: Icon(listo ? Icons.zoom_in : Icons.camera_alt),
                  tooltip: listo ? 'Ver / gestionar' : 'Capturar',
                  onPressed: () => listo ? _verImagen(tipo) : _capturar(tipo),
                ),
                onTap: () => listo ? _verImagen(tipo) : _capturar(tipo),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _obligatoriosListos
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Documentos listos. Continua con el envio (M8).')),
                    )
                : null,
            icon: const Icon(Icons.send),
            label: const Text('Continuar'),
          ),
          if (!_obligatoriosListos)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Captura todos los documentos obligatorios.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
