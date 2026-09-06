import 'package:flutter_test/flutter_test.dart';
import 'package:music_journal/models/track.dart';

void main() {
  group('Track.fromCurrentlyPlayingJson', () {
    test('parsea una cancion normal con ISRC y caratula', () {
      final json = {
        'is_playing': true,
        'progress_ms': 42000,
        'item': {
          'type': 'track',
          'uri': 'spotify:track:abc123',
          'name': 'Bohemian Rhapsody',
          'duration_ms': 354000,
          'external_ids': {'isrc': 'GBUM71029604'},
          'artists': [
            {'name': 'Queen'},
          ],
          'album': {
            'name': 'A Night at the Opera',
            'images': [
              {'url': 'https://img/large.jpg', 'height': 640, 'width': 640},
              {'url': 'https://img/small.jpg', 'height': 64, 'width': 64},
            ],
          },
        },
      };

      final track = Track.fromCurrentlyPlayingJson(json);

      expect(track, isNotNull);
      expect(track!.title, 'Bohemian Rhapsody');
      expect(track.artist, 'Queen');
      expect(track.album, 'A Night at the Opera');
      expect(track.isrc, 'GBUM71029604');
      expect(track.artworkUrl, 'https://img/large.jpg'); // la primera (mayor)
      expect(track.durationMs, 354000);
      expect(track.progressMs, 42000);
      expect(track.isPlaying, isTrue);
    });

    test('une varios artistas con coma', () {
      final json = {
        'is_playing': true,
        'item': {
          'type': 'track',
          'name': 'Song',
          'artists': [
            {'name': 'A'},
            {'name': 'B'},
          ],
          'album': {'name': 'X', 'images': []},
        },
      };

      final track = Track.fromCurrentlyPlayingJson(json);
      expect(track!.artist, 'A, B');
      expect(track.artworkUrl, isNull);
    });

    test('devuelve null si suena un podcast (no es track)', () {
      final json = {
        'is_playing': true,
        'currently_playing_type': 'episode',
        'item': {
          'type': 'episode',
          'name': 'Ep 1',
        },
      };
      expect(Track.fromCurrentlyPlayingJson(json), isNull);
    });

    test('devuelve null si no hay item', () {
      expect(Track.fromCurrentlyPlayingJson({'is_playing': false}), isNull);
    });
  });

  group('Track.dedupeKey', () {
    test('usa el ISRC cuando existe (independiente de mayusculas)', () {
      const a = Track(title: 'X', artist: 'Y', album: '', isrc: 'ABC123');
      expect(a.dedupeKey, 'isrc:abc123');
    });

    test('cae a titulo|artista normalizado sin ISRC', () {
      const a = Track(title: '  Song ', artist: 'Artist', album: '');
      const b = Track(title: 'song', artist: 'ARTIST', album: '');
      // Misma cancion escrita distinto -> misma clave.
      expect(a.dedupeKey, b.dedupeKey);
      expect(a.dedupeKey, 'ta:song|artist');
    });

    test('dos canciones con distinto ISRC no colisionan', () {
      const a = Track(title: 'X', artist: 'Y', album: '', isrc: 'AAA');
      const b = Track(title: 'X', artist: 'Y', album: '', isrc: 'BBB');
      expect(a.dedupeKey, isNot(b.dedupeKey));
    });
  });
}
