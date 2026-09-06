/// Un resultado de busqueda del Internet Archive (archive.org).
class ArchiveItem {
  final String identifier;
  final String title;
  final String creator;
  final String? year;
  final String? licenseUrl;

  const ArchiveItem({
    required this.identifier,
    required this.title,
    required this.creator,
    this.year,
    this.licenseUrl,
  });

  /// Etiqueta legible de la licencia.
  String get licenseLabel => licenseLabelFor(licenseUrl);

  /// True si la licencia es claramente libre (CC o dominio publico).
  bool get isOpenLicense => isOpenLicenseUrl(licenseUrl);

  /// Construye desde un doc de advancedsearch.php. Devuelve null si no hay id.
  static ArchiveItem? fromSearchDoc(Map<String, dynamic> doc) {
    final id = doc['identifier'] as String?;
    if (id == null || id.isEmpty) return null;
    return ArchiveItem(
      identifier: id,
      title: _first(doc['title']) ?? id,
      creator: _first(doc['creator']) ?? '',
      year: _first(doc['year'])?.toString(),
      licenseUrl: _first(doc['licenseurl']),
    );
  }

  static String? _first(dynamic v) {
    if (v is List) return v.isEmpty ? null : v.first?.toString();
    return v?.toString();
  }
}

/// Un archivo de audio concreto dentro de un item del Internet Archive.
class ArchiveAudioFile {
  final String name;
  final String? title;
  final int? sizeBytes;

  const ArchiveAudioFile({required this.name, this.title, this.sizeBytes});
}

// --- Helpers de licencia (logica pura, testeable) ---

const _audioExtensions = ['.mp3', '.flac', '.ogg', '.oga', '.m4a', '.wav', '.opus'];

bool isAudioFileName(String name) {
  final lower = name.toLowerCase();
  return _audioExtensions.any(lower.endsWith);
}

/// True si la URL de licencia es Creative Commons o dominio publico.
bool isOpenLicenseUrl(String? licenseUrl) {
  if (licenseUrl == null) return false;
  final u = licenseUrl.toLowerCase();
  return u.contains('creativecommons.org') || u.contains('publicdomain');
}

/// Convierte una URL de licencia en una etiqueta corta legible.
String licenseLabelFor(String? licenseUrl) {
  if (licenseUrl == null || licenseUrl.isEmpty) return 'Licencia desconocida';
  final u = licenseUrl.toLowerCase();
  if (u.contains('publicdomain')) return 'Dominio publico';
  if (u.contains('creativecommons.org')) {
    final match = RegExp(r'/licenses/([a-z-]+)/').firstMatch(u);
    return match != null ? 'CC ${match.group(1)!.toUpperCase()}' : 'Creative Commons';
  }
  return licenseUrl;
}
