import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sustihorario/services/guardias_service.dart';

// Definición de una clase que extiende StatefulWidget, utilizando POO en Dart
// Esta clase representa una página para mostrar y gestionar bajas pendientes.
class BajasPendientesPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key', usando parámetros nombrados
  const BajasPendientesPage({super.key});

  @override
  // Método que crea el estado asociado, sobrescribiendo un método de la clase padre
  State<BajasPendientesPage> createState() => _BajasPendientesPageState();
}

// Clase privada que extiende State, utilizando herencia y POO
class _BajasPendientesPageState extends State<BajasPendientesPage> {
  // Declaración de variable con null safety, tipo inferido como User?
  final User? user = FirebaseAuth.instance.currentUser;

  // Función asíncrona que retorna un Future<String?>, usando async/await mencionado en similitudes con JS
  // Obtiene el ID del centro actual del usuario.
  Future<String?> _getCurrentCentroId() async {
    // Control de flujo con if, verifica si user es null usando null safety.
    if (user == null) return null;
    // Await para esperar el resultado de una operación asíncrona.
    final doc = await FirebaseFirestore.instance
        .collection(
          'users',
        ) // Uso de colecciones (similar a Maps o Lists, sección 5.1).
        .doc(user!.uid) // Acceso seguro con ! (null safety).
        .get();
    // Retorna un valor de un Map , con cast a String? .
    return doc.data()?['centroId'] as String?;
  }

  // Función asíncrona para reiniciar bajas y guardias, usando async/await.
  Future<void> _reiniciarTodo() async {
    // Muestra un diálogo y espera confirmación, usando await.
    final ok = await showDialog<bool>(
      context: context, // Parámetro nombrado
      builder: (_) => AlertDialog(
        // Función anónima
        title: const Text('¿Reiniciar?'), // Constante
        content: const Text(
          'Esto borrará todas las guardias y bajas del centro.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false), // Navigator function
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true), // Navigator function.
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    // Control de flujo if, verifica si ok no es true usando operadores
    if (ok != true) return;
    // Await para obtener centroId.
    final centroId = await _getCurrentCentroId();
    // If con null check.
    if (centroId == null) return;
    // Variable para batch de operaciones.
    final batch = FirebaseFirestore.instance.batch();
    // Await para obtener documentos de guardias
    final guardias = await FirebaseFirestore.instance
        .collection('guardias')
        .where('centroId', isEqualTo: centroId)
        .get();
    // Await similar para bajas.
    final bajas = await FirebaseFirestore.instance
        .collection('bajas')
        .where('centroId', isEqualTo: centroId)
        .get();
    // Bucle for-in para recorrer listas
    for (var doc in guardias.docs) batch.delete(doc.reference);
    // Bucle similar para bajas.
    for (var doc in bajas.docs) batch.delete(doc.reference);
    // Await para commit del batch.
    await batch.commit();
    // If para verificar si el widget está montado.
    if (mounted) {
      // Muestra un mensaje usando ScaffoldMessenger.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reiniciado')));
    }
  }

  // Utiliza showDialog para confirmación y delete de Firestore.
  Future<void> _eliminarBaja(String docId, String profesorNombre) async {
    // Diálogo de confirmación (Control de flujo asíncrono)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar baja?'),
        content: Text(
          '¿Seguro que quieres eliminar la solicitud de $profesorNombre?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Operación de eliminación en Firestore
        await FirebaseFirestore.instance
            .collection('bajas')
            .doc(docId)
            .delete();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Baja eliminada')));
      } catch (e) {
        // Manejo de errores
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Permite asignar una guardia manualmente desde esta pantalla.
  Future<void> _reasignarGuardia(
    String guardiaId,
    String dia,
    String hora,
  ) async {
    final centroId = await _getCurrentCentroId();
    if (centroId == null) return;

    // 1. Buscamos profesores disponibles
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('centroId', isEqualTo: centroId)
        .where('role', isEqualTo: 'profesor')
        .get();

    Map<String, String> disponibles = {};

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final uid = userDoc.id;
      final nombre = userData['nombre'] as String? ?? 'Profesor $uid';

      final horarioDoc = await FirebaseFirestore.instance
          .collection('horarios')
          .doc(uid)
          .get();

      if (!horarioDoc.exists) continue;

      final disp =
          horarioDoc.data()?['disponibilidad'] as Map<String, dynamic>? ?? {};
      final horaMap = disp[hora] as Map<String, dynamic>? ?? {};

      if (horaMap[dia] == true) {
        disponibles[nombre] = uid;
      }
    }

    if (disponibles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay profesores disponibles en este horario'),
          ),
        );
      }
      return;
    }

    // selector
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) {
        String? seleccionado;
        return AlertDialog(
          title: const Text('Asignar Guardia Manualmente'),
          content: DropdownButtonFormField<String>(
            hint: const Text('Selecciona sustituto'),
            items: disponibles.keys
                .map((prof) => DropdownMenuItem(value: prof, child: Text(prof)))
                .toList(),
            onChanged: (value) => seleccionado = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, seleccionado),
              child: const Text('Asignar'),
            ),
          ],
        );
      },
    );

    if (nuevoNombre != null) {
      try {
        await GuardiasService.reasignarGuardia(
          guardiaId: guardiaId,
          sustitutoUid: disponibles[nuevoNombre]!,
          sustitutoNombre: nuevoNombre,
          tipo: 'Manual (Desde Bajas)',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Guardia asignada a $nuevoNombre')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  // Método sobrescrito build, que retorna un Widget (herencia).
  Widget build(BuildContext context) {
    // Retorna una Column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Parámetros nombrados.
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bajas Pendientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red, size: 22),
              tooltip: 'Reiniciar todo',
              onPressed: _reiniciarTodo, // Asignación de función como closure
            ),
          ],
        ),
        const SizedBox(height: 12),
        // FutureBuilder para manejar Future (asincronía).
        FutureBuilder<String?>(
          future: _getCurrentCentroId(),
          builder: (context, idSnapshot) {
            // Función anónima con parámetros.
            // Control de flujo if para estado de conexión.
            if (idSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Variable con null safety.
            final centroId = idSnapshot.data;
            // If para error si null.
            if (centroId == null) {
              return const Text('Error: Centro no encontrado');
            }
            // StreamBuilder para flujo de datos en tiempo real.
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bajas')
                  .where('estado', isEqualTo: 'pendiente')
                  .where('centroId', isEqualTo: centroId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // If para error.
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                // If para datos no disponibles.
                if (!snapshot.hasData) return const CircularProgressIndicator();
                // Lista de documentos (colección List, sección 5.1).
                final bajas = snapshot.data!.docs;
                // If para lista vacía.
                if (bajas.isEmpty) {
                  return const Text('No hay bajas pendientes');
                }
                // LayoutBuilder para responsive.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Variable bool usando operadores
                    final isMobile = constraints.maxWidth < 800;
                    // If para mobile.
                    if (isMobile) {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bajas.length,
                        itemBuilder: (context, i) {
                          // Función anónima.
                          // Map de datos
                          final data = bajas[i].data() as Map<String, dynamic>;
                          // Llamada a función auxiliar pasando el documento para obtener el ID
                          return _buildBajaCard(bajas[i], data);
                        },
                      );
                    } else {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            // Lista constante
                            DataColumn(label: Text('Profesor')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Inicio')),
                            DataColumn(label: Text('Fin')),
                            DataColumn(label: Text('Horas')),
                            DataColumn(label: Text('Acciones')),
                          ],
                          rows: bajas.map((doc) {
                            // Método map en List
                            final data = doc.data() as Map<String, dynamic>;
                            return DataRow(
                              cells: [
                                // Lista de celdas.
                                DataCell(
                                  Text(data['profesorNombre'] ?? '-'),
                                ), // Operador ??
                                DataCell(Text(data['tipo'] ?? '-')),
                                DataCell(
                                  Text(
                                    data['fechaInicio'] != null
                                        ? DateFormat('dd/MM/yyyy').format(
                                            (data['fechaInicio'] as Timestamp)
                                                .toDate(),
                                          )
                                        : '-', // Operador ternario
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    data['fechaFin'] != null
                                        ? DateFormat('dd/MM/yyyy').format(
                                            (data['fechaFin'] as Timestamp)
                                                .toDate(),
                                          )
                                        : '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (data['horasAfectadas'] as List?)?.length
                                            .toString() ??
                                        '0', // Null-aware y ?? .
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        onPressed: () => _eliminarBaja(
                                          doc.id,
                                          data['profesorNombre'] ?? '',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(), // Convierte Iterable a List.
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Función que construye un Widget para cada baja, usando parámetros posicionales
  // Actualizado para recibir el DocumentSnapshot y poder manejar acciones
  Widget _buildBajaCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Profesor: ${data['profesorNombre'] ?? 'Profesor'}', // Interpolación de strings
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Iconos de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () =>
                          _eliminarBaja(doc.id, data['profesorNombre'] ?? ''),
                      tooltip: 'Eliminar baja',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Motivo: ${data['tipo'] ?? '-'}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Inicio: ${data['fechaInicio'] != null ? DateFormat('dd/MM/yyyy').format((data['fechaInicio'] as Timestamp).toDate()) : '-'}',
                ),
                const SizedBox(width: 16),
                Text(
                  'Fin: ${data['fechaFin'] != null ? DateFormat('dd/MM/yyyy').format((data['fechaFin'] as Timestamp).toDate()) : '-'}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Horas: ${(data['horasAfectadas'] as List?)?.length.toString() ?? '0'}',
            ),
            const Divider(),
            // StreamBuilder para mostrar las guardias pendientes de esta baja
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('guardias')
                  .where('bajaId', isEqualTo: doc.id)
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, gSnap) {
                if (!gSnap.hasData || (gSnap.data?.docs.isEmpty ?? true)) {
                  return const SizedBox.shrink();
                }

                final pendientess = gSnap.data!.docs;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guardias Pendientes:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...pendientess.map((g) {
                      final gData = g.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${gData['fecha'] ?? ''} - ${gData['hora'] ?? ''}: ${gData['asignatura'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _reasignarGuardia(
                                g.id,
                                gData['dia'] ?? '',
                                gData['hora'] ?? '',
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Asignar',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
