import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class CalendarioService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin =
      DeviceCalendarPlugin();

  /// Inicializa la base de datos de zonas horarias.
  static void inicializarZonasHorarias() {
    tz_data.initializeTimeZones();
  }

  /// Solicita permisos y añade una guardia al calendario.
  static Future<bool> agregarGuardiaAlCalendario({
    required String titulo,
    required String descripcion,
    required String fechaStr, // dd/MM/yyyy
    required String horaStr, // HH:mm o HH:mm-HH:mm
  }) async {
    try {
      // 1. Verificar permisos
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return false;
        }
      }

      // 2. Buscar calendario por defecto (o el primero disponible)
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data!.isEmpty) {
        return false;
      }

      // Intentamos usar un calendario "Primario" o el primero de la lista
      final calendar = calendarsResult.data!.firstWhere(
        (c) => c.isDefault ?? false,
        orElse: () => calendarsResult.data!.first,
      );

      // 3. Parsear fecha y hora
      final DateFormat formatter = DateFormat('dd/MM/yyyy');
      final DateTime fechaBase = formatter.parse(fechaStr);

      // Extraer hora de inicio (asumimos formato HH:mm... o HH:mm-HH:mm)
      final String horaInicioStr = horaStr.split('-').first.trim();
      final List<String> partesHora = horaInicioStr.split(':');
      final int hora = int.parse(partesHora[0]);
      final int minuto = int.parse(partesHora[1]);

      final DateTime startDateTime = DateTime(
        fechaBase.year,
        fechaBase.month,
        fechaBase.day,
        hora,
        minuto,
      );

      final DateTime endDateTime = startDateTime.add(const Duration(hours: 1));

      // 4. Crear el evento
      final Event event = Event(
        calendar.id,
        title: titulo,
        description: descripcion,
        start: tz.TZDateTime.from(startDateTime, tz.local),
        end: tz.TZDateTime.from(endDateTime, tz.local),
      );

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      return result?.isSuccess ?? false;
    } catch (e) {
      debugPrint('Error al sincronizar con calendario: $e');
      return false;
    }
  }
}
