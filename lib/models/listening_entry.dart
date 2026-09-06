import 'track.dart';

/// Un evento de escucha: "esta cancion sono en este momento".
/// Cada vez que se detecta una cancion NUEVA se guarda uno de estos.
/// El historial (diario) es la lista de estos eventos; las estadisticas
/// se calculan a partir de ellos.
class ListeningEntry {
  /// Id autoincremental de la base de datos (null hasta que se guarda).
  final int? id;

  /// Clave de deduplicacion (ISRC o titulo|artista). Ver [Track.dedupeKey].
  final String dedupeKey;

  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? isrc;
  final String? spotifyId;
  final String source;

  /// Momento en que se detecto la escucha.
  final DateTime playedAt;

  const ListeningEntry({
    this.id,
    required this.dedupeKey,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.isrc,
    this.spotifyId,
    this.source = 'spotify',
    required this.playedAt,
  });

  /// Crea una entrada a partir de un [Track] detectado ahora mismo.
  factory ListeningEntry.fromTrack(Track track, {DateTime? at}) {
    return ListeningEntry(
      dedupeKey: track.dedupeKey,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artworkUrl: track.artworkUrl,
      isrc: track.isrc,
      spotifyId: track.spotifyId,
      source: track.source,
      playedAt: at ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'dedupe_key': dedupeKey,
        'title': title,
        'artist': artist,
        'album': album,
        'artwork_url': artworkUrl,
        'isrc': isrc,
        'spotify_id': spotifyId,
        'source': source,
        'played_at': playedAt.millisecondsSinceEpoch,
      };

  factory ListeningEntry.fromMap(Map<String, Object?> map) => ListeningEntry(
        id: map['id'] as int?,
        dedupeKey: map['dedupe_key'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        album: map['album'] as String? ?? '',
        artworkUrl: map['artwork_url'] as String?,
        isrc: map['isrc'] as String?,
        spotifyId: map['spotify_id'] as String?,
        source: map['source'] as String? ?? 'spotify',
        playedAt:
            DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
      );
}

/// Ventana temporal para considerar dos detecciones como LA MISMA escucha.
/// Evita duplicados cuando dos fuentes (la Web API de Spotify y el Notification
/// Listener de Android) detectan la misma cancion casi a la vez.
const Duration kCrossSourceWindow = Duration(seconds: 30);

/// True si [track] NO debe registrarse por ser un duplicado reciente de
/// [lastEntry] (misma cancion dentro de [window]).
bool isDuplicatePlay({
  required Track track,
  required ListeningEntry? lastEntry,
  required DateTime now,
  Duration window = kCrossSourceWindow,
}) {
  if (lastEntry == null) return false;
  if (lastEntry.dedupeKey != track.dedupeKey) return false;
  return now.difference(lastEntry.playedAt).abs() < window;
}
