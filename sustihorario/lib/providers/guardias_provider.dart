import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GuardiasProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- MÉTODOS PÚBLICOS ---

  /// Procesa la solicitud de baja completa: crea la baja y asigna guardias automáticamente.
  Future<void> solicitarBaja({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required String tipoBaja,
    required String tareas,
    required Map<String, List<String>>
    horasPorDia, // CAMBIO: Mapa Día -> Lista de Horas
    required Map<String, Map<String, String>> horarioFijo,
    required String profesorNombre,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final centroId = await _getCurrentCentroId(user.uid);
      if (centroId == null) throw Exception('Usuario no tiene centro asignado');

      // 1. Validaciones previas (Duplicados)
      await _validarDuplicados(user.uid, fechaInicio, fechaFin);

      // 2. Obtener límite de guardias
      final limiteGuardias = await _obtenerLimiteGuardias(centroId);

      // Aplanar horas para guardar en BD (solo informativo)
      final List<String> horasAfectadasFlat = [];
      horasPorDia.forEach((dia, horas) {
        for (var h in horas) {
          horasAfectadasFlat.add('$dia: $h');
        }
      });

      // 3. Crear documento de BAJA
      final bajaRef = await _firestore.collection('bajas').add({
        'profesorUid': user.uid,
        'profesorNombre': profesorNombre,
        'tipo': tipoBaja,
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'horasAfectadas':
            horasAfectadasFlat, // Guardamos con día para referencia
        'tareasParaSustituto': tareas,
        'estado': 'pendiente',
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Procesar GUARDIAS (Asignación automática)
      final Map<String, int> contadorGuardiasTemporales = {};

      for (var entry in horasPorDia.entries) {
        final diaNombre = entry.key;
        final listaHoras = entry.value;

        // Buscamos las fechas dentro del rango que coinciden con este nombre de día
        List<DateTime> fechasParaEsteDia = _obtenerFechasParaDia(
          diaNombre,
          fechaInicio,
          fechaFin,
        );

        for (DateTime fecha in fechasParaEsteDia) {
          for (String horaCompleta in listaHoras) {
            await _procesarHoraIndividual(
              diaEspecifico: diaNombre, // Pasamos el día explícito
              horaCompleta: horaCompleta,
              horarioFijo: horarioFijo,
              centroId: centroId,
              limiteGuardias: limiteGuardias,
              user: user,
              profesorNombre: profesorNombre,
              bajaRef: bajaRef,
              fechaInicio: fecha, // Usamos la fecha concreta de ese día
              tareas: tareas,
              contadorGuardiasTemporales: contadorGuardiasTemporales,
            );
          }
        }
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- MÉTODOS PRIVADOS (Lógica de Negocio) ---

  // Helper para calcular fechas
  List<DateTime> _obtenerFechasParaDia(
    String diaNombre,
    DateTime inicio,
    DateTime fin,
  ) {
    List<DateTime> fechas = [];
    DateTime current = DateTime(inicio.year, inicio.month, inicio.day);
    DateTime end = DateTime(fin.year, fin.month, fin.day);

    // Mapeo de nombres a int (Lunes=1, ...)
    final mapDias = {
      'Lunes': 1,
      'Martes': 2,
      'Miércoles': 3,
      'Jueves': 4,
      'Viernes': 5,
      'Sábado': 6,
      'Domingo': 7,
    };
    final targetWeekday = mapDias[diaNombre];

    if (targetWeekday == null) return [];

    while (!current.isAfter(end)) {
      if (current.weekday == targetWeekday) {
        fechas.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return fechas;
  }

  Future<void> _procesarHoraIndividual({
    required String diaEspecifico, // NUEVO
    required String horaCompleta,
    required Map<String, Map<String, String>> horarioFijo,
    required String centroId,
    required int limiteGuardias,
    required User user,
    required String profesorNombre,
    required DocumentReference bajaRef,
    required DateTime fechaInicio,
    required String tareas,
    required Map<String, int> contadorGuardiasTemporales,
  }) async {
    // Desglosar string "08:00 - Matemáticas"
    final parts = horaCompleta.split(' - ');
    if (parts.length < 2) return;

    final hora = parts[0].trim();
    final asignatura = parts[1].trim();
    String curso = '';
    String aula = '';

    // Buscar curso y aula en el horario fijo pero USANDO EL DÍA ESPECÍFICO
    // Ya no buscamos en todo el mapa, vamos directos al día
    if (horarioFijo.containsKey(hora)) {
      final diasMap = horarioFijo[hora];
      if (diasMap != null && diasMap.containsKey(diaEspecifico)) {
        final claseValue = diasMap[diaEspecifico]!;
        // Verificamos que coincida (debería, porque viene de ahí)
        if ('$hora - $claseValue' == horaCompleta) {
          final claseParts = claseValue.split(' - ');
          if (claseParts.length >= 2) curso = claseParts[1].trim();
          if (claseParts.length >= 3) {
            aula = claseParts[2].trim().replaceFirst('Aula ', '');
          }
        }
      }
    }

    // Usamos diaEspecifico directamente
    final diaEncontrado = diaEspecifico;

    // BUSCAR CANDIDATOS
    List<Map<String, dynamic>> candidatos = await _buscarCandidatos(
      centroId: centroId,
      dia: diaEncontrado,
      hora: hora,
      userUid: user.uid,
      limiteGuardias: limiteGuardias,
      fechaInicio: fechaInicio,
      fechaFin: fechaInicio, // Chequeamos conflicto solo en el día de inicio
      contadorGuardiasTemporales: contadorGuardiasTemporales,
    );

    // FALLBACK si no hay nadie
    bool esFallback = false;
    if (candidatos.isEmpty) {
      candidatos = await _buscarCandidatosFallback(
        dia: diaEncontrado,
        hora: hora,
        centroId: centroId,
        limiteGuardias: limiteGuardias,
        userUid: user.uid,
        fechaInicio: fechaInicio,
      );
      esFallback = true;
    }

    // ASIGNAR O DEJAR PENDIENTE
    if (candidatos.isNotEmpty) {
      // Ordenar por menos carga
      candidatos.sort(
        (a, b) => a['guardiasCount'].compareTo(b['guardiasCount']),
      );
      final elegido = candidatos.first;
      final sustitutoUid = elegido['uid'] as String;
      String sustitutoNombre = elegido['nombreBase'] as String;

      // Obtener nombre real si es necesario
      if (sustitutoNombre == 'Profesor disponible') {
        final userDoc = await _firestore
            .collection('users')
            .doc(sustitutoUid)
            .get();
        sustitutoNombre = userDoc.data()?['nombre'] ?? 'Sustituto';
      }

      await _firestore.collection('guardias').add({
        'bajaId': bajaRef.id,
        'profesorAusenteUid': user.uid,
        'profesorAusenteNombre': profesorNombre,
        'sustitutoUid': sustitutoUid,
        'sustitutoNombre': sustitutoNombre,
        'dia': diaEncontrado,
        'hora': hora,
        'aula': aula,
        'curso': curso,
        'asignatura': asignatura,
        'tareas': tareas,
        'tipo': esFallback ? 'Automática (Fallback)' : 'Automática',
        'fecha': DateFormat('dd/MM/yyyy').format(fechaInicio),
        'estado': 'asignada',
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar contador temporal
      contadorGuardiasTemporales.update(
        sustitutoUid,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      if (esFallback) {
        await _notificarCoordinador(
          centroId: centroId,
          titulo: 'Guardia asignada por Fallback',
          mensaje:
              '$asignatura - $curso\n$diaEncontrado $hora → $sustitutoNombre (posible sobrecarga)',
          tipo: 'guardia_fallback',
        );
      }
    } else {
      // SIN CANDIDATOS -> PENDIENTE
      await _firestore.collection('guardias').add({
        'bajaId': bajaRef.id,
        'profesorAusenteUid': user.uid,
        'profesorAusenteNombre': profesorNombre,
        'sustitutoUid': '',
        'sustitutoNombre': 'PENDIENTE ASIGNACIÓN',
        'dia': diaEncontrado,
        'hora': hora,
        'aula': aula.isEmpty ? '-' : aula,
        'curso': curso,
        'asignatura': asignatura,
        'tareas': tareas,
        'tipo': 'Sin Sustituto (Pendiente)',
        'fecha': DateFormat('dd/MM/yyyy').format(fechaInicio),
        'estado': 'pendiente',
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _notificarCoordinador(
        centroId: centroId,
        titulo: '¡URGENTE! Guardia sin asignar',
        mensaje:
            'No se encontró sustituto para $asignatura - $curso ($diaEncontrado $hora)',
        tipo: 'guardia_sin_asignar',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _buscarCandidatos({
    required String centroId,
    required String dia,
    required String hora,
    required String userUid,
    required int limiteGuardias,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required Map<String, int> contadorGuardiasTemporales,
  }) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('centroId', isEqualTo: centroId)
        .get();

    List<Map<String, dynamic>> candidatos = [];

    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      if (userData['role'] != 'profesor') continue;
      if (userDoc.id == userUid) continue;

      // 1. Disponibilidad Horaria
      final horarioDoc = await _firestore
          .collection('horarios')
          .doc(userDoc.id)
          .get();
      if (!horarioDoc.exists) continue;

      final data = horarioDoc.data()!;
      final disponibilidad =
          data['disponibilidad'] as Map<String, dynamic>? ?? {};
      final horaMap = disponibilidad[hora] as Map<String, dynamic>?;

      if (horaMap == null || horaMap[dia] != true) continue;

      // 2. Carga de trabajo (Guardias esta semana)
      int countEstaSemana = await _obtenerCountGuardiasEstaSemana(userDoc.id);
      countEstaSemana += contadorGuardiasTemporales[userDoc.id] ?? 0;

      if (countEstaSemana >= limiteGuardias) continue;

      // 3. Que no esté de baja él mismo
      final deBaja = await _profesorEstaDeBaja(
        userDoc.id,
        fechaInicio,
        fechaFin,
      );
      if (deBaja) continue;

      candidatos.add({
        'uid': userDoc.id,
        'nombreBase': userData['nombre'] ?? 'Sustituto',
        'guardiasCount': countEstaSemana,
      });
    }
    return candidatos;
  }

  Future<List<Map<String, dynamic>>> _buscarCandidatosFallback({
    required String dia,
    required String hora,
    required String centroId,
    required int limiteGuardias,
    required String userUid,
    required DateTime fechaInicio,
  }) async {
    // Implementación real: ignoramos límite de guardias (ponemos 999) para encontrar a ALGUIEN.
    final candidates = await _buscarCandidatos(
      centroId: centroId,
      dia: dia,
      hora: hora,
      userUid: userUid,
      limiteGuardias: 999, // <--- TRUCO: Fallback ignora límite de guardias
      fechaInicio: fechaInicio,
      fechaFin: fechaInicio,
      contadorGuardiasTemporales: {},
    );
    return candidates;
  }

  // --- HERRAMIENTAS ---

  Future<String?> _getCurrentCentroId(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['centroId'] as String?;
  }

  Future<int> _obtenerLimiteGuardias(String centroId) async {
    try {
      final doc = await _firestore.collection('centros').doc(centroId).get();
      return doc.data()?['config']?['limiteGuardiasSemanal'] as int? ?? 999;
    } catch (_) {
      return 999;
    }
  }

  Future<int> _obtenerCountGuardiasEstaSemana(String uid) async {
    // Calcular rango semana
    final now = DateTime.now();
    final inicio = now.subtract(Duration(days: now.weekday - 1));
    final fin = inicio.add(const Duration(days: 6));
    final startOfWeek = DateTime(inicio.year, inicio.month, inicio.day);
    final endOfWeek = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);

    final snap = await _firestore
        .collection('guardias')
        .where('sustitutoUid', isEqualTo: uid)
        .get();

    int count = 0;
    for (var doc in snap.docs) {
      final fechaStr = doc['fecha'] as String?;
      if (fechaStr == null) continue;
      try {
        final fecha = DateFormat('dd/MM/yyyy').parse(fechaStr);
        if (!fecha.isBefore(startOfWeek) && !fecha.isAfter(endOfWeek)) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<bool> _profesorEstaDeBaja(
    String uid,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _firestore
        .collection('bajas')
        .where('profesorUid', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .get(); // Traemos todas y filtramos fecha en memoria para mayor seguridad con queries complejas

    for (var doc in snap.docs) {
      final dInicio = (doc['fechaInicio'] as Timestamp).toDate();
      final dFin = (doc['fechaFin'] as Timestamp).toDate();
      // Solapamiento
      if (!(fin.isBefore(dInicio) || inicio.isAfter(dFin))) {
        return true;
      }
    }
    return false;
  }

  Future<void> _validarDuplicados(
    String uid,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _firestore
        .collection('bajas')
        .where('profesorUid', isEqualTo: uid)
        .where('estado', whereIn: ['pendiente', 'aprobada'])
        .get();

    for (var doc in snap.docs) {
      final existingInicio = (doc['fechaInicio'] as Timestamp).toDate();
      final existingFin = (doc['fechaFin'] as Timestamp).toDate();
      if (!(fin.isBefore(existingInicio) || inicio.isAfter(existingFin))) {
        throw Exception('Ya tienes una solicitud activa en este periodo');
      }
    }
  }

  Future<void> _notificarCoordinador({
    required String centroId,
    required String titulo,
    required String mensaje,
    required String tipo,
  }) async {
    final coords = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'coordinador')
        .where('centroId', isEqualTo: centroId)
        .get();

    final batch = _firestore.batch();
    for (var doc in coords.docs) {
      final ref = _firestore.collection('notificaciones').doc();
      batch.set(ref, {
        'tipo': tipo,
        'mensaje': '$titulo\n$mensaje',
        'destinatarioUid': doc.id,
        'leida': false,
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
