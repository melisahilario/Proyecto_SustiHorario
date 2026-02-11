import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sustihorario/pages/admin/gestion_centros_page.dart';

/// Página exclusiva para administradores - creación y gestión de centros.
class AdminPage extends StatefulWidget {
  final String nombreAdministrador;
  final String rol;

  const AdminPage({
    super.key,
    required this.nombreAdministrador,
    this.rol = "Administrador",
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String nombreAdministrador = 'Cargando...';
  final User? user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  // Eliminado: _horasController
  final _codigoController = TextEditingController(); // Nuevo controlador

  bool _isLoading = false;

  Future<void> _cargarNombre() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      setState(() {
        nombreAdministrador = doc.data()?['nombre'] ?? 'Administrador';
      });
    } catch (_) {
      setState(() => nombreAdministrador = 'Administrador');
    }
  }

  Future<void> _crearCentro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final codigo = _codigoController.text.trim();
      final nombre = _nombreController.text.trim();

      // 1. Validar que el código no esté vacío
      if (codigo.isEmpty) {
        throw 'El código es obligatorio';
      }

      // 2. Validar unicidad del Código (ID del documento)
      // Chequeamos si ya existe un documento con ese ID
      final docCheck = await FirebaseFirestore.instance
          .collection('centros')
          .doc(codigo)
          .get();

      if (docCheck.exists) {
        throw 'Ya existe un centro con este código';
      }

      // 3. Validar unicidad del Nombre
      final existingName = await FirebaseFirestore.instance
          .collection('centros')
          .where('nombre', isEqualTo: nombre)
          .get();

      if (existingName.docs.isNotEmpty) {
        throw 'Ya existe un centro con este nombre';
      }

      // 4. Crear usando el código como ID
      await FirebaseFirestore.instance
          .collection('centros')
          .doc(codigo) // Usamos .doc(codigo) en lugar de .add()
          .set({
            'nombre': nombre,
            'direccion': _direccionController.text.trim(),
            'codigo': codigo, // Guardamos el código también como campo
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': user?.uid,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Centro creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _nombreController.clear();
        _direccionController.clear();
        _codigoController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _codigoController.dispose(); // Limpieza
    super.dispose();
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.indigo[300]
                    : Colors.indigo[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.rol,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red[200]
                      : Colors.red[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              button: true,
              label: 'Cerrar sesión',
              child: GestureDetector(
                onTap: () async {
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

                  if (confirm == true) {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    context.go('/login');
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nombreAdministrador,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'EEEE d \'de\' MMMM \'de\' yyyy',
                        'es_ES',
                      ).format(DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenid@, $nombreAdministrador',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
            const Text(
              'Panel de Control Maestro',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),

            // Tarjeta de Creación
            Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.add_business,
                                color: Colors.indigo[400],
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Registrar Nuevo Centro',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          TextFormField(
                            controller: _nombreController,
                            decoration: InputDecoration(
                              labelText: 'Nombre del centro',
                              prefixIcon: const Icon(Icons.school_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[50],
                            ),
                            validator: (v) => v?.trim().isEmpty ?? true
                                ? 'Obligatorio'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _direccionController,
                            decoration: InputDecoration(
                              labelText: 'Dirección',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // NUEVO: Campo Código
                          TextFormField(
                            controller: _codigoController,
                            decoration: InputDecoration(
                              labelText: 'Código del centro (ID único)',
                              hintText: 'Ej: 4601901',
                              prefixIcon: const Icon(Icons.vpn_key_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[50],
                            ),
                            validator: (v) => v?.trim().isEmpty ?? true
                                ? 'Obligatorio'
                                : null,
                          ),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _crearCentro,
                              icon: _isLoading
                                  ? const SizedBox.shrink()
                                  : const Icon(Icons.save_outlined),
                              label: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'CREAR CENTRO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms)
                .scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            const Text(
              'Gestión Operativa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GestionCentrosPage()),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [const Color(0xFF1E2130), const Color(0xFF141624)]
                        : [Colors.indigo[700]!, Colors.indigo[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.list_alt,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestionar Centros',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ver, editar o eliminar centros existentes',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}
