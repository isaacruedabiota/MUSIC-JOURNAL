/// Una cancion descargada y guardada en el dispositivo (biblioteca offline).
class DownloadedTrack {
  final String id; // identifier del Internet Archive + nombre de archivo
  final String title;
  final String artist;
  final String album;
  final String license;

  /// Nombre del archivo local (dentro de la carpeta library de la app).
  final String fileName;

  /// URL de origen (para referencia/atribucion).
  final String sourceUrl;

  final DateTime downloadedAt;

  const DownloadedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.license,
    required this.fileName,
    required this.sourceUrl,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'license': license,
        'fileName': fileName,
        'sourceUrl': sourceUrl,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) => DownloadedTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        license: json['license'] as String? ?? '',
        fileName: json['fileName'] as String,
        sourceUrl: json['sourceUrl'] as String? ?? '',
        downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
