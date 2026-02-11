class CentroModel {
  // Atributos definidos
  final String id;
  final String nombre;
  final String direccion;
  final List<String> horas;

  // Constructor de la clase
  CentroModel({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.horas = const [],
  });

  /// Constructor de tipo 'factory' para crear una instancia desde un JSON.
  factory CentroModel.fromJson(Map<String, dynamic> json, String documentId) {
    return CentroModel(
      id: documentId,
      nombre: json['nombre'] ?? 'Centro sin nombre',
      direccion: json['direccion'] ?? '',
      horas: List<String>.from(json['horas'] ?? []),
    );
  }

  /// Método para convertir el objeto en un mapa (JSON).
  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'direccion': direccion, 'horas': horas};
  }
}
