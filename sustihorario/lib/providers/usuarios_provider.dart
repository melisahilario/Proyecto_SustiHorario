import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Proveedor de estado para la autenticación y datos del usuario.
class UsuariosProvider with ChangeNotifier {
  // --- ESTADO PRIVADO
  User? _user;
  String? _rol;
  String? _nombre;
  String? _centroId;

  // Getters para exponer el estado de forma segura
  User? get user => _user;
  String? get rol => _rol;
  String? get nombre => _nombre;
  String? get centroId => _centroId;

  // Instancias de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Constructor de la clase.
  UsuariosProvider() {
    // Escuchar cambios en la sesión del usuario en tiempo real
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Maneja los cambios en el estado de autenticación.
  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();
          _rol = data?['role'] as String? ?? data?['rol'] as String?;
          _nombre = data?['nombre'] as String?;
          _centroId = data?['centroId'] as String?;
        }
      } catch (e) {
        print('Error cargando datos del usuario: $e');
      }
    } else {
      // Usuario cerró sesión
      _rol = null;
      _nombre = null;
      _centroId = null;
    }

    notifyListeners();
  }

  /// Registra un nuevo usuario en Firebase Auth y guarda sus datos en Firestore.
  Future<void> register({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    required String centroId,
  }) async {
    try {
      // Creación de usuario con email y contraseña
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Escritura de documento (.doc().set({...}))
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'nombre': nombre,
        'role': rol,
        'email': email,
        'centroId': centroId, // Guardamos la referencia al centro
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar estado local inmediatamente
      _user = credential.user;
      _rol = rol;
      _nombre = nombre;

      // Notificar cambios de estado
      notifyListeners();
    } catch (e) {
      throw Exception('Error en registro: $e');
    }
  }

  /// Inicia sesión con email y contraseña.
  Future<void> login(String nombre, String password) async {
    try {
      // Generar email ficticio basado en el nombre
      final email = '$nombre@centro.edu';

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Disparar manualmente la carga de datos
      await _onAuthStateChanged(credential.user);
    } catch (e) {
      debugPrint('Error en el login: $e');
    }
  }

  /// Cierra la sesión del usuario.
  Future<void> logout() async {
    await _auth.signOut();
    // El listener authStateChanges se encargará de limpiar las variables _rol, _nombre, etc.
  }
}
