import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:sustihorario/pages/loginYregister/login_page.dart';
import 'package:sustihorario/pages/profesor/profesores_home_page.dart';
import 'package:sustihorario/pages/loginYregister/register_page.dart';
import 'package:sustihorario/pages/admin/admin_page.dart';
import 'package:sustihorario/pages/coordinador/coordinador_home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',

  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Usuario no logueado
    if (user == null) {
      // Permanecer en login o register si ya está ahí
      if (state.uri.path != '/login' && state.uri.path != '/register') {
        return '/login';
      }
      return null;
    }

    // 2. Usuario logueado -> Verificar rol y redirigir
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] ?? doc.data()?['rol'] ?? 'profesor';

      // Si intenta ir a login/register y está logueado, redirigir a su Home
      if (state.uri.path == '/login' || state.uri.path == '/register') {
        return _getHomePath(role);
      }

      // Verificar si el rol tiene permiso para la ruta actual
      if (!_isAuthorizedForPath(state.uri.path, role)) {
        return _getHomePath(role);
      }

      return null;
    } catch (e) {
      print('Error en redirección: $e');
      return '/login';
    }
  },

  routes: [
    // Públicas
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // Privadas: Apuntan a las nuevas HOME PAGES
    GoRoute(
      path: '/coordinador',
      builder: (context, state) => const CoordinadorHomePage(
        nombreCoordinador: 'Coordinador',
        rol: 'Coordinador',
      ),
    ),
    GoRoute(
      path: '/profesor',
      builder: (context, state) => const ProfesoresHomePage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => AdminPage(
        nombreAdministrador: state.extra as String? ?? 'Administrador',
        rol: 'Administrador',
      ),
    ),
  ],
);

// Obtener ruta home según rol
String _getHomePath(String role) {
  final cleanRole = role.toLowerCase();
  if (cleanRole == 'admin' || cleanRole == 'administrador') {
    return '/admin';
  } else if (cleanRole == 'coordinador') {
    return '/coordinador';
  } else {
    return '/profesor';
  }
}

// Verificar autorización
bool _isAuthorizedForPath(String path, String role) {
  final cleanRole = role.toLowerCase();

  if (path.startsWith('/profesor') && cleanRole == 'profesor') return true;
  if (path == '/admin' &&
      (cleanRole == 'admin' || cleanRole == 'administrador'))
    return true;
  if (path == '/coordinador' && cleanRole == 'coordinador') return true;

  return false;
}
