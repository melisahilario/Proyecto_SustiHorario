import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sustihorario/models/horario_model.dart';

// Servicio para manejar operaciones relacionadas con modelos de horarios en Firestore.
class HorarioProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'horarioModelos';

  // Obtiene el centroId del usuario actual de forma privada.
  Future<String?> _getCurrentCentroId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['centroId'] as String?;
  }

  // Obtiene un stream de todos los modelos de horarios del centro actual, ordenados por creación descendente.
  Stream<List<HorarioModelo>> getModelosDelCentro() async* {
    final centroId = await _getCurrentCentroId();
    if (centroId == null) {
      yield [];
      return;
    }
    yield* _firestore
        .collection(_collection)
        .where('centroId', isEqualTo: centroId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HorarioModelo.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Guarda un modelo nuevo o actualiza uno existente, asegurando el centroId.
  Future<String> guardarModelo(
    HorarioModelo modelo, {
    String? idExistente,
  }) async {
    final centroId = await _getCurrentCentroId();
    if (centroId == null) {
      throw Exception('No se encontró centro asociado al usuario');
    }
    final data = modelo.toJson();
    data['centroId'] = centroId; // Asegura que siempre tenga centroId
    if (idExistente != null && idExistente.isNotEmpty) {
      await _firestore
          .collection(_collection)
          .doc(idExistente)
          .set(data, SetOptions(merge: true));
      return idExistente;
    } else {
      final ref = await _firestore.collection(_collection).add(data);
      return ref.id;
    }
  }

  // Elimina un modelo de horario por ID.
  Future<void> eliminarModelo(String modeloId) async {
    await _firestore.collection(_collection).doc(modeloId).delete();
  }
}
