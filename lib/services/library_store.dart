import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/downloaded_track.dart';

/// Gestiona el almacenamiento local de la biblioteca offline:
///  - los archivos de audio en `documentos_app/library/`
///  - un indice JSON con los metadatos de cada descarga
///
/// Usa el directorio de documentos de la app, que NO requiere permisos de
/// almacenamiento en Android/iOS.
class LibraryStore {
  static const _indexName = 'index.json';

  Directory? _cachedDir;

  Future<Directory> _libraryDir() async {
    if (_cachedDir != null) return _cachedDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  Future<String> filePathFor(String fileName) async {
    final dir = await _libraryDir();
    return p.join(dir.path, fileName);
  }

  Future<File> _indexFile() async {
    final dir = await _libraryDir();
    return File(p.join(dir.path, _indexName));
  }

  Future<List<DownloadedTrack>> load() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .map((e) => DownloadedTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<DownloadedTrack> tracks) async {
    final file = await _indexFile();
    final data = tracks.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  /// Borra el archivo de audio de una descarga (si existe).
  Future<void> deleteFile(String fileName) async {
    final path = await filePathFor(fileName);
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
