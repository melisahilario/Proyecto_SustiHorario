import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sustihorario/pages/profesor/solicitar_baja_page.dart';

import 'misguardias_page.dart';
import 'horarios_page.dart';
import 'package:sustihorario/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'mercado_intercambio_page.dart';

// Página principal para profesores con pestañas de navegación.
// Clase que extiende StatefulWidget, utilizando POO en Dart
class ProfesoresHomePage extends StatefulWidget {
  // Variable de instancia para el rol (sección 6.1).
  final String rol;

  // Constructor con parámetros nombrados y valor por defecto
  const ProfesoresHomePage({super.key, this.rol = "Profesor"});

  @override
  // Método que crea el estado asociado
  State<ProfesoresHomePage> createState() => _ProfesoresHomePageState();
}

// Clase privada que extiende State, utilizando herencia
class _ProfesoresHomePageState extends State<ProfesoresHomePage> {
  // Variable para el nombre del profesor
  String nombreProfesor = 'Cargando...';

  // Variable con null safety para el usuario autenticado
  final User? user = FirebaseAuth.instance.currentUser;

  // Variable entera para controlar la pestaña activa
  int activeTab = 0;

  @override
  // Método sobrescrito initState
  void initState() {
    super.initState();
    _cargarNombre(); // Carga del nombre al iniciar.
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
        setState(() => nombreProfesor = nombre ?? 'Usuario');
      } else {
        setState(() => nombreProfesor = 'Usuario');
      }
    } catch (e) {
      // En caso de error mostramos mensaje en consola y valor por defecto.
      debugPrint('Error cargando nombre: $e');
      setState(() => nombreProfesor = 'Usuario');
    }
  }

  @override
  // Método principal que construye la interfaz completa (herencia).
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            Text(
              'SUSTIHORARIO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.rol, // Acceso a propiedad del widget padre.
                style: TextStyle(fontSize: 12, color: Colors.indigo[800]),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return IconButton(
                icon: Icon(
                  theme.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                  color: theme.isDarkMode ? Colors.amber : Colors.indigo[800],
                ),
                onPressed: () => theme.toggleTheme(),
                tooltip: theme.isDarkMode ? 'Modo Claro' : 'Modo Oscuro',
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              button: true,
              label: 'Cerrar sesión',
              child: GestureDetector(
                onTap: () async {
                  final router = GoRouter.of(context);
                  // Diálogo de confirmación de cierre de sesión.
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text(
                        '¿Estás seguro de que quieres cerrar sesión?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sí'),
                        ),
                      ],
                    ),
                  );

                  // Si confirmó, cerramos sesión y navegamos.
                  if (confirm == true) {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    router.go('/login');
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nombreProfesor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'EEEE d \'de\' MMMM \'de\' yyyy',
                        'es_ES',
                      ).format(DateTime.now()), // Formateo de fecha actual.
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header fijo superior con saludo y pestañas.
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Saludo personalizado con interpolación de strings.
                Text(
                  'Bienvenid@, $nombreProfesor',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                const Text(
                  'Tu Terminal de Gestión Educativa',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),

                // Fila de pestañas (tabs).
                Row(
                  children: [
                    _buildTab('Solicitar Baja', 0),
                    _buildTab('Mis Guardias', 1),
                    _buildTab('Horarios', 2),
                    _buildTab('Mercado', 3),
                  ],
                ),
              ],
            ),
          ),

          // Área de contenido principal (expansible).
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Builder(
                    builder: (context) {
                      // Control de flujo switch para seleccionar la pestaña activa.
                      Widget content;
                      switch (activeTab) {
                        case 0:
                          content = const SolicitudAusenciaPage();
                          break;
                        case 1:
                          content = const MisGuardiasPage();
                          break;
                        case 2:
                          content = const HorariosPage();
                          break;
                        case 3:
                          content = const MercadoIntercambioPage();
                          break;
                        default:
                          content = const Center(
                            child: Text('Selecciona una pestaña'),
                          );
                      }
                      return content
                          .animate(key: ValueKey(activeTab))
                          .fadeIn(duration: const Duration(milliseconds: 300))
                          .slideX(begin: 0.05, curve: Curves.easeOutQuad);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Función auxiliar que construye cada pestaña (tab).
  // Parámetros posicionales
  Widget _buildTab(String title, int index) {
    // Variable local para saber si la pestaña está activa.
    final isActive = activeTab == index;

    return Expanded(
      child: Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          // Arrow function para cambiar pestaña activa.
          onTap: () => setState(() => activeTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.indigo[700]
                        : Colors.indigo[50])
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100]),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      width: 1.5,
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child:
                Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono diferente según título (operador ternario).
                        Icon(
                          title.contains('Solicitar')
                              ? Icons.assignment
                              : title.contains('Guardias')
                              ? Icons.emoji_events
                              : title.contains('Horarios')
                              ? Icons.schedule
                              : Icons.swap_horiz,
                          size: 18,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.indigo[900])
                                : Colors.grey[600],
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    )
                    .animate(target: isActive ? 1 : 0)
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: const Duration(milliseconds: 200),
                    ),
          ),
        ),
      ),
    );
  }
}
