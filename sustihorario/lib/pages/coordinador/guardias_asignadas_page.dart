import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sustihorario/services/guardias_service.dart';

// Página dedicada a mostrar y gestionar las guardias asignadas en el centro.
// Definición de clase que extiende StatefulWidget, utilizando POO en Dart
class GuardiasAsignadasPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key', usando parámetros nombrados
  const GuardiasAsignadasPage({super.key});

  @override
  // Método que crea el estado asociado, sobrescribiendo un método de la clase padre
  State<GuardiasAsignadasPage> createState() => _GuardiasAsignadasPageState();
}

// Clase privada que extiende State, utilizando herencia y POO
class _GuardiasAsignadasPageState extends State<GuardiasAsignadasPage> {
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
    // Retorna un valor de un Map, con cast a String? .
    return doc.data()?['centroId'] as String?;
  }

  // Función asíncrona para reiniciar todas las guardias, usando async/await.
  Future<void> _reiniciarGuardias() async {
    // Await para mostrar diálogo de confirmación.
    final ok = await showDialog<bool>(
      context: context, // Parámetro nombrado
      builder: (_) => AlertDialog(
        // Función anónima
        title: const Text('¿Reiniciar Guardias?'), // Constant
        content: const Text(
          'Esto borrará todas las guardias asignadas en el centro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Arrow function
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Arrow function.
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    // Control de flujo if, verifica si ok no es true
    if (ok != true) return;
    // Await para obtener centroId.
    final centroId = await _getCurrentCentroId();
    // If con null check.
    if (centroId == null) return;

    // Bloque try-catch para manejo de errores
    try {
      // Variable para batch de operaciones.
      final batch = FirebaseFirestore.instance.batch();
      // Await para obtener documentos de guardias.
      final guardias = await FirebaseFirestore.instance
          .collection('guardias')
          .where('centroId', isEqualTo: centroId)
          .get();
      // Bucle for-in para recorrer lista
      for (var doc in guardias.docs) batch.delete(doc.reference);
      // Await para commit del batch.
      await batch.commit();
      // If para verificar si el widget está montado.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guardias reiniciadas')));
      }
    } catch (e) {
      // If mounted, muestra mensaje de error con interpolación
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al reiniciar: $e')));
      }
    }
  }

  // Función asíncrona para reasignar una guardia a otro profesor.
  // Ahora busca primero en 'users' para obtener el nombre y luego el horario individual.
  Future<void> _reasignarGuardia(
    String guardiaId,
    String dia,
    String hora,
  ) async {
    // Await para obtener centroId.
    final centroId = await _getCurrentCentroId();
    // Control de flujo if.
    if (centroId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Centro no encontrado')),
      );
      return;
    }

    // 1. Obtenemos los usuarios del centro que son profesores.
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('centroId', isEqualTo: centroId)
        .where('role', isEqualTo: 'profesor')
        .get();

    // Map para almacenar profesores disponibles (Nombre -> UID)
    Map<String, String> disponibles = {};

    // 2. Iteramos por cada usuario para verificar su disponibilidad individual.
    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final uid = userDoc.id;

      // Obtenemos el nombre desde la colección 'users', no 'horarios'.
      final nombre = userData['nombre'] as String? ?? 'Profesor $uid';

      // Consultamos el horario específico de este profesor
      final horarioDoc = await FirebaseFirestore.instance
          .collection('horarios')
          .doc(uid)
          .get();

      if (!horarioDoc.exists) continue;

      final horarioData = horarioDoc.data()!;

      // Verificamos disponibilidad
      final disp = horarioData['disponibilidad'] as Map<String, dynamic>? ?? {};
      final horaMap = disp[hora] as Map<String, dynamic>? ?? {};

      // Si el profesor está marcado como 'true' (disponible) en ese día y hora
      if (horaMap[dia] == true) {
        disponibles[nombre] = uid;
      }
    }

    // Await para mostrar diálogo con selector.
    String? nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) {
        String? seleccionado;
        return AlertDialog(
          title: const Text('Reasignar Guardia'),
          content: DropdownButtonFormField<String>(
            hint: const Text('Selecciona nuevo sustituto'),
            // Convertimos claves del Map a lista de items
            items: disponibles.keys
                .map((prof) => DropdownMenuItem(value: prof, child: Text(prof)))
                .toList(),
            onChanged: (value) => seleccionado = value, // Función anónima.
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

    // Si no se seleccionó nada, salimos.
    if (nuevoNombre == null) return;

    // Obtenemos el uid del profesor seleccionado.
    final nuevoUid = disponibles[nuevoNombre]!;

    try {
      // Usamos el servicio centralizado para reasignar
      await GuardiasService.reasignarGuardia(
        guardiaId: guardiaId,
        sustitutoUid: nuevoUid,
        sustitutoNombre: nuevoNombre,
        tipo: 'Manual (Coordinador)',
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
        ).showSnackBar(SnackBar(content: Text('Error al reasignar: $e')));
      }
    }
  }

  // Función generadora que retorna un Stream de guardias (asincronía con yield*).
  Stream<QuerySnapshot> _getGuardiasStream() async* {
    final centroId = await _getCurrentCentroId();
    if (centroId == null) yield* Stream.empty();
    yield* FirebaseFirestore.instance
        .collection('guardias')
        .where('centroId', isEqualTo: centroId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  // Método sobrescrito build, que retorna un Widget (herencia).
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Guardias Asignadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange, size: 22),
              tooltip: 'Reiniciar todas las guardias',
              onPressed:
                  _reiniciarGuardias, // Asignación de función como closure
            ),
          ],
        ),
        const SizedBox(height: 12),
        // StreamBuilder para mostrar datos en tiempo real.
        StreamBuilder<QuerySnapshot>(
          stream: _getGuardiasStream(),
          builder: (context, snapshot) {
            // Control de flujo para estado de conexión.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // If para errores.
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            // Lista de documentos
            final guardias = snapshot.data?.docs ?? [];
            // If para lista vacía.
            if (guardias.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No hay guardias asignadas aún')),
              );
            }
            // ListView.builder para mostrar cada guardia.
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: guardias.length,
              itemBuilder: (context, index) {
                final doc = guardias[index];
                // Map de datos
                final data = doc.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                                    '${data['dia'] ?? '—'} • ${data['hora'] ?? '—'}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // Condicional con if para mostrar fecha
                                  if (data['fecha'] != null)
                                    Builder(
                                      builder: (context) {
                                        try {
                                          DateTime dateToShow;
                                          // Control de flujo if para tipo de fecha.
                                          if (data['fecha'] is Timestamp) {
                                            dateToShow =
                                                (data['fecha'] as Timestamp)
                                                    .toDate();
                                          } else {
                                            dateToShow = DateFormat(
                                              'dd/MM/yyyy',
                                            ).parse(data['fecha'].toString());
                                          }
                                          return Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(dateToShow),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        } catch (e) {
                                          // En caso de error mostramos el valor original.
                                          return Text(
                                            data['fecha'].toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                            // Condicional para mostrar tipo de guardia.
                            if (data['tipo'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      data['tipo'].toString().contains(
                                        'Automática',
                                      )
                                      ? Colors.blueGrey[700]
                                      : Colors.grey[500],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  data['tipo'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _infoLine('Asignatura', data['asignatura'] ?? '—'),
                        _infoLine('Curso', data['curso'] ?? '—'),
                        _infoLine('Aula', data['aula'] ?? '—'),
                        const Divider(height: 24),
                        _infoLine(
                          'Ausente',
                          data['profesorAusenteNombre'] ?? '—',
                        ),
                        Row(
                          children: [
                            const Text(
                              'Sustituto: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            // Condicional con operador && y ! para null safety.
                            if (data['sustitutoUid'] != null &&
                                data['sustitutoUid']!.isNotEmpty)
                              Text(data['sustitutoNombre'] ?? '—')
                            else
                              _buildPendienteBadge(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Reasignar'),
                            onPressed: () => _reasignarGuardia(
                              doc.id,
                              data['dia'] as String? ?? '',
                              data['hora'] as String? ?? '',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange[700],
                              side: BorderSide(color: Colors.deepOrange[700]!),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Función que construye un badge indicando que está pendiente.
  Widget _buildPendienteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 4),
          Text(
            'PENDIENTE',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Función auxiliar para mostrar líneas de información.
  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
