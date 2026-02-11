import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sustihorario/pages/coordinador/editar_modelo_page.dart';
import '../../models/horario_model.dart'; // Importación del modelo (clase personalizada, sección 6.1 Clases)

// Página dedicada a la gestión de modelos de horarios
// Clase que extiende StatefulWidget, utilizando POO en Dart (sección 6.1 Clases, 6.2 Herencia)
class ModelosHorarioPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key' (sección 4.1 Parámetros nombrados)
  const ModelosHorarioPage({super.key});

  @override
  // Método que crea el estado asociado, usando arrow function (sección 4.3)
  State<ModelosHorarioPage> createState() => _ModelosHorarioPageState();
}

// Clase privada que extiende State, utilizando herencia (sección 6.2)
class _ModelosHorarioPageState extends State<ModelosHorarioPage> {
  // Variable con null safety para el usuario actual (sección 5.2 Null Safety)
  final User? user = FirebaseAuth.instance.currentUser;
  // Variable nullable para almacenar el ID del centro (sección 5.2 Null Safety)
  String? centroId;

  // Variable para controlar si estamos actualizando (evitar múltiples pulsaciones rápidas)
  bool _isRefreshing = false;

  @override
  // Método sobrescrito initState (herencia, sección 6.2)
  void initState() {
    super.initState();
    _getCentroId(); // Llamada a función asíncrona al iniciar la página
  }

  // Función asíncrona para obtener el ID del centro del usuario logueado
  Future<void> _getCentroId() async {
    // Control de flujo if (sección 3.3)
    if (user != null) {
      // Await para esperar el resultado de la consulta a Firestore
      final doc = await FirebaseFirestore.instance
          .collection(
            'users',
          ) // Uso de colecciones (similar a Maps o Lists, sección 5.1)
          .doc(user!.uid) // Acceso seguro con ! (null safety, sección 5.2)
          .get();
      // Actualización del estado con setState (función anónima, sección 4.2)
      setState(() {
        centroId = doc.data()?['centroId'] as String?;
      });
    }
  }

  // Función asíncrona para forzar la actualización del horario de TODOS los profesores asignados
  Future<void> _refreshAllAssignedTeachers() async {
    // Evitamos múltiples pulsaciones simultáneas
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // 1. Buscamos todos los modelos que estén asignados a algún profesor
      final modelosSnap = await FirebaseFirestore.instance
          .collection('horarioModelos')
          .where('centroId', isEqualTo: centroId)
          .where('asignadoA', isNotEqualTo: null) // Solo los asignados
          .get();

      if (modelosSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay modelos asignados para refrescar'),
            ),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      // 2. Para cada modelo asignado, actualizamos el campo 'updatedAt' del profesor
      for (var doc in modelosSnap.docs) {
        final modeloData = doc.data() as Map<String, dynamic>; // Cast añadido
        final profesorUid = modeloData['asignadoA'] as String?;

        if (profesorUid != null && profesorUid.isNotEmpty) {
          final horarioRef = FirebaseFirestore.instance
              .collection('horarios')
              .doc(profesorUid);

          batch.update(horarioRef, {'updatedAt': FieldValue.serverTimestamp()});
        }
      }

      // 3. Ejecutamos todas las actualizaciones en una sola operación atómica
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horarios de profesores actualizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al refrescar horarios: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Control de flujo: si aún no se ha obtenido el centroId, mostramos indicador de carga
    if (centroId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con título, botón de creación y botón de refrescar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Modelos de Horario',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                // Botón de refrescar horarios de profesores asignados
                IconButton(
                  onPressed: _isRefreshing ? null : _refreshAllAssignedTeachers,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.indigo),
                  tooltip: 'Refrescar horarios de profesores asignados',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _navToEditor(context), // Arrow function (sección 4.3)
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Modelo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // StreamBuilder para mostrar lista de modelos en tiempo real (sección 5.1 Colecciones)
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('horarioModelos')
              .where('centroId', isEqualTo: centroId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Control de flujo para errores
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            // Indicador mientras se cargan los datos
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            // Lista de documentos obtenidos
            final models = snapshot.data!.docs;

            // Caso lista vacía
            if (models.isEmpty) {
              return const Center(child: Text('No hay modelos creados aún.'));
            }

            // ListView.builder para mostrar cada modelo (sección 5.1 List)
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              itemBuilder: (context, index) {
                final doc = models[index];
                // Conversión de Map a objeto personalizado (clase HorarioModelo, sección 6.1)
                final modelo = HorarioModelo.fromJson(
                  doc.data() as Map<String, dynamic>, // Cast añadido
                  doc.id,
                );
                return _buildModelCard(
                  context,
                  modelo,
                ); // Llamada a función auxiliar
              },
            );
          },
        ),
      ],
    );
  }

  // Función auxiliar que construye la tarjeta visual de cada modelo
  Widget _buildModelCard(BuildContext context, HorarioModelo modelo) {
    // Variable local bool (sección 3.1 Tipos básicos)
    final bool isAssigned = modelo.asignadoA != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelo.nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Horas definidas: ${modelo.horas.length}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _navToEditor(context, modelo: modelo),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                    // Control de flujo condicional con operador spread (...) (sección 3.3)
                    if (!isAssigned) ...[
                      ElevatedButton.icon(
                        onPressed: () => _asignarProfesor(context, modelo),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Asignar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _eliminarModelo(context, modelo),
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Eliminar Modelo',
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: () => _desasignarProfesor(context, modelo),
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: const Text('Liberar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            // Condicional para mostrar estado de asignación
            if (isAssigned) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Asignado a: ${modelo.asignadoNombre}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Sin asignar',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Función asíncrona para mostrar diálogo y seleccionar profesor para asignar
  // Actualizado: Filtra por role == 'profesor' y excluye horarios ya asignados
  Future<void> _asignarProfesor(
    BuildContext context,
    HorarioModelo modelo,
  ) async {
    // 1. Obtenemos lista de usuarios del centro filtrando por 'profesor'
    final profesoresSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('centroId', isEqualTo: centroId)
        .where(
          'role',
          isEqualTo: 'profesor',
        ) // ← Solo profesores (excluye coordinador)
        .get();

    if (profesoresSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay profesores disponibles en este centro'),
        ),
      );
      return;
    }

    // 2. Filtrar profesores SIN horario asignado
    List<QueryDocumentSnapshot> profesoresDisponibles = [];
    for (var profDoc in profesoresSnap.docs) {
      final horarioDoc = await FirebaseFirestore.instance
          .collection('horarios')
          .doc(profDoc.id)
          .get();
      // Cast necesario para acceder a los datos del mapa
      final horarioData = horarioDoc.data() as Map<String, dynamic>?;
      final modeloAsignado = horarioData?['modeloAsignadoId'] as String?;
      if (modeloAsignado == null || modeloAsignado.isEmpty) {
        profesoresDisponibles.add(profDoc);
      }
    }

    if (profesoresDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los profesores ya tienen horario asignado'),
        ),
      );
      return;
    }

    String? selectedUid;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asignar Modelo a Profesor'),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Seleccionar Profesor'),
          items: profesoresDisponibles.map((doc) {
            // CORRECCIÓN AQUÍ: Hacemos cast explícito a Map antes de acceder a ['nombre']
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['nombre'] ?? 'Sin nombre'),
            );
          }).toList(),
          onChanged: (val) => selectedUid = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (selectedUid != null) {
                Navigator.pop(ctx);
                // Pasamos la lista filtrada
                await _confirmarAsignacion(
                  modelo,
                  selectedUid!,
                  profesoresDisponibles,
                );
              }
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }

  // Función asíncrona que realiza la asignación usando batch (operaciones atómicas)
  Future<void> _confirmarAsignacion(
    HorarioModelo modelo,
    String profUid,
    List<QueryDocumentSnapshot> profList,
  ) async {
    // Buscamos el documento dentro de la lista
    final docFound = profList.firstWhere((doc) => doc.id == profUid);
    // CORRECCIÓN AQUÍ: Hacemos cast explícito a Map<String, dynamic>
    final profData = docFound.data() as Map<String, dynamic>;

    final profNombre = profData['nombre'] as String?;

    // Copias de mapas para horario fijo y disponibilidad (sección 5.1 Maps)
    Map<String, Map<String, String>> horarioFijoCopia = {};
    Map<String, Map<String, bool>> disponibilidadCopia = {};

    // Recorrido de mapa con forEach (método útil de colecciones, sección 5.1)
    modelo.slots.forEach((hora, diasMap) {
      horarioFijoCopia.putIfAbsent(hora, () => {});
      disponibilidadCopia.putIfAbsent(hora, () => {});
      diasMap.forEach((dia, slot) {
        if (slot.estado == EstadoSlot.fijo &&
            slot.clase != null &&
            slot.clase!.isNotEmpty) {
          horarioFijoCopia[hora]![dia] = slot.clase!;
        } else if (slot.estado == EstadoSlot.guardia) {
          disponibilidadCopia[hora]![dia] = true;
        }
      });
    });

    final batch = FirebaseFirestore.instance.batch();

    // Actualizamos modelo con datos de asignación
    final modeloRef = FirebaseFirestore.instance
        .collection('horarioModelos')
        .doc(modelo.id);
    batch.update(modeloRef, {
      'asignadoA': profUid,
      'asignadoNombre': profNombre,
      'asignadoAt': FieldValue.serverTimestamp(),
    });

    // Actualizamos/establecemos horario del profesor
    final horarioRef = FirebaseFirestore.instance
        .collection('horarios')
        .doc(profUid);
    batch.set(horarioRef, {
      'modeloAsignadoId': modelo.id,
      'horarioFijo': horarioFijoCopia,
      'disponibilidad': disponibilidadCopia,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Modelo asignado a $profNombre')));
    }
  }

  // Función asíncrona para desasignar modelo de profesor
  Future<void> _desasignarProfesor(
    BuildContext context,
    HorarioModelo modelo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Liberar Modelo?'),
        content: const Text(
          'El profesor dejará de tener este horario asignado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // Limpiamos campos de asignación en el modelo
        final modeloRef = FirebaseFirestore.instance
            .collection('horarioModelos')
            .doc(modelo.id);
        batch.update(modeloRef, {
          'asignadoA': null,
          'asignadoNombre': null,
          'asignadoAt': null,
        });

        // Si había profesor asignado, limpiamos su horario
        if (modelo.asignadoA != null) {
          final horarioRef = FirebaseFirestore.instance
              .collection('horarios')
              .doc(modelo.asignadoA!);
          batch.update(horarioRef, {
            'modeloAsignadoId': null,
            'horarioFijo': FieldValue.delete(),
            'disponibilidad': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      } catch (e) {
        print("Error al desasignar: $e");
      }
    }
  }

  // Función asíncrona para eliminar modelo (solo si no está asignado)
  Future<void> _eliminarModelo(
    BuildContext context,
    HorarioModelo modelo,
  ) async {
    // Validación antes de proceder
    if (modelo.asignadoA != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar. El modelo está asignado a un profesor. '
            'Primero debes liberar al profesor.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Modelo?'),
        content: const Text('Esta acción borrará el modelo permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('horarioModelos')
            .doc(modelo.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Modelo eliminado')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  // Función para navegar a la página de edición/creación
  void _navToEditor(BuildContext context, {HorarioModelo? modelo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditarModeloPage(
          centroId: centroId!,
          userUid: user!.uid,
          modeloExistente: modelo,
        ),
      ),
    );
  }
}
