import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/archive_item.dart';
import '../models/downloaded_track.dart';
import '../services/archive_service.dart';
import '../services/download_service.dart';
import '../services/library_store.dart';

/// Estado de la biblioteca offline legal: descargas (con progreso), lista de
/// canciones guardadas y reproduccion local.
class LibraryProvider extends ChangeNotifier {
  final ArchiveService _archive;
  final DownloadService _downloads;
  final LibraryStore _store;
  final AudioPlayer _player;

  LibraryProvider({
    ArchiveService? archive,
    DownloadService? downloads,
    LibraryStore? store,
    AudioPlayer? player,
  })  : _archive = archive ?? ArchiveService(),
        _downloads = downloads ?? DownloadService(),
        _store = store ?? LibraryStore(),
        _player = player ?? AudioPlayer() {
    _player.onPlayerComplete.listen((_) {
      _playingId = null;
      _playing = false;
      notifyListeners();
    });
  }

  // --- Biblioteca descargada ---
  List<DownloadedTrack> _tracks = [];
  List<DownloadedTrack> get tracks => _tracks;

  // --- Progreso de descargas en curso, por identifier (0..1, -1 = indefinido) ---
  final Map<String, double> _progress = {};
  Map<String, double> get progress => _progress;
  bool isDownloading(String identifier) => _progress.containsKey(identifier);

  bool hasTrack(String identifier) => _tracks.any((t) => t.id.startsWith(identifier));

  // --- Reproduccion ---
  String? _playingId;
  String? get playingId => _playingId;
  bool _playing = false;
  bool get isPlaying => _playing;

  Future<void> load() async {
    _tracks = await _store.load();
    notifyListeners();
  }

  // --- Busqueda ---
  Future<List<ArchiveItem>> search(String query) {
    return _archive.search(query);
  }

  // --- Descarga ---

  /// Descarga el primer archivo de audio (preferente mp3) de un item del
  /// Internet Archive y lo guarda en la biblioteca offline.
  Future<void> downloadItem(ArchiveItem item) async {
    if (isDownloading(item.identifier) || hasTrack(item.identifier)) return;

    _progress[item.identifier] = -1;
    notifyListeners();

    try {
      final files = await _archive.audioFiles(item.identifier);
      if (files.isEmpty) {
        throw DownloadException('El item no tiene archivos de audio.');
      }
      final file = files.first;
      final url = _archive.downloadUrlFor(item.identifier, file.name);

      final safeName = _safeFileName('${item.identifier}__${file.name}');
      final destPath = await _store.filePathFor(safeName);

      await _downloads.download(url, destPath, onProgress: (p) {
        _progress[item.identifier] = p;
        notifyListeners();
      });

      final track = DownloadedTrack(
        id: '${item.identifier}/${file.name}',
        title: file.title ?? item.title,
        artist: item.creator,
        album: item.title,
        license: item.licenseLabel,
        fileName: safeName,
        sourceUrl: url,
        downloadedAt: DateTime.now(),
      );

      _tracks = [track, ..._tracks];
      await _store.save(_tracks);
    } finally {
      _progress.remove(item.identifier);
      notifyListeners();
    }
  }

  Future<void> deleteTrack(DownloadedTrack track) async {
    if (_playingId == track.id) await stop();
    await _store.deleteFile(track.fileName);
    _tracks = _tracks.where((t) => t.id != track.id).toList();
    await _store.save(_tracks);
    notifyListeners();
  }

  // --- Reproduccion offline ---

  Future<void> togglePlay(DownloadedTrack track) async {
    final path = await _store.filePathFor(track.fileName);

    if (_playingId == track.id) {
      if (_playing) {
        await _player.pause();
        _playing = false;
      } else {
        await _player.resume();
        _playing = true;
      }
    } else {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      _playingId = track.id;
      _playing = true;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _playingId = null;
    _playing = false;
    notifyListeners();
  }

  String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
