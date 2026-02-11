import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificacionesService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Inicializa las notificaciones y solicita permisos
  static Future<void> inicializar() async {
    // 1. Solicitar permisos (especialmente importante en iOS/Web)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('Permiso concedido para notificaciones');
      }

      // 2. Obtener el Token y guardarlo
      _actualizarToken();
    } else {
      if (kDebugMode) {
        print('Permiso denegado por el usuario');
      }
    }

    // 3. Configurar listeners de primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print(
          'Mensaje recibido en primer plano: ${message.notification?.title}',
        );
      }
      // Aquí podrías mostrar un banner local o actualizar la UI
    });

    // 4. Configurar listener cuando se abre la app desde una notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('App abierta desde notificación: ${message.data}');
      }
      // Aquí podrías navegar a una pantalla específica
    });
  }

  /// Obtiene el token del dispositivo y lo guarda en el perfil del usuario
  static Future<void> _actualizarToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'ultimaActividad': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        print('Token FCM actualizado: $token');
      }
    }
  }

  /// Permite suscribirse a temas (ej: suscripción a avisos del centro)
  static Future<void> suscribirATema(String tema) async {
    await _messaging.subscribeToTopic(tema);
  }
}
