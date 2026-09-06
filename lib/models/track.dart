/// Representa una cancion detectada, independientemente de la fuente
/// (Spotify hoy; Notification Listener / ShazamKit en el futuro).
class Track {
  /// Id de Spotify si viene de ahi (ej: "spotify:track:..."). Puede ser null
  /// para canciones detectadas por otras fuentes.
  final String? spotifyId;

  final String title;
  final String artist;
  final String album;

  /// URL de la caratula (la mayor disponible). Puede ser null.
  final String? artworkUrl;

  /// ISRC = codigo internacional unico de grabacion. Es la MEJOR clave para
  /// deduplicar ("¿ya tengo esta cancion?") porque no depende de mayusculas
  /// ni de como este escrito el titulo. Puede ser null si Spotify no lo da.
  final String? isrc;

  /// Duracion total y progreso actual, en milisegundos.
  final int? durationMs;
  final int? progressMs;

  /// Si esta sonando (true) o en pausa (false).
  final bool isPlaying;

  /// De donde vino la deteccion. Util cuando sumemos otras fuentes.
  final String source;

  const Track({
    this.spotifyId,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.isrc,
    this.durationMs,
    this.progressMs,
    this.isPlaying = false,
    this.source = 'spotify',
  });

  /// Clave estable para deduplicar en la base de datos local.
  /// Preferimos ISRC; si no hay, caemos a "titulo|artista" normalizado.
  String get dedupeKey {
    if (isrc != null && isrc!.isNotEmpty) return 'isrc:${isrc!.toLowerCase()}';
    final t = title.trim().toLowerCase();
    final a = artist.trim().toLowerCase();
    return 'ta:$t|$a';
  }

  /// Construye un Track desde la respuesta JSON del endpoint
  /// GET /v1/me/player/currently-playing de la Web API de Spotify.
  ///
  /// Devuelve null si el JSON no trae un item reproducible (por ejemplo,
  /// cuando esta sonando un podcast/episodio en vez de una cancion).
  static Track? fromCurrentlyPlayingJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>?;
    if (item == null) return null;

    // Solo tratamos "track". Los episodios de podcast tienen otra forma.
    final type = item['type'] as String?;
    if (type != null && type != 'track') return null;

    final artists = (item['artists'] as List?) ?? const [];
    final artistNames = artists
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');

    final album = item['album'] as Map<String, dynamic>?;
    final images = (album?['images'] as List?) ?? const [];
    final artworkUrl = images.isNotEmpty
        ? (images.first as Map<String, dynamic>)['url'] as String?
        : null;

    final externalIds = item['external_ids'] as Map<String, dynamic>?;

    return Track(
      spotifyId: item['uri'] as String?,
      title: item['name'] as String? ?? 'Desconocido',
      artist: artistNames.isEmpty ? 'Desconocido' : artistNames,
      album: album?['name'] as String? ?? '',
      artworkUrl: artworkUrl,
      isrc: externalIds?['isrc'] as String?,
      durationMs: item['duration_ms'] as int?,
      progressMs: json['progress_ms'] as int?,
      isPlaying: json['is_playing'] as bool? ?? false,
      source: 'spotify',
    );
  }

  @override
  String toString() => '$title — $artist';
}
