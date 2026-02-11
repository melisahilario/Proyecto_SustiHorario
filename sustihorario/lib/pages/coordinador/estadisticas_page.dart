import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EstadisticasPage extends StatefulWidget {
  const EstadisticasPage({super.key});

  @override
  State<EstadisticasPage> createState() => _EstadisticasPageState();
}

class _EstadisticasPageState extends State<EstadisticasPage> {
  bool _isLoading = true;
  Map<String, int> _datosGuardias = {};
  String _filtroTiempo = 'Semana'; // 'Semana', 'Mes', 'Año'

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final centroId = userDoc.data()?['centroId'];
      if (centroId == null) return;

      DateTime ahora = DateTime.now();
      DateTime fechaFiltro;

      if (_filtroTiempo == 'Mes') {
        fechaFiltro = DateTime(ahora.year, ahora.month - 1, ahora.day);
      } else if (_filtroTiempo == 'Año') {
        fechaFiltro = DateTime(ahora.year - 1, ahora.month, ahora.day);
      } else {
        // Semana por defecto
        fechaFiltro = ahora.subtract(const Duration(days: 7));
      }

      final query = await FirebaseFirestore.instance
          .collection('guardias')
          .where('centroId', isEqualTo: centroId)
          .where('estado', isEqualTo: 'asignada')
          .get();

      Map<String, int> counts = {};
      final DateFormat df = DateFormat('dd/MM/yyyy');

      for (var doc in query.docs) {
        final data = doc.data();
        final fechaStr = data['fecha'] as String?;
        if (fechaStr == null) continue;

        try {
          final fechaG = df.parse(fechaStr);
          if (fechaG.isAfter(fechaFiltro)) {
            final nombre = data['sustitutoNombre'] as String? ?? 'Desconocido';
            counts[nombre] = (counts[nombre] ?? 0) + 1;
          }
        } catch (_) {}
      }

      final sortedEntries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _datosGuardias = Map.fromEntries(sortedEntries.take(5));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carga de Guardias',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Héroes más activos del centro',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: ['Semana', 'Mes', 'Año'].map((f) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: FilterChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    selected: _filtroTiempo == f,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _filtroTiempo = f);
                        _cargarDatos();
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ],
        ).animate().fadeIn().slideY(begin: -0.1),
        const SizedBox(height: 32),
        if (_datosGuardias.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text('No hay datos según el filtro seleccionado.'),
          ).animate().fadeIn()
        else
          AspectRatio(
            aspectRatio: 1.5,
            child:
                BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            (_datosGuardias.values.isEmpty
                                ? 0
                                : _datosGuardias.values
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble()) +
                            1,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 &&
                                    index < _datosGuardias.length) {
                                  String name = _datosGuardias.keys.elementAt(
                                    index,
                                  );
                                  if (name.length > 8) {
                                    name = "${name.substring(0, 7)}..";
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: _generateGroups(),
                      ),
                    )
                    .animate(key: ValueKey(_filtroTiempo))
                    .fadeIn()
                    .scale(begin: const Offset(0.95, 0.95)),
          ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Resumen Detallado',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._datosGuardias.entries.map(
          (e) =>
              ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        e.value.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Guardias completadas en el periodo: $_filtroTiempo',
                    ),
                    dense: true,
                  )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 100))
                  .slideX(begin: 0.1),
        ),
      ],
    );
  }

  List<BarChartGroupData> _generateGroups() {
    List<BarChartGroupData> groups = [];
    int i = 0;
    _datosGuardias.forEach((name, cantidad) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cantidad.toDouble(),
              color: Colors.indigo,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      i++;
    });
    return groups;
  }
}
