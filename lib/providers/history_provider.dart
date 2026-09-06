import 'package:flutter/foundation.dart';

import '../data/listening_repository.dart';
import '../models/listening_entry.dart';
import '../models/listening_stats.dart';
import '../models/track.dart';

/// Expone a la UI el historial de escuchas y sus estadisticas.
/// Se alimenta del [ListeningRepository]; el enganche con Spotify se hace
/// en main.dart conectando NowPlayingProvider.onNewTrack -> [record].
class HistoryProvider extends ChangeNotifier {
  final ListeningRepository _repo;

  HistoryProvider(this._repo);

  List<ListeningEntry> _entries = [];
  List<ListeningEntry> get entries => _entries;

  ListeningStats _stats = ListeningStats.empty;
  ListeningStats get stats => _stats;

  bool _loading = false;
  bool get loading => _loading;

  /// Carga inicial desde la base de datos.
  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _entries = await _repo.allEntries();
    _recompute();
    _loading = false;
    notifyListeners();
  }

  /// Guarda una escucha nueva (llamado desde onNewTrack) y refresca la UI.
  /// Ignora duplicados recientes entre fuentes (Spotify API vs listener Android).
  Future<void> record(Track track) async {
    final now = DateTime.now();
    final last = _entries.isNotEmpty ? _entries.first : null;
    if (isDuplicatePlay(track: track, lastEntry: last, now: now)) return;

    await _repo.recordPlay(track, at: now);
    // Insertamos al principio (mas reciente) sin releer toda la DB.
    _entries = [ListeningEntry.fromTrack(track, at: now), ..._entries];
    _recompute();
    notifyListeners();
  }

  /// ¿Ya se ha escuchado antes esta cancion? (base para "¿ya la tengo?").
  bool alreadyHeard(Track track) =>
      _entries.any((e) => e.dedupeKey == track.dedupeKey);

  Future<void> clear() async {
    await _repo.clear();
    _entries = [];
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    _stats = ListeningStats.from(_entries);
  }
}
