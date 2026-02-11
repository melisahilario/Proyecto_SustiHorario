import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Definición de una clase que extiende StatefulWidget, utilizando POO en Dart
// Esta clase representa una página para la configuración del centro.
class ConfiguracionPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key', usando parámetros nombrados
  const ConfiguracionPage({super.key});

  @override
  // Método que crea el estado asociado, sobrescribiendo un método de la clase padre
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

// Clase privada que extiende State, utilizando herencia  y POO
class _ConfiguracionPageState extends State<ConfiguracionPage> {
  // Declaración de variable con null safety , tipo inferido como User?
  final User? user = FirebaseAuth.instance.currentUser;
  // Instancia de TextEditingController, utilizando clases
  final TextEditingController _limiteController = TextEditingController();

  // Variable para modo de recuperación, usando null safety
  String? _centroRecuperacionId;

  // Función asíncrona que retorna un Future<String?>, usando async/await mencionado en similitudes con JS
  // Obtiene el ID del centro actual.
  Future<String?> _getCurrentCentroId() async {
    // Control de flujo con if , verifica si user es null.
    if (user == null) return null;
    // Await para esperar el resultado de una operación asíncrona.
    final doc = await FirebaseFirestore.instance
        .collection('users') // Uso de colecciones
        .doc(user!.uid) // Acceso seguro con ! (null safety).
        .get();
    // Retorna un valor de un Map, con cast a String?.
    return doc.data()?['centroId'] as String?;
  }

  // Función asíncrona para asignar centro, usando async/await.
  Future<void> _asignarCentro(String idCentro) async {
    // Bloque try-catch para manejo de errores
    try {
      // Await para actualizar documento.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'centroId': idCentro}); // Uso de Map
      // Muestra mensaje de éxito.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario arreglado correctamente. Recargando...'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Muestra mensaje de error con interpolación de string
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al asignar centro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  // Método sobrescrito dispose, para limpieza
  void dispose() {
    // Llama a dispose del controller.
    _limiteController.dispose();
    // Llama al super (herencia).
    super.dispose();
  }

  @override
  // Método sobrescrito build, que retorna un Widget
  Widget build(BuildContext context) {
    // Retorna FutureBuilder para manejar Future
    return FutureBuilder<String?>(
      future: _getCurrentCentroId(),
      builder: (context, snap) {
        // Función anónima
        // Variable con null safety.
        final centroId = snap.data;
        // Control de flujo if para centro no encontrado.
        if (centroId == null)
          return const Center(child: Text('Centro no encontrado'));

        // StreamBuilder para datos en tiempo real.
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('centros')
              .doc(centroId)
              .snapshots(),
          builder: (context, snapshotWrapper) {
            // Función anónima.
            // If para estado de espera.
            if (snapshotWrapper.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());

            // Variable con null safety.
            final DocumentSnapshot? docSnapshot = snapshotWrapper.data;

            // If para documento no existente.
            if (docSnapshot == null || !docSnapshot.exists) {
              return const Center(
                child: Text(
                  'El documento del centro no existe en la base de datos.',
                ),
              );
            }

            // Map de datos
            final Map<String, dynamic> data =
                docSnapshot.data() as Map<String, dynamic>;

            // Acceso a Map anidado con null safety.
            final configMap = data['config'] as Map<String, dynamic>?;
            final limite = configMap?['limiteGuardiasSemanal'] as int?;

            // String desde int? con null-aware.
            final textoDB = limite?.toString() ?? '';
            // If para actualizar controller solo si diferente.
            if (_limiteController.text != textoDB) {
              // Verifica mounted.
              if (mounted) {
                _limiteController.text = textoDB;
              }
            }

            // Retorna Column con widgets.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración del Centro',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Card para información.
                Card(
                  elevation: 2,
                  color: Colors.deepPurple[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.deepPurple.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.deepPurple,
                          size: 40,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Límite de Guardias',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                limite != null
                                    ? 'Periodo: SEMANAL'
                                    : 'Periodo: No configurado', // Operador ternario
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.deepPurple[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          (limite ?? 0).toString(), // Null-aware ??
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Modificar límite',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si un profesor tiene igual o más guardias que este límite, el sistema no le asignará nuevas sustituciones automáticamente.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _limiteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nuevo límite semanal',
                          hintText: 'Ej: 5',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Función anónima asíncrona.
                        // Cierra teclado.
                        FocusScope.of(context).unfocus();
                        // Parsea int con tryParse.
                        final nuevo = int.tryParse(
                          _limiteController.text.trim(),
                        );
                        // If para validación.
                        if (nuevo == null || nuevo < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Número inválido')),
                          );
                          return;
                        }

                        // Bloque try-catch.
                        try {
                          // Await para set con merge, usando Map
                          await FirebaseFirestore.instance
                              .collection('centros')
                              .doc(centroId)
                              .set({
                                'config': {
                                  'limiteGuardiasSemanal': nuevo,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                },
                              }, SetOptions(merge: true));

                          // If mounted, muestra mensaje.
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Límite actualizado a $nuevo / Semana',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          // If mounted, muestra error.
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
