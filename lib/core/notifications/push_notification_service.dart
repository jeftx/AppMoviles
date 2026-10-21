import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Identificador estable del canal Android usado por los avisos de NutriMenu.
const _notificationChannel = AndroidNotificationChannel(
  'nutrimenu_reminders',
  'Recordatorios de NutriMenu',
  description: 'Recordatorios de comidas y seguimiento nutricional.',
  importance: Importance.high,
);

/// Debe permanecer como una función de nivel superior para que Android pueda
/// invocarla cuando la aplicación está en segundo plano o cerrada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Los mensajes con payload `notification` se muestran automáticamente por
  // Android. Aquí se reserva el punto de extensión para futuros payloads data.
  debugPrint('Notificación en segundo plano: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Crea el canal que Android usa para avisos visibles y escucha mensajes
  /// recibidos mientras la app está abierta.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_nutrimenu'),
    );
    await _localNotifications.initialize(settings: settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_notificationChannel);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notificación abierta: ${message.messageId}');
    });
    FirebaseMessaging.instance.onRegistered.listen((installationId) {
      _logInstallationId(installationId, source: 'registrado');
    });

    _isInitialized = true;
  }

  /// Se invoca al iniciar sesión. Android 13+ mostrará el permiso del sistema.
  static Future<void> requestPermissionAndRegister() async {
    await initialize();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await FirebaseMessaging.instance.register();
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'NutriMenu AI',
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrimenu_reminders',
          'Recordatorios de NutriMenu',
          channelDescription:
              'Recordatorios de comidas y seguimiento nutricional.',
          icon: 'ic_stat_nutrimenu',
          color: Color(0xFFF0B5CC),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static void _logInstallationId(
    String installationId, {
    required String source,
  }) {
    if (kDebugMode) {
      debugPrint('Identificador FCM $source: $installationId');
    }
  }
}
