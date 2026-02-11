import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Página dedicada a mostrar la lista de usuarios del centro.
// Clase que extiende StatefulWidget, utilizando POO en Dart
class UsuariosPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key'
  const UsuariosPage({super.key});

  @override
  // Método que crea el estado asociado, usando arrow function
  State<UsuariosPage> createState() => _UsuariosPageState();
}

// Clase privada que extiende State, utilizando herencia
class _UsuariosPageState extends State<UsuariosPage> {
  // Variable con null safety para el usuario actual
  final User? user = FirebaseAuth.instance.currentUser;

  // Función asíncrona que obtiene el ID del centro del usuario logueado (async/await).
  Future<String?> _getCurrentCentroId() async {
    // Control de flujo con if (sección 3.3).
    if (user == null) return null;

    // Await para esperar la respuesta de Firestore.
    final doc = await FirebaseFirestore.instance
        .collection('users') // Colección similar a Map/List
        .doc(user!.uid) // Acceso seguro con ! (null safety).
        .get();

    // Retorno con null safety y casting.
    return doc.data()?['centroId'] as String?;
  }

  // Función asíncrona para eliminar un usuario (con confirmación).
  Future<void> _eliminarUsuario(String uid, String nombre) async {
    // No permitir eliminar al usuario actual (control de flujo).
    if (user?.uid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes eliminar tu propio usuario.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Diálogo de confirmación usando showDialog (await).
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar a $nombre?'), // Interpolación de string.
        content: const Text(
          'Esta acción eliminará al usuario del sistema permanentemente. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Arrow function.
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Solo procedemos si el usuario confirmó (control de flujo if).
    if (confirm == true) {
      try {
        // Eliminación del documento en Firestore.
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();

        // Mensaje de éxito si el widget sigue montado.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$nombre eliminado correctamente')),
          );
        }
      } catch (e) {
        // Manejo de errores con try-catch (control de flujo).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Función auxiliar para obtener estadísticas de sustituciones de un usuario.
  // Consulta la colección 'guardias' filtrando por el campo 'sustitutoUid'.
  Future<Map<String, int>> _getUserStats(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('guardias')
          .where('sustitutoUid', isEqualTo: uid)
          .get();

      // Contamos documentos. Asumimos 1 guardia = 1 hora = 1 clase sustituida.
      final count = snap.docs.length;
      return {'horas': count, 'clases': count};
    } catch (e) {
      // Retorno de valores por defecto en caso de error.
      return {'horas': 0, 'clases': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder para manejar la obtención asíncrona del centroId.
    return FutureBuilder<String?>(
      future: _getCurrentCentroId(),
      builder: (context, snapshot) {
        // Variable local con null safety.
        final centroId = snapshot.data;

        // Mientras se está cargando...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Caso de error: no se obtuvo el centroId.
        if (centroId == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No se pudo cargar el centro ID. Inicia sesión de nuevo.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // StreamBuilder para mostrar la lista de usuarios en tiempo real.
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('centroId', isEqualTo: centroId)
              .snapshots(),
          builder: (context, snap) {
            // Mientras se cargan los datos...
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Caso de error en la consulta.
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            // Si no hay datos o la lista está vacía.
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(
                child: Text('No hay usuarios en este centro'),
              );
            }

            // Lista de documentos usuarios
            final usuarios = snap.data!.docs;

            // ListView.separated para mostrar usuarios con separadores.
            return ListView.separated(
              shrinkWrap: true, // Ajusta altura al contenido.
              physics:
                  const NeverScrollableScrollPhysics(), // No scroll propio.
              itemCount: usuarios.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, i) {
                // Datos de cada usuario como Map
                final data = usuarios[i].data() as Map<String, dynamic>;
                final uid = usuarios[i].id; // ID del documento = uid.

                // Obtenemos rol con operadores null-aware.
                final rol = data['role'] ?? data['rol'] ?? 'desconocido';

                // Determinamos color según rol (operador ternario).
                final color = rol == 'profesor'
                    ? Colors.blue
                    : rol == 'coordinador'
                    ? Colors.purple
                    : Colors.red;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Text(
                              (data['nombre'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(color: color),
                            ),
                          ),
                          title: Text(
                            data['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['email'] ?? '-'),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Rol: ${rol.toUpperCase()}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: uid != user?.uid
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Eliminar usuario',
                                  onPressed: () => _eliminarUsuario(
                                    uid,
                                    data['nombre'] ?? 'Usuario',
                                  ),
                                )
                              : null,
                        ),
                        // Sección de estadísticas: visible solo si el rol es profesor.
                        // Utilizamos un FutureBuilder anidado para calcular las guardias por usuario.
                        if (rol == 'profesor')
                          FutureBuilder<Map<String, int>>(
                            future: _getUserStats(uid),
                            builder: (context, statsSnapshot) {
                              // Indicador de carga pequeño mientras se calculan las stats.
                              if (statsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 20,
                                  child: Center(
                                    child: SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Obtenemos los datos o inicializamos a 0 si hay error.
                              final stats =
                                  statsSnapshot.data ??
                                  {'horas': 0, 'clases': 0};

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    // Icono dinámico: cambia si el profesor tiene muchas horas (>20).
                                    // Mejora visual para identificar carga de trabajo alta.
                                    // Se usa ?? 0 para asegurar que la comparación sea con un int no nulo.
                                    Icon(
                                      (stats['horas'] ?? 0) > 20
                                          ? Icons.warning_amber_rounded
                                          : Icons.history,
                                      size: 16,
                                      color: (stats['horas'] ?? 0) > 20
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sustituciones: ${stats['horas']} horas / ${stats['clases']} clases',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
