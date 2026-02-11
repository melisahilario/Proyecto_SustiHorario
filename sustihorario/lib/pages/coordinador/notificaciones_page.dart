import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Página dedicada a mostrar notificaciones y alertas pendientes para el coordinador.
// Definición de clase que extiende StatefulWidget, utilizando POO en Dart
class NotificacionesPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key', usando parámetros nombrados
  const NotificacionesPage({super.key});

  @override
  // Método que crea el estado asociado, sobrescribiendo un método de la clase padre
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

// Clase privada que extiende State, utilizando herencia  y POO
class _NotificacionesPageState extends State<NotificacionesPage> {
  // Declaración de variable con null safety (sección 5.2 Null Safety), tipo inferido como User?
  final User? user = FirebaseAuth.instance.currentUser;

  // Función asíncrona que retorna un Future<String?>, usando async/await mencionado en similitudes con JS
  // Obtiene el ID del centro actual del usuario.
  Future<String?> _getCurrentCentroId() async {
    // Control de flujo con if, verifica si user es null usando null safety.
    if (user == null) return null;
    // Await para esperar el resultado de una operación asíncrona.
    final doc = await FirebaseFirestore.instance
        .collection('users') // Uso de colecciones
        .doc(user!.uid) // Acceso seguro con ! (null safety).
        .get();
    // Retorna un valor de un Map, con cast a String? .
    return doc.data()?['centroId'] as String?;
  }

  @override
  // Método sobrescrito build, que retorna un Widget (herencia).
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row con título e icono (estructura básica de widgets).
        const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Notificaciones y Alertas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<String?>(
          future: _getCurrentCentroId(),
          builder: (context, idSnapshot) {
            if (idSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final centroId = idSnapshot.data;
            if (centroId == null) {
              return const Text('Error: Centro no encontrado');
            }
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notificaciones')
                  .where(
                    'destinatarioUid',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('leida', isEqualTo: false)
                  .where('centroId', isEqualTo: centroId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final notificaciones = snapshot.data!.docs;
                if (notificaciones.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No tienes notificaciones pendientes.'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notificaciones.length,
                  itemBuilder: (context, index) {
                    final data =
                        notificaciones[index].data() as Map<String, dynamic>;
                    final isUrgente = data['tipo'] == 'guardia_sin_asignar';
                    final isFallback = data['tipo'] == 'guardia_fallback';
                    return Semantics(
                      button: true,
                      label: 'Notificación de ${data['tipo']}',
                      child: Card(
                        color: isUrgente
                            ? Colors.red[50]
                            : isFallback
                            ? Colors.orange[50]
                            : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: Icon(
                            isUrgente
                                ? Icons.error_outline
                                : isFallback
                                ? Icons.info_outline
                                : Icons.notifications,
                            color: isUrgente ? Colors.red : Colors.orange,
                          ),
                          title: Text(
                            isUrgente ? '⚠️ URGENTE' : 'ℹ️ Información',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(data['mensaje'] ?? 'Sin mensaje'),
                          // Aquí se integra el trailing solicitado
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data['createdAt'] != null
                                    ? DateFormat('HH:mm').format(
                                        (data['createdAt'] as Timestamp)
                                            .toDate(),
                                      )
                                    : '--:--',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Borrar notificación'),
                                      content: const Text(
                                        '¿Seguro que quieres borrar esta notificación?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Borrar',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection('notificaciones')
                                        .doc(notificaciones[index].id)
                                        .update(
                                          {'leida': true},
                                        ); // O .delete() si prefieres borrar del todo
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Notificación marcada como leída',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
