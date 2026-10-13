import 'package:flutter/services.dart';

/// Permisos de Android que necesita el servicio para funcionar en segundo plano.
abstract final class Permissions {
  static const _channel = MethodChannel('musiclist/permissions');

  /// «Acceso a notificaciones»: imprescindible para leer la sesión de Spotify.
  static Future<bool> hasNotificationAccess() async =>
      await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;

  static Future<void> openNotificationAccess() =>
      _channel.invokeMethod('openNotificationAccess');

  /// Sin optimización de batería, fabricantes como Xiaomi, Samsung o Huawei no
  /// duermen el servicio con la pantalla apagada. Recomendado, no obligatorio.
  static Future<bool> isBatteryUnrestricted() async =>
      await _channel.invokeMethod<bool>('isBatteryUnrestricted') ?? false;

  static Future<void> requestBatteryUnrestricted() =>
      _channel.invokeMethod('requestBatteryUnrestricted');
}
