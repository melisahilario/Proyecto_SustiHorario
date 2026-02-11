import 'package:cloud_firestore/cloud_firestore.dart'; // Clase para interactuar con Firestore.
import 'package:firebase_auth/firebase_auth.dart'; // Clase para autenticación.
import 'package:flutter/material.dart'; // Paquete para construir interfaces, usando widgets como clases.
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'bajas_pendientes_page.dart'; // Importamos otras páginas como clases.
import 'guardias_asignadas_page.dart';
import 'notificaciones_page.dart';
import 'modelos_horario_page.dart';
import 'usuarios_page.dart';
import 'configuracion_page.dart';
import 'estadisticas_page.dart';
import 'package:sustihorario/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// Definimos una clase StatefulWidget, que es un concepto de POO en Dart: herencia de una clase base.
class CoordinadorHomePage extends StatefulWidget {
  final String nombreCoordinador; // Variable de instancia, tipo String.
  final String rol; // Otra variable de instancia.

  const CoordinadorHomePage({
    super.key, // Parámetro nombrado, visto en funciones avanzadas.
    required this.nombreCoordinador, // Parámetro requerido.
    this.rol = "Coordinador", // Parámetro con valor por defecto.
  });

  @override
  State<CoordinadorHomePage> createState() => _CoordinadorHomePageState(); // Método que crea el estado, usando arrow function.
}

// Clase privada que extiende State, usando herencia en POO.
class _CoordinadorHomePageState extends State<CoordinadorHomePage> {
  String nombreCoordinador =
      'Cargando...'; // Variable de instancia inicializada.
  final User? user = FirebaseAuth
      .instance
      .currentUser; // Variable con null safety (? para nullable).
  int activeTab = 0; // Variable entera.

  @override
  void initState() {
    super.initState(); // Llamada al método de la superclase.
    _cargarNombre(); // Llamamos a una función para cargar datos.
  }

  // Función asíncrona para cargar el nombre. En Dart, las funciones pueden ser async para manejar Futures.
  // Aunque no explícitamente en el índice, se relaciona con funciones avanzadas.
  Future<void> _cargarNombre() async {
    if (user == null)
      return setState(
        () => nombreCoordinador = 'Usuario',
      ); // Control de flujo con if, y función anónima en setState.
    try {
      final doc = await FirebaseFirestore
          .instance // Uso de await para resolver Future.
          .collection('users') // Colección como mapa implícito.
          .doc(user!.uid) // ! para non-null assertion, null safety.
          .get();
      setState(
        () => nombreCoordinador = doc.data()?['nombre'] ?? 'Usuario',
      ); // Operador ?? para null coalescing.
    } catch (_) {
      setState(
        () => nombreCoordinador = 'Usuario',
      ); // Manejo de errores con catch.
    }
  }

  @override
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
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.rol, // Acceso a variable de widget.
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple[800],
                  fontWeight: FontWeight.bold,
                ),
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
                  // Función anónima async.
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      // Función anónima que retorna widget.
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Confirmas?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false), // Arrow function.
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sí'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) context.go('/login'); // Control de flujo if.
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nombreCoordinador,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'EEEE d \'de\' MMMM \'de\' yyyy',
                        'es_ES',
                      ).format(DateTime.now()), // Función para formatear fecha.
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
          // Header fijo superior
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenid@, $nombreCoordinador',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                const Text(
                  'Centro de Operaciones Tácticas',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),
                // Pestañas de navegación
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTab('Bajas Pendientes', 0),
                      _buildTab('Guardias Asignadas', 1),
                      _buildTab('Notificaciones', 2),
                      _buildTab('Modelos Horario', 3),
                      _buildTab('Usuarios', 4),
                      _buildTab('Estadísticas', 5),
                      _buildTab('Configuración', 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Área de contenido con scroll
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
                      switch (activeTab) {
                        // Control de flujo switch.
                        case 0:
                          return const BajasPendientesPage();
                        case 1:
                          return const GuardiasAsignadasPage();
                        case 2:
                          return const NotificacionesPage();
                        case 3:
                          return const ModelosHorarioPage();
                        case 4:
                          return const UsuariosPage();
                        case 5:
                          return const EstadisticasPage();
                        case 6:
                          return const ConfiguracionPage();
                        default:
                          return const Center(
                            child: Text('Selecciona una pestaña'),
                          );
                      }
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

  // Función privada que retorna un widget. Parámetros posicionales.
  Widget _buildTab(String title, int index) {
    final isActive =
        activeTab == index; // Variable local con operador de comparación.
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () =>
            setState(() => activeTab = index), // Función anónima con arrow.
        child:
            Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.5),
                            width: 1.5,
                          )
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.indigo[900])
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                )
                .animate(target: isActive ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 200.ms,
                ),
      ),
    );
  }
}
