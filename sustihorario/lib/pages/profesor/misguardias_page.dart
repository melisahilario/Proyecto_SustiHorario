import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sustihorario/services/guardias_service.dart';
import 'package:sustihorario/services/calendario_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Página dedicada a mostrar las guardias asignadas al profesor.
// Clase que extiende StatefulWidget, utilizando POO en Dart
class MisGuardiasPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key'
  const MisGuardiasPage({super.key});

  @override
  // Método que crea el estado asociado ç
  State<MisGuardiasPage> createState() => _MisGuardiasPageState();
}

// Clase privada que extiende State, utilizando herencia
class _MisGuardiasPageState extends State<MisGuardiasPage> {
  // Variable para mostrar el nombre del profesor (inicializada con valor por defecto).
  String nombreProfesor = 'Cargando...';

  // Variable con null safety para el usuario autenticado .
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  // Método sobrescrito initState
  void initState() {
    super.initState();
    _cargarNombre(); // Carga del nombre del profesor al iniciar.
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
      if (doc.exists) {
        final nombre = doc.data()?['nombre'] as String?;
        setState(() {
          nombreProfesor = nombre ?? 'Usuario';
        });
      } else {
        setState(() => nombreProfesor = 'Usuario');
      }
    } catch (e) {
      // En caso de error, mostramos mensaje en consola y valor por defecto.
      print('Error cargando nombre: $e');
      setState(() => nombreProfesor = 'Usuario');
    }
  }

  @override
  // Método principal que construye la interfaz (herencia).
  Widget build(BuildContext context) {
    // Caso especial: usuario no autenticado.
    if (user == null) {
      return const Center(child: Text('No autenticado'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con título e icono.
        Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.indigo[400], size: 28),
            const SizedBox(width: 12),
            Text(
              'Mis Guardias Asignadas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
        const SizedBox(height: 8),
        const Text(
          'Historial de misiones y coberturas tácticas.',
          style: TextStyle(color: Colors.grey),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 20),

        // StreamBuilder para obtener las guardias asignadas al profesor en tiempo real.
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('guardias')
              .where(
                'sustitutoUid',
                isEqualTo: user!.uid,
              ) // Filtro por uid del profesor.
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Control de flujo para errores.
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            // Indicador de carga mientras se obtienen los datos.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Convertimos los documentos a una lista de Maps y añadimos el id.
            final guardias = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; // Guardamos el ID del documento.
              return data;
            }).toList();

            // Ordenamos la lista manualmente por fecha y hora (ya que orderBy solo ordena por createdAt).
            guardias.sort((a, b) {
              // Parseamos las fechas (formato 'dd/MM/yyyy').
              DateTime dateA = DateFormat(
                'dd/MM/yyyy',
              ).parse(a['fecha'] ?? '01/01/1970');
              DateTime dateB = DateFormat(
                'dd/MM/yyyy',
              ).parse(b['fecha'] ?? '01/01/1970');

              int dateCompare = dateA.compareTo(dateB);
              if (dateCompare != 0) return dateCompare;

              // Si la fecha es la misma, ordenamos por hora.
              String horaA = a['hora'] ?? '';
              String horaB = b['hora'] ?? '';

              // Tomamos solo la parte inicial de la hora si tiene formato rango (ej: 08:00-09:00).
              String horaInicioA = horaA.contains('/')
                  ? horaA.split('/').first
                  : horaA;
              String horaInicioB = horaB.contains('/')
                  ? horaB.split('/').first
                  : horaB;

              return horaInicioA.compareTo(horaInicioB);
            });

            // Caso sin guardias asignadas.
            if (guardias.isEmpty) {
              return const Center(
                child: Text('No tienes guardias asignadas aún'),
              );
            }

            // Widget responsive según ancho disponible.
            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 700;

                if (isMobile) {
                  // Vista móvil: lista de tarjetas.
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: guardias.length,
                    itemBuilder: (context, index) {
                      final guardia = guardias[index];
                      return Semantics(
                        button: true,
                        label: 'Guardia el día ${guardia['dia']}',
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha: ${guardia['fecha'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Día: ${guardia['dia'] ?? '-'} • Hora: ${guardia['hora'] ?? '-'}',
                                ),
                                Text(
                                  'Aula: ${guardia['aula'] ?? '-'} • Curso: ${guardia['curso'] ?? '-'}',
                                ),
                                Text(
                                  'Asignatura: ${guardia['asignatura'] ?? '-'}',
                                ),
                                Text(
                                  'Profesor Ausente: ${guardia['profesorAusenteNombre'] ?? '-'}',
                                ),
                                Row(
                                  children: [
                                    // Badge de tipo con operador ternario.
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: guardia['tipo'] == 'Automática'
                                            ? Colors.black
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        guardia['tipo'] ?? 'Manual',
                                        style: TextStyle(
                                          color: guardia['tipo'] == 'Automática'
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (guardia['estado'] == 'asignada')
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _ofrecerIntercambio(guardia['id']),
                                        icon: const Icon(
                                          Icons.swap_horiz,
                                          size: 16,
                                        ),
                                        label: const Text('INTERCAMBIAR'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                        ),
                                      ),
                                    if (guardia['estado'] == 'en_intercambio')
                                      const Text(
                                        'EN MERCADO',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    const Spacer(),
                                    // Botón para ver tareas si existen.
                                    if (guardia['tareas'] != null &&
                                        guardia['tareas'].toString().isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(guardia['tareas']),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.visibility,
                                          size: 16,
                                        ),
                                        label: const Text('Ver tareas'),
                                      )
                                    else
                                      const Text(
                                        'Sin tareas',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () =>
                                          _sincronizarConCalendario(guardia),
                                      icon: const Icon(
                                        Icons.event,
                                        color: Colors.blue,
                                      ),
                                      tooltip: 'Sincronizar con Calendario',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 400.ms);
                } else {
                  // Vista escritorio/tablet: DataTable con scroll horizontal.
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child:
                        DataTable(
                              columnSpacing: 16,
                              headingRowHeight: 40,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 80,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Fecha',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Día',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Hora',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Aula',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Curso',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Asignatura',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Profesor Ausente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tipo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tareas',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Acciones',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              rows: guardias.map((guardia) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(guardia['fecha'] ?? '-')),
                                    DataCell(Text(guardia['dia'] ?? '-')),
                                    DataCell(Text(guardia['hora'] ?? '-')),
                                    DataCell(Text(guardia['aula'] ?? '-')),
                                    DataCell(Text(guardia['curso'] ?? '-')),
                                    DataCell(
                                      Text(guardia['asignatura'] ?? '-'),
                                    ),
                                    DataCell(
                                      Text(
                                        guardia['profesorAusenteNombre'] ?? '-',
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: guardia['tipo'] == 'Automática'
                                              ? Colors.black
                                              : Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          guardia['tipo'] ?? 'Manual',
                                          style: TextStyle(
                                            color:
                                                guardia['tipo'] == 'Automática'
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      guardia['tareas'] != null &&
                                              guardia['tareas']
                                                  .toString()
                                                  .isNotEmpty
                                          ? Row(
                                              children: [
                                                const Icon(
                                                  Icons.description,
                                                  size: 18,
                                                  color: Colors.indigo,
                                                ),
                                                const SizedBox(width: 6),
                                                TextButton.icon(
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          guardia['tareas'],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.visibility,
                                                    size: 16,
                                                  ),
                                                  label: const Text('Ver'),
                                                ),
                                              ],
                                            )
                                          : const Text(
                                              'Sin tareas',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          guardia['estado'] == 'asignada'
                                              ? ElevatedButton(
                                                  onPressed: () =>
                                                      _ofrecerIntercambio(
                                                        guardia['id'],
                                                      ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.orange,
                                                      ),
                                                  child: const Text(
                                                    'OFRECER',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                )
                                              : guardia['estado'] ==
                                                    'en_intercambio'
                                              ? const Text(
                                                  'EN MERCADO',
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.event,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _sincronizarConCalendario(
                                                  guardia,
                                                ),
                                            tooltip: 'Sincronizar',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            )
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .scale(begin: const Offset(0.98, 0.98)),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _sincronizarConCalendario(Map<String, dynamic> guardia) async {
    final success = await CalendarioService.agregarGuardiaAlCalendario(
      titulo: 'Guardia: ${guardia['asignatura']}',
      descripcion:
          'Guardia de ${guardia['hora']} en el aula ${guardia['aula']}. '
          'Profesor ausente: ${guardia['profesorAusenteNombre']}',
      fechaStr: guardia['fecha'] ?? '',
      horaStr: guardia['hora'] ?? '',
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronizado con éxito con tu calendario local'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al sincronizar o permisos denegados'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _ofrecerIntercambio(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ofrecer Intercambio'),
        content: const Text(
          '¿Estás seguro de poner esta guardia en el mercado de intercambio?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÍ, OFRECER'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await GuardiasService.ofrecerParaIntercambio(guardiaId: id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardia puesta en el mercado'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
