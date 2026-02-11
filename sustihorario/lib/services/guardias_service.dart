import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GuardiasService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calcula el rango de la semana (Lunes a Domingo) para una fecha dada.
  static Map<String, DateTime> getRangoSemana(DateTime fecha) {
    final int diaSemana = fecha.weekday;
    final DateTime lunes = fecha.subtract(Duration(days: diaSemana - 1));
    final DateTime domingo = lunes.add(const Duration(days: 6));

    return {
      'inicio': DateTime(lunes.year, lunes.month, lunes.day),
      'fin': DateTime(domingo.year, domingo.month, domingo.day, 23, 59, 59),
    };
  }

  /// Cuenta las guardias de un profesor en la semana de la [fechaReferencia].
  static Future<int> obtenerCountGuardiasSemana(
    String uid,
    DateTime fechaReferencia,
  ) async {
    final snap = await _firestore
        .collection('guardias')
        .where('sustitutoUid', isEqualTo: uid)
        .get();

    if (snap.docs.isEmpty) return 0;

    final rango = getRangoSemana(fechaReferencia);
    final inicio = rango['inicio']!;
    final fin = rango['fin']!;

    int count = 0;
    for (var doc in snap.docs) {
      final data = doc.data();
      final fechaStr = data['fecha'] as String?;
      final estado = data['estado'] as String?;

      // Solo contamos las guardias que están realmente asignadas (no las pendientes de asignar o canceladas)
      if (fechaStr == null || estado != 'asignada') continue;

      try {
        final fechaGuardia = DateFormat('dd/MM/yyyy').parse(fechaStr);
        if (!fechaGuardia.isBefore(inicio) && !fechaGuardia.isAfter(fin)) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  /// Obtiene todas las fechas dentro de un rango que coinciden con un nombre de día (ej: 'Lunes').
  static List<DateTime> obtenerFechasParaDia(
    String diaNombre,
    DateTime inicio,
    DateTime fin,
  ) {
    List<DateTime> fechas = [];
    DateTime current = DateTime(inicio.year, inicio.month, inicio.day);
    DateTime end = DateTime(fin.year, fin.month, fin.day);

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

  /// Busca candidatos para una guardia específica.
  static Future<List<Map<String, dynamic>>> buscarCandidatos({
    required String centroId,
    required String dia,
    required String hora,
    required String? excluirUid,
    required int limiteGuardias,
    required DateTime fechaConcreta,
    Map<String, int>? contadorTemporal,
  }) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('centroId', isEqualTo: centroId)
        .where(
          'role',
          whereIn: ['profesor', 'Profesor'],
        ) // Manejamos posible inconsistencia de mayúsculas
        .get();

    List<Map<String, dynamic>> candidatos = [];

    for (var userDoc in usersSnapshot.docs) {
      if (userDoc.id == excluirUid) continue;

      // 1. Disponibilidad
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

      // 2. Carga de trabajo
      int countSemana = await obtenerCountGuardiasSemana(
        userDoc.id,
        fechaConcreta,
      );
      countSemana += (contadorTemporal?[userDoc.id] ?? 0);

      if (countSemana >= limiteGuardias) continue;

      // 3. No estar de baja
      final deBaja = await _profesorEstaDeBaja(userDoc.id, fechaConcreta);
      if (deBaja) continue;

      candidatos.add({
        'uid': userDoc.id,
        'nombre': userDoc.data()['nombre'] ?? 'Profesor',
        'guardiasCount': countSemana,
      });
    }

    return candidatos;
  }

  static Future<bool> _profesorEstaDeBaja(String uid, DateTime fecha) async {
    final snap = await _firestore
        .collection('bajas')
        .where('profesorUid', isEqualTo: uid)
        .where('estado', isEqualTo: 'pendiente')
        .get();

    for (var doc in snap.docs) {
      final inicio = (doc['fechaInicio'] as Timestamp).toDate();
      final fin = (doc['fechaFin'] as Timestamp).toDate();

      final inicioD = DateTime(inicio.year, inicio.month, inicio.day);
      final finD = DateTime(fin.year, fin.month, fin.day);
      final targetD = DateTime(fecha.year, fecha.month, fecha.day);

      if (!targetD.isBefore(inicioD) && !targetD.isAfter(finD)) {
        return true;
      }
    }
    return false;
  }

  /// Procesa la creación de una guardia, buscando sustituto o marcándola como pendiente.
  static Future<void> procesarCreacionGuardia({
    required String bajaId,
    required String centroId,
    required String profesorAusenteUid,
    required String profesorAusenteNombre,
    required String dia,
    required String hora,
    required String asignatura,
    required String curso,
    required String aula,
    required String tareas,
    required DateTime fecha,
    required int limiteGuardias,
    Map<String, int>? contadorTemporal,
  }) async {
    // Intentar candidatos normales
    List<Map<String, dynamic>> candidatos = await buscarCandidatos(
      centroId: centroId,
      dia: dia,
      hora: hora,
      excluirUid: profesorAusenteUid,
      limiteGuardias: limiteGuardias,
      fechaConcreta: fecha,
      contadorTemporal: contadorTemporal,
    );

    bool esFallback = false;
    if (candidatos.isEmpty) {
      // Intentar fallback (ignorando carga de trabajo o similar)
      candidatos = await buscarCandidatos(
        centroId: centroId,
        dia: dia,
        hora: hora,
        excluirUid: profesorAusenteUid,
        limiteGuardias: 999, // Fallback
        fechaConcreta: fecha,
      );
      esFallback = true;
    }

    if (candidatos.isNotEmpty) {
      candidatos.sort(
        (a, b) => a['guardiasCount'].compareTo(b['guardiasCount']),
      );
      final elegido = candidatos.first;

      await _firestore.collection('guardias').add({
        'bajaId': bajaId,
        'profesorAusenteUid': profesorAusenteUid,
        'profesorAusenteNombre': profesorAusenteNombre,
        'sustitutoUid': elegido['uid'],
        'sustitutoNombre': elegido['nombre'],
        'dia': dia,
        'hora': hora,
        'aula': aula,
        'curso': curso,
        'asignatura': asignatura,
        'tareas': tareas,
        'tipo': esFallback ? 'Automática (Fallback)' : 'Automática',
        'fecha': DateFormat('dd/MM/yyyy').format(fecha),
        'estado': 'asignada',
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notificar al sustituto elegido
      await _notificarSustituto(
        sustitutoUid: elegido['uid'],
        centroId: centroId,
        mensaje:
            'Se te ha asignado una guardia de $asignatura ($curso) para el $dia a las $hora. Revisa los detalles en la Atalaya.',
      );

      if (contadorTemporal != null) {
        contadorTemporal[elegido['uid']] =
            (contadorTemporal[elegido['uid']] ?? 0) + 1;
      }

      if (esFallback) {
        await _notificarCoordinador(
          centroId: centroId,
          tipo: 'guardia_fallback',
          mensaje:
              'Guardia Fallback: $asignatura - $curso ($dia $hora) -> ${elegido['nombre']}',
        );
      }
    } else {
      // Sin sustituto -> Pendiente
      await _firestore.collection('guardias').add({
        'bajaId': bajaId,
        'profesorAusenteUid': profesorAusenteUid,
        'profesorAusenteNombre': profesorAusenteNombre,
        'sustitutoUid': '',
        'sustitutoNombre': 'PENDIENTE ASIGNACIÓN',
        'dia': dia,
        'hora': hora,
        'aula': aula,
        'curso': curso,
        'asignatura': asignatura,
        'tareas': tareas,
        'tipo': 'Sin Sustituto (Pendiente)',
        'fecha': DateFormat('dd/MM/yyyy').format(fecha),
        'estado': 'pendiente',
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _notificarCoordinador(
        centroId: centroId,
        tipo: 'guardia_sin_asignar',
        mensaje:
            'URGENTE: Guardia sin asignar: $asignatura - $curso ($dia $hora)',
      );
    }
  }

  static Future<void> _notificarCoordinador({
    required String centroId,
    required String tipo,
    required String mensaje,
  }) async {
    final coords = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'coordinador')
        .where('centroId', isEqualTo: centroId)
        .get();

    for (var coord in coords.docs) {
      await _firestore.collection('notificaciones').add({
        'tipo': tipo,
        'mensaje': mensaje,
        'destinatarioUid': coord.id,
        'leida': false,
        'centroId': centroId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Reasigna una guardia manualmente.
  static Future<void> reasignarGuardia({
    required String guardiaId,
    required String sustitutoUid,
    required String sustitutoNombre,
    required String tipo,
  }) async {
    await _firestore.collection('guardias').doc(guardiaId).update({
      'sustitutoUid': sustitutoUid,
      'sustitutoNombre': sustitutoNombre,
      'estado': 'asignada',
      'tipo': tipo,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notificar al nuevo sustituto
    await _notificarSustituto(
      sustitutoUid: sustitutoUid,
      centroId:
          '', // Buscaremos el centro del usuario o lo pasamos si está disponible
      mensaje: 'Se te ha reasignado una guardia a tu nombre: $tipo.',
    );
  }

  /// Pone una guardia en el mercado de intercambio.
  static Future<void> ofrecerParaIntercambio({
    required String guardiaId,
  }) async {
    await _firestore.collection('guardias').doc(guardiaId).update({
      'estado': 'en_intercambio',
      'enIntercambioDesde': FieldValue.serverTimestamp(),
    });
  }

  /// Reclama una guardia del mercado de intercambio.
  static Future<void> reclamarIntercambio({
    required String guardiaId,
    required String nuevoSustitutoUid,
    required String nuevoSustitutoNombre,
    required String centroId,
  }) async {
    await _firestore.collection('guardias').doc(guardiaId).update({
      'sustitutoUid': nuevoSustitutoUid,
      'sustitutoNombre': nuevoSustitutoNombre,
      'estado': 'asignada',
      'tipo': 'Intercambio',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notificar al nuevo sustituto
    await _notificarSustituto(
      sustitutoUid: nuevoSustitutoUid,
      centroId: centroId,
      mensaje: 'Has reclamado con éxito una guardia del mercado.',
    );
  }

  /// Envía una notificación interna al sustituto (se guarda en Firestore)
  static Future<void> _notificarSustituto({
    required String sustitutoUid,
    required String centroId,
    required String mensaje,
  }) async {
    await _firestore.collection('notificaciones').add({
      'tipo': 'guardia_asignada',
      'mensaje': mensaje,
      'destinatarioUid': sustitutoUid,
      'leida': false,
      'centroId': centroId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
