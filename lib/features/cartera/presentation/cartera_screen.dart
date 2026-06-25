import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/network_monitor.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_nocturna.dart';
import '../../alertas/data/alertas_repository.dart';
import '../../auth/domain/asesor_model.dart';
import '../../auth/presentation/login_viewmodel.dart';
import '../../solicitud/data/solicitud_local_datasource.dart';
import '../../../shared/widgets/cliente_card.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/logo_santander_consumer.dart';
import '../domain/cartera_model.dart';
import 'cartera_viewmodel.dart';

/// Pantalla de cartera diaria (M1).
class CarteraScreen extends ConsumerStatefulWidget {
  const CarteraScreen({super.key});

  @override
  ConsumerState<CarteraScreen> createState() => _CarteraScreenState();
}

class _CarteraScreenState extends ConsumerState<CarteraScreen> {
  String? _ultimoAsesorCargado;

  String _asesorKey(AsesorModel a) =>
      a.id.isNotEmpty ? a.id : a.codigoEmpleado;

  void _cargarCartera(AsesorModel asesor) {
    final key = _asesorKey(asesor);
    if (key.isEmpty || key == _ultimoAsesorCargado) return;
    _ultimoAsesorCargado = key;
    ref.read(carteraViewModelProvider.notifier).cargar(key);
    try {
      SyncNocturna.programar();
    } catch (_) {/* workmanager no disponible en web */}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final asesor = ref.read(loginViewModelProvider).asesor;
      if (asesor != null) _cargarCartera(asesor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asesor = ref.watch(loginViewModelProvider).asesor;
    final state = ref.watch(carteraViewModelProvider);
    final vm = ref.read(carteraViewModelProvider.notifier);

    ref.listen(loginViewModelProvider, (prev, next) {
      final a = next.asesor;
      if (a != null) _cargarCartera(a);
    });

    // RF-18: al recuperar la red, sincroniza la cola y refresca.
    ref.listen(connectivityStreamProvider, (prev, next) {
      final volvio = (prev?.value ?? true) == false && next.value == true;
      if (volvio) {
        _ultimoAsesorCargado = null;
        vm.refrescar(asesor != null ? _asesorKey(asesor) : null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Conexion recuperada - sincronizando...')));
      }
    });

    // Refresca el sello de "Ultima actualizacion" cuando la cartera carga.
    ref.listen(carteraViewModelProvider, (prev, next) {
      if (prev?.status != next.status &&
          next.status == CarteraStatus.ready &&
          !next.desdeCache) {
        ref.invalidate(ultimaSyncProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: AppStrings.carteraTitle,
        actions: [
          // Insignia de alertas no leidas (HU-14/RF-36)
          Consumer(builder: (context, ref, _) {
            final n = ref.watch(alertasNoLeidasProvider).valueOrNull ?? 0;
            return IconButton(
              tooltip: 'Alertas',
              onPressed: () => context.push('/alertas'),
              icon: Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                child: const Icon(Icons.notifications),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.actualizar,
            onPressed: () {
              _ultimoAsesorCargado = null;
              vm.refrescar(asesor != null ? _asesorKey(asesor) : null);
            },
          ),
        ],
      ),
      drawer: _Drawer(asesor: asesor),
      body: Column(
        children: [
          if (state.desdeCache) const _OfflineBanner(),
          _Encabezado(state: state),
          _Filtros(state: state, onChanged: vm.cambiarFiltro),
          _BuscadorCartera(onChanged: vm.buscar),
          Expanded(child: _Lista(state: state)),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(AppStrings.modoOffline,
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final CarteraState state;
  const _Encabezado({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${state.total} clientes · ${state.visitados} visitados · '
            '${state.pendientes} pendientes',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          // Ultima actualizacion (HU-05)
          Consumer(builder: (context, ref, _) {
            final dt = ref.watch(ultimaSyncProvider).valueOrNull;
            if (dt == null) return const SizedBox(height: 8);
            final ahora = DateTime.now();
            final esHoy = dt.year == ahora.year &&
                dt.month == ahora.month &&
                dt.day == ahora.day;
            final hh = dt.hour.toString().padLeft(2, '0');
            final mm = dt.minute.toString().padLeft(2, '0');
            final cuando = esHoy
                ? 'hoy $hh:$mm'
                : '${dt.day.toString().padLeft(2, '0')}/'
                    '${dt.month.toString().padLeft(2, '0')} $hh:$mm';
            return Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text('${AppStrings.ultimaActualizacion}: $cuando',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            );
          }),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.progreso,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  final CarteraState state;
  final ValueChanged<FiltroCartera> onChanged;
  const _Filtros({required this.state, required this.onChanged});

  static const _labels = {
    FiltroCartera.todos: 'Todos',
    FiltroCartera.renovaciones: 'Renovaciones',
    FiltroCartera.nuevas: 'Nuevas',
    FiltroCartera.enMora: 'En mora',
    FiltroCartera.visitados: 'Visitados',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _labels.entries.map((e) {
          final sel = state.filtro == e.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Text(e.value),
              selected: sel,
              selectedColor: AppColors.primary.withValues(alpha: 0.18),
              onSelected: (_) => onChanged(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BuscadorCartera extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _BuscadorCartera({required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: AppStrings.buscarCliente,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  final CarteraState state;
  const _Lista({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == CarteraStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == CarteraStatus.error) {
      return Center(child: Text(state.error ?? AppStrings.errorGenerico));
    }
    final visibles = state.visibles;
    if (visibles.isEmpty) {
      return const Center(child: Text(AppStrings.sinClientes));
    }
    final vm = ref.read(carteraViewModelProvider.notifier);

    Widget tarjeta(CarteraItem item) => ClienteCard(
          nombre: item.clienteNombre,
          documentoCensurado: item.documento,
          tipoGestion: item.tipoGestion,
          montoCredito: item.montoCredito,
          prioridad: item.prioridad,
          visitado: item.visitado,
          // Abre la ficha del cliente; pasa el id de cartera para registrar
          // la visita al salir (HU-07).
          onTap: () =>
              context.push('/ficha/${item.clienteId}', extra: item.id),
        );

    // RF-16: reordenamiento manual con arrastrar y soltar (solo sobre la lista
    // completa, sin filtro ni busqueda).
    if (state.puedeReordenar) {
      // âœ… CORREGIDO: Usar StatefulReorderableList en lugar de ReorderableListView directo
      return _ReorderableCarteraList(
        items: visibles,
        onReorder: (oldIndex, newIndex) {
          vm.reordenar(oldIndex, newIndex);
        },
        itemBuilder: (context, item, index) => tarjeta(item),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        final a = ref.read(loginViewModelProvider).asesor;
        final key = a != null && a.id.isNotEmpty ? a.id : a?.codigoEmpleado;
        return vm.refrescar(key);
      },
      child: ListView.builder(
        itemCount: visibles.length,
        itemBuilder: (context, i) => tarjeta(visibles[i]),
      ),
    );
  }
}

/// âœ… NUEVO: Widget Stateful para manejar el reordenamiento
class _ReorderableCarteraList extends StatefulWidget {
  final List<CarteraItem> items;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget Function(BuildContext context, CarteraItem item, int index) itemBuilder;

  const _ReorderableCarteraList({
    required this.items,
    required this.onReorder,
    required this.itemBuilder,
  });

  @override
  State<_ReorderableCarteraList> createState() => _ReorderableCarteraListState();
}

class _ReorderableCarteraListState extends State<_ReorderableCarteraList> {
  late List<CarteraItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant _ReorderableCarteraList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = List.from(widget.items);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          // Corregir Ã­ndices cuando se mueve hacia abajo
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
        // Notificar al ViewModel despuÃ©s del reordenamiento local
        widget.onReorder(oldIndex, newIndex);
      },
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          key: ValueKey(item.id), // Usar ID Ãºnico si estÃ¡ disponible
          child: widget.itemBuilder(context, item, index),
        );
      }).toList(),
    );
  }
}

/// Menu lateral adaptativo por perfil (RF-05).
class _Drawer extends ConsumerWidget {
  final AsesorModel? asesor;
  const _Drawer({this.asesor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = asesor?.perfil ?? PerfilAsesor.operador;
    final items = <(IconData, String, String)>[
      (Icons.list_alt, 'Cartera', '/cartera'),
      (Icons.map, 'Ruta', '/ruta'),
      (Icons.person, 'Ficha cliente', '/ficha'),
      (Icons.fact_check, 'Pre-evaluacion', '/preevaluacion'),
      (Icons.person_off, 'Cliente desertor', '/desertor'),
      (Icons.assignment, 'Solicitud', '/solicitud'),
      (Icons.calculate, 'Simulador', '/simulador'),
      (Icons.history, 'Mis solicitudes', '/historial'),
      (Icons.campaign, 'Campanas', '/campanas'),
      (Icons.camera_alt, 'Documentos', '/documentos'),
      (Icons.credit_score, 'Consulta buro', '/buro'),
      (Icons.dashboard, 'Estado solicitudes', '/estado'),
      (Icons.attach_money, 'Cobranza', '/cobranza'),
      if (perfil.puedeSupervisar)
        (Icons.bar_chart, 'Reportes', '/reportes'),
    ];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
            ),
            accountName: Text(asesor?.nombreCompleto ?? 'Asesor'),
            accountEmail: Text(perfil.label),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: LogoSantanderConsumerPeru(size: 36),
              ),
            ),
          ),
          ...items.map((it) => ListTile(
                leading: Icon(it.$1),
                title: Text(it.$2),
                onTap: () {
                  Navigator.pop(context);
                  if (it.$3 != '/cartera') context.push(it.$3);
                },
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text(AppStrings.cerrarSesion,
                style: TextStyle(color: AppColors.danger)),
            onTap: () => _cerrarSesion(context, ref, asesor),
          ),
        ],
      ),
    );
  }

  /// Cierre de sesion con advertencia de pendientes (RF-08) y borrado de
  /// cache sensible (RF-07).
  Future<void> _cerrarSesion(
      BuildContext context, WidgetRef ref, AsesorModel? asesor) async {
    var pendientes = 0;
    try {
      pendientes = await LocalDb.instance.contarPendientesSync();
      if (asesor != null) {
        final borradores = await SolicitudLocalDataSource().listar(asesor.id);
        pendientes += borradores.length;
      }
    } catch (_) {/* si falla el conteo, continuamos con el cierre */}

    if (!context.mounted) return;
    if (pendientes > 0) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(AppStrings.cerrarSesion),
          content: Text(
              'Tienes $pendientes elemento(s) sin sincronizar. '
              '${AppStrings.cerrarSesionConfirmar}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cerrar de todas formas')),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    // RF-07: limpiar cache sensible al cerrar sesion (SQLite).
    // En web SQLite no esta disponible, por eso se captura la excepcion.
    try {
      await LocalDb.instance.limpiarCacheSesion();
    } catch (_) {
      // Si falla (ej. web sin SQLite), continuamos con el logout de todos modos.
    }
    await ref.read(loginViewModelProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}