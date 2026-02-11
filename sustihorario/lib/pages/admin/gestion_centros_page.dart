import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class GestionCentrosPage extends StatefulWidget {
  const GestionCentrosPage({super.key});

  @override
  State<GestionCentrosPage> createState() => _GestionCentrosPageState();
}

class _GestionCentrosPageState extends State<GestionCentrosPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Centros'),
        backgroundColor: Colors.grey,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('centros')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final centros = snapshot.data!.docs;

          if (centros.isEmpty) {
            return const Center(child: Text('No hay centros creados aún.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: centros.length,
            itemBuilder: (context, index) {
              final doc = centros[index];
              final data = doc.data() as Map<String, dynamic>;
              final codigo = doc.id; // El ID del doc es el código
              final nombre = data['nombre'] ?? 'Sin nombre';
              final direccion = data['direccion'] ?? 'Sin dirección';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Código: $codigo\n$direccion',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        tooltip: 'Editar',
                        onPressed: () => _mostrarDialogoEditar(
                          context,
                          docId: codigo,
                          nombreActual: nombre,
                          direccionActual: direccion,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Eliminar',
                        onPressed: () =>
                            _confirmarEliminar(context, codigo, nombre),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _mostrarDialogoEditar(
    BuildContext context, {
    required String docId,
    required String nombreActual,
    required String direccionActual,
  }) async {
    final ctrlId = TextEditingController(text: docId);
    final ctrlNombre = TextEditingController(text: nombreActual);
    final ctrlDir = TextEditingController(text: direccionActual);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Centro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: ctrlId,
              decoration: const InputDecoration(
                labelText: 'Código (ID)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrlNombre,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrlDir,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final nuevoId = ctrlId.text.trim();
              final nuevoNombre = ctrlNombre.text.trim();
              final nuevaDir = ctrlDir.text.trim();

              if (nuevoNombre.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }

              final idCambiado = nuevoId != docId;

              if (idCambiado) {
                // 1. Validar unicidad del nuevo ID
                final idExists = await FirebaseFirestore.instance
                    .collection('centros')
                    .doc(nuevoId)
                    .get();

                if (idExists.exists) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El código ID ya está en uso por otro centro',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // 2. Operación de migración completa
                  final oldDoc = await FirebaseFirestore.instance
                      .collection('centros')
                      .doc(docId)
                      .get();

                  if (!oldDoc.exists) return;
                  final data = oldDoc.data()!;

                  final batch = FirebaseFirestore.instance.batch();

                  // A. Crear nuevo centro
                  final newDocRef = FirebaseFirestore.instance
                      .collection('centros')
                      .doc(nuevoId);
                  batch.set(newDocRef, data);

                  // B. Migrar Usuarios
                  final usersSnap = await FirebaseFirestore.instance
                      .collection('users')
                      .where('centroId', isEqualTo: docId)
                      .get();
                  for (var userDoc in usersSnap.docs) {
                    batch.update(userDoc.reference, {'centroId': nuevoId});
                  }

                  // C. Migrar Modelos de Horario
                  final modelosSnap = await FirebaseFirestore.instance
                      .collection('horarioModelos')
                      .where('centroId', isEqualTo: docId)
                      .get();
                  for (var modeloDoc in modelosSnap.docs) {
                    batch.update(modeloDoc.reference, {'centroId': nuevoId});
                  }

                  // D. NUEVO: Migrar Bajas
                  final bajasSnap = await FirebaseFirestore.instance
                      .collection('bajas')
                      .where('centroId', isEqualTo: docId)
                      .get();
                  for (var bajaDoc in bajasSnap.docs) {
                    batch.update(bajaDoc.reference, {'centroId': nuevoId});
                  }

                  // E. NUEVO: Migrar Guardias
                  final guardiasSnap = await FirebaseFirestore.instance
                      .collection('guardias')
                      .where('centroId', isEqualTo: docId)
                      .get();
                  for (var guardiaDoc in guardiasSnap.docs) {
                    batch.update(guardiaDoc.reference, {'centroId': nuevoId});
                  }

                  // F. NUEVO: Migrar Notificaciones
                  final notifsSnap = await FirebaseFirestore.instance
                      .collection('notificaciones')
                      .where('centroId', isEqualTo: docId)
                      .get();
                  for (var notifDoc in notifsSnap.docs) {
                    batch.update(notifDoc.reference, {'centroId': nuevoId});
                  }

                  // G. Eliminar centro antiguo
                  batch.delete(oldDoc.reference);

                  // Ejecutar batch
                  await batch.commit();

                  if (ctx.mounted) Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Centro actualizado. Usuarios, Modelos, Bajas, Guardias y Notificaciones migrados.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('Error cambiando ID: $e');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error: $e (Posible límite de 500 operaciones)',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Actualización simple
                try {
                  await FirebaseFirestore.instance
                      .collection('centros')
                      .doc(docId)
                      .update({'nombre': nuevoNombre, 'direccion': nuevaDir});

                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Datos actualizados')),
                  );
                } catch (e) {
                  print('Error actualizando: $e');
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    String docId,
    String nombre,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Centro?'),
        content: Text(
          '¿Estás seguro de eliminar "$nombre"?\n\nEsta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('centros')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Centro eliminado correctamente')),
          );
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
}
