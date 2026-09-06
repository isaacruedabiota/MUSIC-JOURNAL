import 'package:flutter/services.dart';

import '../models/track.dart';

/// Nombres "bonitos" para las apps de musica mas comunes (por packageName).
String friendlyAppName(String? packageName) {
  switch (packageName) {
    case 'com.spotify.music':
      return 'Spotify';
    case 'com.google.android.apps.youtube.music':
      return 'YouTube Music';
    case 'com.google.android.youtube':
      return 'YouTube';
    case 'com.apple.android.music':
      return 'Apple Music';
    case 'deezer.android.app':
      return 'Deezer';
    case 'com.amazon.mp3':
      return 'Amazon Music';
    case 'com.aspiro.tidal':
      return 'TIDAL';
    case 'com.soundcloud.android':
      return 'SoundCloud';
    case null:
      return 'otra app';
    default:
      return packageName;
  }
}

/// Puente con el codigo nativo de Android que lee "que suena ahora" en
/// CUALQUIER app de musica (via MediaSessionManager + NotificationListener).
///
/// Solo tiene sentido en Android. En iOS estos channels no existen; el caller
/// debe evitar usarlo (ver SystemMediaProvider, que lo protege con Platform).
class SystemMediaService {
  static const _method = MethodChannel('music_journal/media');
  static const _events = EventChannel('music_journal/media_events');

  /// ¿El usuario concedio "Acceso a notificaciones"?
  Future<bool> isPermissionGranted() async {
    final granted = await _method.invokeMethod<bool>('isPermissionGranted');
    return granted ?? false;
  }

  /// Abre la pantalla de Ajustes para conceder el permiso.
  Future<void> openPermissionSettings() =>
      _method.invokeMethod('openPermissionSettings');

  /// Lectura puntual de la cancion actual (o null).
  Future<Track?> getNowPlaying() async {
    final map = await _method.invokeMapMethod<String, dynamic>('getNowPlaying');
    return _trackFromMap(map);
  }

  /// Stream de cambios de "que suena ahora" (null = nada sonando).
  Stream<Track?> nowPlayingStream() {
    return _events
        .receiveBroadcastStream()
        .map((event) => _trackFromMap(_asStringMap(event)));
  }

  Map<String, dynamic>? _asStringMap(dynamic event) {
    if (event is Map) {
      return event.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Track? _trackFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final title = map['title'] as String?;
    if (title == null || title.isEmpty) return null;

    final pkg = map['packageName'] as String?;
    final durationRaw = map['durationMs'];
    return Track(
      title: title,
      artist: (map['artist'] as String?) ?? '',
      album: (map['album'] as String?) ?? '',
      durationMs: durationRaw is int ? durationRaw : (durationRaw as num?)?.toInt(),
      isPlaying: (map['isPlaying'] as bool?) ?? false,
      // Guardamos el packageName como fuente para saber de que app vino.
      source: pkg ?? 'system',
    );
  }
}
