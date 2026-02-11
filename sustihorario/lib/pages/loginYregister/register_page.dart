import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Página de registro de nuevos usuarios.
/// Clase que extiende StatefulWidget, utilizando POO en Dart
class RegisterPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key'
  const RegisterPage({super.key});

  @override
  // Método que crea el estado asociado
  State<RegisterPage> createState() => _RegisterPageState();
}

// Clase privada que extiende State, utilizando herencia
class _RegisterPageState extends State<RegisterPage> {
  // Clave global para validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController(); // NUEVO CONTROLADOR

  // Variable para el rol seleccionado
  String _rol = 'Profesor';

  // Variable nullable para el ID del centro seleccionado
  String? selectedCentroId;

  // Variable para controlar estado de carga
  bool _isLoading = false;

  // Función asíncrona principal: registra al usuario en Firebase Auth y Firestore.
  Future<void> _registrar() async {
    // Validación del formulario y centro seleccionado (control de flujo if).
    if (!_formKey.currentState!.validate() || selectedCentroId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, completa todos los campos y selecciona un centro',
          ),
        ),
      );
      return;
    }

    // Indicamos que está en proceso de carga.
    setState(() => _isLoading = true);

    try {
      // NUEVO: Chequeo en Firestore antes de crear usuario para evitar duplicados
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw 'El email ya está registrado';
      }

      // Registro del usuario en Firebase Authentication.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // Guardado de datos adicionales en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'nombre': _nombreController.text.trim(),
            'email': _emailController.text.trim(),
            // Operador ternario para asignar rol
            'role': _rol == 'Profesor'
                ? 'profesor'
                : _rol == 'Coordinador'
                ? 'coordinador'
                : 'admin',
            'centroId': selectedCentroId,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Feedback de éxito si el widget sigue montado.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Registro completado!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navegación a la página principal tras registro exitoso.
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      // Manejo específico de errores de autenticación.
      String error = 'Error desconocido';
      if (e.code == 'email-already-in-use') {
        error = 'El correo ya está registrado en Firebase Auth.';
      } else if (e.code == 'weak-password') {
        error = 'La contraseña es demasiado débil.';
      } else if (e.code == 'invalid-email') {
        error = 'El formato del email no es válido.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Manejo genérico de otros errores (incluido el throw de Firestore anterior).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Siempre finalizamos el estado de carga (bloque finally).
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Limpieza de recursos al destruir el estado (herencia).
  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // LIMPIEZA DEL NUEVO CONTROLADOR
    super.dispose();
  }

  // Construcción de la interfaz de usuario.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'REGISTRO SUSTIHORARIO',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // Campo Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      hintText: 'Ej. Juan Pérez',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 20),

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'usuario@centro.edu',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatorio';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña (mín. 6 caracteres)',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // NUEVO: Campo Confirmar Contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Selector de Rol (DropdownButtonFormField)
                  DropdownButtonFormField<String>(
                    value: _rol,
                    items: ['Profesor', 'Coordinador', 'Administrador']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _rol = v!), // Actualiza estado.
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      filled: true,
                      fillColor: Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selector de Centro (usando StreamBuilder para datos en tiempo real)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('centros')
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Caso de error en la consulta.
                      if (snapshot.hasError) {
                        return Text(
                          'ERROR: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }

                      // Mientras se cargan los centros...
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Caso sin centros disponibles.
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          'No hay centros disponibles.\nContacta al administrador.',
                          style: TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        );
                      }

                      // Lista de documentos centros
                      final centros = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedCentroId,
                        hint: const Text('Selecciona tu centro'),
                        items: centros.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              data['nombre']?.toString() ??
                                  'Sin nombre (${doc.id})',
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => selectedCentroId = v),
                        decoration: const InputDecoration(
                          labelText: 'Centro',
                          filled: true,
                          fillColor: Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => v == null ? 'Obligatorio' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                  // Botón de Registro
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Semantics(
                      button: true,
                      label: 'Registrarse',
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'REGISTRAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Enlace a pantalla de login.
                  Semantics(
                    button: true,
                    label: 'Ir a inicio de sesión',
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        '¿Ya tienes cuenta? Inicia sesión',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
