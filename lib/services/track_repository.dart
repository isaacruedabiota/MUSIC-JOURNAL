import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';

/// Historial de canciones. Lo escribe la parte nativa (SpotifyListenerService)
/// aunque la app esté cerrada; aquí solo se lee y se reciben las novedades.
class TrackRepository extends ChangeNotifier {
  static const _tracks = MethodChannel('musiclist/tracks');
  static const _updates = EventChannel('musiclist/track_updates');

  final List<Track> _items = [];
  StreamSubscription<Object?>? _subscription;

  /// IDs quitados de la lista con [remove] que aún no se han borrado.
  final Set<String> _removed = {};

  /// Canciones guardadas, de la más reciente a la más antigua.
  late final List<Track> tracks = UnmodifiableListView(_items);

  /// Carga el historial y empieza a recibir en directo las canciones nuevas.
  Future<void> load() async {
    // Suscribirse antes de leer para no perder nada que llegue entre medias.
    _subscription ??= _updates.receiveBroadcastStream().listen(_onUpdate);
    final rows =
        await _tracks.invokeListMethod<Map<Object?, Object?>>('getAll') ??
        const [];
    _items
      ..clear()
      ..addAll(rows.map(Track.fromMap).where((t) => !_removed.contains(t.id)));
    notifyListeners();
  }

  /// Quita la canción de la lista. No se borra del móvil hasta [delete], así
  /// que [restore] puede devolverla tal cual (el «Deshacer»).
  void remove(Track track) {
    _removed.add(track.id);
    _items.removeWhere((t) => t.id == track.id);
    notifyListeners();
  }

  /// Devuelve a su sitio una canción quitada con [remove].
  void restore(Track track) {
    if (!_removed.remove(track.id)) return;
    final index = _items.indexWhere(
      (t) => t.detectedAt.isBefore(track.detectedAt),
    );
    _items.insert(index < 0 ? _items.length : index, track);
    notifyListeners();
  }

  /// Borra del móvil (fila y portada) una canción quitada con [remove].
  Future<void> delete(Track track) async {
    await _tracks.invokeMethod<void>('delete', track.id);
    _removed.remove(track.id);
  }

  /// Cambia la marca `descargado`, que mueve la canción entre «Sin procesar»
  /// y «Procesadas». La lista cambia al momento; el móvil, justo después.
  Future<void> setDescargado(Track track, bool value) async {
    final index = _items.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(descargado: value);
      notifyListeners();
    }
    await _tracks.invokeMethod<void>('setDescargado', {
      'id': track.id,
      'value': value,
    });
  }

  void _onUpdate(Object? event) {
    final track = Track.fromMap(event! as Map<Object?, Object?>);
    if (_removed.contains(track.id)) return; // pendiente de borrar
    final index = _items.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      _items[index] = track; // ya estaba: p. ej. su portada llegó más tarde
    } else {
      _items.insert(0, track);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
