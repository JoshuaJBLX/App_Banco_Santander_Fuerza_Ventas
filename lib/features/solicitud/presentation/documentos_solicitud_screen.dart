import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/gradient_app_bar.dart';

/// Pantalla para adjuntar documentos a una solicitud.
class DocumentosSolicitudScreen extends StatefulWidget {
  final String solicitudId;
  final String numeroExpediente;
  final String clienteNombre;

  const DocumentosSolicitudScreen({
    super.key,
    required this.solicitudId,
    required this.numeroExpediente,
    required this.clienteNombre,
  });

  @override
  State<DocumentosSolicitudScreen> createState() =>
      _DocumentosSolicitudScreenState();
}

class _DocumentoItem {
  final String tipo;
  final String label;
  final IconData icono;
  bool adjuntado;

  _DocumentoItem({
    required this.tipo,
    required this.label,
    required this.icono,
    this.adjuntado = false,
  }) : super();
}

class _DocumentosSolicitudScreenState
    extends State<DocumentosSolicitudScreen> {
  final _picker = ImagePicker();
  bool _cargando = false;

  final List<_DocumentoItem> _documentos = [
    _DocumentoItem(
        tipo: 'DNI_FRENTE',
        label: 'DNI Frente',
        icono: Icons.badge_outlined),
    _DocumentoItem(
        tipo: 'DNI_DORSO', label: 'DNI Dorso', icono: Icons.badge_outlined),
    _DocumentoItem(
        tipo: 'SUSTENTO_NEGOCIO',
        label: 'Sustento del Negocio',
        icono: Icons.description_outlined),
    _DocumentoItem(
        tipo: 'FOTO_NEGOCIO',
        label: 'Foto del Negocio',
        icono: Icons.store_outlined),
    _DocumentoItem(
        tipo: 'FOTO_VISITA',
        label: 'Foto de la Visita',
        icono: Icons.camera_alt_outlined),
  ];

  bool get _todosAdjuntados => _documentos.every((d) => d.adjuntado);
  int get _adjuntados => _documentos.where((d) => d.adjuntado).length;

  Future<void> _adjuntarDocumento(int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() => _cargando = true);

      final bytes = await image.readAsBytes();
      final tamanioKb = bytes.length / 1024.0;

      final payload = {
        'solicitud_id': widget.solicitudId,
        'tipo_documento': _documentos[index].tipo,
        'storage_url':
            'https://storage.bancoandino.pe/documentos/${widget.solicitudId}/${_documentos[index].tipo}.jpg',
        'tamanio_kb': tamanioKb,
      };

      final client = ApiClient();
      await client.post('/solicitudes/documentos', payload);

      setState(() {
        _documentos[index].adjuntado = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${_documentos[index].label} adjuntado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al adjuntar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _documentos.isEmpty ? 0.0 : _adjuntados / _documentos.length;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Adjuntar Documentos'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info de la solicitud + barra de progreso
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expediente: ${widget.numeroExpediente}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Cliente: ${widget.clienteNombre}'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: AppColors.neutral,
                      color: AppColors.primary,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_adjuntados de ${_documentos.length} documentos adjuntados',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Documentos Requeridos:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._documentos.asMap().entries.map((entry) {
            final i = entry.key;
            final doc = entry.value;
            return Card(
              child: ListTile(
                leading: Icon(
                  doc.adjuntado ? Icons.check_circle : doc.icono,
                  color: doc.adjuntado ? AppColors.success : AppColors.textSecondary,
                  size: 32,
                ),
                title: Text(doc.label),
                trailing: doc.adjuntado
                    ? const Icon(Icons.check, color: AppColors.success)
                    : ElevatedButton(
                        onPressed: _cargando
                            ? null
                            : () => _adjuntarDocumento(i),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Adjuntar'),
                      ),
              ),
            );
          }),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _todosAdjuntados
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FirmaSolicitudScreen(
                            solicitudId: widget.solicitudId,
                            numeroExpediente: widget.numeroExpediente,
                            clienteNombre: widget.clienteNombre,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                  _cargando ? 'Cargando...' : 'Continuar a Firma'),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// FIRMA SCREEN (embebida en el flujo)
// =========================================================================

class _FirmaSolicitudScreen extends StatefulWidget {
  final String solicitudId;
  final String numeroExpediente;
  final String clienteNombre;

  const _FirmaSolicitudScreen({
    required this.solicitudId,
    required this.numeroExpediente,
    required this.clienteNombre,
  });

  @override
  State<_FirmaSolicitudScreen> createState() => _FirmaSolicitudScreenState();
}

class _FirmaSolicitudScreenState extends State<_FirmaSolicitudScreen> {
  final List<Offset> _puntos = [];
  bool _firmaCapturada = false;
  bool _cargando = false;

  Future<void> _guardarFirma() async {
    try {
      setState(() => _cargando = true);

      // Generar imagen PNG de la firma
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0;

      for (int i = 0; i < _puntos.length - 1; i++) {
        canvas.drawLine(_puntos[i], _puntos[i + 1], paint);
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Error al generar imagen');

      final bytes = byteData.buffer.asUint8List();
      final base64Image = base64Encode(bytes);
      final firmaBase64 = 'data:image/png;base64,$base64Image';

      // Enviar al backend
      final client = ApiClient();
      await client.put('/solicitudes/firma', {
        'solicitud_id': widget.solicitudId,
        'firma_base64': firmaBase64,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firma capturada exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _ComiteSolicitudScreen(
              solicitudId: widget.solicitudId,
              numeroExpediente: widget.numeroExpediente,
              clienteNombre: widget.clienteNombre,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Capturar Firma'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expediente: ${widget.numeroExpediente}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Cliente: ${widget.clienteNombre}'),
                  const SizedBox(height: 8),
                  const Text(
                    'El cliente debe firmar en el area a continuacion:',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Firma:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.neutral, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() => _puntos.add(details.localPosition));
              },
              onPanEnd: (_) {
                if (_puntos.isNotEmpty) {
                  setState(() => _firmaCapturada = true);
                }
              },
              child: CustomPaint(
                painter: _FirmaPainter(puntos: _puntos),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _puntos.clear();
                      _firmaCapturada = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _firmaCapturada ? _guardarFirma : null,
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(
                      _cargando ? 'Guardando...' : 'Aceptar Firma'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirmaPainter extends CustomPainter {
  final List<Offset> puntos;
  _FirmaPainter({required this.puntos});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < puntos.length - 1; i++) {
      canvas.drawLine(puntos[i], puntos[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_FirmaPainter oldDelegate) =>
      oldDelegate.puntos != puntos;
}

// =========================================================================
// COMITE SCREEN (embebida en el flujo)
// =========================================================================

class _ComiteSolicitudScreen extends StatefulWidget {
  final String solicitudId;
  final String numeroExpediente;
  final String clienteNombre;

  const _ComiteSolicitudScreen({
    required this.solicitudId,
    required this.numeroExpediente,
    required this.clienteNombre,
  });

  @override
  State<_ComiteSolicitudScreen> createState() => _ComiteSolicitudScreenState();
}

class _ComiteSolicitudScreenState extends State<_ComiteSolicitudScreen> {
  String _estadoActual = 'enviado';
  String _proximoEstado = 'recibido_comite';
  bool _cargando = false;
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final client = ApiClient();
      final data = await client.get('/solicitudes/${widget.solicitudId}');
      if (data is Map) {
        setState(() {
          _estadoActual = data['estado'] as String? ?? 'enviado';
          _proximoEstado = _estadoActual == 'enviado'
              ? 'recibido_comite'
              : 'en_evaluacion';
        });
      }
    } catch (_) {
      setState(() => _sinConexion = true);
    }
  }

  Future<void> _promover() async {
    try {
      setState(() => _cargando = true);
      final client = ApiClient();
      final data = await client.put(
        '/solicitudes/${widget.solicitudId}/promover',
        {},
      );

      if (data is Map) {
        final nuevoEstado = data['estado'] as String? ?? '';
        setState(() {
          _estadoActual = nuevoEstado;
          _proximoEstado = nuevoEstado == 'enviado'
              ? 'recibido_comite'
              : 'en_evaluacion';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solicitud promovida a: $nuevoEstado'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'enviado':
        return 'ENVIADO';
      case 'recibido_comite':
        return 'RECIBIDO COMITE';
      case 'en_evaluacion':
        return 'EN EVALUACION';
      case 'aprobado':
        return 'APROBADO';
      case 'condicionado':
        return 'CONDICIONADO';
      case 'rechazado':
        return 'RECHAZADO';
      case 'desembolsado':
        return 'DESEMBOLSADO';
      default:
        return estado.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool puedePromover = _estadoActual == 'enviado' ||
        _estadoActual == 'recibido_comite';

    return Scaffold(
      appBar: const GradientAppBar(title: 'Envio al Comite'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expediente: ${widget.numeroExpediente}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Cliente: ${widget.clienteNombre}'),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('Documentos adjuntados: 5/5'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('Firma capturada'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Progreso:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          // Timeline de estados
          _buildTimeline(),
          const SizedBox(height: 24),
          if (_sinConexion)
            const Card(
              color: AppColors.warning,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexion. Se mostrara el estado local.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estado Actual: ${_labelEstado(_estadoActual)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (puedePromover) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Siguiente: ${_labelEstado(_proximoEstado)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (puedePromover) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _cargando ? null : _promover,
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch),
                label: Text(_cargando
                    ? 'Promoviendo...'
                    : 'Promover al Core'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
          if (_estadoActual == 'desembolsado')
            const Card(
              color: AppColors.success,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Caso completado exitosamente',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final estados = ['enviado', 'recibido_comite', 'en_evaluacion'];
    final labels = ['Enviado', 'Comite', 'Evaluacion'];
    final colors = <Color>[];
    for (final e in estados) {
      if (_estadoActual == e) {
        colors.add(AppColors.primary);
      } else if (estados.indexOf(_estadoActual) > estados.indexOf(e)) {
        colors.add(AppColors.success);
      } else {
        colors.add(AppColors.neutral);
      }
    }

    return Row(
      children: [
        for (int i = 0; i < estados.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                color: colors[i - 1] == AppColors.neutral
                    ? AppColors.neutral
                    : AppColors.primary,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                ),
                child: Center(
                  child: Icon(
                    estados.indexOf(_estadoActual) >= i
                        ? Icons.check
                        : Icons.circle_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: TextStyle(
                      fontSize: 11,
                      color: colors[i] == AppColors.neutral
                          ? AppColors.textSecondary
                          : AppColors.primary)),
            ],
          ),
        ],
        // Estado final (aprobado o desembolsado)
        Expanded(
          child: Container(
            height: 3,
            color: _estadoActual == 'aprobado' ||
                    _estadoActual == 'desembolsado'
                ? AppColors.success
                : AppColors.neutral,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _estadoActual == 'aprobado' ||
                        _estadoActual == 'desembolsado'
                    ? AppColors.success
                    : AppColors.neutral,
              ),
              child: Center(
                child: Icon(
                  _estadoActual == 'aprobado' ||
                          _estadoActual == 'desembolsado'
                      ? Icons.check
                      : Icons.circle_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Decisión',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}