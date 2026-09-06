import 'listening_entry.dart';
import 'track.dart';

/// Una cancion que el usuario quiere conseguir por vias legales (comprar,
/// anadir a su playlist, etc.). El puente entre "lo que escucho" y "tenerlo",
/// sin descargar nada con copyright.
class WishlistItem {
  final String dedupeKey;
  final String title;
  final String artist;
  final String album;

  /// URI de Spotify si se conoce (spotify:track:...), para abrir la cancion.
  final String? spotifyId;

  final DateTime addedAt;

  const WishlistItem({
    required this.dedupeKey,
    required this.title,
    required this.artist,
    required this.album,
    this.spotifyId,
    required this.addedAt,
  });

  factory WishlistItem.fromEntry(ListeningEntry e) => WishlistItem(
        dedupeKey: e.dedupeKey,
        title: e.title,
        artist: e.artist,
        album: e.album,
        spotifyId: e.spotifyId,
        addedAt: DateTime.now(),
      );

  factory WishlistItem.fromTrack(Track t) => WishlistItem(
        dedupeKey: t.dedupeKey,
        title: t.title,
        artist: t.artist,
        album: t.album,
        spotifyId: t.spotifyId,
        addedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'dedupeKey': dedupeKey,
        'title': title,
        'artist': artist,
        'album': album,
        'spotifyId': spotifyId,
        'addedAt': addedAt.toIso8601String(),
      };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        dedupeKey: json['dedupeKey'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        spotifyId: json['spotifyId'] as String?,
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
