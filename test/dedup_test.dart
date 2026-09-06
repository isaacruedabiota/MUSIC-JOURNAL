import 'package:flutter_test/flutter_test.dart';
import 'package:music_journal/models/listening_entry.dart';
import 'package:music_journal/models/track.dart';

void main() {
  group('isDuplicatePlay (dedupe entre fuentes)', () {
    final now = DateTime(2026, 7, 1, 12, 0, 0);

    ListeningEntry lastAt(DateTime t, {String key = 'ta:song|artist'}) =>
        ListeningEntry(
          dedupeKey: key,
          title: 'Song',
          artist: 'Artist',
          album: '',
          playedAt: t,
        );

    const track = Track(title: 'Song', artist: 'Artist', album: '');

    test('sin entradas previas -> NO es duplicado (se registra)', () {
      expect(
        isDuplicatePlay(track: track, lastEntry: null, now: now),
        isFalse,
      );
    });

    test('misma cancion hace 5s (dos fuentes) -> ES duplicado (se ignora)', () {
      final last = lastAt(now.subtract(const Duration(seconds: 5)));
      expect(isDuplicatePlay(track: track, lastEntry: last, now: now), isTrue);
    });

    test('misma cancion hace 2min -> NO es duplicado (replay legitimo)', () {
      final last = lastAt(now.subtract(const Duration(minutes: 2)));
      expect(isDuplicatePlay(track: track, lastEntry: last, now: now), isFalse);
    });

    test('cancion distinta dentro de la ventana -> NO es duplicado', () {
      final last = lastAt(now.subtract(const Duration(seconds: 3)),
          key: 'ta:otra|artista');
      expect(isDuplicatePlay(track: track, lastEntry: last, now: now), isFalse);
    });

    test('justo en el borde de la ventana (30s) -> NO es duplicado', () {
      final last = lastAt(now.subtract(kCrossSourceWindow));
      expect(isDuplicatePlay(track: track, lastEntry: last, now: now), isFalse);
    });

    test('coincide por ISRC aunque el titulo cambie de formato', () {
      const spotify = Track(
          title: 'Song', artist: 'Artist', album: '', isrc: 'ABC123');
      final last = lastAt(now.subtract(const Duration(seconds: 4)),
          key: 'isrc:abc123');
      expect(
          isDuplicatePlay(track: spotify, lastEntry: last, now: now), isTrue);
    });
  });
}
