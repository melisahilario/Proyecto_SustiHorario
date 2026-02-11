import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sustihorario/services/guardias_service.dart';

class MercadoIntercambioPage extends StatefulWidget {
  const MercadoIntercambioPage({super.key});

  @override
  State<MercadoIntercambioPage> createState() => _MercadoIntercambioPageState();
}

class _MercadoIntercambioPageState extends State<MercadoIntercambioPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Inicia sesión'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swap_horizontal_circle_outlined,
              color: Colors.indigo[400],
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Mercado de Intercambio',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
        const SizedBox(height: 8),
        const Text(
          'Intercambia turnos con tus compañeros de forma táctica y eficiente.',
          style: TextStyle(color: Colors.grey),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('guardias')
              .where('estado', isEqualTo: 'en_intercambio')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyMarket();
            }

            final guardias = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: guardias.length,
              itemBuilder: (context, index) {
                final data = guardias[index].data() as Map<String, dynamic>;
                final id = guardias[index].id;

                // No mostrar mis propias guardias en el mercado (opcional, pero lógico)
                if (data['sustitutoUid'] == user!.uid) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.orange[800],
                        size: 28,
                      ),
                    ),
                    title: Text(
                      '${data['asignatura']} - ${data['curso']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '📅 DÍA: ${data['dia']}\n⏰ HORA: ${data['hora']}\n👤 DE: ${data['sustitutoNombre']}',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _reclamarGuardia(id, data),
                      child: const Text('RECLAMAR'),
                    ),
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyMarket() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300])
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 24),
          const Text(
            '¡Atalaya Despejada!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay guardias pendientes de intercambio.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Future<void> _reclamarGuardia(String id, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reclamar Guardia'),
        content: Text(
          '¿Quieres quedarte con la guardia de ${data['asignatura']} de las ${data['hora']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SÍ, RECLAMAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Necesitamos el nombre del usuario actual
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        final miNombre = userDoc.data()?['nombre'] ?? 'Profesor';
        final centroId = userDoc.data()?['centroId'] ?? '';

        await GuardiasService.reclamarIntercambio(
          guardiaId: id,
          nuevoSustitutoUid: user!.uid,
          nuevoSustitutoNombre: miNombre,
          centroId: centroId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Guardia reclamada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reclamar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
