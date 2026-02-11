import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sustihorario/services/guardias_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';

// Página para solicitar ausencia/baja por parte del profesor.
// Clase que extiende StatefulWidget, utilizando POO en Dart
class SolicitudAusenciaPage extends StatefulWidget {
  // Constructor con parámetro nombrado 'key'
  const SolicitudAusenciaPage({super.key});

  @override
  // Método que crea el estado asociado
  State<SolicitudAusenciaPage> createState() => _SolicitudAusenciaPageState();
}

// Clase privada que extiende State, utilizando herencia
class _SolicitudAusenciaPageState extends State<SolicitudAusenciaPage> {
  // Variable para el nombre del profesor (inicializada con valor por defecto).
  String nombreProfesor = 'Cargando...';

  // Variable con null safety para el usuario autenticado
  final User? user = FirebaseAuth.instance.currentUser;

  // Formato para obtener el día de la semana en español.
  final DateFormat diaSemanaFormat = DateFormat('EEEE', 'es_ES');

  // Lista constante de tipos de baja posibles
  final List<String> tiposBaja = [
    'Enfermedad común (sin baja médica)',
    'Enfermedad común (con baja médica)',
    'Asuntos propios',
    'Permiso no retribuido',
    'Enfermedad común (sin baja médica) ',
    'Incapacitado laboral transitoria (baja médica)',
    'Enfermedad grave (hospitalización) \no defunción de cónyuge  \no pareja de hecho \no familiar de 1.º o 2.º grado',
    'Paternidad',
    'Maternidad biológica',
    'Lactancia',
    'Traslado de domicilio habitual',
    'Deber inexcusable (citaciones de tribunales y\n organismos oficiales)',
    'Celebración de matrimonio o \nunión de hecho /\n Matrimonio o unión de hecho',
    'Asistencia médica, educativo o asistencial',
    'Adopción o acogida de menores',
    'Asistencia a pruebas selectivas y exámenes',
    'Técnicas prenatales ',
    'Licencias, conferencias, jornadas.. (retribuidos)',
    'Funciones representativas y formación',
    'Licencia por estudios (retribuida)',
    'Licencia por interés particular (no retribuidos)',
    'Licencia becas de estudio o investigación\n (no retribuidos)',
    'Licencia cursos (no retribuidos)',
    'Licencia por enfermedad de familiares (no retribuidos)',
    'Contrato de relevo (jubilación parcial)',
    'Jubilación parcial',
    'Interrupción de la embarazó',
    'Adopción internacional',
    'Otros',
  ];

  // Variable para el tipo de baja seleccionado (null safety).
  String? tipoBajaSeleccionado = 'Enfermedad común (sin baja médica)';

  // Variables para fechas de inicio y fin (null safety).
  DateTime? fechaInicio;
  DateTime? fechaFin;

  // Controlador para el campo de texto de tareas
  final TextEditingController tareasController = TextEditingController();

  // Mapas para almacenar horario real y fijo
  Map<String, List<String>> horarioReal = {};
  Map<String, Map<String, String>> horarioFijo = {};

  // Mapa para guardar las horas seleccionadas por día
  final Map<String, Set<String>> horasSeleccionadas = {};

  // Lista para días válidos dentro del rango seleccionado.
  List<String> diasValidos = [];

  // Variables para adjuntos
  PlatformFile? _archivoAdjunto;
  bool _isUploading = false;

  // Variable para controlar estado de carga.
  bool _isLoading = true;

  @override
  // Método sobrescrito initState (herencia).
  void initState() {
    super.initState();
    _cargarNombre(); // Carga nombre del profesor.
    // Solo cargamos horario si hay usuario autenticado.
    if (user != null) {
      _cargarHorarioReal();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    tareasController.dispose();
    super.dispose();
  }

  // Función para seleccionar un archivo.
  Future<void> _seleccionarArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _archivoAdjunto = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar archivo: $e');
    }
  }

  // Función para subir el archivo a Firebase Storage.
  Future<String?> _subirArchivo(String bajaId) async {
    if (_archivoAdjunto == null) return null;

    try {
      final fileName = _archivoAdjunto!.name;
      final destination = 'materiales_bajas/$bajaId/$fileName';
      final ref = FirebaseStorage.instance.ref(destination);

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(_archivoAdjunto!.bytes!);
      } else {
        uploadTask = ref.putFile(File(_archivoAdjunto!.path!));
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error al subir archivo: $e');
      return null;
    }
  }

  // Función asíncrona para obtener el ID del centro del usuario actual.
  Future<String?> _getCurrentCentroId() async {
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    return doc.data()?['centroId'] as String?;
  }
  // Los métodos auxiliares de cálculo de guardias y rangos semanales ahora están en GuardiasService.dart

  // Función asíncrona: obtiene el límite semanal de guardias del centro.
  Future<int> _obtenerLimiteGuardias(String centroId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('centros')
          .doc(centroId)
          .get();
      return doc.data()?['config']?['limiteGuardiasSemanal'] as int? ?? 999;
    } catch (e) {
      debugPrint('Error obteniendo límite: $e');
      return 999; // Valor por defecto muy alto si falla.
    }
  }

  // Carga el nombre del profesor desde Firestore.
  Future<void> _cargarNombre() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      setState(() {
        nombreProfesor = doc.data()?['nombre'] ?? 'Usuario';
      });
    } catch (_) {
      setState(() => nombreProfesor = 'Usuario');
    }
  }

  // Carga el horario real y fijo del profesor (prioriza modelo asignado).
  Future<void> _cargarHorarioReal() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('horarios')
          .doc(user!.uid)
          .get();

      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;
      Map<String, List<String>> tempReal = {};
      Map<String, Map<String, String>> tempFijo = {};

      final modeloId = data['modeloAsignadoId'] as String?;

      if (modeloId != null && modeloId.isNotEmpty) {
        final modeloDoc = await FirebaseFirestore.instance
            .collection('horarioModelos')
            .doc(modeloId)
            .get();

        if (modeloDoc.exists) {
          final slotsMap =
              modeloDoc.data()?['slots'] as Map<String, dynamic>? ?? {};
          slotsMap.forEach((hora, diasMap) {
            if (diasMap is Map<String, dynamic>) {
              tempFijo.putIfAbsent(hora, () => {});
              diasMap.forEach((dia, slotJson) {
                if (slotJson is Map<String, dynamic>) {
                  final estado = slotJson['estado'];
                  final clase = slotJson['clase'];
                  if (estado == 'fijo' && clase != null && clase.isNotEmpty) {
                    tempFijo[hora]![dia] = clase;
                    tempReal.putIfAbsent(dia, () => []);
                    tempReal[dia]!.add('$hora - $clase');
                  }
                }
              });
            }
          });
        }
      } else {
        final horarioFijoRaw =
            data['horarioFijo'] as Map<String, dynamic>? ?? {};
        horarioFijoRaw.forEach((hora, diasMap) {
          tempFijo[hora] = Map<String, String>.from(diasMap as Map);
          (diasMap as Map<String, dynamic>).forEach((dia, clase) {
            tempReal.putIfAbsent(dia, () => []);
            tempReal[dia]!.add('$hora - $clase');
          });
        });
      }

      // Ordenamos las horas por día.
      tempReal.forEach((dia, lista) {
        lista.sort();
      });

      setState(() {
        horarioReal = tempReal;
        horarioFijo = tempFijo;
        horasSeleccionadas.clear();
        for (var dia in horarioReal.keys) {
          horasSeleccionadas[dia] = {};
        }
      });
    } catch (e) {
      debugPrint('Error cargando horario: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Calcula los días lectivos válidos dentro del rango seleccionado.
  void _calcularDiasValidos() {
    diasValidos.clear();
    if (fechaInicio == null || fechaFin == null) return;

    DateTime current = DateTime(
      fechaInicio!.year,
      fechaInicio!.month,
      fechaInicio!.day,
    );
    final end = DateTime(fechaFin!.year, fechaFin!.month, fechaFin!.day);

    while (!current.isAfter(end)) {
      final diaSemana = diaSemanaFormat.format(current);
      final diaCapitalizado =
          diaSemana.substring(0, 1).toUpperCase() +
          diaSemana.substring(1).toLowerCase();

      if ([
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
      ].contains(diaCapitalizado)) {
        if (!diasValidos.contains(diaCapitalizado)) {
          diasValidos.add(diaCapitalizado);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    // Limpiamos y reconstruimos el mapa de horas seleccionadas solo para días válidos.
    horasSeleccionadas.removeWhere((key, _) => !diasValidos.contains(key));
    for (var dia in diasValidos) {
      horasSeleccionadas.putIfAbsent(dia, () => {});
    }
    setState(() {});
  }

  // Alterna la selección de una hora en un día concreto.
  void toggleHora(String dia, String horaCompleta) {
    setState(() {
      if (horasSeleccionadas[dia]!.contains(horaCompleta)) {
        horasSeleccionadas[dia]!.remove(horaCompleta);
      } else {
        horasSeleccionadas[dia]!.add(horaCompleta);
      }
    });
  }

  // La lógica de búsqueda, fallback y notificaciones se ha movido a GuardiasService.dart

  // Función principal: solicita la baja y gestiona automáticamente las guardias afectadas.
  Future<void> _solicitarBaja() async {
    // 1. Validación básica de campos obligatorios.
    if (tipoBajaSeleccionado == null ||
        fechaInicio == null ||
        fechaFin == null ||
        tareasController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return;
    }

    // Validación B: Fechas inconsistentes
    if (fechaFin!.isBefore(fechaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha de fin no puede ser anterior a la fecha de inicio.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validación B: Fechas pasadas
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    if (fechaInicio!.isBefore(hoySinHora)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes solicitar bajas para fechas anteriores a hoy.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Recopilamos todas las horas seleccionadas.
    List<String> horasAfectadas = [];
    for (var entry in horasSeleccionadas.entries) {
      if (entry.value.isNotEmpty) {
        horasAfectadas.addAll(entry.value.where((h) => h.trim().isNotEmpty));
      }
    }

    if (horasAfectadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una hora afectada')),
      );
      return;
    }

    try {
      final userUid = user?.uid;
      if (userUid != null) {
        // Buscamos cualquier solicitud que el usuario tenga activa
        final querySnapshot = await FirebaseFirestore.instance
            .collection('bajas')
            .where('profesorUid', isEqualTo: userUid)
            .where('estado', whereIn: ['pendiente', 'aprobada'])
            .get();

        bool haySolapamiento = false;

        // Iteramos sobre las bajas existentes
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final existingInicio = (data['fechaInicio'] as Timestamp).toDate();
          final existingFin = (data['fechaFin'] as Timestamp).toDate();

          // Lógica de solapamiento de fechas:
          if (!(fechaFin!.isBefore(existingInicio) ||
              fechaInicio!.isAfter(existingFin))) {
            haySolapamiento = true;
            break; // Salimos del bucle, ya encontramos conflicto
          }
        }

        if (haySolapamiento) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ya tienes una solicitud de baja activa para este periodo de fechas. No puedes duplicarla.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error verificando duplicados: $e');
    }

    try {
      final currentCentroId = await _getCurrentCentroId();
      final limiteGuardias = await _obtenerLimiteGuardias(currentCentroId!);

      setState(() => _isUploading = true);
      final Map<String, int> contadorGuardiasTemporales = {};

      // 1. Crear documento de baja (temporalmente sin el URL del adjunto)
      final bajaRef = await FirebaseFirestore.instance.collection('bajas').add({
        'profesorUid': user?.uid ?? '',
        'profesorNombre': nombreProfesor,
        'tipo': tipoBajaSeleccionado,
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'horasAfectadas': horasAfectadas,
        'tareasParaSustituto': tareasController.text.trim(),
        'estado': 'pendiente',
        'centroId': currentCentroId,
        'adjuntoUrl': null, // Se actualizará después si hay adjunto
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 1b. Subir archivo si existe
      if (_archivoAdjunto != null) {
        final url = await _subirArchivo(bajaRef.id);
        if (url != null) {
          await bajaRef.update({'adjuntoUrl': url});
        }
      }

      // 2. Procesamos cada día y sus horas seleccionadas -> GuardiasService hace el resto.
      for (var entry in horasSeleccionadas.entries) {
        final diaNombre = entry.key;
        final horasSeleccionadasEnDia = entry.value;

        if (horasSeleccionadasEnDia.isEmpty) continue;

        // Calculamos las fechas reales para este día dentro del rango (Bug de Fechas Solucionado)
        final fechasConcretas = GuardiasService.obtenerFechasParaDia(
          diaNombre,
          fechaInicio!,
          fechaFin!,
        );

        for (DateTime fechaConcreta in fechasConcretas) {
          for (String horaCompleta in horasSeleccionadasEnDia) {
            // Desglosar la horaCompleta para obtener asignatura, curso, aula
            final parts = horaCompleta.split(' - ');
            if (parts.length < 2) continue;
            final hora = parts[0].trim();
            final asignatura = parts[1].trim();
            String curso = '';
            String aula = '';

            // Obtener curso y aula del horarioFijo original usando el día específico
            if (horarioFijo.containsKey(hora) &&
                horarioFijo[hora]!.containsKey(diaNombre)) {
              final claseValue = horarioFijo[hora]![diaNombre]!;
              final claseParts = claseValue.split(' - ');
              if (claseParts.length >= 2) curso = claseParts[1].trim();
              if (claseParts.length >= 3) {
                aula = claseParts[2].trim().replaceFirst('Aula ', '');
              }
            }

            await GuardiasService.procesarCreacionGuardia(
              bajaId: bajaRef.id,
              centroId: currentCentroId,
              profesorAusenteUid: user?.uid ?? '',
              profesorAusenteNombre: nombreProfesor,
              dia: diaNombre,
              hora: hora,
              asignatura: asignatura,
              curso: curso,
              aula: aula,
              tareas: tareasController.text.trim(),
              fecha: fechaConcreta,
              limiteGuardias: limiteGuardias,
              contadorTemporal: contadorGuardiasTemporales,
            );
          }
        }
      }

      // 3. Reasignación de guardias existentes (donde el profesor que se va era el sustituto)
      // Delegamos la detección al servicio si fuera necesario, pero por ahora mantenemos el loop aquí
      // optimizado para usar el servicio si encontramos candidatos.
      final guardiasDondeSustituye = await FirebaseFirestore.instance
          .collection('guardias')
          .where('sustitutoUid', isEqualTo: user?.uid)
          .where('centroId', isEqualTo: currentCentroId)
          .get();

      for (var doc in guardiasDondeSustituye.docs) {
        final gData = doc.data();
        final fStr = gData['fecha'] as String?;
        if (fStr == null) continue;
        final fGuardia = DateFormat('dd/MM/yyyy').parse(fStr);

        if (!fGuardia.isBefore(fechaInicio!) && !fGuardia.isAfter(fechaFin!)) {
          // Reasignar esta guardia porque el sustituto se va de baja
          final candidatos = await GuardiasService.buscarCandidatos(
            centroId: currentCentroId,
            dia: gData['dia'],
            hora: gData['hora'],
            excluirUid: user?.uid,
            limiteGuardias: limiteGuardias,
            fechaConcreta: fGuardia,
          );

          if (candidatos.isNotEmpty) {
            candidatos.sort(
              (a, b) => a['guardiasCount'].compareTo(b['guardiasCount']),
            );
            final elegido = candidatos.first;
            await GuardiasService.reasignarGuardia(
              guardiaId: doc.id,
              sustitutoUid: elegido['uid'],
              sustitutoNombre: elegido['nombre'],
              tipo: 'Automática (Reasignada por Baja)',
            );
          } else {
            // Queda pendiente
            await FirebaseFirestore.instance
                .collection('guardias')
                .doc(doc.id)
                .update({
                  'sustitutoUid': '',
                  'sustitutoNombre': 'PENDIENTE ASIGNACIÓN',
                  'estado': 'pendiente',
                  'tipo': 'Pendiente (Sustituto de Baja)',
                });
          }
        }
      }

      // Notificación de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Baja solicitada y guardias gestionadas!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        setState(() {
          tipoBajaSeleccionado = tiposBaja.first;
          fechaInicio = null;
          fechaFin = null;
          tareasController.clear();
          horasSeleccionadas.clear();
          diasValidos.clear();
          _archivoAdjunto = null;
          for (var dia in horarioReal.keys) {
            horasSeleccionadas[dia] = {};
          }
        });
      }
    } catch (e) {
      debugPrint('Error al solicitar baja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (horarioReal.isEmpty && horarioFijo.isEmpty)
            ? _buildNoHorarioView()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_late_outlined,
                        color: Colors.indigo[400],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Solicitar Ausencia / Baja',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                  const SizedBox(height: 8),
                  const Text(
                    'Registra tu ausencia para la gestión táctica de guardias.',
                    style: TextStyle(color: Colors.grey),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: tipoBajaSeleccionado,
                    items: tiposBaja.map((tipo) {
                      return DropdownMenuItem(
                        value: tipo,
                        child: Text(
                          tipo,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => tipoBajaSeleccionado = value),
                    decoration: InputDecoration(
                      labelText: 'Tipo de baja / Permiso',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[50],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFechaPicker(
                          'Inicio',
                          fechaInicio,
                          (date) {
                            setState(() {
                              fechaInicio = date;
                              if (fechaFin != null &&
                                  fechaFin!.isBefore(date)) {
                                fechaFin = null;
                              }
                            });
                            _calcularDiasValidos();
                          },
                          DateTime.now(),
                          DateTime.now().add(const Duration(days: 365)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFechaPicker(
                          'Fin',
                          fechaFin,
                          (date) {
                            setState(() => fechaFin = date);
                            _calcularDiasValidos();
                          },
                          fechaInicio ?? DateTime.now(),
                          (fechaInicio ?? DateTime.now()).add(
                            const Duration(days: 90),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 32),
                  if (diasValidos.isNotEmpty) ...[
                    const Text(
                      'Horas afectadas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...diasValidos.map((dia) {
                      final horasDia = horarioReal[dia] ?? [];
                      if (horasDia.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dia,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: horasDia.map((horaCompleta) {
                              final isSelected = horasSeleccionadas[dia]!
                                  .contains(horaCompleta);
                              return FilterChip(
                                label: Text(horaCompleta),
                                selected: isSelected,
                                onSelected: (_) =>
                                    toggleHora(dia, horaCompleta),
                                selectedColor: Colors.indigo[100],
                                checkmarkColor: Colors.indigo,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ] else if (fechaInicio != null && fechaFin != null) ...[
                    const Text(
                      'No hay días lectivos en el rango seleccionado',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: tareasController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Tareas e indicaciones tácticas',
                      hintText: 'Describe las misiones para tu sustituto...',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[50],
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),
                  // SECCIÓN DE ADJUNTOS
                  const Text(
                    'Material Adicional (Opcional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _seleccionarArchivo,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _archivoAdjunto == null
                          ? 'VINCULAR INTELIGENCIA (PDF, JPG, DOC...)'
                          : 'REEMPLAZAR ARCHIVO',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  if (_archivoAdjunto != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ListTile(
                        leading: const Icon(
                          Icons.insert_drive_file,
                          color: Colors.indigo,
                        ),
                        title: Text(_archivoAdjunto!.name),
                        subtitle: Text(
                          '${(_archivoAdjunto!.size / 1024).toStringAsFixed(1)} KB',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              setState(() => _archivoAdjunto = null),
                        ),
                        tileColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isUploading || nombreProfesor == 'Cargando...'
                              ? null
                              : _solicitarBaja,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(
                            _isUploading
                                ? 'PROCESANDO...'
                                : 'SOLICITAR AUSENCIA',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 700.ms)
                      .scale(begin: const Offset(0.95, 0.95)),
                  const SizedBox(height: 20),
                ],
              ),
        if (_isUploading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Enviando solicitud y materiales...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoHorarioView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Aún no tienes horario asignado',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Necesitas un horario para poder solicitar bajas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/profesor/horarios'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ver mi horario'),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para mostrar selector de fecha (inicio/fin).
  Widget _buildFechaPicker(
    String label,
    DateTime? initial,
    Function(DateTime) onSelect,
    DateTime firstDate,
    DateTime lastDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: initial ?? firstDate,
              firstDate: firstDate,
              lastDate: lastDate,
              locale: const Locale('es', 'ES'),
            );
            if (picked != null) {
              onSelect(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  initial != null
                      ? DateFormat('dd/MM/yyyy').format(initial)
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: initial != null
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87)
                        : Colors.grey,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.indigo),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
