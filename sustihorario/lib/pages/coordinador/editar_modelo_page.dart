import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/horario_model.dart';

// Página de edición/creación de modelos de horario
// Nueva clase StatefulWidget
class EditarModeloPage extends StatefulWidget {
  final String centroId;
  final String userUid;
  final HorarioModelo? modeloExistente;

  const EditarModeloPage({
    super.key,
    required this.centroId,
    required this.userUid,
    this.modeloExistente,
  });

  @override
  State<EditarModeloPage> createState() => _EditarModeloPageState();
}

class _EditarModeloPageState extends State<EditarModeloPage> {
  // Clave para el formulario
  final _formKey = GlobalKey<FormState>();
  // Controlador para el nombre
  final _nombreController = TextEditingController();
  // Lista de horas
  List<String> horas = [];
  // Mapa anidado para slots
  Map<String, Map<String, SlotData>> slots = {};
  // Lista constante de días
  final List<String> dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inicialización condicional según si es edición o creación
    if (widget.modeloExistente != null) {
      _nombreController.text = widget.modeloExistente!.nombre;
      horas = List.from(widget.modeloExistente!.horas);
      widget.modeloExistente!.slots.forEach((hora, diaMap) {
        slots[hora] = {};
        diaMap.forEach((dia, slot) {
          slots[hora]![dia] = slot;
        });
      });
    } else {
      // Inicialización por defecto si es nuevo
      horas = ['08:00'];
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  // Función asíncrona para guardar o actualizar el modelo
  Future<void> _guardar() async {
    // Validación del formulario
    if (!_formKey.currentState!.validate()) return;
    if (horas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Añade al menos una hora')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Creación del objeto modelo
      final modelo = HorarioModelo(
        id:
            widget.modeloExistente?.id ??
            FirebaseFirestore.instance.collection('horarioModelos').doc().id,
        nombre: _nombreController.text.trim(),
        centroId: widget.centroId,
        createdBy: widget.userUid,
        createdAt: widget.modeloExistente?.createdAt,
        updatedAt: DateTime.now(),
        slots: slots,
        horas: horas,
        asignadoA: widget.modeloExistente?.asignadoA,
        asignadoNombre: widget.modeloExistente?.asignadoNombre,
        asignadoAt: widget.modeloExistente?.asignadoAt,
      );

      // Guardado en Firestore con merge
      await FirebaseFirestore.instance
          .collection('horarioModelos')
          .doc(modelo.id)
          .set(modelo.toJson(), SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modelo guardado correctamente')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.modeloExistente == null ? 'Crear Modelo' : 'Editar Modelo',
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _guardar,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Modelo (Ej: Turno Mañana)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Configuración de Horas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildHorasEditor(),
            const SizedBox(height: 24),
            const Text(
              'Configuración de Clases/Disponibilidad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSlotsGrid(),

            const SizedBox(height: 24),

            // Resumen del modelo con contador de horas
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen del modelo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Contadores: contamos celdas que existen en el mapa slots
                    Builder(
                      builder: (context) {
                        int countFijo = 0;
                        int countDisponible = 0;
                        int countVacio = 0;

                        // Recorremos los que existe en slots
                        slots.forEach((hora, diasMap) {
                          diasMap.forEach((dia, slot) {
                            // Si la celda existe (no es null)
                            if (slot != null) {
                              if (slot.estado == EstadoSlot.fijo) {
                                countFijo++;
                              } else if (slot.estado == EstadoSlot.guardia) {
                                countDisponible++;
                              } else if (slot.estado == EstadoSlot.vacio) {
                                countVacio++;
                              }
                            }
                          });
                        });

                        final totalConfiguradas =
                            countFijo + countDisponible + countVacio;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Horas fijas (clases):'),
                                Text(
                                  '$countFijo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Horas disponibles (guardias):'),
                                Text(
                                  '$countDisponible',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Horas vacías (tocadas):'),
                                Text(
                                  '$countVacio',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total configuradas:'),
                                Text(
                                  '$totalConfiguradas',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '(Total posible en la tabla: ${horas.length * dias.length})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Editor de horas con reordenamiento
  Widget _buildHorasEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Define los tramos horarios (Ej: 08:00 - 08:55)'),
            const SizedBox(height: 10),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: horas.length,
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final String item = horas.removeAt(oldIndex);
                  horas.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                return ListTile(
                  key: ValueKey(horas[index]),
                  leading: const Icon(Icons.drag_handle),
                  title: TextFormField(
                    initialValue: horas[index],
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      horas[index] = val;
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => horas.removeAt(index)),
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => horas.add('Nueva Hora')),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Hora'),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Widget para Clase Fija: Contenedor Azul con etiquetas
  Widget _buildClaseCell(String claseData) {
    // Separamos los datos (formato: Asignatura - Curso - Aula)
    final partes = claseData.split(' - ');
    final asignatura = partes.isNotEmpty ? partes[0] : '';
    final curso = partes.length > 1 ? partes[1] : '';
    final aula = partes.length > 2 ? partes[2] : '';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.blue[900]!.withOpacity(0.3)
            : Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.blue[400]!.withOpacity(0.5)
              : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asignatura.isNotEmpty)
            Text(
              'Asignatura: $asignatura',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[100]
                    : Colors.blue[900],
              ),
            ),
          if (curso.isNotEmpty)
            Text(
              'Curso: $curso',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[100]
                    : Colors.blue[900],
              ),
            ),
          if (aula.isNotEmpty)
            Text(
              'Aula: $aula',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[100]
                    : Colors.blue[900],
              ),
            ),
        ],
      ),
    );
  }

  // 2. Widget para Disponibilidad: Badge Verde
  Widget _buildDisponibilidadCell() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.green[900]!.withOpacity(0.3)
            : Colors.green[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.green[400]!.withOpacity(0.5)
              : Colors.green.shade100,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 14),
          SizedBox(width: 4),
          Text(
            'Disponible',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Grid Actualizado: Usa los nuevos widgets
  Widget _buildSlotsGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 2, // Espacio mínimo entre columnas
        horizontalMargin: 2,
        headingRowHeight: 40,
        dataRowHeight: 80, // Altura suficiente para el contenido
        columns: [
          const DataColumn(
            label: Text(
              'Hora',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...dias.map(
            (d) => DataColumn(
              label: Text(
                d,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
        rows: horas.map((hora) {
          // Aseguramos que exista la entrada para esta hora
          slots.putIfAbsent(hora, () => {});
          return DataRow(
            cells: [
              DataCell(
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    hora,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              ...dias.map((dia) {
                // Si no existe aún la celda → la creamos VACÍA por defecto
                slots[hora]!.putIfAbsent(
                  dia,
                  () => SlotData(estado: EstadoSlot.vacio, clase: null),
                );
                final slot = slots[hora]![dia]!;

                Widget contenido;

                // Lógica de visualización IDÉNTICA a HorariosPage
                if (slot.estado == EstadoSlot.fijo &&
                    slot.clase != null &&
                    slot.clase!.isNotEmpty) {
                  contenido = _buildClaseCell(slot.clase!);
                } else if (slot.estado == EstadoSlot.guardia) {
                  contenido = _buildDisponibilidadCell();
                } else {
                  // Celda Vacía (Tiene que ser clicable, pero visualmente neutra)
                  contenido = Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }

                return DataCell(
                  GestureDetector(
                    onTap: () => _editSlot(hora, dia, slot),
                    behavior: HitTestBehavior
                        .opaque, // Permite hacer click en espacios vacíos
                    child: Container(
                      width: 115, // Ancho fijo para que se vea bien la tabla
                      height: 70,
                      alignment: Alignment.center,
                      child: contenido,
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Diálogo para editar un slot específico (hora + día)
  Future<void> _editSlot(String hora, String dia, SlotData currentSlot) async {
    final ctrlAsignatura = TextEditingController(
      text: currentSlot.clase?.split('-')[0]?.trim() ?? '',
    );
    final ctrlCurso = TextEditingController(
      text: currentSlot.clase?.split('-')[1]?.trim() ?? '',
    );
    final ctrlAula = TextEditingController(
      text: currentSlot.clase?.split('-')[2]?.trim() ?? '',
    );

    EstadoSlot selectedEstado = currentSlot.estado;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('$hora - $dia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de estado con 3 opciones
              SegmentedButton<EstadoSlot>(
                segments: const [
                  ButtonSegment(
                    value: EstadoSlot.vacio,
                    label: Text('Vacío'),
                    icon: Icon(Icons.block),
                  ),
                  ButtonSegment(
                    value: EstadoSlot.guardia,
                    label: Text('Guardia'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: EstadoSlot.fijo,
                    label: Text('Fijo'),
                    icon: Icon(Icons.book),
                  ),
                ],
                selected: {selectedEstado},
                onSelectionChanged: (s) =>
                    setDialogState(() => selectedEstado = s.first),
              ),
              const SizedBox(height: 16),

              if (selectedEstado == EstadoSlot.fijo) ...[
                TextFormField(
                  controller: ctrlAsignatura,
                  decoration: const InputDecoration(labelText: 'Asignatura'),
                ),
                TextFormField(
                  controller: ctrlCurso,
                  decoration: const InputDecoration(labelText: 'Curso'),
                ),
                TextFormField(
                  controller: ctrlAula,
                  decoration: const InputDecoration(labelText: 'Aula'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  String? claseStr;
                  if (selectedEstado == EstadoSlot.fijo) {
                    claseStr =
                        '${ctrlAsignatura.text.trim()} - ${ctrlCurso.text.trim()} - ${ctrlAula.text.trim()}';
                    if (claseStr.trim().isEmpty || claseStr == ' -  - ') {
                      claseStr = null;
                      selectedEstado = EstadoSlot.vacio;
                    }
                  }
                  if (slots[hora] == null) slots[hora] = {};
                  slots[hora]![dia] = SlotData(
                    estado: selectedEstado,
                    clase: claseStr,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('Guardar Celda'),
            ),
          ],
        ),
      ),
    );
  }
}
