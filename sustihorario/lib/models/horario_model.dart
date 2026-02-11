import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo principal para un horario, incluyendo slots, horas y asignación.
class HorarioModelo {
  final String id;
  final String nombre;
  final String centroId;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, Map<String, SlotData>> slots;
  final List<String> horas;
  // Campos nuevos para asignación
  final String? asignadoA;
  final String? asignadoNombre;
  final Timestamp? asignadoAt;

  HorarioModelo({
    required this.id,
    required this.nombre,
    required this.centroId,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    required this.slots,
    required this.horas,
    this.asignadoA,
    this.asignadoNombre,
    this.asignadoAt,
  });

  HorarioModelo copyWith({
    String? id,
    String? nombre,
    String? centroId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, Map<String, SlotData>>? slots,
    List<String>? horas,
    String? asignadoA,
    String? asignadoNombre,
    Timestamp? asignadoAt,
  }) {
    return HorarioModelo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      centroId: centroId ?? this.centroId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      slots: slots ?? this.slots,
      horas: horas ?? this.horas,
      asignadoA: asignadoA ?? this.asignadoA,
      asignadoNombre: asignadoNombre ?? this.asignadoNombre,
      asignadoAt: asignadoAt ?? this.asignadoAt,
    );
  }

  // Constructor factory desde JSON.
  factory HorarioModelo.fromJson(Map<String, dynamic> json, String docId) {
    final slotsMap = (json['slots'] as Map<String, dynamic>?) ?? {};
    final processedSlots = <String, Map<String, SlotData>>{};
    slotsMap.forEach((hora, diasMap) {
      if (diasMap is Map<String, dynamic>) {
        final dias = diasMap.map(
          (dia, slotJson) => MapEntry(
            dia,
            SlotData.fromJson(slotJson as Map<String, dynamic>),
          ),
        );
        processedSlots[hora] = dias;
      }
    });
    return HorarioModelo(
      id: docId,
      nombre: json['nombre'] ?? 'Sin nombre',
      centroId: json['centroId'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      slots: processedSlots,
      horas: List<String>.from(json['horas'] ?? []),
      asignadoA: json['asignadoA'] as String?,
      asignadoNombre: json['asignadoNombre'] as String?,
      asignadoAt: json['asignadoAt'] as Timestamp?,
    );
  }

  // Método toJson para serializar.
  Map<String, dynamic> toJson() {
    final slotsJson = slots.map(
      (hora, diasMap) => MapEntry(
        hora,
        diasMap.map((dia, slot) => MapEntry(dia, slot.toJson())),
      ),
    );
    return {
      'nombre': nombre,
      'centroId': centroId,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'slots': slotsJson,
      'horas': horas,
      'asignadoA': asignadoA,
      'asignadoNombre': asignadoNombre,
      'asignadoAt': asignadoAt,
    };
  }
}

// Enumeración para los estados posibles de un slot en el horario.
enum EstadoSlot { vacio, guardia, fijo }

// Clase que representa los datos de un slot individual en el horario.
class SlotData {
  final EstadoSlot estado;
  final String? clase;

  SlotData({required this.estado, this.clase});

  // Constructor factory para crear desde JSON.
  factory SlotData.fromJson(Map<String, dynamic> json) {
    return SlotData(
      estado: _estadoFromString(json['estado'] ?? 'no_disponible'),
      clase: json['clase'] as String?,
    );
  }

  // Método para convertir a JSON.
  Map<String, dynamic> toJson() => {
    'estado': _estadoToString(estado),
    'clase': clase,
  };

  // Conversión de string a enumeración.
  static EstadoSlot _estadoFromString(String value) {
    switch (value.toLowerCase()) {
      case 'fijo':
        return EstadoSlot.fijo;
      case 'guardia':
        return EstadoSlot.guardia;
      default:
        return EstadoSlot.vacio;
    }
  }

  // Conversión de enumeración a string.
  static String _estadoToString(EstadoSlot estado) {
    switch (estado) {
      case EstadoSlot.fijo:
        return 'fijo';
      case EstadoSlot.guardia:
        return 'guardia';
      default:
        return ' ';
    }
  }

  // Método copyWith para crear copias modificadas.
  SlotData copyWith({EstadoSlot? estado, String? clase}) {
    return SlotData(estado: estado ?? this.estado, clase: clase ?? this.clase);
  }
}
