/// Construye enlaces a servicios legales para CONSEGUIR una cancion:
/// comprarla (Bandcamp / iTunes-Apple Music) o abrirla para anadirla a tu
/// biblioteca (Spotify / Apple Music / YouTube Music).
///
/// Nada de esto descarga audio con copyright: son busquedas/enlaces a las
/// tiendas y servicios oficiales.
class LegalLinks {
  static String _query(String artist, String title) =>
      Uri.encodeComponent('$artist $title'.trim());

  /// Bandcamp: comprar directamente al artista (cuando esta disponible).
  static String bandcamp(String artist, String title) =>
      'https://bandcamp.com/search?q=${_query(artist, title)}';

  /// Apple Music / iTunes Store: comprar o anadir.
  static String appleMusic(String artist, String title) =>
      'https://music.apple.com/search?term=${_query(artist, title)}';

  /// YouTube Music.
  static String youtubeMusic(String artist, String title) =>
      'https://music.youtube.com/search?q=${_query(artist, title)}';

  /// Spotify: si tenemos el id exacto, abre la cancion (para anadir a playlist).
  /// Si no, cae a una busqueda en Spotify.
  static String spotify(String? spotifyId, String artist, String title) {
    if (spotifyId != null && spotifyId.startsWith('spotify:track:')) {
      final id = spotifyId.split(':').last;
      if (id.isNotEmpty) return 'https://open.spotify.com/track/$id';
    }
    return 'https://open.spotify.com/search/${_query(artist, title)}';
  }
}

/// Un destino para mostrar como boton.
class LegalDestination {
  final String label;
  final String url;
  const LegalDestination(this.label, this.url);
}

/// Lista de destinos para una cancion, en orden de utilidad.
List<LegalDestination> legalDestinationsFor({
  required String artist,
  required String title,
  String? spotifyId,
}) =>
    [
      LegalDestination('Spotify', LegalLinks.spotify(spotifyId, artist, title)),
      LegalDestination('Bandcamp', LegalLinks.bandcamp(artist, title)),
      LegalDestination('Apple Music', LegalLinks.appleMusic(artist, title)),
      LegalDestination('YouTube Music', LegalLinks.youtubeMusic(artist, title)),
    ];
