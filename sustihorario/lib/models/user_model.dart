class UserModel {
  // Atributos
  final String uid;
  final String nombre;
  final String rol;
  final String? centroId;
  final String? email;

  /// Constructor
  UserModel({
    required this.uid,
    required this.nombre,
    required this.rol,
    this.centroId,
    this.email,
  });

  /// Constructor factory desde JSON.
  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      nombre: json['nombre'] ?? 'Usuario sin nombre',
      rol: json['role'] ?? json['rol'] ?? 'profesor',
      centroId: json['centroId'],
      email: json['email'],
    );
  }

  /// Método para convertir el objeto en un mapa (JSON).
  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'rol': rol, 'centroId': centroId, 'email': email};
  }
}
