import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../services/system_media_service.dart';

/// Estado de la deteccion de "cualquier app de musica" via el Notification
/// Listener de Android. En plataformas que no sean Android queda inerte
/// ([supported] == false) y no toca los channels nativos.
class SystemMediaProvider extends ChangeNotifier {
  final SystemMediaService _service;

  SystemMediaProvider([SystemMediaService? service])
      : _service = service ?? SystemMediaService();

  /// Solo Android tiene esta capacidad.
  bool get supported => !kIsWeb && Platform.isAndroid;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  Track? _current;
  Track? get current => _current;

  StreamSubscription<Track?>? _sub;

  /// Se dispara con cada cancion NUEVA detectada en otras apps.
  /// En main.dart se conecta a HistoryProvider.record.
  void Function(Track track)? onNewTrack;

  /// Comprueba el permiso y, si esta concedido, empieza a escuchar.
  Future<void> init() async {
    if (!supported) return;
    await refreshPermission();
    if (_permissionGranted) _startListening();
  }

  Future<void> refreshPermission() async {
    if (!supported) return;
    _permissionGranted = await _service.isPermissionGranted();
    notifyListeners();
  }

  /// Abre Ajustes para conceder el permiso. Tras volver, llamar a
  /// [refreshPermission] (lo hace HomeScreen al reanudarse la app).
  Future<void> openSettings() async {
    if (!supported) return;
    await _service.openPermissionSettings();
  }

  void _startListening() {
    _sub?.cancel();
    _sub = _service.nowPlayingStream().listen((track) {
      final changed = track != null &&
          (_current == null || track.dedupeKey != _current!.dedupeKey);
      _current = track;
      if (changed) onNewTrack?.call(track);
      notifyListeners();
    });
  }

  /// Llamar cuando el usuario vuelve de Ajustes: si acaba de conceder el
  /// permiso, arrancamos la escucha.
  Future<void> onResume() async {
    if (!supported) return;
    final was = _permissionGranted;
    await refreshPermission();
    if (_permissionGranted && !was) _startListening();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
