/// Canción registrada por el servicio nativo de Android.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverPath,
    required this.detectedAt,
    this.descargado = false,
  });

  /// Mapa que envía la parte nativa (`Track.toMap()` en Kotlin).
  factory Track.fromMap(Map<Object?, Object?> map) => Track(
    id: map['id']! as String,
    title: map['title']! as String,
    artist: map['artist']! as String,
    coverPath: map['coverPath'] as String?,
    detectedAt: DateTime.fromMillisecondsSinceEpoch(map['detectedAt']! as int),
    descargado: map['descargado'] as bool? ?? false,
  );

  /// Track ID de Spotify (o `meta:título|artista` si Spotify no lo expone).
  final String id;
  final String title;
  final String artist;

  /// Ruta local de la portada (un JPEG pequeño), o `null` si no llegó.
  final String? coverPath;
  final DateTime detectedAt;

  /// Si ya se descargó su archivo: decide si sale en «Sin procesar» o en
  /// «Procesadas». Empieza en `false`.
  final bool descargado;

  Track copyWith({bool? descargado}) => Track(
    id: id,
    title: title,
    artist: artist,
    coverPath: coverPath,
    detectedAt: detectedAt,
    descargado: descargado ?? this.descargado,
  );
}
