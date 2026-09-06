import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/archive_item.dart';

/// Cliente del Internet Archive (archive.org) para buscar y localizar audio
/// con licencia libre. Todo lo que descarga es dominio publico o Creative
/// Commons: catalogo legal por diseno.
class ArchiveService {
  static const _searchUrl = 'https://archive.org/advancedsearch.php';
  static const _metadataUrl = 'https://archive.org/metadata';
  static const _downloadUrl = 'https://archive.org/download';

  final http.Client _http;

  ArchiveService([http.Client? client]) : _http = client ?? http.Client();

  /// Busca items de audio. Por defecto solo devuelve licencias libres
  /// confirmadas (CC / dominio publico), igual que la herramienta de PC.
  Future<List<ArchiveItem>> search(
    String query, {
    int limit = 25,
    bool onlyOpenLicense = true,
  }) async {
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': '($query) AND mediatype:audio',
      'fl[]': ['identifier', 'title', 'creator', 'year', 'licenseurl'],
      'rows': '$limit',
      'sort[]': 'downloads desc',
      'output': 'json',
    });

    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      throw ArchiveException('Error de busqueda (${res.statusCode})');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (json['response']?['docs'] as List?) ?? const [];
    final items = docs
        .map((d) => ArchiveItem.fromSearchDoc(d as Map<String, dynamic>))
        .whereType<ArchiveItem>()
        .toList();

    if (onlyOpenLicense) {
      return items.where((i) => i.isOpenLicense).toList();
    }
    return items;
  }

  /// Devuelve los archivos de audio de un item, preferendo mp3.
  Future<List<ArchiveAudioFile>> audioFiles(String identifier) async {
    final res = await _http.get(Uri.parse('$_metadataUrl/$identifier'));
    if (res.statusCode != 200) {
      throw ArchiveException('No se pudo leer el item (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (json['files'] as List?) ?? const [];

    final audio = <ArchiveAudioFile>[];
    for (final f in files) {
      final map = f as Map<String, dynamic>;
      final name = map['name'] as String?;
      if (name == null || !isAudioFileName(name)) continue;
      audio.add(ArchiveAudioFile(
        name: name,
        title: map['title'] as String?,
        sizeBytes: int.tryParse(map['size']?.toString() ?? ''),
      ));
    }

    // mp3 primero (no depende de nada extra para reproducir).
    audio.sort((a, b) {
      final am = a.name.toLowerCase().endsWith('.mp3') ? 0 : 1;
      final bm = b.name.toLowerCase().endsWith('.mp3') ? 0 : 1;
      return am.compareTo(bm);
    });
    return audio;
  }

  /// URL de descarga directa de un archivo dentro de un item.
  String downloadUrlFor(String identifier, String fileName) {
    final encoded = Uri.encodeComponent(fileName);
    return '$_downloadUrl/$identifier/$encoded';
  }
}

class ArchiveException implements Exception {
  final String message;
  ArchiveException(this.message);
  @override
  String toString() => message;
}
