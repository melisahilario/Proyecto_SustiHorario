import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Página dedicada a mostrar el horario asignado al profesor.
// Clase que extiende StatefulWidget, utilizando POO en Dart
class HorariosPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key'
  const HorariosPage({super.key});

  @override
  // Método que crea el estado asociado
  State<HorariosPage> createState() => _HorariosPageState();
}

// Clase privada que extiende State, utilizando herencia
class _HorariosPageState extends State<HorariosPage> {
  // Variable para mostrar el nombre del profesor
  String nombreProfesor = 'Cargando...';

  // Variable con null safety para el usuario autenticado
  final User? user = FirebaseAuth.instance.currentUser;

  // Lista constante de días de la semana
  final List<String> dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
  ];

  // Lista dinámica para almacenar los tramos horarios
  List<String> horas = [];

  // Map anidado para el horario fijo de clases
  Map<String, Map<String, String>> horarioFijo = {};

  // Map anidado para la disponibilidad de guardias
  Map<String, Map<String, bool>> disponibilidad = {};

  // Variable para controlar estado de carga
  bool _isLoading = true;

  @override
  // Método sobrescrito initState
  void initState() {
    super.initState();
    _cargarNombre(); // Carga del nombre del profesor.
    // Solo intentamos cargar horario si hay usuario autenticado.
    if (user != null) {
      _cargarHorarioDesdeFirestore();
      _cargarHorasDelCentro();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // Función asíncrona para cargar el nombre del profesor desde Firestore.
  Future<void> _cargarNombre() async {
    // Control de flujo: si no hay usuario autenticado.
    if (user == null) {
      setState(() => nombreProfesor = 'Usuario');
      return;
    }

    try {
      // Obtenemos documento del usuario.
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      // Actualizamos nombre con null safety.
      if (doc.exists && doc.data()?['nombre'] != null) {
        setState(() {
          nombreProfesor = doc.data()?['nombre'] as String;
        });
      } else {
        setState(() => nombreProfesor = 'Usuario');
      }
    } catch (e) {
      // En caso de error, valor por defecto.
      setState(() => nombreProfesor = 'Usuario');
    }
  }

  // Función asíncrona que obtiene el ID del centro del usuario actual.
  Future<String?> _getCurrentCentroId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['centroId'] as String?;
  }

  // Carga los tramos horarios definidos en el centro.
  Future<void> _cargarHorasDelCentro() async {
    final centroId = await _getCurrentCentroId();

    // Control de flujo si no hay centro asociado.
    if (centroId == null) {
      setState(() {
        horas = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('centros')
          .doc(centroId)
          .get();

      if (doc.exists) {
        setState(() {
          // Convertimos el campo 'horas' (que es una lista en Firestore) a List<String>.
          horas = List<String>.from(doc.data()?['horas'] ?? []);
        });
      } else {
        horas = [];
      }
    } catch (e) {
      print('Error cargando horas del centro: $e');
      horas = [];
    } finally {
      // Finalizamos el estado de carga.
      setState(() => _isLoading = false);
    }
  }

  // Función principal que carga el horario del profesor (prioriza modelo asignado).
  Future<void> _cargarHorarioDesdeFirestore() async {
    if (user == null) return;

    try {
      // Obtenemos documento de horario del profesor.
      final horarioDoc = await FirebaseFirestore.instance
          .collection('horarios')
          .doc(user!.uid)
          .get();

      if (!horarioDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = horarioDoc.data()!;

      // Variables temporales para no modificar las globales directamente.
      List<String> horasUsar = [];
      Map<String, Map<String, String>> nuevoHorarioFijo = {};
      Map<String, Map<String, bool>> nuevaDisponibilidad = {};

      // Si existe modelo asignado, lo usamos como base.
      final modeloId = data['modeloAsignadoId'] as String?;
      if (modeloId != null && modeloId.isNotEmpty) {
        final modeloDoc = await FirebaseFirestore.instance
            .collection('horarioModelos')
            .doc(modeloId)
            .get();

        if (modeloDoc.exists) {
          final modeloData = modeloDoc.data()!;
          horasUsar = List<String>.from(modeloData['horas'] ?? []);

          // Procesamos los slots del modelo (mapa anidado).
          final slotsMap = modeloData['slots'] as Map<String, dynamic>? ?? {};
          slotsMap.forEach((hora, diasMap) {
            if (diasMap is Map<String, dynamic>) {
              nuevoHorarioFijo.putIfAbsent(hora, () => {});
              nuevaDisponibilidad.putIfAbsent(hora, () => {});

              diasMap.forEach((dia, slotJson) {
                if (slotJson is Map<String, dynamic>) {
                  final estado = slotJson['estado'];
                  final clase = slotJson['clase'];
                  if (estado == 'fijo' && clase != null && clase.isNotEmpty) {
                    nuevoHorarioFijo[hora]![dia] = clase;
                  } else if (estado == 'disponible') {
                    nuevaDisponibilidad[hora]![dia] = true;
                  }
                }
              });
            }
          });
        }
      } else {
        // Si no hay modelo, usamos las horas del centro.
        final centroId = await _getCurrentCentroId();
        if (centroId != null) {
          final centroDoc = await FirebaseFirestore.instance
              .collection('centros')
              .doc(centroId)
              .get();
          if (centroDoc.exists) {
            horasUsar = List<String>.from(centroDoc.data()?['horas'] ?? []);
          }
        }
      }

      // Combinamos con disponibilidad manual (si existe).
      if (data['disponibilidad'] != null) {
        final manualDisp = data['disponibilidad'] as Map<String, dynamic>;
        manualDisp.forEach((hora, diasMap) {
          if (diasMap is Map<String, dynamic>) {
            nuevaDisponibilidad.putIfAbsent(hora, () => {});
            diasMap.forEach((dia, valor) {
              nuevaDisponibilidad[hora]![dia] = valor as bool;
            });
          }
        });
      }

      // Actualizamos el estado una sola vez.
      setState(() {
        horas = horasUsar;
        horarioFijo = nuevoHorarioFijo;
        disponibilidad = nuevaDisponibilidad;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando horario: $e');
      setState(() => _isLoading = false);
    }
  }

  // Función auxiliar que construye la celda visual para clases fijas.
  Widget _buildClaseCell(String? claseData) {
    // Caso vacío o nulo.
    if (claseData == null || claseData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Separamos los datos (formato: Asignatura - Curso - Aula).
    final partes = claseData.split(' - ');
    final asignatura = partes.isNotEmpty ? partes[0] : '';
    final curso = partes.length > 1 ? partes[1] : '';
    final aula = partes.length > 2 ? partes[2].replaceFirst('Aula ', '') : '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asignatura.isNotEmpty)
            Text(
              'Asignatura: $asignatura',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          if (curso.isNotEmpty)
            Text('Curso: $curso', style: const TextStyle(fontSize: 11)),
          if (aula.isNotEmpty)
            Text('Aula: $aula', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se cargan los datos...
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de la página.
        Row(
          children: [
            const Icon(
              Icons.calendar_view_month_rounded,
              color: Colors.indigo,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Tu Horario Asignado',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
        const SizedBox(height: 8),
        const Text(
          'Visualización estratégica de tus clases y guardias',
          style: TextStyle(color: Colors.grey),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),

        // Tabla horizontalmente desplazable.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).primaryColor.withOpacity(0.05),
            ),
            headingRowHeight: 56,
            dataRowMaxHeight: 88,
            dataRowMinHeight: 70,
            columns: [
              const DataColumn(
                label: Text(
                  'Hora',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...dias.map((dia) => DataColumn(label: Text(dia))),
            ],
            rows: horas.map((hora) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      hora,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...dias.map((dia) {
                    final clase = horarioFijo[hora]?[dia];
                    final disponible = disponibilidad[hora]?[dia] ?? false;

                    if (clase != null && clase.isNotEmpty) {
                      return DataCell(_buildClaseCell(clase));
                    } else if (disponible) {
                      return DataCell(
                        Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Disponible',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .scale(begin: const Offset(0.98, 0.98)),
                      );
                    } else {
                      return const DataCell(SizedBox.shrink());
                    }
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
